function rxDiagnostics = captureData(bbtrx, captureLength, m)
    % captureData: Capture IQ data using bbtrx and save it in memory-mapped file
    % m: Memory-mapped file handle from InitMemmap.
    
    % Persistent variables to store diagnostics history
    persistent rxDiagnosticsHistory;
    
    if isempty(rxDiagnosticsHistory)
        % Initialize persistent structure with preallocated arrays
        maxMessages = 10000; % Adjust size based on your expected usage
        % rxDiagnosticsHistory.timestamp = cell(maxMessages, 1);                      % 每次捕获的时间戳，存储在 cell 数组中
        rxDiagnosticsHistory.droppedSamples = zeros(maxMessages, 1, 'int8');        % 每次捕获中丢失的样本数量（int8 类型）
        rxDiagnosticsHistory.numSamples = zeros(maxMessages, 1);                    % 每次捕获的样本总数
        % rxDiagnosticsHistory.USRPcaptureTime = zeros(maxMessages, 1, 'single');     % 每次捕获在 USRP 中的采集时间（单位：秒）
        rxDiagnosticsHistory.HostcaptureTime = zeros(maxMessages, 1, 'single');     % 每次捕获从 USRP 到主机内存的保存时间（单位：秒）
        rxDiagnosticsHistory.saveTime = zeros(maxMessages, 1, 'single');            % 每次捕获数据存储到内存映射文件的时间（单位：秒）
        rxDiagnosticsHistory.totalCaptureTime = zeros(maxMessages, 1, 'single');    % 每次捕获的总时间（采集保存时间 + 存储时间）
        % rxDiagnosticsHistory.dataStartIdx = zeros(maxMessages, 1);                  % 每次捕获的数据在内存映射文件中的起始索引
        % rxDiagnosticsHistory.dataEndIdx = zeros(maxMessages, 1);                    % 每次捕获的数据在内存映射文件中的结束索引
        rxDiagnosticsHistory.writePointer = zeros(maxMessages, 1, 'int16');                  % 每次捕获对应的写指针值
        rxDiagnosticsHistory.captureMsgCount = 0;                                   % 累计调用 captureData 的次数，表示捕获了多少个 message
    end

    % fprintf('\n--------Starting Reception--------\n');

    % Determine capture length
    sampleRate = bbtrx.SampleRate;
    if isa(captureLength, 'double') && mod(captureLength, 1) == 0
        numSamples = captureLength; % Length in samples
    elseif isa(captureLength, 'duration')
        numSamples = ceil(seconds(captureLength) * sampleRate); % Convert to samples
    else
        error('Invalid captureLength type. Must be an integer (number of samples) or duration.');
    end

    % Fetch write pointer
    writePointer = m.Data.writePointer;
    % fprintf('Using write pointer: %d\n', writePointer);

    % Calculate startIdx and endIdx
    if writePointer == 1
        % For the first message, start at index 1
        startIdx = 1;
    else
        prevMetadata = m.Data.messageMetadata(writePointer - 1, :);
        startIdx = prevMetadata(3) + 1; % Previous endIdx + 1
    end
    endIdx = startIdx + numSamples - 1;

    % Check if the endIdx exceeds the storage space
    if endIdx > size(m.Data.complexData, 1)
        warning('Insufficient space in memory-mapped file. Wrapping around...');
        startIdx = 1;
        endIdx = numSamples;
        m.Data.maxWritePointer = writePointer - 1; % Update maxWritePointer for the previous round        
        writePointer = int16(1);
        m.Data.writePointer = writePointer;
    % elseif writePointer > m.Data.maxWritePointer
    %     m.Data.maxWritePointer = writePointer; % Ensure maxWritePointer is updated
    end

    % Check header flag at current pointer
    if m.Data.headerFlags(writePointer) == 0
        warning('Overwriting unprocessed data at message %d.', writePointer);
        rxDiagnostics = [];
        pause(1); % 等待1s
        return
    end

    % Capture data
    start_time = tic;
    [rxWaveform, timestamp, droppedSamples] = capture(bbtrx, numSamples);
    HostscaptureTime = toc(start_time);

    % Save data to memory-mapped file
    start_time = tic;
    m.Data.complexData(startIdx:endIdx, :) = [real(rxWaveform), imag(rxWaveform)];
    m.Data.messageMetadata(writePointer, :) = [numSamples, startIdx, endIdx];
    m.Data.headerFlags(writePointer) = 0; % Mark as unprocessed

    % Update write pointer
    writePointer = writePointer + 1;
    if writePointer > m.Data.maxWritePointer
        m.Data.maxWritePointer = writePointer; % Ensure maxWritePointer is updated
    end

    if writePointer > size(m.Data.headerFlags, 1)
        error(['The sizes of headerFlags (%d) and messageMetadata (%d) must be greater than or equal ' ...
            'to the total number of messages that can be stored in complexData.'], ...
            size(m.Data.headerFlags, 1), size(m.Data.messageMetadata, 1));
    end
    m.Data.writePointer = writePointer;

    saveTime = toc(start_time);
    % USRPcaptureTime = numSamples / sampleRate;
    totalCaptureTime = HostscaptureTime + saveTime; % Total time for the operation
    
    % Update diagnostics history
    captureCount = rxDiagnosticsHistory.captureMsgCount + 1;
    % rxDiagnosticsHistory.timestamp{captureCount} = timestamp;
    rxDiagnosticsHistory.droppedSamples(captureCount) = droppedSamples;
    rxDiagnosticsHistory.numSamples(captureCount) = numSamples;
    % rxDiagnosticsHistory.USRPcaptureTime(captureCount) = USRPcaptureTime;
    rxDiagnosticsHistory.HostcaptureTime(captureCount) = HostscaptureTime;
    rxDiagnosticsHistory.saveTime(captureCount) = saveTime;
    rxDiagnosticsHistory.totalCaptureTime(captureCount) = totalCaptureTime;
    % rxDiagnosticsHistory.dataStartIdx(captureCount) = startIdx;
    % rxDiagnosticsHistory.dataEndIdx(captureCount) = endIdx;
    rxDiagnosticsHistory.writePointer(captureCount) = writePointer;
    rxDiagnosticsHistory.captureMsgCount = captureCount;

    % Return updated diagnostics
    rxDiagnostics = rxDiagnosticsHistory;

    % Log capture summary
    % fprintf('Captured %.5e samples (%.5f seconds) in %.3f seconds capture time and %.3f seconds save time.\n', ...
    %     numSamples, captureTime, capture_time, save_time);
    % fprintf('--------Data reception completed.--------\n');
    fprintf('.')
    if mod(writePointer, 30) == 0
        fprintf('\n'); % 达到每行点数时换行
    end
end
