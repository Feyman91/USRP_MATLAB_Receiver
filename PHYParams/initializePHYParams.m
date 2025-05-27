function PHYParams = initializePHYParams(direction)
    % initializePHYParams: 初始化控制基站（CBS）物理层发送与接收参数
    %
    % 功能：
    %   本函数用于初始化控制基站（CBS）自身物理层（PHY）信号处理的发送和接收参数。
    %   这些参数用于 CBS 在物理层中进行信号的发送波形生成以及接收信号解调。
    %   该函数支持上行和下行两种传输模式，返回包含通用和方向特定参数的结构体。
    %
    % 输入：
    %   direction: 指定 CBS 端物理层的工作模式，支持以下值：
    %       - 'uplink'：生成 CBS 端接收 UE 上行信号的解调参数。
    %       - 'downlink'：生成 CBS 端发送至 UE 的下行信号的传输参数。
    %
    % 输出：
    %   PHYParams: 包含通用（Common）参数和方向特定（Uplink 或 Downlink）
    %              参数的一级结构体，供 CBS 信号处理函数调用。
    %
    % 功能描述：
    %   - 从预定义的 JSON 配置文件（PHYParams.json）中读取 CBS 所需的通用参数和方向特定参数。
    %   - 根据输入参数 direction 合并通用和方向特定参数，生成一个完整的 PHY 参数结构体。
    %   - 返回的 PHY 参数供 CBS 的物理层信号处理模块使用，用于发送波形生成或接收信号解调。
    %
    % 示例：
    %   % 初始化用于接收上行信号的 CBS 物理层参数
    %   PHYParams = initializePHYParams('uplink');
    %
    %   % 初始化用于发送下行信号的 CBS 物理层参数
    %   PHYParams = initializePHYParams('downlink');
    %
    % 注意：
    %   1. JSON 文件路径已在函数中固定为 'PHYParams.json'。
    %   2. JSON 文件必须包含以下顶级字段：'Common'、'Uplink'、'Downlink'。
    %   3. 返回的参数用于 CBS 自身信号处理，而非用于生成控制信令。
    %

    % JSON 文件路径
    jsonFilePath = fullfile(fileparts(mfilename('fullpath')), 'PHYParams.json');

    % 检查输入参数
    if nargin < 1
        error('Missing input argument. You must specify the direction.');
    end
    if ~isfile(jsonFilePath)
        error('PHYParams.json 文件未找到，请检查路径：%s', jsonFilePath);
    end
    if ~any(strcmp(direction, {'uplink', 'downlink'}))
        error('Invalid direction. Must be ''uplink'' or ''downlink''.');
    end

    % 读取 JSON 文件内容
    jsonData = fileread(jsonFilePath);

    % 解析 JSON 数据为 MATLAB 结构体
    allParams = jsondecode(jsonData);

    % 提取通用参数
    if ~isfield(allParams, 'Common')
        error('JSON 文件缺少 "Common" 参数，请检查文件内容。');
    end
    commonParams = allParams.Common;

    % 提取方向参数
    if strcmp(direction, 'uplink')
        if ~isfield(allParams, 'Uplink')
            error('JSON 文件缺少 "Uplink" 参数，请检查文件内容。');
        end
        directionParams = allParams.Uplink;
    elseif strcmp(direction, 'downlink')
        if ~isfield(allParams, 'Downlink')
            error('JSON 文件缺少 "Downlink" 参数，请检查文件内容。');
        end
        directionParams = allParams.Downlink;
    end

    % 合并 Common 和指定方向参数为一级结构体
    PHYParams = commonParams; % 初始化为 Common 参数
    directionFields = fieldnames(directionParams);
    for i = 1:numel(directionFields)
        PHYParams.(directionFields{i}) = directionParams.(directionFields{i});
    end
end
