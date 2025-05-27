function [camped,toff,foff] = helperOFDMRxSearch(rxIn,sysParam,frameNum,messagePointer)
%helperOFDMRxSearch Receiver search sequencer.
%   This helper function searches for the synchronization signal of the
%   base station to align the receiver timing to the transmitter timing.
%   Following successful detection of the sync signal, frequency offset
%   estimation is performed to on the first five frames to align the
%   receiver center frequency to the transmitter frequency.
%
%   Once this is completed, the receiver is declared camped and ready for
%   processing data frames. 
%
%   [camped,toff,foff] = helperOFDMRxSearch(rxIn,sysParam)
%   rxIn - input time-domain waveform
%   sysParam - structure of system parameters
%   camped - boolean to indicate receiver has detected sync signal and
%   estimated frequency offset
%   toff - timing offset as calculated from the sync signal location in
%   signal buffer
%   foff - frequency offset as calculated from the first minNumOfSymb_4CFOest symbols
%   following sync symbol detection
%

% 生成 ULBS_ID，例如 "@ULBS_1"
ULBS_ID = sysParam.ULBS_ID;
fieldname = sprintf('@ULBS_%d', ULBS_ID);

persistent syncDetected;
% 初始化 camped，如果为空
if isempty(syncDetected)
    syncDetected = false;
end

% Create a countdown frame timer to wait for the frequency offset
% estimation algorithm to converge

% ********************注意！！！**********************
% 这里的minNumOfSymb_4CFOest和本函数中调用的helperOFDMFrequencyOffset里的minNumOfSymb_4CFOest变量保持一致，要改动都改！
% ********************注意！！！**********************
% 其代表着刚接收到同步信号时，初始的时候，需要进行CFO估计的最小的symbol总数。根据测试和经验，其值越大
% 估计的越稳定，CFO矫正越稳定。但导致缓存增加，程序计算量增加，初始化耗费帧数增多
% 这里最初example默认值取150
minNumOfSymb_4CFOest = 60;
persistent campedDelay;
% 初始化 camped，如果为空
if isempty(campedDelay)
    % The frequency offset algorithm requires 150 symbols to average before
    % the first valid frequency offset estimate. Wait a minimum number of
    % frames before declaring camped state.
    campedDelay = ceil(minNumOfSymb_4CFOest/sysParam.numSymPerFrame); 
end

toff = [];  % by default, return an empty timing offset value to indicate
            % no sync symbol found or searched
camped = false;
foff = 0;

% Form the sync signal
% Step 1: Synchronization signal in BWP (relative index)
FFTLength = sysParam.FFTLen;
dcIdx = (FFTLength/2)+1;          
ZCsyncsignal_FD = helperOFDMSyncSignal(sysParam, 'rx');
syncSignalIndRel = floor(sysParam.usedSubCarr / 2) - floor(length(ZCsyncsignal_FD) / 2) + (1:length(ZCsyncsignal_FD));  % Relative index in BWP
% Step 2: Calculate absolute index in total FFT based on BWP start index
syncSignalIndAbs = sysParam.subcarrier_start_index + syncSignalIndRel - 1;  % Absolute index in FFT grid
% Check if DC subcarrier index is included in syncSignalIndAbs, then drop that
if any(syncSignalIndAbs == dcIdx)
    % Adjust indices: for indices >= dcIdx, add 1 to avoid DC subcarrier
    syncSignalIndAbs(syncSignalIndAbs >= dcIdx) = syncSignalIndAbs(syncSignalIndAbs >= dcIdx) + 1;
end
syncNullInd = [1:(syncSignalIndAbs(1) - 1), (syncSignalIndAbs(end) + 1):FFTLength].';
% Step: Check if DC subcarrier is already in the null indices
if ~ismember(dcIdx, syncNullInd)
    syncNullInd = [syncNullInd; dcIdx];  % Include DC subcarrier only if it's not already in null indices
end
syncSignal = ofdmmod(ZCsyncsignal_FD,FFTLength,0,syncNullInd);

if ~syncDetected
    % Perform timing synchronization
    toff = timingEstimate(rxIn,syncSignal,Threshold = 0.6);

    if ~isempty(toff)
        syncDetected = true;
        toff = toff - sysParam.CPLen;
        fprintf('[%s]Msg(%d):Sync symbol found at frame %d.\n',fieldname, messagePointer, frameNum);
        if sysParam.enableCFO
            fprintf('[%s]Msg(%d):Estimating carrier frequency offset ...\n',fieldname,messagePointer);
        else
            camped = true; % go straight to camped if CFO not enabled
            fprintf('[%s]Msg(%d):Receiver camped at frame %d.\n',fieldname, messagePointer,frameNum);
        end
    else
        if sysParam.verbosity > 0
            syncDetected = false;
            fprintf('.');
        else
            syncDetected = false;            
        end
    end
else
    % Estimate frequency offset after finding sync symbol
    if campedDelay > 0 && sysParam.enableCFO
        % Run the frequency offset estimator and start the averaging to
        % converge to the final estimate
        foff = helperOFDMFrequencyOffset(rxIn,sysParam);
        % fprintf('.');
        campedDelay = campedDelay - 1;
    else
        fprintf('[%s]Msg(%d):Receiver camped at frame %d.\n',fieldname, messagePointer,frameNum);
        foff = helperOFDMFrequencyOffset(rxIn,sysParam);
        camped = true;
    end
end

end