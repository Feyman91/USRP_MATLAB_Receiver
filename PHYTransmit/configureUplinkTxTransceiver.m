function bbtrx = configureUplinkTxTransceiver(bbtrx, TXantenna, TXcenterFrequency, TXgain, radioDevice)
    % configureUplinkTxTransceiver 配置上行传输的 basebandTransceiver 对象参数
    %
    % 输入:
    %   bbtrx - 已初始化的 basebandTransceiver 对象
    %   TXantenna - 设置发送天线
    %   TXCenterFrequency - 发送中心频率
    %   TXgain - 发送增益
    %   radioConfig - 设备名称
    % 输出:
    %   bbtrx - 配置后的 basebandTransceiver 对象
    
    % 检查接收参数的有效性
    sampleRate = bbtrx.SampleRate;  % 从已设置的 bbtrx 对象中获取采样率
    radioHardware = checkTXRadioArg(bbtrx, radioDevice, TXantenna, TXcenterFrequency, TXgain, sampleRate);

    bbtrx.TransmitCenterFrequency = TXcenterFrequency;  % 发射中心频率
    bbtrx.TransmitRadioGain =TXgain;             % 发射增益
    bbtrx.TransmitAntennas = TXantenna;   % 根据需求设置传输天线，假设使用'TX1'

    % 输出配置确认
    disp('Uplink Tx transceiver configured successfully.');
end


function radioHardware = checkTXRadioArg(bbtrx, radioDevice, TXantenna, TXcenterFrequency, TXgain, sampleRate)
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
