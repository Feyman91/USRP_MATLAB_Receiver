% 重置控制参数传输的状态，并清空相关文件

% 定义共享文件路径
root_flagfile = './RRC/cache_file/';
binName = 'ControlParamsFlag.bin';
binFullPath = fullfile(root_flagfile, binName);

% 如果共享文件不存在，则创建并初始化
if ~isfile(binFullPath)
    fid = fopen(binFullPath, 'w');
    fwrite(fid, 0, 'int8');       % flag = 0, 表示无控制参数更新
    fwrite(fid, 0, 'double');    % timestamp = 0
    fclose(fid);
end

% 加载内存映射文件
mmHandle = memmapfile(binFullPath, ...
                      'Writable', true, ...
                      'Format', { ...
                          'int8', [1,1], 'isReadyFlag'; ...      % 标志位
                          'double', [1,1], 'timestamp' ... % 时间戳
                       });

% 重置标志位和时间戳
mmHandle.Data.isReadyFlag = int8(0);
mmHandle.Data.timestamp = double(0);

% 提示重置完成
disp('控制参数生成状态已重置');
