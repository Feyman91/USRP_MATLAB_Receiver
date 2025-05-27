function isPipelineOpen = openDataPipeline(bbtrx)
    % openDataPipeline - 初始化 basebandTransceiver 对象，打开数据管道
    % 
    % 该函数用于首次将传输/接收命令传入 basebandTransceiver 对象 (bbtrx)，
    % 触发 USRP 的初始化，确保数据传输管道准备就绪。
    % 
    % 输入:
    %   bbtrx - basebandTransceiver 对象
    %
    % 输出:
    %   isPipelineOpen - 数据管道打开的标识 (true 表示初始化完成)
    
    % 1. 生成测试波形
    numSamples = 1024;  % 可根据需要调整测试波形的采样点数
    testWaveform = ((rand(numSamples, 1) + 1i * rand(numSamples, 1)) * 2 - (1 + 1i))*0.01;  
    % 确保波形在 [-1, 1] 范围内且不会太大

    % 2. 调用 transmit 函数发送一次波形，触发初始化
    startt = tic;
    disp('Opening USRP data pipeline......');
    transmit(bbtrx, testWaveform, "once");
    endtime = toc(startt);

    % 3. 返回初始化状态标识
    disp(['Data pipeline opened successfully with ', num2str(endtime), ' seconds']);
    isPipelineOpen = true;
end
