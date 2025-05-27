function bbtrx = configureDownlinkRxTransceiver(bbtrx, RXantenna, RXCenterFrequency, RXgain, RXDataType, DroppedSamplesAction, radioConfig)
    % configureDownlinkRxTransceiver 配置接收的 basebandTransceiver 对象参数
    %
    % 输入:
    %   bbtrx - 已初始化的 basebandTransceiver 对象
    %   RXantenna - 设置接收天线
    %   RXCenterFrequency - 接收中心频率
    %   RXgain - 接收增益
    %   RXDataType - 数据类型 ("double", "single", "int16")
    %   DroppedSamplesAction - 丢弃样本行为 ("error", "warning", "none")
    %   radioConfig - 设备名称
    % 输出:
    %   bbtrx - 配置后的 basebandTransceiver 对象

    % 检查接收参数的有效性
    sampleRate = bbtrx.SampleRate;  % 从已设置的 bbtrx 对象中获取采样率
    radioName = checkRXRadioArg(bbtrx, radioConfig, RXantenna, RXCenterFrequency, RXgain, sampleRate);
    
    % 配置接收参数
    bbtrx.CaptureCenterFrequency = RXCenterFrequency;  % 设置接收中心频率
    bbtrx.CaptureRadioGain = RXgain;  % 设置接收增益
    bbtrx.CaptureAntennas = RXantenna;  % 设置接收天线
    bbtrx.CaptureDataType = RXDataType;  % 设置接收数据类型
    bbtrx.DroppedSamplesAction = DroppedSamplesAction;  % 设置丢弃样本行为
    
    % 输出配置确认
    disp('Downlink Rx transceiver configured successfully.');
end

function radioHardware = checkRXRadioArg(bbtrx, radioDevice, antenna, centerFrequency, gain, sampleRate)
    % 获取当前保存的USRP设备配置
    Allradios = radioConfigurations;
    savedConfigurations = [string({Allradios.Name})];
    radioIndex = savedConfigurations == radioDevice;
    radioHardware = Allradios(radioIndex).Hardware;
    
    % 去掉 "USRP " 前缀，保留硬件关键信息
    radioHardware = strrep(radioHardware, "USRP ", "");
    
    % 根据不同的硬件类型定义支持的主时钟频率和增益范围
    switch radioHardware
        case {"N310", "N300"}
            MCRs = [122.88e6, 125e6, 153.6e6];
            gainRange = [0, 75];
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
    
    % 检查 gain 是否在有效范围内
    if gain < gainRange(1) || gain > gainRange(2)
        error("Gain %.2f dB is out of the supported range (%g dB to %g dB) for device %s.", gain, gainRange(1), gainRange(2), radioHardware);
    end

    % 检查 `sampleRate` 是否符合设备要求
    if bbtrx.SampleRate ~= sampleRate
        error("Mismatch between host sampleRate (%.2f) and bbtrx.SampleRate (%.2f)", sampleRate, bbtrx.SampleRate);
    end

    % 检查插值因子
    validSampleRate = false;
    for mcr = MCRs
        interpolationFactor = mcr / sampleRate;
        
        if ismember(radioHardware, ["N300", "N310", "N320", "N321", "X410"])
            % 设备支持的插值因子
            if ismember(interpolationFactor, [1, 2, 3]) || ...
               (mod(interpolationFactor, 2) == 0 && interpolationFactor >= 4 && interpolationFactor <= 256) || ...
               (mod(interpolationFactor, 4) == 0 && interpolationFactor >= 256 && interpolationFactor <= 512) || ...
               (mod(interpolationFactor, 8) == 0 && interpolationFactor >= 512 && interpolationFactor <= 1016)
                validSampleRate = true;
                break;
            end
            
        elseif ismember(radioHardware, ["X300", "X310"])
            % X300/X310 支持的插值因子
            if (interpolationFactor >= 1 && interpolationFactor <= 128 && mod(interpolationFactor, 1) == 0) || ...
               (mod(interpolationFactor, 2) == 0 && interpolationFactor >= 128 && interpolationFactor <= 256) || ...
               (mod(interpolationFactor, 4) == 0 && interpolationFactor >= 256 && interpolationFactor <= 512) || ...
               (mod(interpolationFactor, 8) == 0 && interpolationFactor >= 512 && interpolationFactor <= 1016)
                validSampleRate = true;
                break;
            end
        end
    end
    if ~validSampleRate
        error("The calculated interpolation factor %g is not valid for the selected hardware: %s.", interpolationFactor, radioHardware);
    end
    
    % 检查中心频率是否在支持范围内
    switch radioHardware
        case {"N300", "N310", "N320", "N321"}
            if centerFrequency < 1e6 || centerFrequency > 6e9
                error("Center Frequency %.2f Hz is out of the supported range (1 MHz to 6 GHz) for device %s.", centerFrequency, radioHardware);
            end
        case {"X300", "X310"}
            if centerFrequency < 10e6 || centerFrequency > 6e9
                error("Center Frequency %.2f Hz is out of the supported range (10 MHz to 6 GHz) for device %s.", centerFrequency, radioHardware);
            end
        case "X410"
            if centerFrequency < 1e6 || centerFrequency > 8e9
                error("Center Frequency %.2f Hz is out of the supported range (1 MHz to 8 GHz) for device %s.", centerFrequency, radioHardware);
            end
    end

    % 检查天线是否有效
    switch radioHardware
        case {"N300", "N320", "N321"}
            validAntennas = ["RF0:RX2", "RF1:RX2"];
        case "N310"
            validAntennas = ["RF0:RX2", "RF1:RX2", "RF2:RX2", "RF3:RX2"];
        case {"X300", "X310"}
            validAntennas = ["RFA:RX2", "RFB:RX2"];
        case "X410"
            validAntennas = ["DB0:RF0:RX1", "DB0:RF1:RX1", "DB1:RF0:RX1", "DB1:RF1:RX1"];
    end
    if ~ismember(antenna, validAntennas)
        error("Antenna '%s' is not supported for device %s.", antenna, radioHardware);
    end
    
    % disp("All Rx radio arguments are validated and correct.");
end

