function startLogging()
    % startLogging - 启动日志记录，自动识别调用脚本或函数名称
    % 日志文件保存在 ./logs/xxx_log.txt，其中 xxx 是调用该函数的脚本或函数名称。

    % 获取调用栈信息
    stackInfo = dbstack;
    callerName = stackInfo(2).name;

    % 定义日志文件路径
    logDir = './logs';
    % if ~exist(logDir, 'dir')
    %     mkdir(logDir);
    % end
    logFileName = fullfile(logDir, [callerName, '_log.txt']);
    currentTime = datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss');

    % 清空日志文件并写入初始化信息
    fid = fopen(logFileName, 'w');
    if fid == -1
        error('Failed to open log file: %s', logFileName);
    end
    fprintf(fid, 'Logging started for: %s\n', callerName);
    fprintf(fid, 'Log file: %s\n', logFileName);
    fprintf(fid, 'Logging time: %s\n', currentTime);

    fclose(fid);

    % 启用 diary 记录后续日志
    diary(logFileName);
    diary on;
end
