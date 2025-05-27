% 重置CBS端建立连接的状态, 并且清空文件

% 初始化存储当前连接状态的共享文件
root_stagefile = './MAC/cache_file/';
binName   = 'CBS_connection_state.bin';  
binFullPath = fullfile(root_stagefile, binName);
if ~isfile(binFullPath)
    % 文件不存在则新建，写入两个 int8(默认为0)
    fid = fopen(binFullPath, 'w');
    fwrite(fid, 1, 'int8');  % stage = 1, CBS的起始阶段是1
    fwrite(fid, 0, 'int8');  % flag  = 0
    fwrite(fid, 0, 'double');% enterTimeSec(初始写入0.0)
    fclose(fid);
end
% 使用结构化方式映射
m = memmapfile(binFullPath, ...
                      'Writable', true, ...
                      'Format', { ...
                          'int8', [1,1], 'stage'; ...
                          'int8', [1,1], 'flag';  ...
                          'double', [1,1], 'enterTimeSec' ...
                       } ...
                      );

m.Data.stage = int8(1);
m.Data.flag = int8(0);
m.Data.enterTimeSec = double(0);

% 清空日志信息
% vervosity log文件路径
root_logfile = './MAC/logs/';
txtName = 'CBS_connection_verbosity_log.txt';
txtFullPath = fullfile(root_logfile, txtName);

% 清空文件内容
% 打开文件并读取第一行
fileID = fopen(txtFullPath, 'r'); % 以只读模式打开文件
if fileID == -1
    error('无法打开文件：%s', txtFullPath);
end

firstLine = fgetl(fileID); % 读取第一行内容
fclose(fileID); % 关闭文件

% 打开文件并写回第一行内容
fileID = fopen(txtFullPath, 'w'); % 以写模式打开文件，清空内容
if fileID == -1
    error('无法打开文件：%s', txtFullPath);
end

if ischar(firstLine) % 确保第一行不为空
    fprintf(fileID, '%s\n', firstLine); % 写入第一行内容
end

fclose(fileID); % 关闭文件

% brief log文件路径
briefLogName = 'CBS_connection_brief_log.txt';
briefLogPath = fullfile(root_logfile, briefLogName);

% 清空文件内容
% 打开文件并读取第一行
fileID = fopen(briefLogPath, 'r'); % 以只读模式打开文件
if fileID == -1
    error('无法打开文件：%s', briefLogPath);
end
firstLine = fgetl(fileID); % 读取第一行内容
fclose(fileID); % 关闭文件

% 打开文件并写回第一行内容
fileID = fopen(briefLogPath, 'w'); % 以写模式打开文件，清空内容
if fileID == -1
    error('无法打开文件：%s', briefLogPath);
end

if ischar(firstLine) % 确保第一行不为空
    fprintf(fileID, '%s\n', firstLine); % 写入第一行内容
end

fclose(fileID); % 关闭文件

disp('连接状态已重置，日志文件已清空');
% % 清空文件内容
% fileID = fopen(binFullPath, 'w'); % 打开文件，'w'模式会清空内容
% if fileID == -1
%     error('无法打开文件：%s', binFullPath);
% end
% fclose(fileID); % 关闭文件
% disp('连接状态已重置，日志文件已清空');