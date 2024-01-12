classdef teDataNode_fileSystem < teDataNode
    
    properties (SetAccess = private)
        Path
        Type = 'filesystem'
    end
    
    methods
        
        function obj = teDataNode_fileSystem(parent, path_root)
            
            % superclass constructor 
            obj = obj@teDataNode(parent);
            
            pathSupplied = exist('path_root', 'var') && ~isempty(path_root);
            switch pathSupplied
                
                case true
                    
                    obj.Create(path_root)
            
                case false
                    
                    % create node
                    obj.TreeNode = uitreenode(parent,...
                        'Text', 'Click to select a folder...',...
                        'Icon', 'ico_fileSystem.png',...
                        'NodeData', obj.GUID);
                    
            end
            
        end
        
        function Update(obj)
            
            if ~obj.Dirty, return, end
            
            % prompt user for root path
            tmp_path = uigetdir(pwd);
            if isequal(tmp_path, 0)
                errordlg('Select a valid folder')
                return
            end
            
            obj.Create(path_root)
            
        end
        
        function Create(obj, path_root)
            
            if ~exist(path_root, 'dir')
                errordlg(sprintf('Path not found: %s', path_root))
            end
        
            % get folder name of root path
            [~, name] = fileparts(path_root);
            obj.Path = path_root;
            
            % create file system node
            obj.TreeNode = uitreenode(obj.TreeNodeParent,...
                'Text', name,...
                'Icon', 'ico_fileSystem.png',...
                'NodeData', obj.GUID);   
            
            % create folder node as child
            teDataNode_folder(obj, path_root);
            
            addlistener(obj.RootParent, 'SingleNodeSelected',...
                @obj.Select)
            
            expand(obj.TreeNode)
            
        end
            
        function Select(obj, src, event)
            
            expand(obj.TreeNode)
            
        end
        
    end
    
end