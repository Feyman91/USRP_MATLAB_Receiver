function ZCsyncSignal = helperOFDMSyncSignal(sysParam, mode)
%helperOFDMSyncSignal Generates synchronization signal
%   This function returns a length-62 complex-valued vector for the
%   frequency-domain representation of the sync signal.
%
%   By default, this function uses a length-62 Zadoff-Chu sequence with
%   root index 25. Zadoff-Chu is a constant amplitude signal so long as the
%   length is a prime number, so the sequence is generated with a length of
%   63 and adjusted for a length of 62.
%
%   This sequence can be user-defined as needed (e.g., a maximum length
%   sequence) as long as the sequence is of length 62 to fit the OFDM
%   simulation.
%
%   ZCsyncSignal = helperOFDMSyncSignal(sysParam, mode)
%   sysParam - system parameters structure
%   mode     - operating mode ('tx' or 'rx')
%   ZCsyncSignal - frequency-domain sync signal

% 检查 mode 参数是否被输入
if ~exist('mode', 'var')
    error('Mode must be specified as either "tx" or "rx".');
end

% Select SYNC_ID based on mode
if strcmp(mode, 'rx')
    SYNC_id = 1;  % 当前考虑单用户，只有一个用户，生成一个同步信号
elseif strcmp(mode, 'tx')
    SYNC_id = sysParam.ULBS_ID;  % 上行数据集站的标识符ID（基本用不到，因为上行基站不发送信号）
else
    error('Invalid mode specified. Use "tx" or "rx".');
end

% Set sequence length, must fit within the BWP
seqLen = min(63, sysParam.usedSubCarr);

% Calculate Zadoff-Chu root index based on BS_id
zcRootIndex = mod(SYNC_id + (SYNC_id - 1) * 7 + 21, seqLen);

% Ensure zcRootIndex and seqLen are relatively prime
while gcd(zcRootIndex, seqLen) ~= 1
    zcRootIndex = zcRootIndex + 1;
end

% Generate the Zadoff-Chu sequence for synchronization
ZCsyncSignal = zadoffChuSeq(zcRootIndex, seqLen);

end
