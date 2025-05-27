% 该脚本用于控制基站（CBS）的调试和开发阶段：用于生成默认的控制信令传输协议对应的传输参数
% 在 CBS 需要自定义静态 PHY 参数时，生成默认的物理层参数 JSON 文件，
% 供 CBS 自身的发送波形生成或接收解调处理使用。

% 定义默认配置（主脚本部分）
defaultULBS_ID = 1; % 上行数据基站 ID
defaultFFTLength = 256; % FFT 长度
defaultCPFraction = 0.25; % 循环前缀占比
defaultSubcarrierspacing = 30e3; % 子载波间隔
jsonFilePath = fullfile(fileparts(mfilename('fullpath')), 'PHYParams.json');

% 定义 Common 参数（上下行一致）
commonParams = struct();
commonParams.ULBS_ID = defaultULBS_ID;
commonParams.FFTLength = defaultFFTLength;
commonParams.CPFraction = defaultCPFraction;
commonParams.Subcarrierspacing = defaultSubcarrierspacing;

% 定义上行专属参数
uplinkParams = struct();
uplinkParams.BWPoffset = 0;
uplinkParams.PilotSubcarrierSpacing = 20;
uplinkParams.MCS = struct('modOrder', 64, 'coderate', "2/3");
uplinkParams.numSymPerFrame = 15;
uplinkParams.TotalRB = 17; % 上行总资源块数量

% 调用函数生成默认参数并保存到 JSON 文件
getDefaultParamsfcn(commonParams, uplinkParams, jsonFilePath);

function getDefaultParamsfcn(commonParams, uplinkParams, jsonFilePath)
    % getDefaultParamsfcn: 生成默认 PHY 参数并保存到 JSON 文件
    %
    % 功能：
    %   本函数生成控制基站（CBS）物理层信号处理所需的默认参数，包括发送和接收所需的上下行参数，
    %   并将其保存到 JSON 文件中。
    %
    % 输入：
    %   commonParams: 上下行通用参数结构体
    %   uplinkParams: 上行特定参数结构体
    %   downlinkParams: 下行特定参数结构体
    %   jsonFilePath: JSON 文件保存路径
    %
    % 输出：
    %   生成的 JSON 文件包含默认的物理层参数，保存到指定路径中。
    %
    % 注意：
    %   1. Common 参数用于上下行共享，uplink 和 downlink 参数单独定义。
    %   2. 生成的参数主要供 CBS 自身物理层信号处理模块使用（如发送波形生成、接收解调）。

    % 通用参数
    PHYParams.Common = commonParams;

    % 验证和计算资源块参数
    uplinkParams = validateAndCalculateRB(commonParams, uplinkParams, 'uplink');

    % 保存到 PHYParams 结构体中
    PHYParams.Uplink = uplinkParams;

    % 保存到 JSON 文件
    saveParamsToJson(PHYParams, jsonFilePath);

    fprintf('Default PHY parameters successfully saved to %s\n', jsonFilePath);
end

function DirectionParams = validateAndCalculateRB(commonParams, directionParams, direction)
    % validateAndCalculateRB: 验证并计算资源块参数
    %
    % 功能：
    %   根据方向参数（uplink 或 downlink）验证和计算资源块相关参数。
    %
    % 输入：
    %   commonParams: 通用参数结构体
    %   directionParams: 方向专属参数结构体
    %   direction: 方向标识 ('uplink' 或 'downlink')
    %
    % 输出：
    %   DirectionParams: 验证和计算后的方向参数结构体

    % 整合通用参数和方向特定参数
    total_RB = directionParams.TotalRB;
    overAllOfdmParams = commonParams;
    overAllOfdmParams.BWPoffset = directionParams.BWPoffset;
    overAllOfdmParams.PilotSubcarrierSpacing = directionParams.PilotSubcarrierSpacing;

    % 验证资源块配置
    [RB_verified, MaxRB] = calculateRBFinal(overAllOfdmParams, total_RB);
    if total_RB > MaxRB || RB_verified > MaxRB
        error('Error: Defined RB exceeds system maximum allowed RB: %d.', MaxRB);
    end

    overAllOfdmParams.total_RB = total_RB;
    overAllOfdmParams.total_NumSubcarriers = overAllOfdmParams.total_RB * 12;
    overAllOfdmParams.guard_interval = (overAllOfdmParams.FFTLength - overAllOfdmParams.total_NumSubcarriers) / 2;

    % 计算无线资源参数
    alloc_RadioResource = calculateBWPs(overAllOfdmParams, overAllOfdmParams.BWPoffset);

    % 填充方向参数
    DirectionParams = directionParams;
    DirectionParams.dataSubcNum = alloc_RadioResource.UsedSubcc;
    DirectionParams.dataSubc_start_index = alloc_RadioResource.subcarrier_start_index;
    DirectionParams.dataSubc_end_index = alloc_RadioResource.subcarrier_end_index;
    DirectionParams.dataSubc_center_offset = alloc_RadioResource.subcarrier_center_offset;
    DirectionParams.guard_interval = overAllOfdmParams.guard_interval;
    DirectionParams.channelBW = (DirectionParams.guard_interval + DirectionParams.dataSubcNum) * overAllOfdmParams.Subcarrierspacing;
    DirectionParams.signalBW = (2 * DirectionParams.guard_interval + DirectionParams.dataSubcNum) * overAllOfdmParams.Subcarrierspacing;
end

function saveParamsToJson(PHYParams, jsonFilePath)
    % 将参数保存到 JSON 文件
    jsonData = jsonencode(PHYParams);

    % 格式化 JSON 字符串（可选）
    jsonData = strrep(jsonData, ',', sprintf(',\n'));
    jsonData = strrep(jsonData, '{', sprintf('{\n'));
    jsonData = strrep(jsonData, '}', sprintf('\n}'));

    % 写入文件
    fid = fopen(jsonFilePath, 'w');
    if fid == -1
        error('无法打开文件 %s 进行写入', jsonFilePath);
    end
    fwrite(fid, jsonData, 'char');
    fclose(fid);
end
