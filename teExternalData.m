classdef teExternalData < handle
    
    properties 
        Sync = struct
    end
    
    properties (SetAccess = protected)
        Paths teCollection
        InstantiateSuccess = false
        InstantiateOutcome = 'unknown error';          
    end
    
    properties (Abstract)
        Ext2Te
        Te2Ext
    end
        
    properties (Abstract, SetAccess = protected)
        Type
        Valid
        T1
        T2
    end
    
    properties (Constant)
        GUID = GetGUID
    end
    
    properties (Hidden, SetAccess = protected)
  
    end
    
    methods
        
        function obj = teExternalData
            obj.Paths = teCollection('char');
        end
        
        function s = struct(obj)
            s = builtin('struct', obj);
            s = rmfield(s, {'Type', 'Paths'});
        end
        
        function data = Load(obj)
            error('Not supported in this class.')
        end
        
    end
    
end
