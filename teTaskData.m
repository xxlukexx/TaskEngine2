classdef teTaskData 
    
    properties 
        EyeTracking
    end
    
    properties (SetAccess = private)
        Date
        Onset
        Offset
        Task
        GUID
    end
    
    methods
        
        function obj = teTaskData(date, onset, offset, task, guid)
        
            obj.Date = date;
            obj.Onset = onset;
            obj.Offset = offset;
            obj.Task = task;
            obj.GUID = guid;
            
        end
        
    end
    
end