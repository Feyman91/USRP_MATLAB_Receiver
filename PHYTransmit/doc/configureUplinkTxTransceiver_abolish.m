function [bbtrx_new, txWaveform, txDiagnostics, spectrumAnalyze] = configureUplinkTxTransceiver(bbtrx, TXantenna, TXcenterFrequency, TXgain, radioDevice)
    % configureAndTransmitOFDM 配置 OFDM 参数，并生成传输波形，但不进行实际传输
    % 输入:
    %   bbtrx - 已初始化的 basebandTransceiver 对象
    % 输出:
    %   bbtrx - 配置后的 basebandTransceiver 对象
    %   txWaveform - 生成的 OFDM 传输波形

    % 第一部分可以认为是控制基站的功能
    % 初始化 OFDM 参数
    overAllOfdmParams.online_BS = 1;           % Number of online data BS
    overAllOfdmParams.FFTLength = 1024;        % FFT length
    overAllOfdmParams.CPLength = ceil(overAllOfdmParams.FFTLength * 0.25);  % Cyclic prefix length
    overAllOfdmParams.PilotSubcarrierSpacing = 36;  % Pilot sub-carrier spacing
    total_RB = 67;                             % User input Resource block number

    % 计算 RB 和子载波数
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

    % 基站的 OFDM 参数设置
    BS_id                             = 1;                    %当前基站的ID标识符
    BWPoffset                         = 0;                    %当前基站的总带宽offset（单位/1个子载波），offset设置的是实际带宽start位置相对于初始计算的start的位置的偏移
    % 根据BS id计算基站分配到的无线频谱资源, calculate allocated radio resource
    [alloc_RadioResource, all_radioResource]     = calculateBWPs(overAllOfdmParams, BS_id, BWPoffset);

    % 将部分total 全局参数和计算得到的分配给当前基站的空口资源赋给本地基站OFDMParam参数
    OFDMParams.online_BS              = overAllOfdmParams.online_BS;                 % number of online data BS 
    OFDMParams.BS_id                  = BS_id;                                       % BS id information
    OFDMParams.BWPoffset              = BWPoffset;                                    %当前基站的总带宽offset（单位/1个子载波）
    OFDMParams.FFTLength              = overAllOfdmParams.FFTLength;                  % FFT length
    OFDMParams.CPLength               = overAllOfdmParams.CPLength;                   % Cyclic prefix length
    OFDMParams.PilotSubcarrierSpacing = overAllOfdmParams.PilotSubcarrierSpacing;     % Pilot sub-carrier spacing这里直接默认为全局配置，后续可以针对化修改，即每个基站的pilot间隔不一样
    OFDMParams.NumSubcarriers               = alloc_RadioResource.UsedSubcc;                 % Number of sub-carriers in the band = resourceblock * 12 (must less than FFTlength)
    OFDMParams.subcarrier_start_index       = alloc_RadioResource.subcarrier_start_index;    % 对应分配的BWP子载波起始位置
    OFDMParams.subcarrier_end_index         = alloc_RadioResource.subcarrier_end_index;      % 对应分配的BWP子载波结束位置
    OFDMParams.subcarrier_center_offset     = alloc_RadioResource.subcarrier_center_offset;  % 对应分配的BWP子载波中心偏移（相对于DC子载波)
    OFDMParams.BWPoffset     = alloc_RadioResource.BWPoffset;                                % 对应分配的BWP人为设置Offset
    OFDMParams.Subcarrierspacing      = 30e3;                          % Sub-carrier spacing of 30 KHz
    OFDMParams.guard_interval         = overAllOfdmParams.guard_interval;              % 基站使用带宽的保护间隔
    OFDMParams.channelBW              = (OFDMParams.guard_interval+OFDMParams.NumSubcarriers)*OFDMParams.Subcarrierspacing;   % Bandwidth of the channel for filter to pass
    OFDMParams.signalBW               = (2*OFDMParams.guard_interval+OFDMParams.NumSubcarriers)*OFDMParams.Subcarrierspacing;   % Bandwidth of the signal for filter to cut-off

    % 数据参数配置
    dataParams.modOrder = 16;          % 调制阶数
    dataParams.coderate = "1/2";       % 编码率
    dataParams.numSymPerFrame = 30;    % 每帧符号数量
    dataParams.numFrames = 10000;      % 传输帧数
    dataParams.enableScopes = false;   % 是否启用示波器
    dataParams.printunderflow = false;  % 打印 underrun 信息
    dataParams.verbosity = false;      % 数据诊断输出

    % 使用配置函数获取参数
    [sysParam, txParam, trBlk] = helperOFDMSetParamsSDR(OFDMParams, dataParams, all_radioResource, 'tx');
    sysParam.total_usedSubcc = overAllOfdmParams.total_NumSubcarriers;
    sysParam.total_usedRB = overAllOfdmParams.total_RB;

    % 无线参数
    radioConfig = radioDevice;
    channelmapping = TXantenna;
    centerFrequency = TXcenterFrequency;
    gain = TXgain;
    sampleRate = sysParam.scs * sysParam.FFTLen;
    radioName = checkRadioArg(bbtrx,radioConfig,channelmapping,centerFrequency,gain,sampleRate);

    ofdmTx = helperGetRadioParams(sysParam, radioName, sampleRate, centerFrequency, gain, channelmapping);

    % 配置 basebandTransceiver 发射参数
    bbtrx_new = intern_cfg_TxTransceiver(bbtrx, ofdmTx);

    % 初始化发送器
    txObj = helperOFDMTxInit(sysParam);

    % 生成数据
    txParam.txDataBits = trBlk;
    [txOut, txGrid, txDiagnostics] = helperOFDMTx(txParam, sysParam, txObj);

    % 显示资源网格（如果启用）
    if dataParams.verbosity
        helperOFDMPlotResourceGrid(txGrid, sysParam);
    end

    % 准备波形数据
    txOutSize = length(txOut);
    if contains(radioName, 'PLUTO') && txOutSize < 48000
        frameCnt = ceil(48000 / txOutSize);
        txWaveform = zeros(txOutSize * frameCnt, 1);
        for i = 1:frameCnt
            txWaveform(txOutSize * (i-1) + 1:i * txOutSize) = txOut;
        end
    else
        txWaveform = txOut;
    end

    spectrumAnalyze = spectrumAnalyzer( ...
    'Name',             'Signal Spectrum', ...
    'Title',            'Transmitted Signal', ...
    'SpectrumType',     'Power', ...
    'Method',           'welch', ...
    'FrequencyResolutionMethod', 'rbw', ...
    'FrequencySpan',    'Full', ...
    'SampleRate',       ofdmTx.SampleRate, ...
    'ShowLegend',       true, ...
    'Position',         [100 100 800 500], ...
    'ChannelNames',     {'Transmitted'});

    if dataParams.enableScopes
        spectrumAnalyze(txWaveform)
    end

    % 返回已配置的 bbtrx_new 和生成的 txWaveform
end

% uplink_transmit/configureUplinkTxTransceiver.m
function bbtrx = intern_cfg_TxTransceiver(bbtrx, ofdmTxParams)
    % configureUplinkTxTransceiver 配置上行传输的 basebandTransceiver 对象参数
    %
    % bbtrx       - 输入的 basebandTransceiver 对象，配置完成后返回
    % sysParam    - 系统参数结构体，包含 OFDM 参数、采样率等
    % ofdmTxParams - 传输相关的 OFDM 配置结构体

    % 配置基本参数
    bbtrx.TransmitCenterFrequency = ofdmTxParams.CenterFrequency;  % 发射中心频率
    bbtrx.TransmitRadioGain = ofdmTxParams.Gain;             % 发射增益

    % 配置其他相关参数
    bbtrx.TransmitAntennas = ofdmTxParams.channelmapping;   % 根据需求设置传输天线，假设使用'TX1'

    % 配置捕获时的行为
    bbtrx.DroppedSamplesAction = 'warning';  % 设定丢弃采样时的行为

    % 输出配置确认
    disp('Uplink Tx transceiver configured successfully.');
end

function radioHardware = checkRadioArg(bbtrx, radioDevice, TXantenna, TXcenterFrequency, TXgain, sampleRate)
    % 获取当前保存的USRP设备配置
    Allradios = radioConfigurations;
    savedConfigurations = [string({Allradios.Name})];
    radioIndex = savedConfigurations == radioDevice;
    radioHardware = Allradios(radioIndex).Hardware;
    
    % 去掉 "USRP " 前缀，保留硬件关键信息
    radioHardware = strrep(radioHardware, "USRP ", "");
    
    % 根据不同的硬件类型定义支持的主时钟频率
    switch radioHardware
        case {"N310", "N300"}
            MCRs = [122.88e6, 125e6, 153.6e6];
            gainRange = [0, 65];
        case {"N320", "N321"}
            MCRs = [200e6, 245.76e6, 250e6];
            gainRange = [0, 60];
        case {"X310", "X300"}
            MCRs = [184.32e6, 200e6];
            gainRange = [0, 31.5];
        case {"X410"}
            MCRs = [245.76e6, 250e6];
            gainRange = [0, 60];
        otherwise
            error("Unsupported radio hardware: %s", radioHardware);
    end
    
    % 检查TXgain是否在支持范围内
    if TXgain < gainRange(1) || TXgain > gainRange(2)
        error("TXgain %.2f dB is out of the supported range (%g dB to %g dB) for device %s.", TXgain, gainRange(1), gainRange(2), radioHardware);
    end

    % 检查传入的 `sampleRate` 是否与 `bbtrx` 对象的采样率相符
    if bbtrx.SampleRate ~= sampleRate
        error("Mismatch between host transmit waveform sampleRate (%.2f) and bbtrx.SampleRate (%.2f)", sampleRate, bbtrx.SampleRate);
    end
    
    % 检查插值因子是否有效
    validSampleRate = false;
    for mcr = MCRs
        interpolationFactor = mcr / sampleRate;
        
        if ismember(radioHardware, ["N300", "N310", "N320", "N321", "X410"])
            % N300/N310/N320/N321/X410: 支持插值因子 1, 2, 3，或以下范围内的值
            if ismember(interpolationFactor, [1, 2, 3]) || ...
               (mod(interpolationFactor, 2) == 0 && interpolationFactor >= 4 && interpolationFactor <= 256) || ...
               (mod(interpolationFactor, 4) == 0 && interpolationFactor >= 256 && interpolationFactor <= 512) || ...
               (mod(interpolationFactor, 8) == 0 && interpolationFactor >= 512 && interpolationFactor <= 1016)
                validSampleRate = true;
                break;
            end
            
        elseif ismember(radioHardware, ["X300", "X310"])
            % X300/X310: 支持插值因子 1 到 128 范围内的整数，或以下范围内的值
            if (interpolationFactor >= 1 && interpolationFactor <= 128 && mod(interpolationFactor, 1) == 0) || ...
               (mod(interpolationFactor, 2) == 0 && interpolationFactor >= 128 && interpolationFactor <= 256) || ...
               (mod(interpolationFactor, 4) == 0 && interpolationFactor >= 256 && interpolationFactor <= 512) || ...
               (mod(interpolationFactor, 8) == 0 && interpolationFactor >= 512 && interpolationFactor <= 1016)
                validSampleRate = true;
                break;
            end
        end
    end
    
    % 返回检查结果
    if ~validSampleRate
        error("The calculated interpolation factor %g is not valid for the selected hardware: %s.", interpolationFactor, radioHardware);
    end
    
    % 检查TXcenterFrequency是否在支持范围内
    switch radioHardware
        case {"N300", "N310", "N320", "N321"}
            if TXcenterFrequency < 1e6 || TXcenterFrequency > 6e9
                error("TXcenterFrequency %.2f Hz is out of the supported range (1 MHz to 6 GHz) for device %s.", TXcenterFrequency, radioHardware);
            end
        case {"X300", "X310"}
            if TXcenterFrequency < 10e6 || TXcenterFrequency > 6e9
                error("TXcenterFrequency %.2f Hz is out of the supported range (10 MHz to 6 GHz) for device %s.", TXcenterFrequency, radioHardware);
            end
        case "X410"
            if TXcenterFrequency < 1e6 || TXcenterFrequency > 8e9
                error("TXcenterFrequency %.2f Hz is out of the supported range (1 MHz to 8 GHz) for device %s.", TXcenterFrequency, radioHardware);
            end
    end

    % 检查TXantenna是否有效
    switch radioHardware
        case {"N300", "N320", "N321"}
            validAntennas = ["RF0:TX/RX", "RF1:TX/RX"];
        case "N310"
            validAntennas = ["RF0:TX/RX", "RF1:TX/RX", "RF2:TX/RX", "RF3:TX/RX"];
        case {"X300", "X310"}
            validAntennas = ["RFA:TX/RX", "RFB:TX/RX"];
        case "X410"
            validAntennas = ["DB0:RF0:TX/RX0", "DB0:RF1:TX/RX0", "DB1:RF0:TX/RX0", "DB1:RF1:TX/RX0"];
    end
    if ~ismember(TXantenna, validAntennas)
        error("TXantenna '%s' is not supported for device %s.", TXantenna, radioHardware);
    end
    
    % disp("All Tx radio arguments are validated and correct.");
end
