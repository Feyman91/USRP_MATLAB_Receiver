function mmHandle = initStateMemmap(binFullPath)
% 初始化(或加载)一个二进制文件，并将其映射为一个结构, 包含字段:
%   1) stage (int8)
%   2) flag  (int8)
%
% 输入:
%   binFullPath : 完整的二进制文件路径(包含文件名)
%
% 输出:
%   mmHandle    : memmapfile 句柄，使用 mmHandle.Data.stage / mmHandle.Data.flag 访问

    if ~isfile(binFullPath)
        % 文件不存在则新建，写入两个 int8(默认为0)
        fid = fopen(binFullPath, 'w');
        fwrite(fid, 1, 'int8');  % stage = 1, CBS的起始阶段是1
        fwrite(fid, 0, 'int8');  % flag  = 0
        fwrite(fid, 0, 'double');% enterTimeSec(初始写入0.0)
        fclose(fid);
    end
    
    % 使用结构化方式映射
    mmHandle = memmapfile(binFullPath, ...
                          'Writable', true, ...
                          'Format', { ...
                              'int8', [1,1], 'stage'; ...
                              'int8', [1,1], 'flag';  ...
                              'double', [1,1], 'enterTimeSec' ...
                           } ...
                          );
    % 之后即可用 mmHandle.Data.stage / mmHandle.Data.flag 进行读写
end
