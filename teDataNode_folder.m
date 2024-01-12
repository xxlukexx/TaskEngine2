classdef teDataNode_folder < teDataNode
    
    properties (SetAccess = private)
        Path
        Type = 'folder'
    end
    
    methods
        
        function obj = teDataNode_folder(parent, path_folder)
            
            % superclass constructor 
            obj = obj@teDataNode(parent);
            
            if ~exist(path_folder, 'dir')
                error('Path not found: %s', path_folder)
            end
            
            obj.Path = path_folder;
        
            % get folder name of root path
            [~, name] = fileparts(path_folder);
            
            % create node
            obj.TreeNode = uitreenode(obj.Parent.TreeNode,...
                'Text', name,...
                'Icon', 'ico_folder02.png',...
                'NodeData', obj.GUID);
            
            addlistener(obj.RootParent, 'SingleNodeSelected',...
                @obj.Update);
            
        end
        
        function Update(obj, src, event)
            
            disp(obj.Path)
            
            obj.Clear
            
            % get folders in path
            d = dir(obj.Path);
            idx_rem = ~[d.isdir] | ismember({d.name}, {'.', '..'});
            d(idx_rem) = [];
            if isempty(d), return, end     
                        
            for i = 1:length(d)
                
                path_node = fullfile(d(i).folder, d(i).name);
                [isSes, ~, ~] = teIsSession(path_node);
                
                if isSes
                    % create session node
%                     teDataNode_session(obj, path_node);
                else
                    % create folder node
                    teDataNode_folder(obj, path_node);                
                end
                
            end
 
        end
        
    end
    
end