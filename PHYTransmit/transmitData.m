function [txflag] = transmitData(bbtrx, txmode, numFrames)
    % transmitWaveform 使用 basebandTransceiver 对象发送指定的波形
    %
    % 输入:
    %   bbtrx    - 已初始化并打开数据管道的 basebandTransceiver 对象
    %   txmode   - 发送模式，"once" 或 "continuous"
    %   numFrames - 发送的帧数（仅在 txmode 为 "once" 时有效）
    %
    % 输出:
    %   txflag   - 表示当前发送状态的标志。1 表示正在发送，0 表示未发送
    %   txDiagnostics - 发送过程中的诊断信息

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

    % 定义波形文件路径(同SendDataManager文件内部定义的路径保持一致）
    root_tx = "./PHYTransmit/cache_file/";
    waveformFileName = 'current_waveform.mat';
    waveformFilePath = fullfile(root_tx, waveformFileName);

    % 加载生成的波形文件
    if isfile(waveformFilePath)
        load(waveformFilePath, 'txWaveform');
    else
        error('Waveform file does not exist: %s', waveformFilePath);
    end

    % 开始使用 bbtrx 发送波形数据
    % 根据 txmode 设置传输模式和状态
    if strcmp(txmode, "continuous")
        fprintf('\n********Starting a NEW transmission in "%s" mode!********\n', txmode);
        transmit(bbtrx, txWaveform, "continuous");  % 使用 continuous 模式进行传输
        txflag = 1;  % 设置状态为正在发送
    elseif strcmp(txmode, "once")
        fprintf('\n********Starting a NEW transmission in "%s" mode with %d frames ********\n',txmode, numFrames);
        for frameNum = 1:numFrames
            transmit(bbtrx, txWaveform, "once");  % 使用 once 模式传输单帧
        end
        txflag = 0;  % 单次发送结束后设置状态为未发送
        fprintf('Single-shot transmission completed.\n');
    end
end
