function [txflag,txDiagnostics] = transmitData(bbtrx, txmode, numFrames)
    % transmitWaveform 使用 basebandTransceiver 对象发送指定的波形
    %
    % 输入:
    %   bbtrx    - 已初始化并打开数据管道的 basebandTransceiver 对象
    %   txmode   - 发送模式，"once" 或 "continuous"
    %   numFrames - 发送的帧数（仅在 txmode 为 "once" 时有效）
    %
    % 输出:
    %   txflag   - 表示当前发送状态的标志。1 表示正在发送，0 表示未发送
    %
    % 该函数从已有的 OFDMTransmitter.m 中复用代码并适配 bbtrx 进行波形发送
        
    arguments
        bbtrx
        txmode (1,1) string {mustBeMember(txmode, ["once", "continuous"])}  % 指定 txmode 可选项
        numFrames double = 30  % 默认帧数设置为 30
    end

    % 如果模式为 "continuous"，忽略 numFrames
    if txmode == "continuous" && nargin == 3
        warning('In continuous mode, numFrames is ignored. Use stopTransmission(bbtrx) to stop transmission.');
    elseif txmode == "once" && nargin < 3
        error('In "once" mode, numFrames must be specified to indicate the number of frames to transmit.');
    end

    % 初始化参数
    overAllOfdmParams.online_BS               = 1;              % number of online data BS 
    overAllOfdmParams.FFTLength               = 1024;           % FFT length
    overAllOfdmParams.CPLength                = ceil(overAllOfdmParams.FFTLength * 0.25);   % Cyclic prefix length
    overAllOfdmParams.PilotSubcarrierSpacing  = 36;             % Pilot sub-carrier spacing
    total_RB                                  = 67;             % Resource block number

    % 验证 RB 和子载波数
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

    % 配置基站 OFDM 参数
    BS_id = 1;
    BWPoffset = 0;
    [alloc_RadioResource, all_radioResource] = calculateBWPs(overAllOfdmParams, BS_id, BWPoffset);

    OFDMParams.online_BS              = overAllOfdmParams.online_BS;
    OFDMParams.BS_id                  = BS_id;
    OFDMParams.BWPoffset              = BWPoffset;
    OFDMParams.FFTLength              = overAllOfdmParams.FFTLength;
    OFDMParams.CPLength               = overAllOfdmParams.CPLength;
    OFDMParams.PilotSubcarrierSpacing = overAllOfdmParams.PilotSubcarrierSpacing;
    OFDMParams.NumSubcarriers         = alloc_RadioResource.UsedSubcc;
    OFDMParams.subcarrier_start_index = alloc_RadioResource.subcarrier_start_index;
    OFDMParams.subcarrier_end_index   = alloc_RadioResource.subcarrier_end_index;
    OFDMParams.subcarrier_center_offset = alloc_RadioResource.subcarrier_center_offset;
    OFDMParams.Subcarrierspacing      = 30e3;
    OFDMParams.guard_interval         = overAllOfdmParams.guard_interval;
    OFDMParams.channelBW              = (OFDMParams.guard_interval + OFDMParams.NumSubcarriers) * OFDMParams.Subcarrierspacing;
    OFDMParams.signalBW               = (2 * OFDMParams.guard_interval + OFDMParams.NumSubcarriers) * OFDMParams.Subcarrierspacing;

    % 配置数据参数
    dataParams.modOrder       = 16;
    dataParams.coderate       = "1/2";
    dataParams.numSymPerFrame = 30;
    dataParams.numFrames      = numFrames;  % 使用指定的帧数
    dataParams.enableScopes   = false;
    dataParams.printunderflow = true;
    dataParams.verbosity      = false;

    % 生成系统参数
    [sysParam, txParam, trBlk] = helperOFDMSetParamsSDR(OFDMParams, dataParams, all_radioResource, 'tx');
    sysParam.total_usedSubcc = overAllOfdmParams.total_NumSubcarriers;
    sysParam.total_usedRB = overAllOfdmParams.total_RB;

    % 初始化发送器并生成波形
    txObj = helperOFDMTxInit(sysParam);
    txParam.txDataBits = trBlk;
    [txOut, txGrid, txDiagnostics] = helperOFDMTx(txParam, sysParam, txObj);

    % 如果启用了显示，绘制资源网格
    if dataParams.verbosity
        helperOFDMPlotResourceGrid(txGrid, sysParam);
    end

    % 生成待发送的波形
    txWaveform = txOut;

    % 开始使用 bbtrx 发送波形数据
    % 根据 txmode 设置传输模式和状态
    if strcmp(txmode, "continuous")
        fprintf('\n********Starting "%s" mode transmission********\n', txmode);
        transmit(bbtrx, txWaveform, "continuous");  % 使用 continuous 模式进行传输
        txflag = 1;  % 设置状态为正在发送
        fprintf('Use "stopTransmission(bbtrx)" to stop TX......\n');
    elseif strcmp(txmode, "once")
        fprintf('\n********Transmitting %d frames in "%s" mode********\n', numFrames,txmode);
        for frameNum = 1:numFrames
            transmit(bbtrx, txWaveform, "once");  % 使用 once 模式传输单帧
        end
        txflag = 0;  % 单次发送结束后设置状态为未发送
        fprintf('Single-shot transmission completed.\n');
    end
end
