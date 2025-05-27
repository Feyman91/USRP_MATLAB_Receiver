function saveControlParamsToJson(controlParams, jsonFilePath)
    % saveControlParamsToJson: 将控制信令参数保存为 JSON 文件
    %
    % 功能：
    %   将生成的控制信令参数结构体保存为指定路径的 JSON 文件。
    %
    % 输入：
    %   controlParams: 控制信令参数结构体
    %   jsonFilePath: JSON 文件保存路径

    % 将结构体编码为 JSON 格式
    jsonData = jsonencode(controlParams);
    
    % 格式化 JSON 字符串（可选）
    % jsonData = strrep(jsonData, ',', sprintf(',\n'));
    % jsonData = strrep(jsonData, '{', sprintf('{\n'));
    % jsonData = strrep(jsonData, '}', sprintf('\n}'));

    % 写入 JSON 文件
    fid = fopen(jsonFilePath, 'w');
    if fid == -1
        error('无法打开文件 %s 进行写入', jsonFilePath);
    end
    fwrite(fid, jsonData, 'char');
    fclose(fid);
end
