classdef (ConstructOnLoad) teLogEventData < event.EventData
    
    properties
        LogItem
    end
    
    methods
        function obj = teLogEventData(varargin)
            obj.LogItem = varargin;
        end
    end
    
end