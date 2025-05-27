function mmHandle = initControlParamMemmap(binFullPath)
% 初始化(或加载)一个内存映射文件，用于管理控制参数传输状态
%
% 输入:
%   binFullPath : 完整的二进制文件路径(包含文件名)
%
% 输出:
%   mmHandle    : memmapfile 句柄，用于访问内存映射数据

    % 如果文件不存在，则初始化文件内容
    if ~isfile(binFullPath)
        % 创建文件并写入默认值
        fid = fopen(binFullPath, 'w');
        fwrite(fid, 0, 'int8');           % flag = 0, 无控制参数更新
        fwrite(fid, 0, 'double');        % timestamp = 0
        fclose(fid);
    end

    % 定义内存映射文件结构
    mmHandle = memmapfile(binFullPath, ...
                          'Writable', true, ...
                          'Format', { ...
                              'int8', [1,1], 'isReadyFlag'; ...          % 标志是否有控制参数更新
                              'double', [1,1], 'timestamp' ...   % 时间戳
                           });

    % 返回内存映射句柄
end
