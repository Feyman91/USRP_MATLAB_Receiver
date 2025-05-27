# USRP收发机原型系统

这是一个基于MATLAB+USRP的通信原型系统，实现了用户设备(UE)的上行数据发送功能。注意：此版本仅支持接收信号处理功能，发送功能请参考项目USRP_TX。

## 项目概述

该系统实现了接收端物理层信号处理功能，包括：
- 上行信号接收和解调
- 实时信号处理和数据分析

## 系统架构

```
USRP_RX/
├── USRPTransceiverController.m    # USRP硬件控制器
├── processRcvData.m               # 接收数据处理脚本
├── stop_processing.m              # 停止信号处理
├── stop_receiving.m               # 停止信号接收
├── deleteCacheLogsFiles.m         # 清理缓存和日志文件
├── PHYParams/                     # 物理层参数配置
├── PHYReceive/                    # 接收相关功能
├── PHYTransmit/                   # 发送相关功能
└── logs/                          # 日志文件目录
```

## 运行方法

### 前提条件
1. 确保USRP设备正确连接
2. 确保MATLAB已安装相关工具箱

### 运行步骤

**需要打开3个独立的MATLAB进程：**

#### 进程1: USRP硬件控制器
```matlab
% 运行USRP上行传输控制器
USRPTransceiverController
```

#### 进程2: 数据处理器
```matlab
% 运行接收数据处理脚本
processRcvData
```

#### 进程3: 控制管理器
此进程用于优雅退出前两个程序：
```matlab
% 停止信号处理
stop_processing

% 停止信号接收
stop_receiving
```

### 运行顺序
1. 首先启动**进程1**（USRPTransceiverController）
2. 然后启动**进程2**（processRcvData）
3. **进程3**保持待命，需要停止时运行相应脚本

## 配置说明

### PHY参数配置
系统支持从JSON文件加载物理层参数：
```matlab
% 初始化上行接收参数
uplinkParams = initializePHYParams('uplink');

% 设置默认参数
setDefaultParams();
```

## 重要注意事项

### ⚠️ 清理缓存文件
使用 `deleteCacheLogsFiles.m` 清理缓存时，**必须首先清除所有MATLAB进程的变量**，否则会遇到文件权限错误：

```matlab
% 在所有MATLAB进程中执行：
clear all
close all

% 然后运行清理脚本：
deleteCacheLogsFiles
```

### 内存映射管理
系统使用内存映射文件进行进程间通信，确保：
- 不要同时在多个进程中写入同一内存映射文件
- 退出程序前正确关闭内存映射

### 硬件设置
确保USRP设备配置正确：
- 采样率：根据FFT长度和子载波间距计算
- 中心频率：默认2.3 GHz
- 接收天线配置：RF0:RX2

## 故障排除

### 常见问题
1. **文件权限错误**: 清理缓存前未清除变量
2. **USRP连接失败**: 检查硬件连接和驱动
3. **内存映射错误**: 确保文件路径正确且有写入权限

### 日志查看
系统会自动记录运行日志到 `logs/` 目录，可查看详细的运行信息和错误信息。

## 参数说明

### 关键参数
- `FFTLength`: 1024 (FFT长度)
- `Subcarrierspacing`: 30 kHz (子载波间距)
- `total_RB`: 67 (资源块数量)
- `SampleRate`: 30.72 MHz (采样率)

### 运行模式
- **continuous**: 持续接收/发送模式
- **once**: 单次接收/发送模式
