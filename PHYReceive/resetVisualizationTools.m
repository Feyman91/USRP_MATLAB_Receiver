function visualizationTools = resetVisualizationTools(visualizationTools)
    % resetVisualizationTools: Reset visualization tools to clear display data.
    % Input:
    %   visualizationTools - Structure containing visualization tools (constellation diagram, spectrum analyzer, etc.)
    %
    % Output:
    %   visualizationTools - Updated structure with reset visualization tools
    
    % 重置星座图
    reset(visualizationTools.constDiag);
    
    % 重置频谱分析仪
    reset(visualizationTools.spectrumAnalyze);

    % 重置时间域图
    reset(visualizationTools.timesink);
    
    % fprintf('Visualization tools have been reset.\n');
end
