% 主脚本：生成控制参数 JSON 文件

% 初始化存储控制参数生成状态的共享文件
root_stagefile = './RRC/cache_file/';
binName   = 'ControlParamsFlag.bin';  
binFullPath = fullfile(root_stagefile, binName);
m_controlParamState = initControlParamMemmap(binFullPath);

% 输入参数
CBS_ID = 2; % 控制基站 ID
UE_IDs = [1]; % 当前接入的 UE ID
onlineBS_IDs = [1, 2]; % 当前在线的下行基站 ID

commonParams = struct(); % 初始化通用参数
commonParams.FFTLength = 1024; % FFT 长度
commonParams.CPFraction = 0.25; % 循环前缀比例
commonParams.Subcarrierspacing = 30e3; % 子载波间隔
commonParams.total_RB = 67; % 总资源块数量
commonParams.onlineBS_IDs = onlineBS_IDs;

% 输出 JSON 文件路径
jsonFilePath = fullfile(fileparts(mfilename('fullpath')), 'DownlinkControlParams.json');

% 验证 total_RB 的合法性
[RB_verified, MaxRB] = calculateRBFinal(commonParams, commonParams.total_RB);
if commonParams.total_RB > MaxRB || RB_verified > MaxRB
    error('Error: Defined RB exceeds system maximum allowed RB: %d.', MaxRB);
end

% 调用生成控制参数函数
controlParams = genControlParams4DLTrFcn(CBS_ID, UE_IDs, onlineBS_IDs, commonParams);

% 保存 JSON 文件
saveControlParamsToJson(controlParams, jsonFilePath);

% 标记控制参数已生成
m_controlParamState.Data.isReadyFlag = int8(1);

% 记录时间戳
m_controlParamState.Data.timestamp = posixtime(datetime('now'));

fprintf('Downlink control parameters JSON file generated successfully.\n');
