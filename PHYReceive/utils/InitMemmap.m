function m = InitMemmap(filename, totalMemorySizeInGB)
    % InitMemmap Initialize a memory-mapped file with separate sections for flexible data capture
    %
    % Inputs:
    %   filename - Full path for the memory-mapped file
    %   totalMemorySizeInGB - Total memory size in GB for the file
    %
    % Output:
    %   m - Memory-mapped file handle

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

    % Create or validate memory-mapped file
    if ~exist(filename, 'file')
        [f, msg] = fopen(filename, 'w');
        if f ~= -1
            fwrite(f, InitHeader, 'int8');
            fwrite(f, InitMetadata, 'int32');
            fwrite(f, InitWritePointer, 'int16');
            fwrite(f, InitMaxWritePointer, 'int16');
            fwrite(f, InitData, 'double');
            fclose(f);
            disp('Memory-mapped file created and initialized successfully.');
        else
            error('File creation failed: %s', msg);
        end
    else
        % Validate file size
        fileInfo = dir(filename);
        expectedFileSize = headerSize + metadataSize + totalPointerSize + (maxSamples * sampleSize);
        if fileInfo.bytes ~= expectedFileSize
            error('File size mismatch: expected %d bytes, but found %d bytes.', expectedFileSize, fileInfo.bytes);
        else
            disp('Memory-mapped file exists and matches expected size.');
        end
    end

    % Map the file with the specified structure
    m = memmapfile(filename, ...
        'Format', { ...
            'int8', [totalMessages, 1], 'headerFlags'; ...    % Section 1: Header flags
            'int32', [totalMessages, 3], 'messageMetadata'; ... % Section 2: Metadata
            'int16', [1, 1], 'writePointer'; ...              % Section 3: Write pointer
            'int16', [1, 1], 'maxWritePointer'; ...           % Section 4: Max write pointer
            'double', [maxSamples, 2], 'complexData' ...      % Section 5: Complex data
        }, ...
        'Writable', true);

    disp('Memory mapping initialized successfully.');
end
