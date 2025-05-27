function rxOut = helperOFDMRxFrontEnd(rxIn,sysParam,rxObj,spectrumAnalyze, watchFilterdResult)
%helperOFDMRxFrontEnd Receiver front-end processing
%   This helper function handles sample buffer management and front-end
%   filtering. This simulates a typical receiver front end component. 
%
%   Optional components such as AGC and A/D converters may also be added to
%   this helper function for more detailed simulations.
%
%   rxOut = helperOFDMRxFrontEnd(rxIn,sysParam,rxObj)
%   rxIn - input time-domain waveform
%   sysParam - structure of system parameters
%   rxObj - structure of rx states and parameters
%

symLen = (sysParam.FFTLen+sysParam.CPLen);
frameLen = symLen * sysParam.numSymPerFrame;

persistent signalBuffers;
persistent frameOutDelay;

% 初始化 signalBuffers，如果为空
if isempty(signalBuffers)
    % 初始化 signalBuffers，长度为 3 * frameLen + 3 * symLen
    % 其中，最前面 symLen 个位置用作零填充，后面为信号缓存区域
    signalBuffers = zeros(3 * frameLen + 2 * symLen + symLen, 1);
    frameOutDelay = 1;      % 倒计时，倒计时结束开始从buffer中读取有效帧
    % 目的：为了避免之前Signal buffer的潜在bug，
    % 就是，如果定位的timing过于靠后(在framelength的最后两个symbol内)，会在第二次选取定位的时候，
    % 包含siganal buffer 后部填补的2个全0的symbol
end

% Perform filtering
rxFiltered = rxObj.rxFilter(rxIn);
if watchFilterdResult
    spectrumAnalyze(rxFiltered);
end

% 直接更新信号缓存区域，不改变最前端的 symLen 个零填充
signalBuffers(symLen + (1:3 * frameLen + 2 * symLen)) = [signalBuffers(symLen + frameLen + (1:2 *frameLen)); ...
                             rxFiltered; ...
                             zeros(symLen * 2, 1)];

% 检查是否已经收到了足够的帧数据
if frameOutDelay > 0
    rxOut = [];
    % 帧计数器减一
    frameOutDelay = frameOutDelay - 1;
    return
end

% 计算 timingAdvance，并确保其不会导致负索引
timingAdvance = sysParam.timingAdvance;

% 由于在缓冲区前预留了 symLen 的零填充，加上 symLen，以确保 timingAdvance 不会导致负索引
adjustedTimingAdvance = timingAdvance + symLen;

% 提取信号的输出
rxOut = signalBuffers(adjustedTimingAdvance + (1:frameLen + 2 * symLen));

end

