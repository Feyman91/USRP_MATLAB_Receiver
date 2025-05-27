%% deleteCacheFiles.m
% 本脚本递归搜索所有名为 "cache_file"和"logs" 的文件夹，
% 删除其下所有文件，并打印删除的文件名。
%
% 使用前请注意：
% 1. 脚本在执行删除操作前不会进行确认，请先确保没有误删重要文件。
% 2. 如果 "cache_file/logs" 文件夹中存在子文件夹，当前代码只会删除第一层的文件，如果需要
%    递归删除子文件夹中的文件，可在此基础上扩展代码。

% 获取当前主目录（脚本所在目录）
mainDir = pwd;

% 使用通配符递归搜索所有名为 "cache_file" 的文件夹
cacheDirInfo = dir(fullfile(mainDir, '**', 'cache_file'));

if isempty(cacheDirInfo)
    disp('没有找到名为 "cache_file" 的文件夹！');
else
    % 遍历所有找到的 cache_file 文件夹
    for i = 1:length(cacheDirInfo)
        % 忽略 '.' 和 '..' 两个特殊文件夹，同时忽略文件夹，只处理文件
        if cacheDirInfo(i).isdir
            continue;
        end
        % 拼接出 cache_file 文件夹的完整路径
        cacheFolder = fullfile(cacheDirInfo(i).folder, cacheDirInfo(i).name);

        % fprintf('正在处理文件： %s\n', cacheFolder);
        
        % 获取该文件夹下所有内容信息
        filesInCache = dir(cacheFolder);
        
        % 遍历所有内容，删除文件
        for j = 1:length(filesInCache)
            % 拼接出文件的完整路径
            filePath = fullfile(filesInCache(j).folder, filesInCache(j).name);
            
            % 删除文件
            delete(filePath);
            
            % 打印出删除的文件名（相对于主目录的路径）
            relPath = strrep(filePath, mainDir, '.');
            fprintf('已删除文件： %s\n', relPath);
        end
    end
    disp('所有 cache_file 下的文件已处理完毕。');
end

% 使用通配符递归搜索所有名为 "logs" 的文件夹
logsDirInfo = dir(fullfile(mainDir, '**', 'logs'));

if isempty(logsDirInfo)
    disp('没有找到名为 "logs" 的文件夹！');
else
    % 遍历所有找到的 cache_file 文件夹
    for i = 1:length(logsDirInfo)
        % 忽略 '.' 和 '..' 两个特殊文件夹，同时忽略文件夹，只处理文件
        if logsDirInfo(i).isdir
            continue;
        end
        % 拼接出 logs 文件夹的完整路径
        cacheFolder = fullfile(logsDirInfo(i).folder, logsDirInfo(i).name);

        % 获取该文件夹下所有内容信息
        filesInCache = dir(cacheFolder);
        
        % 遍历所有内容，删除文件
        for j = 1:length(filesInCache)
            % 拼接出文件的完整路径
            filePath = fullfile(filesInCache(j).folder, filesInCache(j).name);
            
            % 删除文件
            delete(filePath);
            
            % 打印出删除的文件名（相对于主目录的路径）
            relPath = strrep(filePath, mainDir, '.');
            fprintf('已删除文件： %s\n', relPath);
        end
    end
    disp('所有 logs 下的文件已处理完毕。');
end