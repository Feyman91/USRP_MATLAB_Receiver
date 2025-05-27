function controlParams = genControlParams4DLTrFcn(CBS_ID, UE_IDs, onlineBS_IDs, commonParams)
    % generateDownlinkControlParams: 动态生成下行控制参数结构体
    %
    % 输入：
    %   CBS_ID: 控制基站 ID
    %   UE_IDs: 当前接入的 UE ID 列表
    %   onlineBS_IDs: 在线的下行基站 ID 列表
    %   commonParams: 包含通用参数的结构体
    %
    % 输出：
    %   controlParams: 下行控制参数结构体

    % 初始化控制参数结构体
    controlParams = struct();
    controlParams.CBS_ID = CBS_ID;
    controlParams.Downlink_TrParams = struct();

    % 遍历每个 UE
    for i = 1:numel(UE_IDs)
        UE_ID = UE_IDs(i);
        UE_Params = struct();
        UE_Params.Common = commonParams; % 将 commonParams 嵌套到 UE 下

        % 遍历每个在线基站为当前 UE 生成传输参数
        for j = 1:numel(onlineBS_IDs)
            BS_ID = onlineBS_IDs(j);

            % 获取当前基站的特定参数
            [BWPoffset, PilotSubcarrierSpacing] = getBSParams(BS_ID);

            % 更新 commonParams 的部分字段
            commonParams.BWPoffset = BWPoffset;
            commonParams.PilotSubcarrierSpacing = PilotSubcarrierSpacing;

            % 生成 OFDM 和数据传输参数并直接存入 BS 字段
            BS_FieldName = sprintf('DL_BS_%d', BS_ID);
            BS_Params = generateBSParams(commonParams, BS_ID);
            UE_Params.(BS_FieldName) = BS_Params;
        end

        % 保存当前 UE 的传输参数
        UE_FieldName = sprintf('UE_ID_%d', UE_ID);
        controlParams.Downlink_TrParams.(UE_FieldName) = UE_Params;
    end
end


function BS_Params = generateBSParams(commonParams, BS_ID)
    % generateBSParams: 为指定基站生成完整的传输参数
    %
    % 输入：
    %   commonParams: 包含通用参数的结构体
    %   BS_ID: 基站 ID
    %
    % 输出：
    %   BS_Params: 包含所有传输参数的结构体

    % 调用 calculateBWPs 函数计算分配资源
    alloc_RadioResource = calculateBWPs(commonParams, BS_ID, commonParams.BWPoffset);

    % 构造基站传输参数
    BS_Params = struct();
    BS_Params.BS_ID = BS_ID;
    BS_Params.dataSubcNum = alloc_RadioResource.UsedSubcc;
    BS_Params.dataSubc_start_index = alloc_RadioResource.subcarrier_start_index;
    BS_Params.dataSubc_end_index = alloc_RadioResource.subcarrier_end_index;
    BS_Params.dataSubc_center_offset = alloc_RadioResource.subcarrier_center_offset;
    
    BS_Params.guard_interval = alloc_RadioResource.guard_interval;
    BS_Params.BWPoffset = commonParams.BWPoffset;
    BS_Params.PilotSubcarrierSpacing = commonParams.PilotSubcarrierSpacing;
    
    BS_Params.channelBW = (alloc_RadioResource.guard_interval + BS_Params.dataSubcNum) * commonParams.Subcarrierspacing;
    BS_Params.signalBW = (2 * alloc_RadioResource.guard_interval + BS_Params.dataSubcNum) * commonParams.Subcarrierspacing;
    
    % 添加基站的特定数据传输参数
    dataParams = getDataParams(BS_ID);
    fields = fieldnames(dataParams);
    for k = 1:numel(fields)
        BS_Params.(fields{k}) = dataParams.(fields{k});
    end
end


function [alloc_RadioResource] = calculateBWPs(commonParams, BS_ID, bwp_offset)
    % calculateBWPs: 计算基站的带宽分配参数
    %
    % 输入：
    %   commonParams: 包含 FFTLength、total_RB 等的结构体
    %   BS_ID: 基站 ID
    %   bwp_offset: BWP 偏移量
    %
    % 输出：
    %   alloc_RadioResource: 基站的传输参数结构体
    
    FFTLength = commonParams.FFTLength;
    total_RB = commonParams.total_RB;
    online_BS = numel(commonParams.onlineBS_IDs);

    % Step 1: 计算总使用的子载波数量
    N_used = total_RB * 12;

    % Step 2: 计算单侧 guard_interval
    guard_interval = (FFTLength - N_used) / 2;

    % Step 3: 计算每个 BWP 的带宽
    total_guard_band = (online_BS - 1) * guard_interval;
    effective_bandwidth = N_used - total_guard_band;
    BWP_bandwidth = floor(effective_bandwidth / online_BS);

    % Step 4: 验证 BWP 带宽合法性
    if BWP_bandwidth < 72 || mod(BWP_bandwidth, 1) ~= 0
        error('Error: Defined BWP bandwidth (%d) is invalid.', BWP_bandwidth);
    end

    % Step 5: 为基站计算子载波分配
    for i = 1:online_BS
        if i == 1
            BWP_start_index = guard_interval + 1;
        else
            BWP_start_index = BWP_end_index + guard_interval + 1;
        end
        BWP_end_index = BWP_start_index + BWP_bandwidth - 1;
        BWP_center_offset = (BWP_start_index + BWP_end_index) / 2 - FFTLength / 2;

        if i == BS_ID
            alloc_RadioResource.subcarrier_start_index = BWP_start_index + bwp_offset;
            alloc_RadioResource.subcarrier_end_index = BWP_end_index + bwp_offset;
            alloc_RadioResource.subcarrier_center_offset = BWP_center_offset + bwp_offset;
            alloc_RadioResource.UsedSubcc = BWP_bandwidth;
            alloc_RadioResource.guard_interval = guard_interval;
        end
    end
end


function [BWPoffset, PilotSubcarrierSpacing] = getBSParams(BS_ID)
    % getBSParams: 获取指定基站的 BWPoffset 和 PilotSubcarrierSpacing 参数
    % 可继续添加支持基站的传输参数个数以及格式
    % 输入：
    %   BS_ID - 基站 ID
    %
    % 输出：
    %   BWPoffset - 基站的带宽偏移量
    %   PilotSubcarrierSpacing - 基站的导频子载波间隔
    %
    % 功能：
    %   根据基站 ID 返回特定的带宽偏移量和导频子载波间隔。
    %   如果 BS_ID 不受支持，则返回错误。

    switch BS_ID
        case 1
            BWPoffset = 0; % 偏移量 0
            PilotSubcarrierSpacing = 36; % 导频间隔
        case 2
            BWPoffset = 0; % 偏移量 100
            PilotSubcarrierSpacing = 36; % 导频间隔
        case 3
            BWPoffset = 200; % 偏移量 200
            PilotSubcarrierSpacing = 72; % 导频间隔
        otherwise
            error('Unsupported BS_ID: %d', BS_ID);
    end
end


function dataParams = getDataParams(BS_ID)
    % generateDataParams: 为指定基站生成数据传输参数
    % 可继续添加支持基站的传输参数个数以及格式
    % 输入：
    %   BS_ID: 基站 ID
    %
    % 输出：
    %   dataParams: 数据传输参数结构体

    switch BS_ID
        case 1
            dataParams.modOrder = 64; % QPSK
            dataParams.coderate = "1/2";
            dataParams.numSymPerFrame = 10;
        case 2
            dataParams.modOrder = 16; % 16-QAM
            dataParams.coderate = "3/4";
            dataParams.numSymPerFrame = 10;
        otherwise
            error('Unsupported BS_ID: %d', BS_ID);
    end
end

