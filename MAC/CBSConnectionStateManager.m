function UE_ID = CBSConnectionStateManager(rxDataBits, rxDiagnostics, sysParam, m_connectState, m_controlParamState)
% CBS端：管理当前与用户建立连接的状态，决定阶段跳转并更新要发送的消息
%
% 输入:
%   rxDataBits      : 接收的比特流(已做过CRC校正)
%   rxDiagnostics   : 其中包含 dataCRCErrorFlag 等诊断信息
%   sysParam        : 系统参数(包含 CBS_ID)
%   mmHandle        : 来自 initStateMemmap(...) 的 memmapfile 句柄
%                     其中:
%                       mmHandle.Data.stage (int8)
%                       mmHandle.Data.flag  (int8)
%
% 注意:
%   - CBS 的初始阶段为 1（无阶段0），阶段上限为3 (1->2->3)。
%   - 当 CBS 收到 UE 的消息时，解析其中的 @UE_ID 并进行阶段判断：
%       1) 若当前是阶段1，期望找到UE的 "RACH Request" 才能进入阶段2；
%       2) 若阶段2，期望"Received Response"之类的，进入阶段3；
%       3) 阶段3及以上，视为已连接完毕，或保持不变。
%   - mmHandle这里使用了两个结构字段: stage 和 flag.
%   - CBS与UE的连接阶段字符串通过 getBaseStageMsgs() 获取, 并在 CBS 侧, 动态解析当前收到的UE_ID (从 recData 中提取) 
%   - 通过rePlaceholders() 替换getBaseStageMsgs获取的阶段字符串.
%   - 若无法解析到 UE_ID, 跳过阶段更新

    %% 1. 日志文件准备
    root_logfile = './MAC/logs/';
    logFilename  = 'CBS_connection_verbosity_log.txt';
    logFullPath  = fullfile(root_logfile, logFilename);
    CBS_fieldname = sprintf('CBS_ID_%d', sysParam.CBS_ID);
    verbosity_log = false;       % 如果为 false, 就不会写详细日志

    %=== 打开日志文件, 并保持fidLog全程有效 ===
    if ~isfile(logFullPath)
        fidLog = fopen(logFullPath, 'w');   % 如果日志不存在，就新建文件并写入
        fprintf(fidLog, '--- Start CBSConnectionStateManager() ---\n');
        fclose(fidLog);
    end
    
    limitLogFile(logFullPath);
    if verbosity_log
        fidLog = fopen(logFullPath, 'a');   % 日志已经存在，附加在后面继续写
        if fidLog == -1
            error('Cannot open log file "%s" for writing.', logFullPath);
        end
        
        %=== 在异常或函数结束时，统一关闭文件句柄 ===
        cleanupObj = onCleanup(@() fclose(fidLog));
        fprintf(fidLog, '\n');
    end
    % 1.1 关键日志文件（仅写关键阶段）
    briefLogName = 'CBS_connection_brief_log.txt';
    briefLogPath = fullfile(root_logfile, briefLogName);

    % 如果简明日志不存在，则写入初始说明
    if ~isfile(briefLogPath)
        fidBriefInit = fopen(briefLogPath, 'w');
        fprintf(fidBriefInit, '********** connection state history **********\n');
        fclose(fidBriefInit);
    end
    
    %=== 不需要一直打开，可以在写入时再 'a' 打开，然后写完就关闭。
    %=== 因为关键信息出现频率较低，这样即可。
    %% 2. 读取当前 stage/flag (老的值)
    oldStage = m_connectState.Data.stage;  % int8
    oldFlag  = m_connectState.Data.flag;   % int8 (这里可能没啥用, 可忽略)
    
    %% 3. 将 rxDataBits 解码为字符串 recData
    if isempty(rxDataBits)
        recData = '';
    else
        numBitsToDecode = length(rxDataBits) - mod(length(rxDataBits), 7);
        if numBitsToDecode <= 0
            recData = '';
        else
            recData = char(bit2int(reshape(rxDataBits(1:numBitsToDecode), 7, []), 7));
        end
    end
    if verbosity_log
        writeLog(fidLog, sprintf('Received Data: "%s"', recData), CBS_fieldname, oldStage, rxDiagnostics);
    end
    %% 4. 检查 CRC
    if rxDiagnostics.dataCRCErrorFlag
        if verbosity_log
            writeLog(fidLog, 'CRC Error detected, ignoring this packet.', CBS_fieldname, oldStage, rxDiagnostics);
        end
        UE_ID = [];
        return;
    end

    %% 5.1. 动态解析UE_ID (从 recData 中查找)
    UEIDParsed = parseUEIDFromRxData(recData);  % 自定义解析函数
    if ~isempty(UEIDParsed)
        % 如果成功解析到 UE_ID, 更新 UE_ID
        UE_ID = UEIDParsed;
        if verbosity_log
            writeLog(fidLog, sprintf('Parsed UE_ID = %d from recData.', UEIDParsed), CBS_fieldname, oldStage, rxDiagnostics);
        end
    else
        % 未解析到CBSID, 跳出本次状态更新.
        if verbosity_log
            writeLog(fidLog, 'No UE_ID found in recData. No UE message. skip updates.', CBS_fieldname, oldStage, rxDiagnostics);
        end
        UE_ID = [];
        return
    end

    %% 5.2. 拿到阶段字符串模板, 并替换 @UE_ID / @CBS_ID
    ueBaseMsgs     = getBaseStageMsgs('UE');
    ueStageMsgs  = rePlaceholders(ueBaseMsgs, UE_ID, sysParam.CBS_ID);

    cbsBaseMsgs  = getBaseStageMsgs('CBS');
    % 这里 CBSID 肯定是 sysParam.CBS_ID, 而 UEID 不一定能解析到.
    cbsStageMsgs = rePlaceholders(cbsBaseMsgs, UE_ID, sysParam.CBS_ID);

    %% 6. 阶段判断逻辑
    newStage = oldStage;  % 默认保持不变
    
    if oldStage < 3
        % 假设 CBS 阶段1 对应 UE 发送"[@UE_ID x] RACH Request Message[@CBS_ID x]"
        % CBS 阶段2 对应 UE 发送"[@UE_ID x] Received Response..."
        % 你可以自己决定要如何匹配
        expectedUeMsg = ueStageMsgs{oldStage + 1};  
        % 例如 oldStage=1 -> ueStageMsgs{2} = "[@UE_ID x] RACH Request..."
        % oldStage=2 -> ueStageMsgs{3} = "[@UE_ID x] Received Response..."

        if contains(recData, expectedUeMsg)
            newStage = oldStage + 1;
            if verbosity_log
                writeLog(fidLog, sprintf('ACK FROM @UE_ID %d -> STATE TRANSITIONS FROM %d TO %d', UE_ID, oldStage, newStage), ...
                         CBS_fieldname, oldStage, rxDiagnostics);
            end
        else
            if verbosity_log
                if oldStage == 1
                writeLog(fidLog, sprintf('NO VALID UE RESPONSE, REMAINS IN STATE %d', oldStage), ...
                         CBS_fieldname, oldStage, rxDiagnostics);
                else
                writeLog(fidLog, sprintf('@UE_ID %d NO ACK.....REMAINS in state %d', UE_ID, oldStage), ...
                     CBS_fieldname, oldStage, rxDiagnostics);
                end
            end
        end
    elseif oldStage == 3
        % 检查控制参数是否更新完毕
        controlParamsFlag = checkControlParamsFlag(m_controlParamState);  % 自定义函数，返回布尔值
        if controlParamsFlag
            % 控制参数更新完毕，进入阶段4
            pause(1)    % 等待1s，让UE过渡
            newStage = oldStage + 1;
            if verbosity_log
                writeLog(fidLog, sprintf('CONTROL PARAMETERS UPDATED AND PREPARE FOR SENDING, STATE TRANSITIONS FROM %d TO %d', oldStage, newStage), ...
                    CBS_fieldname, oldStage, rxDiagnostics);
            end
        else
            % 控制参数未更新，检查并维持阶段3的稳定连接状态
            expectedUeMsg = ueStageMsgs{oldStage+1};  
            if contains(recData, expectedUeMsg)
                if verbosity_log
                     writeLog(fidLog, sprintf('ALREADY in STATE %d (CONNECTED WITH @UE_ID %d), NO FURTHER TRANSITIONS.',oldStage, UE_ID), ...
                                         CBS_fieldname, oldStage, rxDiagnostics);            
                end
                m_connectState.Data.enterTimeSec = posixtime(datetime('now')); % 记录进入新阶段的时间(秒)
    
            else
                if verbosity_log
                    writeLog(fidLog, sprintf('@UE_ID %d NO ACK.....REMAINS in state %d', UE_ID, oldStage), ...
                         CBS_fieldname, oldStage, rxDiagnostics);
                end
            end
        end

    elseif oldStage == 4
        % 检测UE的回复，检测UE是否做好了接受控制参数的准备
        expectedUeMsg = ueStageMsgs{oldStage+1}; 
        if contains(recData, expectedUeMsg)  % 检测是否接收到预期消息
            newStage = oldStage+1;  % 收到确认后进入阶段5
            if verbosity_log
                writeLog(fidLog, sprintf('RECEIVED PREPARE ACK FROM @UE_ID %d -> START SENDING CTSG AND STATE TRANSITIONS FROM %d TO %d', UE_ID, oldStage, newStage), ...
                    CBS_fieldname, oldStage, rxDiagnostics);
            end
        else
            if verbosity_log
                writeLog(fidLog, sprintf('@UE_ID %d NO ACK.....REMAINS in state %d', UE_ID, oldStage), ...
                     CBS_fieldname, oldStage, rxDiagnostics);
            end
        end
    elseif oldStage == 5
        % 已经发送完控制参数文件，只需要等待UE的回应即可，如果UE回应接受到了控制参数文件
        % 那么CBS立即进入state 3，继续保持稳定连接，同时等待下一个控制参数生成信号
        % 如果UE未收到回应，那么CBS继续等待回应，直到连接超时，状态重置。
        % （这里可以进一步优化，即加入重传，重新发送控制参数（可以设定一个重新发送次数的阈值，这里同时也需要一个计时器来判断）而不是直接退回最初状态重新建立连接
        expectedUeMsg = ueStageMsgs{oldStage+1};  
        if contains(recData, expectedUeMsg)
            newStage = 3;  % 收到ACK后返回阶段3（稳定连接阶段）
            if verbosity_log
                 writeLog(fidLog, sprintf('CONTROLING SIGNAL TRANSMISSION COMPLETE! RETURN to STAGE %d (KEEP CONNECTED WITH @UE_ID %d).',newStage, UE_ID), ...
                                     CBS_fieldname, oldStage, rxDiagnostics);            
            end
        else
            if verbosity_log
                writeLog(fidLog, sprintf('@UE_ID %d NO ACK.....REMAINS in state %d', UE_ID, oldStage), ...
                     CBS_fieldname, oldStage, rxDiagnostics);
            end
        end
    else
        error('Undefined CBS Stage!')
    end


    %% 7. 更新 mmHandle.Data并将发送消息存储进发送文件中
    m_connectState.Data.stage = int8(newStage);
    if newStage ~= oldStage
        % CBS 在进入新阶段后，要发送给UE的消息(可选)
        % 例如:
        %   if newStage=2 -> 发送 "[@CBS_ID x] RACH Response Message[@UE_ID x]"
        %   if newStage=3 -> 发送 "[@CBS_ID x] Connected with [@UE_ID x]"
        %   if newStage=4 -> 发送 "[@CBS_ID x] Prepare for Sending Control Parameters to [@UE_ID x]"
        %   if newStage=5 -> 直接发送 JSON 文件
        if newStage == 5
        % 阶段5：发送控制参数JSON文件, 这里需要对JSON文件格式化，使控制参数文件符合建立连接中符合解读要求的格式
            controlParamsFile = './RRC/DownlinkControlParams.json';
            if isfile(controlParamsFile)
                % 1) 读取 JSON 文件内容
                rawJsonStr = fileread(controlParamsFile); 
                
                % 2) 构造消息头尾
                %    假设在我们的系统中, UE_ID 与 CBS_ID 已在上面解析并保存在 UE_ID, sysParam.CBS_ID 等变量
                prefixStr = sprintf('[@CBS_ID %d]', sysParam.CBS_ID);
                suffixStr = sprintf('[@UE_ID %d]', UE_ID);
                
                % 3) 合并为完整消息, 其中中间的 rawJsonStr 即原始控制参数文本
                %    可以加空格或换行分隔, 避免和 JSON 内容混淆
                txMsg = sprintf('%s %s %s', prefixStr, rawJsonStr, suffixStr);
                
                % 这里需要注意，由于控制参数的文本长度超过5000个bit，故要采用大容量的传输参数来实现一帧内的数据传输。（这里可以进一步考虑如何使用多帧分段传输一个大文件？）

                % 4) 写入发射文件
                saveTextFilename = '.\PHYTransmit\transmit_data.txt';
                writeMessageToFile(saveTextFilename, txMsg);
            
                % 5) 设置发送标志, 记录时间戳
                m_connectState.Data.flag = int8(1);
                m_connectState.Data.enterTimeSec = posixtime(datetime('now'));
            
                % 6) 日志记录
                if verbosity_log
                    writeLog(fidLog, 'CBS -> Sent Control Parameters JSON file.', CBS_fieldname, newStage, rxDiagnostics);
                end
            
                % 7) 简明日志
                appendBriefLog(briefLogPath, oldStage, newStage, UE_ID, sysParam.CBS_ID, rxDiagnostics, recData, ...
                               'Control Parameters JSON File');

            else
                % 如果JSON文件不存在，抛出错误
                if verbosity_log
                    writeLog(fidLog, 'Error: Control Parameters file not found. Cannot proceed.', CBS_fieldname, newStage, rxDiagnostics);
                end
                error('Error: Control Parameters file not found. Cannot proceed')
            end
        else
            % 处理其他阶段的普通文本消息发送逻辑
            txMsg = cbsStageMsgs{newStage};
            if ~isempty(txMsg)
                if verbosity_log
                    writeLog(fidLog, sprintf('CBS -> Will send: "%s"', txMsg), CBS_fieldname, newStage, rxDiagnostics);
                end
    
                %=== 同时也要将关键信息写到简明日志 ===
                appendBriefLog(briefLogPath, oldStage, newStage, UE_ID, sysParam.CBS_ID, rxDiagnostics, recData, txMsg);
     
                % 写入(覆盖)到 ./PHYTransmit/transmit_data.txt, 让SendDataManager发下行波形
                saveTextFilename = '.\PHYTransmit\transmit_data.txt';
                writeMessageToFile(saveTextFilename, txMsg);
    
                % 并置 flag=1, 告知SendDataManager(或其他机制)有新的数据需要发射
                m_connectState.Data.flag = int8(1);
                m_connectState.Data.enterTimeSec = posixtime(datetime('now')); % 记录进入新阶段的时间(秒)
            else
                if verbosity_log
                    writeLog(fidLog, sprintf('In stage %d, no CBS message to send.', newStage), CBS_fieldname, newStage, rxDiagnostics);
                end
                m_connectState.Data.flag = int8(0);
                m_connectState.Data.enterTimeSec = posixtime(datetime('now')); % 记录进入新阶段的时间(秒)
            end
        end
    end

end

%% =============== 辅助函数 ===============
function writeLog(fid, msg, prefix, statefield, rxDiagnostics)
    % 利用已有的fid, 直接fprintf追加写
    crt_frameNum = rxDiagnostics.frameNum;
    crt_msgNum = rxDiagnostics.messageNum;
    fprintf(fid, '[%s msg:%d frame:%d](STATE_%d) %s\n', prefix, crt_msgNum, crt_frameNum, statefield, msg);
end

function limitLogFile(logFilePath)
    % 检查文件是否存在
    maxLines = 10000;

    % 读取文件内容
    fileID = fopen(logFilePath, 'r');
    if fileID == -1
        error('无法打开文件：%s', logFilePath);
    end

    % 按行读取文件内容
    fileContent = textscan(fileID, '%s', 'Delimiter', '\n');
    fclose(fileID);

    lines = fileContent{1}; % 获取所有行的内容
    numLines = length(lines); % 获取行数

    if numLines > maxLines
        lines = lines(1); % 保留第一行内容
    else
        % 如果行数未超过 maxLines，不做任何修改
        return;
    end

    % 写回文件
    fileID = fopen(logFilePath, 'w');
    if fileID == -1
        error('无法打开文件：%s', logFilePath);
    end
    fprintf(fileID, '%s\n', lines{:}); % 按行写入文件
    fclose(fileID);

end


function UE_ID = parseUEIDFromRxData(recData)
% 解析 recData 中所有形如:
%   "[@UE_ID  123]"
% 的段落, 并返回最后一个出现的数字(作为 UE_ID).
% 如果没找到, 返回 [].
% 如果要记录所有出现的 UE_ID，也可以把 tokens 全部转换成数组返回。

    % 使用正则表达式, 捕获 (数字) 到 tokens
    % 说明: \s+ 表示一个或多个空白, \d+ 表示一个或多个数字
    pattern = '\[@UE_ID\s+(\d+)\]';

    % tokens 形如 {{'1'},{'1'},{'1'},...} 若匹配多个
    tokens = regexp(recData, pattern, 'tokens');
    
    if ~isempty(tokens)
        % 取最后一个匹配, tokens{end} 是形如 {'123'}
        % 如果想要第一个出现而非最后一个，则用 tokens{1}{1}。
        UEIDstr = tokens{end}{1};  
        UE_ID = str2double(UEIDstr);
    else
        UE_ID = [];
    end
end

function finalStageMsgs = rePlaceholders(baseStageMsgs, ueID, cbsID)
% 将 baseStageMsgs 中的 @UE_ID, @CBS_ID 替换为实际的数字ID
%
% 输入:
%   baseStageMsgs : 形如 {...} 的字符串 cell
%   ueID, cbsID   : 要替换的数值或字符串
%
% 输出:
%   finalStageMsgs: 替换完成的字符串 cell

    finalStageMsgs = cell(size(baseStageMsgs));
    ueID_str  = sprintf('@UE_ID %d', ueID);
    cbsID_str = sprintf('@CBS_ID %d', cbsID);

    for k = 1:length(baseStageMsgs)
        msg = baseStageMsgs{k};
        msg = strrep(msg, '@UE_ID',  ueID_str);
        msg = strrep(msg, '@CBS_ID', cbsID_str);
        finalStageMsgs{k} = msg;
    end
end

function appendBriefLog(briefLogPath, oldStage, newStage, ueID, cbsID, rxDiagnostics, receivedDataStr, txMsg)
% 当 newStage ~= oldStage 时写关键信息到简明日志:
%   1. Received Data
%   2. Parsed UE_ID
%   3. ACK FROM UE -> ...
%   4. Will send message: ...
% 其中 CBS_ID 在本函数命名为 cbsID, UE_ID = ueID

    fid = fopen(briefLogPath, 'a');
    if fid == -1
        error('Cannot open brief log file "%s" for appending.', briefLogPath);
    end
    fprintf(fid, '\n');
    fprintf(fid, '----------------%s----------------\n', datetime('now'));

    % messageNum, frameNum
    msgNum   = rxDiagnostics.messageNum;
    frameNum = rxDiagnostics.frameNum;
    if newStage == 4
        % 1) Parsed UE_ID
        fprintf(fid, '[CBS_ID_%d msg:%d frame:%d](STATE_%d) Parsed UE_ID = %d from recData.\n', ...
            cbsID, msgNum, frameNum, oldStage, ueID);
        % 2) CLAIM CONTROL SIGNALING IS READY (显示 oldStage -> newStage)
        fprintf(fid, '[CBS_ID_%d msg:%d frame:%d](STATE_%d) CONTROL SIGNALING IS READY, PREPARE TO SEND! -> STATE TRANSITIONS FROM %d TO %d\n', ...
            cbsID, msgNum, frameNum, oldStage, oldStage, newStage);
        % 3) 若 txMsg 非空, 记"Will send message: ...", 这时 STATE 已变成 newStage
        fprintf(fid, '[CBS_ID_%d msg:%d frame:%d](STATE_%d) Will send message: "%s"\n', ...
            cbsID, msgNum, frameNum, newStage, txMsg);
      
    else
        % 1) Received Data
        fprintf(fid, '[CBS_ID_%d msg:%d frame:%d](STATE_%d) Received Data: "%s"\n', ...
            cbsID, msgNum, frameNum, oldStage, receivedDataStr);
    
        % 2) Parsed UE_ID
        fprintf(fid, '[CBS_ID_%d msg:%d frame:%d](STATE_%d) Parsed UE_ID = %d from recData.\n', ...
            cbsID, msgNum, frameNum, oldStage, ueID);
    
        % 3) ACK RECEIVING (显示 oldStage -> newStage)
            fprintf(fid, '[CBS_ID_%d msg:%d frame:%d](STATE_%d) ACK FROM UE_ID %d -> STATE TRANSITIONS FROM %d TO %d\n', ...
                cbsID, msgNum, frameNum, oldStage, ueID, oldStage, newStage);
        % 4) 若 txMsg 非空, 记"Will send message: ...", 这时 STATE 已变成 newStage
        fprintf(fid, '[CBS_ID_%d msg:%d frame:%d](STATE_%d) Will send message: "%s"\n', ...
            cbsID, msgNum, frameNum, newStage, txMsg);
    end

    fclose(fid);
end

function writeMessageToFile(filename, message)
    % 将message覆盖写到filename
    fileID = fopen(filename, 'w');
    if fileID == -1
        error('Cannot open file "%s" for writing.', filename);
    end
    fprintf(fileID, '%s', message);
    fclose(fileID);
end
