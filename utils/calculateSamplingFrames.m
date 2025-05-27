function [numFrames, totalBytes, bufferCapacityFrames, buffCapaCrtCaptrTimes] = calculateSamplingFrames(bbtrx, captureLength, frameLength, m)
    % calculateSamplingFrames - 计算采样总帧数、总字节数以及缓冲区帧数
    % 输入参数:
    %   bbtrx - Baseband transceiver 对象，包含 SampleRate 和 CaptureAntennas 属性
    %   captureLength - 采样长度，可以是整数（采样点数）或 duration 类型（持续时间）
    %   frameLength - 每帧包含的采样点数
    %   m - memmapfile 对象，包含内存映射信息
    %
    % 输出参数:
    %   numFrames - 输入采样点数/时间内的帧数
    %   totalBytes - 总采样数据大小（字节）
    %   bufferCapacityFrames - 缓冲区可存储的帧数

    % 获取基本参数
    sampleRate = bbtrx.SampleRate; % 每秒采样点数 (Hz)
    numAntennas = numel(bbtrx.CaptureAntennas); % 天线数量

    % 判断 captureLength 是采样点数还是时间
    if isa(captureLength, 'double') && mod(captureLength, 1) == 0
        % 如果是整数，直接认为是采样点数
        numSamples = captureLength;
    elseif isa(captureLength, 'duration')
        % 如果是 duration 类型，将时间转换为采样点数
        numSamples = ceil(seconds(captureLength) * sampleRate);
    else
        % 输入类型不匹配，报错
        error('Invalid captureLength type. Must be an integer (number of samples) or duration.');
    end

    % 计算采样点的总大小 (每采样点 16 字节，复数类型: double 实部 + double 虚部)
    bytesPerSample = 16; % 每个采样点占 16 字节
    totalBytes = numSamples * numAntennas * bytesPerSample;

    % 计算帧数
    numFrames = ceil(numSamples / frameLength);

    % 缓冲区容量计算
    bufferSamples = size(m.Data.complexData, 1); % 缓冲区最大样本数
    bufferCapacityFrames = floor(bufferSamples / (frameLength*numAntennas));    % 缓冲区最大能存储的帧数
    buffCapaCrtCaptrTimes = floor(bufferSamples / (numSamples*numAntennas));    % 缓冲区最大不循环能够以当前capture duration持续的采样总次数
end
