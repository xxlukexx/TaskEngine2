classdef teTreeNode < dynamicprops
    
    properties
    end
    
    properties %(Access = private)
        node matlab.ui.container.TreeNode
    end
    
    methods
        
        function obj = teTreeNode(varargin)
            obj.node = uitreenode(varargin{:});
            props = properties(obj.node);
            for i = 1:length(props)
                h = addprop(obj, props{i});
                h.GetMethod = @(x)obj.get(props{i});
                h.SetMethod = @(x, y)obj.set(props{i}, y);
            end
        end
        
%         function varargout = subsref(obj, s)
%             
%             if length(s) == 1 && strcmpi(s(1).type, '.')
%                 varargout = {obj.node.(s(1).subs)};
%             end
%             
%         end
        
    end
    
    methods (Hidden)
        
        function val = get(obj, propname)
            val = obj.node.(propname);
        end
        
        function set(obj, propname, val)
            obj.node.(propname) = val;
        end
         
    end
    
end