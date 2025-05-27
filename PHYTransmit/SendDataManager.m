function txDiagnosticsAll = SendDataManager()
% SendDataManager - 在后台运行, 不需要任何输入参数
%                  在函数开头自己初始化内存映射句柄, 并检查interrupt标志
%
% 核心逻辑:
%   1. 通过 initStateMemmap() 打开/创建 UE_connection_state.bin 并得到m_connectStage
%   2. 通过 interrupt_reception_flag.bin 控制无限循环
%   3. 当 m_connectStage.Data.flag == 1 时, 生成并保存波形, 然后置flag=0
%   4. 不再根据阶段生成文本消息, 因为 ueConnectionStateManager 已经写好
%
% 注意:
%   - 需在外部先初始化 interrupt_reception_flag.bin, 并将其值置为1
%   - 当需要退出SendDataManager时, 将interrupt_reception_flag.bin置为0

    %=== 1) 初始化内存映射 (阶段 & flag) ===
    root_stagefile = './MAC/cache_file/';
    binName   = 'CBS_connection_state.bin';  
    binFullPath = fullfile(root_stagefile, binName);
    m_connectState = initStateMemmap(binFullPath); 
    % 现在 m_connectStage.Data.stage / m_connectStage.Data.flag 可用

    %=== 2) interrupt标志文件, 控制循环退出 ===
    root_rx = "./PHYReceive/cache_file/";
    flagFileName = 'interrupt_reception_flag.bin'; % 中断标志文件
    filename4 = fullfile(root_rx, flagFileName);
    if ~isfile(filename4)
        error('Interrupt flag file does not exist. Please initialize it in the main program.');
    end
    m_receiveCtlflag = memmapfile(filename4, 'Writable', true, 'Format', 'int8');
    % 当 m_receiveCtlflag.Data(1) == 0 时退出循环

    %=== 3) 其他需要的标志文件(示例) ===
    root_tx = "./PHYTransmit/cache_file/";
    sendFlagFileName = 'Send_flag.bin';
    filenameSendFlag = fullfile(root_tx, sendFlagFileName);
    if ~isfile(filenameSendFlag)
        fid = fopen(filenameSendFlag, 'w');
        fwrite(fid, 0, 'int8');  % 初始化
        fclose(fid);
    end
    m_sendDataFlag = memmapfile(filenameSendFlag, 'Writable', true, 'Format', 'int8');

    %=== 4) 用于保存最终生成的波形 ===
    waveformFileName = 'current_waveform.mat';
    waveformFilePath = fullfile(root_tx, waveformFileName);

    %=== 5) 初始化返回值数组(存放txDiagnostics) ===
    txDiagnosticsAll = {};

    %=== 6) CBS第一次运行时就要开始发送广播信号 ===
    txDiagnostics = genBroadcastingWaveform(waveformFilePath);
    txDiagnosticsAll{end+1} = txDiagnostics;
    % 告知下游(或USRP)有新数据
    m_sendDataFlag.Data(1) = 1;

    %=== 7) 主循环 ===
    while m_receiveCtlflag.Data(1) == 1
        if m_connectState.Data.flag == 1
            if m_connectState.Data.stage == 1
                % 这是一个不寻常的情况，这种情况只发生在连接中断超时后的重置条件下
                % 此时应当在CBS处发送广播信息
                txDiagnostics = genBroadcastingWaveform(waveformFilePath);
                txDiagnosticsAll{end+1} = txDiagnostics;

                % 告知下游(或USRP)有新数据
                m_sendDataFlag.Data(1) = 1;

                % 清除flag
                m_connectState.Data.flag = int8(0);
            else
                % 说明 ueConnectionStateManager 那边有新消息要发
                txDiagnostics = generateAndSaveWaveform(waveformFilePath);
                txDiagnosticsAll{end+1} = txDiagnostics;
    
                % 告知下游(或USRP)有新数据
                m_sendDataFlag.Data(1) = 1;
    
                % 清除连接状态改变导致的发送文件切换的flag
                m_connectState.Data.flag = int8(0);
            end
        end

        pause(10/1000);  % 每10ms检查一次, 视实际需求可改
    end

    disp('SendDataManager exited safely.');
end

%% ======== 生成并保存“广播”波形(示例) ========
function txDiagnostics = genBroadcastingWaveform(waveformFilePath)
    % 参数说明:
    % waveformFilePath: 保存波形文件的路径
    % saveTextFilename: 保存广播文本的文件路径

    % 1. 保存广播文本到指定文件
    broadcastingMessage = '[@CBS_ID 1] Initial Access Message'; % 定义广播文本
    saveTextFilename = '.\PHYTransmit\transmit_data.txt';
    fileID = fopen(saveTextFilename, 'w'); % 打开文件，以写模式清空并写入
    if fileID == -1
        error('无法打开文件：%s', saveTextFilename);
    end
    fprintf(fileID, '%s', broadcastingMessage); % 写入广播消息
    fclose(fileID);
    % 2. 生成并保存波形
    [txWaveform, txDiagnostics] = generateUSRPWaveform(); % 生成波形数据和诊断信息
    saveTxWaveform(waveformFilePath, txWaveform); % 保存生成的波形到指定路径
end

%% 仅示例: 生成&保存USRP波形
function txDiagnostics = generateAndSaveWaveform(waveformFilePath)
    [txWaveform, txDiagnostics] = generateUSRPWaveform();
    saveTxWaveform(waveformFilePath, txWaveform);
end

function [txWaveform, txDiagnostics] = generateUSRPWaveform()
    % generateUSRPWaveform: 生成用于控制基站（CBS）发送的物理层波形
    %
    % 功能：
    %   本函数生成控制基站（CBS）用于发送的物理层波形，适配 USRP 硬件。
    %   波形生成基于从 JSON 文件初始化的物理层（PHY）参数，这些参数是 CBS 自身
    %   的发送配置，与控制信令无关。
    %
    % 输出：
    %   txWaveform: 生成的发送波形，用于 USRP 硬件的物理层发送。
    %   txDiagnostics: 波形生成的诊断信息，包括波形格式化和调试信息。
    %
    % 功能描述：
    %   1. 读取和初始化 PHY 参数，包括通用参数和上行方向特定参数。
    %   2. 配置数据传输相关功能参数（如是否启用调试输出）。
    %   3. 生成 OFDM 波形，返回发送波形和诊断信息。
    %
    % 示例：
    %   % 调用函数生成波形
    %   [txWaveform, txDiagnostics] = generateUSRPWaveform();
    %
    % 注意：
    %   - 该函数仅适用于 CBS 自身发送物理层波形。
    %   - JSON 文件包含所有必要的物理层参数，需与控制信令传输协议保持一致。

    % Step 1: 初始化发送所需的 PHY 参数
    % 从 JSON 文件加载物理层参数，方向为 'downlink'（发送下行信号）
    PHYParams = initializePHYParams('downlink');

    % Step 2: 配置功能参数（本地配置，用于调试和波形生成控制）
    cfg = struct();
    cfg.enableScopes = false;        % 是否启用波形可视化
    cfg.verbosity = false;           % 是否启用详细调试信息
    cfg.printData = false;           % 是否打印数据块
    cfg.enableConst_measure = false; % 是否启用星座图测量

    % Step 3: 格式化 PHY 参数
    % 使用 reformatPHYParams 函数将 JSON 加载的参数格式化为 OFDM 和数据传输参数
    [OFDMParams, dataParams] = reformatPHYParams(PHYParams, cfg);

    % Step 4: 生成系统参数并从文件中加载数据块
    % 调用 helperOFDMSetParamsSDR 生成系统配置和初始数据块
    [sysParam, txParam, trBlk] = helperOFDMSetParamsSDR(OFDMParams, dataParams, 'tx');

    % 初始化数据块到传输参数中
    txParam.txDataBits = trBlk;

    % Step 5: 初始化发送对象
    % 调用 helperOFDMTxInit 初始化波形生成对象
    txObj = helperOFDMTxInit(sysParam);

    % Step 6: 生成发送波形
    % 调用 helperOFDMTx 生成 OFDM 波形并获取诊断信息
    [txOut, txGrid, txDiagnostics] = helperOFDMTx(txParam, sysParam, txObj);

    % Step 7: 可选的调试与可视化
    % 如果启用了调试信息输出，绘制 OFDM 资源块网格
    if dataParams.verbosity
        helperOFDMPlotResourceGrid(txGrid, sysParam);
    end

    % Step 8: 返回结果
    % 输出生成的波形和诊断信息
    txWaveform = txOut;
end


function saveTxWaveform(filename, txWaveform)
    save(filename, 'txWaveform');
end

