classdef (ConstructOnLoad) teEvent < event.EventData
    
    properties
        Data
    end
    
    methods
        function obj = teEvent(varargin)
            obj.Data = varargin;
        end
    end
    
end