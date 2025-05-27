function baseStageMsgs = getBaseStageMsgs(userType)
% 根据 userType('CBS' or 'UE') 返回最初的阶段字符串模板
%
% 注意：这里的 @UE_ID 和 @CBS_ID 是占位符，后面再进行替换

    switch upper(userType)
        case 'CBS'
            baseStageMsgs = {
                '[@CBS_ID] Initial Access Message',                  
                '[@CBS_ID] RACH Response Message[@UE_ID]',
                '[@CBS_ID] Connected with [@UE_ID]',
                '[@CBS_ID] Prepare for Sending Control Parameters to [@UE_ID]', % 阶段4
                '' % 阶段5，不需要文本,此时直接发送控制参数
            };
        
        case 'UE'
            baseStageMsgs = {
                '',  % 阶段0: 空
                '[@UE_ID] RACH Request Message[@CBS_ID]',
                '[@UE_ID] Received Response, Connecting...[@CBS_ID]',
                '[@UE_ID] Connected with [@CBS_ID]',
                '[@UE_ID] Prepare for Receiving Control Parameters from [@CBS_ID]', % 阶段4
                '[@UE_ID] Successfully Received Control Parameters from [@CBS_ID]'  % 阶段5
            };

        otherwise
            error('Unknown userType: %s (should be "CBS" or "UE")', userType);
    end
end
