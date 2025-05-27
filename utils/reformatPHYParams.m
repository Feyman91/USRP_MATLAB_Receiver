function [OFDMParams, dataParams] = reformatPHYParams(PHYParams, cfg)
    % reformatPHYParams: 通用化的 PHY 参数格式化函数
    %
    % 输入：
    %   PHYParams - 从 JSON 文件加载的参数结构体，可用于上行或下行
    %   cfg - 配置参数结构体（可选，包含功能开关等）
    %
    % 输出：
    %   OFDMParams - 格式化后的 OFDM 参数
    %   dataParams - 格式化后的数据传输参数

    % 从 PHYParams 中提取 OFDM 参数
    OFDMParams.FFTLength = PHYParams.FFTLength;
    OFDMParams.CPLength = ceil(PHYParams.FFTLength * PHYParams.CPFraction);
    OFDMParams.PilotSubcarrierSpacing = PHYParams.PilotSubcarrierSpacing;
    OFDMParams.NumSubcarriers = PHYParams.dataSubcNum;
    OFDMParams.subcarrier_start_index = PHYParams.dataSubc_start_index;
    OFDMParams.subcarrier_end_index = PHYParams.dataSubc_end_index;
    OFDMParams.subcarrier_center_offset = PHYParams.dataSubc_center_offset;
    OFDMParams.BWPoffset = PHYParams.BWPoffset;
    OFDMParams.Subcarrierspacing = PHYParams.Subcarrierspacing;
    OFDMParams.guard_interval = PHYParams.guard_interval;
    OFDMParams.channelBW = PHYParams.channelBW;
    OFDMParams.signalBW = PHYParams.signalBW;

    % 设置 ULBS_ID
    OFDMParams.ULBS_ID = PHYParams.ULBS_ID;

    % Modulation order (64-QAM)
          % Options:
          %  2    -> BPSK
          %  4    -> QPSK
          %  16   -> 16-QAM
          %  64   -> 64-QAM
          %  256  -> 256-QAM
          %  1024 -> 1024-QAM
          %  4096 -> 4096-QAM

    % Code rate
          % Options:
          %  "1/2" -> 1/2 code rate
          %  "2/3" -> 2/3 code rate
          %  "3/4" -> 3/4 code rate
          %  "5/6" -> 5/6 code rate
    % 从 PHYParams 和 cfg 中提取数据传输参数
    dataParams.modOrder = PHYParams.MCS.modOrder;
    dataParams.coderate = PHYParams.MCS.coderate;
    dataParams.numSymPerFrame = PHYParams.numSymPerFrame;
    dataParams.enableScopes   = cfg.enableScopes;  % Enable scopes for visualization
    dataParams.verbosity      = cfg.verbosity;  % Enable verbosity for diagnostics
    dataParams.printData      = cfg.printData;  % Print received data
    dataParams.enableConst_measure = cfg.enableConst_measure; % Enable constellation measurement

end
