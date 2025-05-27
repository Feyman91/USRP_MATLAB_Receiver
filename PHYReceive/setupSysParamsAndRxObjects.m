function [sysParamRxObj] = setupSysParamsAndRxObjects(PHYParams, cfg)
    % 基于接收机参数设置接收系统参数和对象
    %
    % 输入：
    %   PHYParams: 从json文件中提取的PHY参数
    %   cfg: 接收器配置
    %
    % 输出：
    %   sysParamRxObj: 包含系统参数、接收对象和其他相关信息的结构体

    % 初始化保存所有基站 sysParam 和相关参数的结构体
    sysParamRxObj = struct();

    % 格式化PHY传输参数
    [OFDMParams, dataParams] = reformatPHYParams(PHYParams, cfg);
    [sysParam, txParam, transportBlk_bs] = helperOFDMSetParamsSDR(OFDMParams, dataParams, 'rx');
    
    % 设置 UE_ID
    sysParam.ULBS_ID = OFDMParams.ULBS_ID;

    %%%%%%%%%%%%%%%%%%%%%%%%% 设置可选参数 %%%%%%%%%%%%%%%%%%%%%%%%%
    sysParam.enableTimescope = cfg.enableTimescope;
    sysParam.enableCFO = cfg.enableCFO;
    sysParam.enableCPE = cfg.enableCPE;
    sysParam.enableChest = cfg.enableChest;
    sysParam.enableHeaderCRCcheck = cfg.enableHeaderCRCcheck;
    %%%%%%%%%%%%%%%%%%%%%%%%% 设置可选参数 %%%%%%%%%%%%%%%%%%%%%%%%%

    % 初始化接收对象 rxObj
    rxObj = helperOFDMRxInit(sysParam);

    % 将系统参数和对象保存到结构体中
    sysParamRxObj.sysParam = sysParam;
    sysParamRxObj.rxObj = rxObj;
    sysParamRxObj.transportBlk_bs = transportBlk_bs;
    sysParamRxObj.OFDMParams = OFDMParams;
    sysParamRxObj.dataParams = dataParams;
    sysParamRxObj.txParam = txParam;
end
