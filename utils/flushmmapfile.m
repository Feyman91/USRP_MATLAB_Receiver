% FLUSHMMAPFILE Resets the memory-mapped file to its initial state
% 
% Default parameters
defaultRoot = "./downlink_receive/cache_file/";
defaultFilename = "received_buffer_new.bin";
filename = fullfile(defaultRoot, defaultFilename);
totalMemorySizeInGB = 4; % Default memory size (4 GB)

% Define parameters for memory-mapped file structure
headerSizePerMessage = 1;     % Header flag size per message (int8)
metadataSizePerMessage = 12;  % Metadata per message: [numSamples, startIndex, endIndex] (int32 x 3)
sampleSize = 16;              % Data size per complex sample (double for real and imag parts)
totalMessages = 30000;        % Maximum number of messages

% Estimate space allocation
headerSize = headerSizePerMessage * totalMessages;        % Total header flag space
metadataSize = metadataSizePerMessage * totalMessages;    % Total metadata space
pointerSize = 2; % Each pointer (writePointer, maxWritePointer) is int16, hence 2 bytes
totalPointerSize = 2 * pointerSize;                       % Total pointer space
dataSize = totalMemorySizeInGB * 1024^3 - (headerSize + metadataSize + totalPointerSize);
maxSamples = floor(dataSize / sampleSize);                % Calculate max samples that can fit in Data region

% Initialize zero-filled arrays for the sections
InitHeader = -ones(totalMessages, 1, 'int8');             % All initialized to -1
InitMetadata = zeros(totalMessages, 3, 'int32');          % Metadata: [numSamples, startIndex, endIndex]
InitData = zeros(maxSamples, 2, 'double');                % Data storage for complex samples
InitWritePointer = int16(1);                              % Initialize writePointer to 1
InitMaxWritePointer = int16(0);                           % Initialize maxWritePointer to 0

% 创建或重置文件
if ~exist(defaultFilename, 'file')
    % 如果文件不存在，先创建文件
    [f, msg] = fopen(defaultFilename, 'w');
    if f ~= -1
        fwrite(f, InitHeader, 'int8');
        fwrite(f, InitMetadata, 'int32');
        fwrite(f, InitWritePointer, 'int16');
        fwrite(f, InitMaxWritePointer, 'int16');
        fwrite(f, InitData, 'double');
        fclose(f);
        disp('Memory-mapped file created successfully.');
    else
        error('File creation failed: %s', msg);
    end
end

% 使用 memmapfile 映射文件
m = memmapfile(defaultFilename, ...
    'Format', { ...
        'int8', [totalMessages, 1], 'headerFlags'; ...        % 标头部分
        'int32', [totalMessages, 3], 'messageMetadata'; ...   % 元数据部分
        'int16', [1, 1], 'writePointer'; ...                  % 写入指针
        'int16', [1, 1], 'maxWritePointer'; ...               % 最大写入指针
        'double', [maxSamples, 2], 'complexData' ...          % 数据部分
    }, ...
    'Writable', true);

% 使用内存映射的方式写入初始化值
try
    m.Data.headerFlags(:) = InitHeader;                       % 重置标头部分
    m.Data.messageMetadata(:) = InitMetadata;                 % 重置元数据部分
    m.Data.writePointer = InitWritePointer;                   % 重置写入指针
    m.Data.maxWritePointer = InitMaxWritePointer;             % 重置最大写入指针
    m.Data.complexData(:) = InitData;                         % 重置数据部分
    disp('Memory-mapped file reset successfully.');
catch ME
    error('Failed to reset memory-mapped file: %s', ME.message);
end
