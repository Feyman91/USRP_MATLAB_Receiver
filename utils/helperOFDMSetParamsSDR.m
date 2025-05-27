function [sysParam, txParam, payload] = helperOFDMSetParamsSDR(OFDMParam, dataParam, mode)
%helperOFDMSetParamsSDR Generates simulation parameters.
%   This function generates transmit-specific and common transmitter/receiver
%   parameters for the OFDM simulation, based on the high-level user
%   parameter settings passed into the helper function, specifically used in the SDR. Coding parameters may
%   be changed here, subject to some constraints noted below. This function
%   also generates a payload of the computed transport block size.
%
%   [sysParam, txParam, payload] = helperOFDMSetParamsSDR(OFDMParam, dataParam, allRadioResource, mode)
%   OFDMParam - structure of OFDM related parameters
%   dataParam - structure of data related parameters
%   allRadioResource - structure of allocated radio resource
%   mode - operating mode ('rx' or 'tx')
%   sysParam  - structure of system parameters common to tx and rx
%   txParam   - structure of tx parameters
%   payload   - known data payload generated for the trBlk size

% 检查 mode 参数是否被输入
if ~exist('mode', 'var')
    error('Mode must be specified as either "tx" or "rx".');
end

% Set shared tx/rx parameter structure
sysParam = struct();
txParam = struct();
txParam.modOrder = dataParam.modOrder;

sysParam.isSDR = true;
sysParam.numSymPerFrame = dataParam.numSymPerFrame;

sysParam.initState = [1 0 1 1 1 0 1];
sysParam.scrMask = [0 0 0 1 0 0 1];
sysParam.headerIntrlvNColumns = 12;
sysParam.dataIntrlvNColumns = 18;
sysParam.dataConvK = 7;
sysParam.dataConvCode = [171 133];
sysParam.headerConvK = 7;
sysParam.headerConvCode = [171 133];

sysParam.headerCRCPoly = [16 12 5 0];
sysParam.CRCPoly = [32 26 23 22 16 12 11 10 8 7 5 4 2 1 0];
sysParam.CRCLen = 32;

% Transmission grid parameters
sysParam.ssIdx = 1;
sysParam.rsIdx = 2;
sysParam.headerIdx = 3;

% Simulation options
sysParam.enableCFO = true;
sysParam.enableCPE = true;
sysParam.enableScopes = dataParam.enableScopes;
sysParam.verbosity = dataParam.verbosity;

% Derived parameters from simulation settings
if strcmp(mode, 'tx')
    sysParam.ULBS_ID                      = OFDMParam.ULBS_ID;                  % 发射时的标识：ULBS_ID（基本用不到，因为上行基站不发送信号）
end

sysParam.FFTLen = OFDMParam.FFTLength;
sysParam.CPLen = OFDMParam.CPLength;
sysParam.usedSubCarr = OFDMParam.NumSubcarriers;
sysParam.subcarrier_start_index = OFDMParam.subcarrier_start_index;
sysParam.subcarrier_end_index = OFDMParam.subcarrier_end_index;
sysParam.subcarrier_center_offset = OFDMParam.subcarrier_center_offset;
sysParam.BWPoffset = OFDMParam.BWPoffset;
sysParam.channelBW = OFDMParam.channelBW;
sysParam.signalBW = OFDMParam.signalBW;
sysParam.scs = OFDMParam.Subcarrierspacing;
sysParam.pilotSpacing = OFDMParam.PilotSubcarrierSpacing;

% Coding rate settings
codeRate = str2num(dataParam.coderate);
if codeRate == 1/2
    sysParam.tracebackDepth = 30;
    sysParam.codeRate = 1/2;
    sysParam.codeRateK = 2;
    sysParam.puncVec = [1 1];
    txParam.codeRateIndex = 0;
elseif codeRate == 2/3
    sysParam.puncVec = [1 1 0 1];
    sysParam.codeRate = 2/3;
    sysParam.codeRateK = 3;
    sysParam.tracebackDepth = 45;
    txParam.codeRateIndex = 1;
elseif codeRate == 3/4
    sysParam.puncVec = [1 1 1 0 0 1];
    sysParam.codeRate = 3/4;
    sysParam.codeRateK = 4;
    sysParam.tracebackDepth = 60;
    txParam.codeRateIndex = 2;
elseif codeRate == 5/6
    sysParam.puncVec = [1 1 1 0 0 1 1 0 0 1];
    sysParam.codeRate = 5/6;
    sysParam.codeRateK = 6;
    sysParam.tracebackDepth = 90;
    txParam.codeRateIndex = 3;
end

% Calculate pilot indices
numSubCar = sysParam.usedSubCarr;
sysParam.pilotIdx = sysParam.subcarrier_start_index + ...
    (1:sysParam.pilotSpacing:numSubCar).' -1;
dcIdx = (sysParam.FFTLen/2)+1;
if any(sysParam.pilotIdx == dcIdx)
    sysParam.pilotIdx(floor(length(sysParam.pilotIdx)/2)+1:end) = 1 + ...
        sysParam.pilotIdx(floor(length(sysParam.pilotIdx)/2)+1:end);
end
sysParam.pilotsPerSym = length(sysParam.pilotIdx);

% Interleaver row check
numIntrlvRows = 72/sysParam.headerIntrlvNColumns;
if floor(numIntrlvRows) ~= numIntrlvRows
    error('Number of header interleaver rows must divide into number of header subcarriers evenly.');
end

numDataOFDMSymbols = sysParam.numSymPerFrame - length(sysParam.ssIdx) - length(sysParam.rsIdx) - length(sysParam.headerIdx);
if numDataOFDMSymbols < 1
    error('Number of symbols per frame must be greater than the number of sync, header, and reference symbols.');
end

% Calculate transport block size (trBlkSize)
bitsPerModSym = log2(txParam.modOrder);
uncodedPayloadSize = (numSubCar - sysParam.pilotsPerSym) * numDataOFDMSymbols * bitsPerModSym;
codedPayloadSize = floor(uncodedPayloadSize / sysParam.codeRateK) * sysParam.codeRateK;
sysParam.trBlkPadSize = uncodedPayloadSize - codedPayloadSize;
sysParam.trBlkSize = (codedPayloadSize * codeRate) - sysParam.CRCLen - (sysParam.dataConvK - 1);
sysParam.txWaveformSize = ((sysParam.FFTLen + sysParam.CPLen) * sysParam.numSymPerFrame);
sysParam.timingAdvance = sysParam.txWaveformSize;
sysParam.modOrder = dataParam.modOrder;

% Load payload message based on mode
sysParam.NumBitsPerCharacter = 7;
if strcmp(mode, 'rx')
    file_name = "origin_UE_transmit_data.txt";
else
    file_name = "transmit_data.txt";
end
payloadMessage = char(readlines(file_name));
messageLength = length(payloadMessage);
numPayloads = ceil(sysParam.trBlkSize / (messageLength * sysParam.NumBitsPerCharacter)); 
message = repmat(payloadMessage, 1, numPayloads);
trBlk = reshape(int2bit(double(message), sysParam.NumBitsPerCharacter), 1, []);
payload = trBlk(1:sysParam.trBlkSize);

end
