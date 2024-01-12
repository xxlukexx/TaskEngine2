classdef teDataTree < handle
    
    properties (SetAccess = private)
        SelectedItem
    end
    
    properties (Dependent)
        Path_Root 
        Position 
    end
    
    properties (Access = private)
        prPosition = [0, 0, 300, 800]
        prPath_Root
        prWaitBar
        % ui elements
        uiParent
        uiBtnBrowse
        uiTree
    end
    
    properties (Constant)
        CONST_CONTROL_HEIGHT = 35;
    end
    
    events
        SelectionChanged
        MultipleSessionSelection
    end
    
    methods
        
        function obj = teDataTree(h, path_root, position)
            
            % if no handle to a parent supplied, make a figure
            if ~exist('h', 'var') || isempty(h)
                obj.uiParent = uifigure(...
                    'Visible', 'off',...
                    'ToolBar', 'none',...
                    'MenuBar', 'none',...
                    'Name', 'Task Engine Data Tree',...
                    'SizeChangedFcn', @obj.UIFigSizeChanged);
            else
                obj.uiParent = h;
            end
            
            if exist('position', 'var') && assertPosition(position)
                obj.Position = position;
            else
                obj.Position = [0, 0, obj.uiParent.Position(3) * .3,...
                    obj.uiParent.Position(4)];
            end
            
            obj.UIFigSizeChanged;
            obj.CreateUI;
            
            if exist('path_root', 'var') && exist(path_root, 'dir')
                obj.Path_Root = path_root;
            end 
            
        end
        
        function CreateUI(obj)
            
            pos = obj.UICalculatePositions;
            
            obj.uiBtnBrowse = uibutton(...
                'Parent', obj.uiParent,...
                'Text', 'Browse',...
                'Position', pos.BtnBrowse,...
                'ButtonPushedFcn', @obj.UIBtnBrowse_Click);
            
            obj.uiTree = uitree(obj.uiParent,...
                'Position', pos.Tree,...
                'NodeExpandedFcn', @obj.UITreeNodeExpanded,...
                'SelectionChangedFcn', @obj.UITreeNodeSelected,...
                'Multiselect',  'on');
            
            % make figure visible (and enabled callbacks)
            obj.uiParent.Visible = 'on';
            
        end
        
        function UpdateRoot(obj)
            
            delete(obj.uiTree.Children)
            
            if ~exist(obj.Path_Root, 'dir')
                return
            end

            ndRoot = obj.UICreateTreeNode_folder(obj.uiTree, obj.Path_Root);
            ndRoot.expand
            
        end
        
        function UpdateUI(obj)
            
            pos = obj.UICalculatePositions;
            
            obj.uiBtnBrowse.Position = pos.BtnBrowse;
            obj.uiTree.Position = pos.Tree;
            
        end
        
        % UI
        function UIHandleNodeSelectionSingle(obj, node)
                        
            obj.Busy
            
            % only update if not already done
            dat = node.NodeData;
            if dat.needsUpdate
            
                % clear node children
                delete(node.Children)

                % scan data and create child nodes according to current node
                % type
                switch dat.type
                    case 'folder'
                        obj.UITreeNodeScanFolder(node)
                    case 'session'
                        obj.UITreeNodeScanSession(node)
                    case 'tasks'
                        obj.UITreeNodeScanTasks(node)
                    case 'external_data'
                        obj.UITreeNodeScanExternalData(node)
                end

                % flag update as done
                node.NodeData.needsUpdate = false;
                
            end
            
            % store selection
            obj.SelectedItem = node;
            notify(obj, 'SelectionChanged');
            
            obj.NotBusy
                        
        end
        
        function UIHandleNodeSelectionMultiple(obj, nodes)
            
                % get type of each selected node
                types = arrayfun(@(x) x.NodeData.type, nodes,...
                    'UniformOutput', false);
                % check that all types are session
                if all(cellfun(@(x) isequal(x, types{1}), types))
                    notify(obj, 'MultipleSessionSelection')
                end
                
        end
        
        function UIBtnBrowse_Click(obj, ~, ~)
            
            % if a root path has already been set, use this as the starting
            % point for the uigetdir call. Otherwise use the current
            % working folder
            if ~isempty(obj.Path_Root)
                path_start = obj.Path_Root;
            else
                path_start = pwd;
            end
            
            res = uigetdir(path_start);
            
            % detect cancel
            if isequal(res, 0)
                return
            end
            
            % set root path property
            obj.Path_Root = res;
            
        end
        
        function UIFigSizeChanged(obj, ~, ~)
%             pos_parent = obj.uiParent.Position;
%             obj.Position = [0, 0, pos_parent(3), pos_parent(4)];
%             obj.UpdateUI
        end
        
        function UITreeNodeExpanded(obj, src, event)
            
            
            
            
        end
        
        function UITreeNodeSelected(obj, src, event)
            
            numSel = length(event.SelectedNodes);
            if numSel == 1
                obj.UIHandleNodeSelectionSingle(event.SelectedNodes);
            elseif numSel > 1 
                obj.UIHandleNodeSelectionMultiple(event.SelectedNodes);
            end
                    
                
            
%             arrayfun(@obj.UIHandleNodeSelection, event.SelectedNodes);
            
        end
        
        % node scanning
                
        function UITreeNodeScanFolder(obj, node)
            
            dat = node.NodeData;
            
            % get folders in path
            d = dir(dat.path);
            idx_rem = ~[d.isdir] | ismember({d.name}, {'.', '..'});
            d(idx_rem) = [];
            if isempty(d), return, end     
                        
            for i = 1:length(d)
                
                path_node = fullfile(d(i).folder, d(i).name);
                [isSes, ~, tracker] = teIsSession(path_node);
                
                if isSes
                    % create session node
                    obj.UICreateTreeNode_session(node, path_node);
                else
                    % create folder node
                    obj.UICreateTreeNode_folder(node, path_node);                
                end
                
            end
            
            node.expand
            
        end
        
        function UITreeNodeScanSession(obj, node)
            
            dat = node.NodeData;
            data = dat.data;
            
            % log
            
                obj.UICreateTreeNode_log(node);

            % events
            
                obj.UICreateTreeNode_events(node);
                
            % tasks
            
                obj.UICreateTreeNode_tasks(node);
                
            % external data
            
                obj.UICreateTreeNode_externalData(node);
                
            node.expand
            
        end
        
        function UITreeNodeScanTasks(obj, parent)
            
            obj.Busy('Preparing task log data...')
            
            dat = parent.NodeData;
            data = dat.data;
            
            tasks = dat.tasks;
            numTasks = length(tasks);
            tab = cell(numTasks, 1);
            for t = 1:numTasks

                tab{t} = teLogFilter(data.Log.LogArray, 'topic',...
                    'trial_log_data', 'task', tasks{t});     
                
                newDat.type = 'task';
                newDat.trialLog = tab{t};
                newDat.needsUpdate = true;

                % build name
                name = sprintf('%s (%d)', tasks{t}, size(tab{t}, 1));

                % create node
                node = uitreenode(parent,...
                    'Text', name,...
                    'Icon', 'ico_eck.png',...
                    'NodeData', newDat);
            
            end
            
            parent.expand
            
            obj.NotBusy
            
        end
        
        function UITreeNodeScanExternalData(obj, parent)
            
            dat = parent.NodeData;
            ext = dat.data;
            
            if strcmpi(ext.Type, 'eyetracking')
                
                newDat.type = 'eyetracking_detail';
                newDat.data = ext;
                newDat.needsUpdate = true;

                % build name
                name = 'eyetracking_detail';

                % create node
                node = uitreenode(parent,...
                    'Text', name,...
                    'Icon', 'ico_trial.png',...
                    'NodeData', newDat);    
                
                parent.expand
                
            end
            
        end
        
        % node creation
        
        function node = UICreateTreeNode_folder(obj, parent, path)
                    
            if ~exist(path, 'dir')
                obj.Error('Path not found: %s', path)
                return
            end
            
        % node
        
            % get folder name of root path
            [~, name] = fileparts(path);
            
            % make node data
            dat.type = 'folder';
            dat.path = path;
            dat.needsUpdate = true;
            
            % create note
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', 'ico_folder01.png',...
                'NodeData', dat);
                        
        end
        
        function node = UICreateTreeNode_session(obj, parent, path)
            
            obj.Busy('Reading session...');
            
            if ~exist(path, 'dir')
                obj.Error('Path not found: %s', path)
                return
            end
            
            % load data 
            dat.type = 'session';
            dat.data = teSession(path);
            dat.needsUpdate = true;
            
            % build name
            name = sprintf('%s | ', dat.data.DynamicValues{:});
            name(end - 2:end) = [];
            
            % create note
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', 'ico_session01.png',...
                'NodeData', dat);
            
            obj.NotBusy
        
        end
        
        function node = UICreateTreeNode_log(obj, parent)

            % setup node data
%             dat = parent.NodeData;
            dat.type = 'log';
            dat.data = parent.NodeData.data.Log;
            dat.needsUpdate = true;

            % build name
            name = sprintf('Log (%s)',...
                formatThousandsComma(length(dat.data.LogArray)));

            % create node
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', 'ico_nestedlist.png',...
                'NodeData', dat);
                
        end
        
        function node = UICreateTreeNode_externalData(obj, parent)
            
            ext = parent.NodeData.data.ExternalData;
           
            for e = 1:ext.Count

                % setup node data
                dat.type = 'external_data';
                dat.data = ext(e);
                dat.needsUpdate = true;
            
                % build name
                name = ext.Keys{e};
            
                % create node
                node = uitreenode(parent,...
                    'Text', name,...
                    'Icon', 'ico_trial.png',...
                    'NodeData', dat);
                
            end
            
        end
        
        function node = UICreateTreeNode_events(obj, parent)
            
            % setup node data
            dat = parent.NodeData;
            dat.type = 'events';
            dat.data = dat.data.Log.Events;
            dat.needsUpdate = true;

            % build name
            name = sprintf('Events (%s)',...
                formatThousandsComma(size(dat.data, 1)));
            
            % create node
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', 'ico_function.png',...
                'NodeData', dat);
            
        end
        
        function node = UICreateTreeNode_tasks(obj, parent)
            
            obj.Busy('Preparing task logs...')
            
            % get task trial summary
            tasks = parent.NodeData.data.Log.Tasks;
            tts = parent.NodeData.data.Log.TaskTrialSummary;
            
            % setup node data
            dat = parent.NodeData;
            dat.type = 'tasks';
            dat.tasks = tasks;
            dat.tts = tts;
            dat.data = parent.NodeData.data;
            dat.needsUpdate = true;

            % build name
            name = sprintf('Tasks (%d)', length(tasks));

            % create node
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', 'ico_eck.png',...
                'NodeData', dat);                        
            
            obj.NotBusy
            
        end
        
%         function node = UICreateTreeNode_externalData(obj, parent, path)
%             
%             obj.Busy('Reading session...');
%             
%             if ~exist(path, 'dir')
%                 obj.Error('Path not found: %s', path)
%                 return
%             end
%             
%             % load data 
%             dat.type = 'session';
%             dat.data = teSession(path);
%             dat.needsUpdate = true;
%             
%             % build name
%             name = sprintf('%s | ', dat.data.DynamicValues{:});
%             name(end - 2:end) = [];
%             
%             % create note
%             node = uitreenode(parent,...
%                 'Text', name,...
%                 'Icon', 'ico_session01.png',...
%                 'NodeData', dat);
%             
%             obj.NotBusy
%         
%         end
        
        function Busy(obj, msg)
            
            obj.uiTree.Enable = 'off';
            
            if exist('msg', 'var') && ~isempty(msg)
                if isempty(obj.prWaitBar)
                    % create new
                    obj.prWaitBar = waitbar(0, msg);
                else
                    % update existing
                    obj.prWaitBar = waitbar(0, obj.prWaitBar, msg);
                end
            else
                obj.prWaitBar = [];
            end
            
            drawnow;
            
        end
        
        function NotBusy(obj)
            
            obj.uiTree.Enable = 'on';
            
            if ~isempty(obj.prWaitBar)
                delete(obj.prWaitBar)
                obj.prWaitBar = [];
            end
            
            drawnow;
        end
        
        % get / set
        function val = get.Path_Root(obj)
            val = obj.prPath_Root;
        end
        
        function set.Path_Root(obj, val)
            
            % check that path exists
            if ~exist(val, 'dir')
                obj.Error('Path not found.')
            end
            
            obj.prPath_Root = val;
            obj.UpdateRoot
            
        end
        
        function val = get.Position(obj)
            val = obj.prPosition;
        end
        
        function set.Position(obj, val)
            if ~assertPosition(val)
                error('Position must be a positive numeric vector in the form of [x, y, w, h].')
            end
            obj.prPosition = val;
            obj.UpdateUI;
        end
             
    end
    
    methods (Hidden)
        
        function Error(~, varargin)
            
            % todo make this error dialog
            error(varargin)
            
        end
        
        function pos = UICalculatePositions(obj)
            
            % get width/height
            w = obj.Position(3);
            h = obj.Position(4);
            
            % get control width/height 
            ch = obj.CONST_CONTROL_HEIGHT;
            
            % browse button
            pos.BtnBrowse = [0, h - ch, w, ch];      
            
            % tree
            pos.Tree = [0, 0, w, h - ch];
            
        end
        
    end
    
end