function flag = checkControlParamsFlag(m_controlParamState)
    % 检查是否有新的控制参数需要处理
    if m_controlParamState.Data.isReadyFlag == 1
        % flag 置为1
        flag = 1;

        % 重置标志（表示已提取最新的控制信令）
        m_controlParamState.Data.isReadyFlag = int8(0);
    else
        % 控制信令还未生成或旧的信令已处理还未有新的控制信令生成
        flag = 0;
        return
    end

end
