function [rxDataBits, resultStruct, readPointerStruct, SigOccured_frameNum, ...
    sysParamRxObj, visualizationTools, MeasurementTools] = processOneFrameData( ...
    sysParamRxObj, watch_filteredResult, m, visualizationTools, MeasurementTools, ...
    resultStruct, readPointerStruct, m_connectState, m_controlParamState)
    processTime_start = tic;
    % processOneFrameData: 解调单个基站一个帧的数据，支持跨 message 的处理
    % 全局变量，用于追踪消息的绝对索引，即当前处理了总共多少个message
    persistent globalabsolMessageIndex;
    enable_reset = 0;
    if isempty(globalabsolMessageIndex)
        globalabsolMessageIndex = 1;
    end

    % 生成 ULBS_ID，例如 "@ULBS_1"
    ULBS_ID = sysParamRxObj.sysParam.ULBS_ID;
    current_ULBS_field = sprintf('@ULBS_%d', ULBS_ID);

    % 获取传入的基站参数和指针
    transportBlk_bs = sysParamRxObj.transportBlk_bs;
    framePointer = readPointerStruct.frameprocesspointer;
    messagePointer = readPointerStruct.messageprocesspointer;
    framesize = sysParamRxObj.sysParam.txWaveformSize;
    
    % 检查 headerFlags 确保数据未被处理
    headerflag = m.Data.headerFlags(messagePointer);
    if headerflag ~= 0
        if headerflag == -1
            warning('[%s]Msg(%d):Data at message %d is not ready.', ...
            current_ULBS_field,messagePointer, messagePointer);
        else
            warning('[%s]Msg(%d):Data at message %d is already processed.', ...
            current_ULBS_field,messagePointer, messagePointer);
        end
        rxDataBits = [];
        SigOccured_frameNum = [];
        pause(1); % 等待 1s
        return;
    end

    % 获取当前 message 的元数据
    currentMetadata = m.Data.messageMetadata(messagePointer, :);
    messageStartIdx = currentMetadata(2); % message 的 startIdx
    messageEndIdx = currentMetadata(3);   % message 的 endIdx

    % 计算帧的起始和结束索引
    startIdx = messageStartIdx + (framePointer - 1) * framesize;
    endIdx = startIdx + framesize - 1;

    % 检测是否跨越当前 message
    if endIdx > messageEndIdx
        % 当前帧跨越了 message 边界
        warning('[%s]Msg(%d):Detected cross-message boundary at message %d in frame %d, abandoning this frame and ReSyncing...', ...
            current_ULBS_field,messagePointer,messagePointer, framePointer);

        % 设置 headerFlags当前message为数据已处理状态：1
        m.Data.headerFlags(messagePointer) = 1;
        
        % 更新到下一个 message
        messagePointer = messagePointer + 1;
        globalabsolMessageIndex = globalabsolMessageIndex + 1;  % 更新存储结果的 globalMessageIndex
        if messagePointer > m.Data.maxWritePointer
            fprintf('\n[%s]Msg(%d):---------- Wrapping around ----------\n', current_ULBS_field,messagePointer);
            messagePointer = 1; % 循环回第一个 message
        end
        
        % 清除持久变量并重置同步状态,重置统计解调结果函数object
        clear helperOFDMRx helperOFDMFrequencyOffset helperOFDMRxSearch helperOFDMRxFrontEnd;
        sysParamRxObj.sysParam.timingAdvance = framesize;
        if sysParamRxObj.dataParams.enableConst_measure && enable_reset
            MeasurementTools = resetMeasurementTools(MeasurementTools);
        end
        if mod(messagePointer, 10) == 0 && sysParamRxObj.dataParams.enableScopes && enable_reset
            visualizationTools = resetVisualizationTools(visualizationTools);
        end

        framePointer = 1; % 从第一帧开始

        % 检查 headerFlags 确保数据未被处理
        headerflag = m.Data.headerFlags(messagePointer);
        if headerflag ~= 0
            if headerflag == -1
                warning('[%s]Msg(%d):Data at message %d is not ready.', ...
                current_ULBS_field,messagePointer, messagePointer);
            else
                warning('[%s]Msg(%d):Data at message %d is already processed.', ...
                current_ULBS_field,messagePointer, messagePointer);
            end
            rxDataBits = [];
            SigOccured_frameNum = [];
            % 如果本个message未被捕获，那么需要先更新 readPointerStruct，再返回。
            readPointerStruct.frameprocesspointer = framePointer;
            readPointerStruct.messageprocesspointer = messagePointer;
            pause(1); % 等待 1s
            return;
        end

        % 获取新 message 的元数据
        currentMetadata = m.Data.messageMetadata(messagePointer, :);
        messageStartIdx = currentMetadata(2);
        startIdx = messageStartIdx; % 从新 message 的开头处理
        endIdx = startIdx + framesize - 1;
    end

    % 读取一帧数据
    rxWaveform = complex(m.Data.complexData(startIdx:endIdx, 1), ...
                         m.Data.complexData(startIdx:endIdx, 2));
    
    % 显示频谱分析
    if sysParamRxObj.dataParams.enableScopes && ~watch_filteredResult
        visualizationTools.spectrumAnalyze.Title = sprintf('Received Signal from %s', current_ULBS_field);
        visualizationTools.spectrumAnalyze(rxWaveform);
        % visualizationTools.timesink(rxWaveform);
    end

    % 调用前端处理函数
    rxIn = helperOFDMRxFrontEnd(rxWaveform, ...
        sysParamRxObj.sysParam, ...
        sysParamRxObj.rxObj, ...
        visualizationTools.spectrumAnalyze, ...
        watch_filteredResult);


    % 解调数据
    resultStruct.previousTimePerBS = tic;
    [rxDataBits, isConnected, toff, rxDiagnostics, SigOccured_frameNum] = helperOFDMRx( ...
        rxIn, ...
        sysParamRxObj.sysParam, ...
        sysParamRxObj.rxObj, ...
        visualizationTools.timesink, ...
        framePointer, ...
        messagePointer);
    resultStruct.currentTimePerBS = toc(resultStruct.previousTimePerBS);

    if isempty(SigOccured_frameNum)
        % 信号消失的特殊情况
        clear helperOFDMRx helperOFDMFrequencyOffset helperOFDMRxSearch helperOFDMRxFrontEnd;
        sysParamRxObj.sysParam.timingAdvance = framesize;
        if sysParamRxObj.dataParams.enableScopes && enable_reset
            visualizationTools = resetVisualizationTools(visualizationTools);
        end
        if sysParamRxObj.dataParams.enableConst_measure && enable_reset
            MeasurementTools = resetMeasurementTools(MeasurementTools);
        end
    else
        sysParamRxObj.sysParam.timingAdvance = toff;
    end

    % 更新解调结果和状态
    resultStruct.isConnected(globalabsolMessageIndex, framePointer) = isConnected;
    resultStruct.totalBitsReceived = length(rxDataBits);

    % 更新性能测量结果
    if isConnected
        % 进行与用户连接状态的管理
        % 在上行多基站分集接收测试中，不需要进行控制链路的管理，故注释
        % UE_ID = CBSConnectionStateManager(rxDataBits, rxDiagnostics, sysParamRxObj.sysParam, m_connectState, m_controlParamState);
        % if ~isempty(UE_ID)
        %     resultStruct.UE_ID = UE_ID;
        % end

        % 更新误码率 (通过 MeasurementTools 访问 BER 对象)
        berVals = MeasurementTools.BER( ...
            transportBlk_bs((1:sysParamRxObj.sysParam.trBlkSize)).', rxDataBits);
        resultStruct.BER_collection(globalabsolMessageIndex, framePointer) = berVals(1);

        % 计算数据速率
        dataRate = length(rxDataBits) / resultStruct.currentTimePerBS;
        resultStruct.dataRateCollection(globalabsolMessageIndex, framePointer) = dataRate;

        % 更新峰值速率
        if dataRate > resultStruct.peakRate(globalabsolMessageIndex)
            resultStruct.peakRate(globalabsolMessageIndex) = dataRate;
        end

        % 计算EVM、MER、RSSI 和 CFO 
        if sysParamRxObj.dataParams.enableConst_measure
            % 计算并更新 EVM 和 MER
            headerEVM = MeasurementTools.EVM.header(rxDiagnostics.rxConstellationHeader(:));
            dataEVM = MeasurementTools.EVM.data(rxDiagnostics.rxConstellationData(:));
    
            headerMER = MeasurementTools.MER.header(rxDiagnostics.rxConstellationHeader(:));
            dataMER = MeasurementTools.MER.data(rxDiagnostics.rxConstellationData(:));
    
            % 保存 EVM 测量值
            resultStruct.EVM_collection.header(globalabsolMessageIndex, framePointer) = headerEVM;
            resultStruct.EVM_collection.data(globalabsolMessageIndex, framePointer) = dataEVM;

            % 保存 MER 测量值
            resultStruct.MER_collection.header(globalabsolMessageIndex, framePointer) = headerMER;
            resultStruct.MER_collection.data(globalabsolMessageIndex, framePointer) = dataMER;

            % 计算并保存CFO
            resultStruct.CFO_collection(globalabsolMessageIndex, framePointer) = rxDiagnostics.estCFO(end);
        end

        % 显示星座图
        if  sysParamRxObj.dataParams.enableScopes
            visualizationTools.constDiag(complex(rxDiagnostics.rxConstellationHeader(:)), ...
                                         complex(rxDiagnostics.rxConstellationData(:)));
        end
    end

    if ~isempty(rxIn)
        % 计算并保存 RSSI
        if sysParamRxObj.dataParams.enableConst_measure
            resultStruct.RSSI_collection(globalabsolMessageIndex, framePointer) = ...
                10 * log10(mean(abs(rxIn).^2)) + 30;
        end
        processTime_end = toc(processTime_start);
        resultStruct.processTimePerFrame(globalabsolMessageIndex, framePointer) = processTime_end;
        % 更新帧指针
        framePointer = framePointer + 1;
    end

    % 更新 readPointerStruct
    readPointerStruct.frameprocesspointer = framePointer;
    readPointerStruct.messageprocesspointer = messagePointer;
end


