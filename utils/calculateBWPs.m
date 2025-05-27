function [alloc_RadioResource] = calculateBWPs(overAllOfdmParams, bwp_offset)

    % Step 1: 计算 N_used (总使用的子载波数量)
    N_used = overAllOfdmParams.total_RB * 12;  % RB 与 N_used 的关系
    
    % Step 2: 计算 guard interval
    guard_interval = (overAllOfdmParams.FFTLength - N_used) / 2;  % Guard interval, 单侧的空载波
    
    % Step 3: 确定 BWP带宽
    BWP_bandwidth = N_used;  % 每个 BWP 的带宽，不包括保护间隔
    % Check if BWP_bandwidth is legal
    % 1. The minimum available bandwidth is 72 subcarriers
    % 2. The BWP bandwidth must be an integer
    if BWP_bandwidth < 72 || mod(BWP_bandwidth, 1) ~= 0
        error('Error: Defined BWP bandwidth (%d) is invalid. It must be at least 72, an integer.', BWP_bandwidth);
    end

    % Step 4: 计算 BWP 的关键信息
    % 计算每个 BWP 的起始和结束索引，考虑保护间隔
    BWP_start_index = guard_interval + 1;  % 从第一个 guard interval 后开始
    
    % 计算 BWP 的结束索引
    BWP_end_index = BWP_start_index + BWP_bandwidth - 1;
    
    % 计算 BWP 的中心偏移量 (相对于 FFT_length/2)
    BWP_center_offset = (BWP_start_index + BWP_end_index) / 2 - overAllOfdmParams.FFTLength / 2;
    
    % 计算每个 BWP 的长度 (子载波数量)
    BWP_length = BWP_end_index - BWP_start_index + 1;
    
    % 计算每个 BWP 的资源块 (RB) 数量
    BWP_RB_count = BWP_length / 12;  % 每个资源块等于 12 个子载波

    % 保存 BWP 关键信息到结构体
    alloc_RadioResource.subcarrier_start_index = BWP_start_index + bwp_offset;
    alloc_RadioResource.subcarrier_end_index = BWP_end_index + bwp_offset;
    alloc_RadioResource.subcarrier_center_offset = BWP_center_offset + bwp_offset;
    alloc_RadioResource.UsedSubcc = BWP_length;
    alloc_RadioResource.BWPoffset = bwp_offset;
end

