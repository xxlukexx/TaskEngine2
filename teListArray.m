classdef teListArray < handle
    
    properties (Dependent, SetAccess = private)
        Items
    end
    
    properties (Access = private)
        prCol
    end
    
    methods
        
        function obj = teListArray(firstItem)
            
            obj.prCol = teCollection;
            obj.prCol.AddItem(firstItem, 1);
            
        end
        
        function subsassgn(obj, s, varargin)
            
            
        end
        
        function val = get.Items(obj)
            val = obj.prCol.Items;
        end
        
    end
    
end
        
            