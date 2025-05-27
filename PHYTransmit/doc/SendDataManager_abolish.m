function txDiagnosticsAll = SendDataManager()
% 初始化文件路径和发送数据flag文件。如果该flag文件不存在，则创建并初始化它。
% 定义一个无限循环来生成发送数据。根据连接阶段生成相应的数据并将其保存到波形文件中。
% 设置发送数据的flag，然后等待一段时间后进入下一个阶段。
    % 文件路径设置
    root_rx = "./downlink_receive/cache_file/";
    flagFileName = 'interrupt_reception_flag.bin'; % 中断标志文件
    filename4 = fullfile(root_rx, flagFileName);
    % 加载中断标志文件（由主程序初始化）
    if ~isfile(filename4)
        error('Interrupt flag file does not exist. Please initialize it in the main program.');
    end
    m_receiveCtlflag = memmapfile(filename4, 'Writable', true, 'Format', 'int8');

    root_tx = "./uplink_transmit/cache_file/";
    sendFlagFileName = 'Send_flag.bin';
    filename5 = fullfile(root_tx, sendFlagFileName);
    % 创建或加载发送数据flag
    if ~isfile(filename5)
        fid = fopen(filename5, 'w');
        fwrite(fid, 0, 'int8');  % 初始化 flag 为 0
        fclose(fid);
    end
    m_sendDataFlag = memmapfile(filename5, 'Writable', true, 'Format', 'int8');
 
    testfile = 'change_transmit_file.bin';
    testfile = fullfile(root_tx, testfile);
    % 创建或加载发送数据flag
    if ~isfile(testfile)
        fid = fopen(testfile, 'w');
        fwrite(fid, 0, 'int8');  % 初始化 flag 为 0
        fclose(fid);
    end
    m_changeflag = memmapfile(testfile, 'Writable', true, 'Format', 'int8');
    m_changeflag.Data(1) = 0;

    waveformFileName = 'current_waveform.mat';
    waveformFilePath = fullfile(root_tx, waveformFileName);
    % 初始化连接阶段
    currentStage = 1;
    % 初始化返回值数组（单元格数组）
    txDiagnosticsAll = {};

    txDiagnostics = sendDataManagercfg(currentStage, waveformFilePath);
    txDiagnosticsAll{end+1} = txDiagnostics;  % 将结果存入单元格数组

    % 无限循环，不断生成发送数据
    while m_receiveCtlflag.Data(1)
        % 模拟步骤进行
        % fprintf('Generated data for stage %d\n', currentStage);
        % 检查是否接收到预期的信号
        if m_changeflag.Data(1)
            % 接收到，则进行下一个发送阶段数据的准备
            currentStage = currentStage + 1;
            % 如果下一阶段越界，进行修正
            if currentStage > 5
                currentStage = 1; % 循环回到第一个阶段
            end
            % 根据当前连接阶段生成发送数据
            txDiagnostics = sendDataManagercfg(currentStage, waveformFilePath);
            txDiagnosticsAll{end+1} = txDiagnostics;  % 将结果存入单元格数组

            % 设置发送数据的 flag
            m_sendDataFlag.Data(1) = 1;
            m_changeflag.Data(1) = 0;
        end

        % 等待一段时间，再生成下一阶段的数据（模拟不同连接阶段）
        pause(1);  % 这里的时间可以根据实际需求调整
    end

    % 最终退出时返回诊断数据
    disp('SendDataManager exited safely.');
end

function received = checkReceivedSignal(stage)
    % 模拟信号检查过程
    % 根据实际需求实现接收信号的检查逻辑
    % 这里简单模拟为随机接收信号
    received = rand() > 0.5;  % 随机决定是否接收到信号
end

function txDiagnostics = sendDataManagercfg(step, filename)
% 根据不同阶段生成相应的数据并保存到统一的文本文件uplink_transmit/transmit_data.txt。
% 然后生成USRP发送波形并保存到文件中。
    % 定义每个步骤的标识符
    INITIAL_ACCESS = 1;
    RACH_REQUEST = 2;
    RACH_RESPONSE = 3;
    CONNECTION_SETUP = 4;
    CONNECTION_COMPLETE = 5;
    
    saveTextFilename = '.\uplink_transmit\transmit_data.txt';
    % 根据步骤生成相应的数据并保存到统一的文本文件
    switch step
        case INITIAL_ACCESS
            saveToFile(saveTextFilename, '[@CBS_ID 1] Initial Access Message');
        case RACH_REQUEST
            saveToFile(saveTextFilename, 'RACH Request Message');
        case RACH_RESPONSE
            saveToFile(saveTextFilename, 'RACH Response Message');
        case CONNECTION_SETUP
            saveToFile(saveTextFilename, 'Connection Setup Message');
        case CONNECTION_COMPLETE
            saveToFile(saveTextFilename, 'Connection Complete Message');
        otherwise
            error('Unknown step');
    end

    % 生成USRP发送波形
    [txWaveform, txDiagnostics] = generateUSRPWaveform();

    % 通过内存映射或文件保存波形
    saveTxWaveform(filename, txWaveform);
end

function saveToFile(filename, message)
    % 将消息保存到统一的文本文件
    fileID = fopen(filename, 'w');
    fprintf(fileID, '%s', message);
    fclose(fileID);
end

function [txWaveform, txDiagnostics] = generateUSRPWaveform()
    % 使用实际OFDM参数生成波形,这里的传输参数是针对UE1，上行发送的特定配置参数
    overAllOfdmParams.online_BS = 1;
    overAllOfdmParams.FFTLength = 1024;
    overAllOfdmParams.CPLength = ceil(overAllOfdmParams.FFTLength * 0.25);
    overAllOfdmParams.PilotSubcarrierSpacing = 36;
    total_RB = 67;

    [RB_verified, MaxRB] = calculateRBFinal(overAllOfdmParams, total_RB);
    if total_RB > MaxRB || RB_verified > MaxRB
        error('Error: Defined RB (%d) exceeds the system maximum allowed RB (%d).', RB_verified, MaxRB);
    end

    overAllOfdmParams.total_RB = total_RB;
    overAllOfdmParams.total_NumSubcarriers = overAllOfdmParams.total_RB * 12;
    overAllOfdmParams.guard_interval = (overAllOfdmParams.FFTLength - overAllOfdmParams.total_NumSubcarriers) / 2;

    if overAllOfdmParams.total_NumSubcarriers > overAllOfdmParams.FFTLength
        error('Total NumSubcarriers: (%d) exceeds Total FFTLength: (%d). Please reduce the value of RB.', ...
            overAllOfdmParams.total_NumSubcarriers, overAllOfdmParams.FFTLength);
    end

    BS_id = 1;
    BWPoffset = 0;
    [alloc_RadioResource, all_radioResource] = calculateBWPs(overAllOfdmParams, BS_id, BWPoffset);

    OFDMParams.online_BS = overAllOfdmParams.online_BS;
    OFDMParams.BS_id = BS_id;
    OFDMParams.BWPoffset = BWPoffset;
    OFDMParams.FFTLength = overAllOfdmParams.FFTLength;
    OFDMParams.CPLength = overAllOfdmParams.CPLength;
    OFDMParams.PilotSubcarrierSpacing = overAllOfdmParams.PilotSubcarrierSpacing;
    OFDMParams.NumSubcarriers = alloc_RadioResource.UsedSubcc;
    OFDMParams.subcarrier_start_index = alloc_RadioResource.subcarrier_start_index;
    OFDMParams.subcarrier_end_index = alloc_RadioResource.subcarrier_end_index;
    OFDMParams.subcarrier_center_offset = alloc_RadioResource.subcarrier_center_offset;
    OFDMParams.Subcarrierspacing = 30e3;
    OFDMParams.guard_interval = overAllOfdmParams.guard_interval;
    OFDMParams.channelBW = (OFDMParams.guard_interval + OFDMParams.NumSubcarriers) * OFDMParams.Subcarrierspacing;
    OFDMParams.signalBW = (2 * OFDMParams.guard_interval + OFDMParams.NumSubcarriers) * OFDMParams.Subcarrierspacing;

    dataParams.modOrder = 64;
    dataParams.coderate = "1/2";
    dataParams.numSymPerFrame = 30;
    dataParams.numFrames = 30;
    dataParams.enableScopes = false;
    dataParams.printunderflow = true;
    dataParams.verbosity = false;

    % 生成系统参数并从文件中加载数据
    [sysParam, txParam, trBlk] = helperOFDMSetParamsSDR(OFDMParams, dataParams, all_radioResource, 'tx');
    sysParam.total_usedSubcc = overAllOfdmParams.total_NumSubcarriers;
    sysParam.total_usedRB = overAllOfdmParams.total_RB;

    txObj = helperOFDMTxInit(sysParam);
    txParam.txDataBits = trBlk;
    [txOut, txGrid, txDiagnostics] = helperOFDMTx(txParam, sysParam, txObj);

    % 如果启用了显示，绘制资源网格
    if dataParams.verbosity
        helperOFDMPlotResourceGrid(txGrid, sysParam);
    end

    % 生成待发送的波形
    txWaveform = txOut;
end

function saveTxWaveform(filename, txWaveform)
    save(filename, 'txWaveform');
end

