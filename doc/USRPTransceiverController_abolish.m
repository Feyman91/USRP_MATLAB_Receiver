% 主函数 main.m
clear
clear captureData
close all

% 启用 diary 记录终端输出
startLogging();

% 初始化参数
radioConfig = 'My USRP N310';  % Baseband transceiver 配置
bbtrx = basebandTransceiver(radioConfig);  % 初始化 basebandTransceiver 对象

% UE ID 信息
UE_id = 1;

% OFDM 基本参数设置
FFTlength = 1024;
cplen = FFTlength*0.25;
scs = 30e3;  % Subcarrier spacing (30 kHz)
sampleRate = FFTlength * scs;  % 计算采样率
SymbolsPerFrame = 30;   % symbols
SamplesPerFrame = (FFTlength+cplen)*SymbolsPerFrame;
%% 无线参数设置
bbtrx.SampleRate = sampleRate;  % 设置 basebandTransceiver 对象的采样率
% Tx 参数
TXantenna = "RF0:TX/RX";        % 设置传输天线，例如 "RF0:TX/RX" 对于 N310
TXcenterFrequency = 2.37e9;     % 传输中心频率，单位为 Hz
TXgain = 50;                    % 传输增益，单位为 dB
% Rx 参数
RXCenterFrequency = 2.33e9;         % 接收中心频率，单位为 Hz
RXantenna = "RF0:RX2";              % 设置接收天线
RXgain = 50;                        % 接收增益，单位为 dB
RXDataType = "double";              % 数据类型
DroppedSamplesAction = "warning";   % 丢弃样本行为

verbosity            = false;        % 是否打印调试信息

if verbosity
    % 输出初始配置信息，包括发送和接收配置
    disp(['Starting UE ', num2str(UE_id), ' duplex communication with the following configuration:']);
    disp(['  Radio Config: ', radioConfig]);
    disp(['  Sample Rate: ', num2str(sampleRate), ' Hz(FFTlength: ', num2str(FFTlength),' Subcarrier Spacing: ', num2str(scs),')']);
    disp(' ');
    disp('  Transmission Parameters:');
    disp(['    TX Antenna: ', char(TXantenna)]);
    disp(['    TX Center Frequency: ', num2str(TXcenterFrequency), ' Hz']);
    disp(['    TX Gain: ', num2str(TXgain), ' dB']);
    disp(' ');
    disp('  Reception Parameters:');
    disp(['    RX Antenna: ', char(RXantenna)]);
    disp(['    RX Center Frequency: ', num2str(RXCenterFrequency), ' Hz']);
    disp(['    RX Gain: ', num2str(RXgain), ' dB']);
    disp(['    RX Data Type: ', char(RXDataType)]);
    disp(['    Dropped Samples Action: ', char(DroppedSamplesAction)]);
    disp(' ');
end

%% 配置上行发送以及下行接收USRP bbtrx对象（不进行实际传输，仅返回配置后的对象和生成的波形）
% 上行发送配置
bbtrx = configureUplinkTxTransceiver(bbtrx, ...
        TXantenna, TXcenterFrequency, TXgain, radioConfig);
% 下行接收配置
bbtrx = configureDownlinkRxTransceiver(bbtrx, ...
        RXantenna, RXCenterFrequency, RXgain, RXDataType, ...
        DroppedSamplesAction, radioConfig);
%% 配置初始化内存buffer映射文件
root = "./downlink_receive/cache_file/";
filename = "received_buffer_new.bin";
filename = fullfile(root, filename);
totalMemorySizeInGB = 4;
m = InitMemmap(filename, totalMemorySizeInGB);


% 初始化中断持续接收循环的共享文件（存储中断flag 用）
flagFileName = 'interrupt_reception_flag.bin';
filename4 = fullfile(root,flagFileName);
% 如果文件不存在，初始化并写入默认 flag 值
if ~isfile(filename4)
    fid = fopen(filename4, 'w');
    fwrite(fid, 1, 'int8');  % flag置为1表示继续接收
    fclose(fid);
end
% 创建内存映射文件对象
m_receiveCtlflag = memmapfile(filename4, 'Writable', true, 'Format', 'int8');
m_receiveCtlflag.Data(1) = 1;

%% 在上行、下行、处理缓冲区配置完成后，打开数据管道并进行初始化
isPipelineOpen = openDataPipeline(bbtrx);
fprintf('Press Enter to continue...');
input('');
[txflag,txDiagnostics] = transmitData(bbtrx, "continuous");
captureLength = milliseconds(100);
[numFrames, totalBytes, bufferCapacityFrames, buffCapaCrtCaptrTimes] = calculateSamplingFrames( ...
    bbtrx, captureLength, SamplesPerFrame, m);
fprintf('\nNumframes per cature: %d frames; Data size(bytes) per cature: %e',numFrames,totalBytes)
fprintf(['\nBuffers can save %d frames for current framesize; ' ...
    'Buffers allow %d capture times for current capturelength\n'], bufferCapacityFrames,buffCapaCrtCaptrTimes)

% 指定运行时间（单位：秒）
runTime = 40; % 运行 40 秒
tic; % 开始计时


try 
    % while toc < runTime
    while m_receiveCtlflag.Data(1)
        % capture 100ms (80frames)
        rxDiagnostics = captureData(bbtrx, captureLength, m);
    end
catch ME
    fprintf('Receiving terminated: %s\n', ME.message);
end

stopTransmission(bbtrx);
fprintf('\n********Stop transmiting!********\n')
% 其他传输操作可以放在这里，视需要执行
% 例如，可以在此处设置实际传输逻辑，如：
% startTransmission(bbtrx_new, txWaveform);

disp("Main script completed successfully.");
diary off; % 关闭日志功能
disp("close diary recording")
