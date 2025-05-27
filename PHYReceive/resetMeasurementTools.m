function MeasurementTools = resetMeasurementTools(MeasurementTools)
    % resetMeasurementTools: Reset measurement tools to clear previous data.
    % Input:
    %   MeasurementTools - Structure containing measurement tools for BER, EVM, MER
    %
    % Output:
    %   MeasurementTools - Updated structure with reset measurement tools
    
    % 重置 BER 对象
    reset(MeasurementTools.BER);
    
    % 重置 EVM 对象
    reset(MeasurementTools.EVM.header);
    reset(MeasurementTools.EVM.data);
    
    % 重置 MER 对象
    reset(MeasurementTools.MER.header);
    reset(MeasurementTools.MER.data);
    
    % fprintf('Measurement tools have been reset.\n');
end
