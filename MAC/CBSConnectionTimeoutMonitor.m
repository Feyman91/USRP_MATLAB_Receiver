function CBSConnectionTimeoutMonitor(m_handle, readPointerStruct, sysParamRxObj, resultStruct)
% 函数，用于定时检测CBS当前阶段是否超过6秒没变化
% 若超时则回到初始阶段(stage=1).

    %=== 1) 进行一次检查
    root_logfile = './MAC/logs/';
    briefLogName = 'CBS_connection_brief_log.txt';
    briefLogPath = fullfile(root_logfile, briefLogName);

    framePointer = readPointerStruct.frameprocesspointer;
    messagePointer = readPointerStruct.messageprocesspointer;
    currentStage = m_handle.Data.stage;
    timeEntered  = m_handle.Data.enterTimeSec;
    nowSec       = posixtime(datetime('now')); 
    
    cbsID = sysParamRxObj.sysParam.CBS_ID;
    % 仅当阶段>1时(假设1是CBS初始阶段), 才做超时检测
    if currentStage > 1  
        ueID = resultStruct.UE_ID;
        elapsed = nowSec - timeEntered;
        if elapsed > 6
            % 超时, 回到初始阶段=1，仅在简短日志里记录
            appendBriefLog(briefLogPath, currentStage, ueID, cbsID, framePointer, messagePointer)
            m_handle.Data.stage        = int8(1);
            m_handle.Data.flag         = int8(1);
            m_handle.Data.enterTimeSec = nowSec; % 重置时间
        end
    end
end


function appendBriefLog(briefLogPath, crtStage, ueID, cbsID, framePointer, messagePointer)
% 仅在简短日志里记录
    fid = fopen(briefLogPath, 'a');
    if fid == -1
        error('Cannot open brief log file "%s" for appending.', briefLogPath);
    end
    fprintf(fid, '\n');
    fprintf(fid, '----------------%s----------------\n', datetime('now'));

    fprintf(fid, '[CBS_ID_%d msg:%d frame:%d](STATE_%d) Waiting timed out！ (>6s)\n', ...
        cbsID, messagePointer, framePointer, crtStage);
    fprintf(fid, '[CBS_ID_%d msg:%d frame:%d](STATE_%d) Lost connection with @UE_ID %d！\n', ...
        cbsID, messagePointer, framePointer, crtStage, ueID);
    fprintf(fid, '[CBS_ID_%d msg:%d frame:%d](STATE_%d) Revert to stage 1\n', ...
        cbsID, messagePointer, framePointer, crtStage);    
    fclose(fid);
end

