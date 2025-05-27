function MeasurementTools = setupMeasurementTools(sysParamRxObj)
    % setupMeasurementTools: 初始化与测量相关的工具（BER、EVM、MER）并返回。
    %
    % Input:
    %   sysParamRxObj - 包含系统参数和接收器对象的结构体
    %
    % Output:
    %   MeasurementTools - 包含所有测量工具的结构体

    % 初始化保存测量工具的结构体
    MeasurementTools = struct();

    % 初始化测量工具
    % 提取基站的相关参数
    dataParams = sysParamRxObj.dataParams;

    % 初始化误码率测量对象
    MeasurementTools.BER = comm.ErrorRate();

    % 根据基站的调制阶数生成星座图参考点
    refConstHeader = qammod(0:1, 2, UnitAveragePower=true);  % Header is always BPSK
    refConstData   = qammod(0:dataParams.modOrder-1, dataParams.modOrder, UnitAveragePower=true);

    % 初始化 EVM 测量对象
    MeasurementTools.EVM.header = comm.EVM( ...
        "MeasurementIntervalSource", "Entire history", ...
        "ReferenceSignalSource", "Estimated from reference constellation", ...
        "ReferenceConstellation", refConstHeader);

    MeasurementTools.EVM.data = comm.EVM( ...
        "MeasurementIntervalSource", "Entire history", ...
        "ReferenceSignalSource", "Estimated from reference constellation", ...
        "ReferenceConstellation", refConstData);

    % 初始化 MER 测量对象
    MeasurementTools.MER.header = comm.MER( ...
        "MeasurementIntervalSource", "Entire history", ...
        "ReferenceSignalSource", "Estimated from reference constellation", ...
        "ReferenceConstellation", refConstHeader);

    MeasurementTools.MER.data = comm.MER( ...
        "MeasurementIntervalSource", "Entire history", ...
        "ReferenceSignalSource", "Estimated from reference constellation", ...
        "ReferenceConstellation", refConstData);
end
