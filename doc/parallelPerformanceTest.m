function parallelPerformanceTest()
    % 配置测试参数，使用命名的并行池配置
    configurations = {
        struct('Name', 'HighParallelMode', 'NumWorkers', 32, 'NumThreads', 1);  % 配置 1：高并行度，单线程
        struct('Name', 'ExtremePerformanceMode', 'NumWorkers', 4, 'NumThreads', 8);  % 配置 2：极致性能
        struct('Name', 'HighPerformanceMode', 'NumWorkers', 8, 'NumThreads', 4); % 配置 3：高性能模式
        struct('Name', 'BalancedMode', 'NumWorkers', 16, 'NumThreads', 2);       % 配置 4：混合模式
        struct('Name', 'Processes', 'NumWorkers', 16, 'NumThreads', 1);       % 配置 5：默认
        };

    % 每种配置重复测试次数
    numRepeats = 3;

    % 初始化结果存储
    results = table('Size', [0, 3], 'VariableTypes', {'string', 'double', 'double'}, ...
                    'VariableNames', {'Configuration', 'NumWorkers', 'AvgTime'});

    % 遍历配置进行测试
    for i = 1:numel(configurations)
        config = configurations{i};
        fprintf('Testing configuration: %s\n', config.Name);

        % 存储运行时间
        times = zeros(1, numRepeats);

        for j = 1:numRepeats
            fprintf('  Test %d/%d...\n', j, numRepeats);

            % 启动并行池，使用命名配置
            if ~isempty(gcp('nocreate'))
                delete(gcp);  % 删除现有池
            end
            parpool(config.Name);  % 使用命名配置文件初始化并行池
            pause(2)
            % 记录运行时间
            tic;
            parfor k = 1:4
                % 模拟基站解调任务
                simulateBaseStationTask(k);
            end
            times(j) = toc;

            % 删除并行池
            delete(gcp);
            pause(2)
        end

        % 计算平均时间
        avgTime = mean(times);

        % 保存结果
        results = [results; {config.Name, config.NumWorkers, avgTime}];
        fprintf('Configuration %s completed: AvgTime = %.2f seconds\n', config.Name, avgTime);
    end

    % 显示测试结果
    disp('Performance Test Results:');
    disp(results);

    % 可视化结果
    visualizeResults(results);
end

function simulateBaseStationTask(idx)
   % 模拟基站解调任务
    for i = 1:5
        fprintf('Worker %d processing task...\n', idx);
        
        % 参数设置
        numSubcarriers = 2430000;          % OFDM 子载波数
        fftLength = numSubcarriers;  % FFT 长度
        qamOrder = 4096;               % QAM 调制阶数
        numSymbols = 30000;            % 每次传输的符号数量
        
        % QAM 调制
        dataBits = randi([0 1], numSymbols * log2(qamOrder), 1); % 随机生成比特流
        qamModulatedSymbols = qammod(dataBits, qamOrder, 'InputType', 'bit', 'UnitAveragePower', true);
        
        % 调整 QAM 调制后的符号为 OFDM 所需的形状
        % 每个 OFDM 符号需要填满所有子载波
        numOFDMSymbols = ceil(length(qamModulatedSymbols) / numSubcarriers);  % 计算 OFDM 符号数
        % 数据循环填充
        repeatedSymbols = repmat(qamModulatedSymbols, ceil(numOFDMSymbols * numSubcarriers / length(qamModulatedSymbols)), 1);
        qamModulatedSymbols = repeatedSymbols(1:(numOFDMSymbols * numSubcarriers)); % 截取填满所需长度
        qamModulatedSymbols = reshape(qamModulatedSymbols, numSubcarriers, []);  % 重塑为子载波 x 符号数的矩阵
        
        % OFDM 调制
        ofdmModulatedSignal = ofdmmod(qamModulatedSymbols, fftLength, fftLength*0.5);
        
        % 信道效应（加入噪声和随机衰落）
        channel = (randn(size(ofdmModulatedSignal)) + 1j * randn(size(ofdmModulatedSignal))) * 1e-5; % 随机信道
        noisySignal = ofdmModulatedSignal + channel; % 添加信道效应
        
        % OFDM 解调
        receivedSymbols = ofdmdemod(noisySignal, fftLength, fftLength*0.5);
        
        % QAM 解调
        receivedSymbols = receivedSymbols(:);  % 展平为列向量
        receivedBits = qamdemod(receivedSymbols, qamOrder, 'OutputType', 'bit', 'UnitAveragePower', true);
        
        % 误比特率计算（作为验证）
        repeateddatabits = repmat(dataBits, ceil(numOFDMSymbols * numSubcarriers / 30000), 1);
        numBitErrors = sum(receivedBits ~= repeateddatabits);
        ber = numBitErrors / length(repeateddatabits);
        fprintf('Worker %d: Bit Error Rate (BER) = %.6f %%\n', idx, ber*100);
    end
end

function visualizeResults(results)
    % 可视化测试结果
    figure;
    bar(categorical(results.Configuration), results.AvgTime);
    xlabel('Configuration');
    ylabel('Average Time (s)');
    title('Parallel Performance Test');
end
