classdef teDataNode < handle
    
    properties
        TreeNode
        Panel
        GUID
    end
    
    properties (SetAccess = private)
        Parent
    end
    
    properties (Dependent, SetAccess = private)
        RootParent
        TreeNodeParent
    end
    
    properties (Abstract, SetAccess = private)
        Type
    end
    
    properties (Access = private)
        prDirty = true
    end
    
    methods
        
        function obj = teDataNode(parent) 
            
            obj.GUID = GetGUID;
            obj.Parent = parent;
           
        end
        
        function Update(~)
            % handles by subclasses
        end
        
        function Clear(obj)
            delete(obj.TreeNode.Children) 
        end
        
        function val = get.RootParent(obj)
        % walk down the tree to find the root parent
        
            if isempty(obj.TreeNode)
                val = [];
                return
            end
            
            val = obj.FindRootParent(obj);
            
        end
        
        function val = get.TreeNodeParent(obj)
            
            if isempty(obj.Parent)
                val = [];
                return
            end
            
            if isa(obj.Parent, 'teDataExplorer')
                val = obj.Parent.Tree;
            elseif isa(obj.Parent, 'teDataNode')
                val = obj.Parent.TreeNode;
            else
                error('Parent was not teDataExplorer or teDataNode - debug!')
            end
            
        end
                
    end
    
    methods (Hidden)
        
        function val = FindRootParent(obj, val)
            
            if isa(val, 'teDataExplorer')
                return
            elseif isa(val, 'teDataNode')
                val = obj.FindRootParent(val.Parent);
            else 
                error('Parent was not teDataExplorer or teDataNode - debug!')
            end
            
        end
        
    end
    
end