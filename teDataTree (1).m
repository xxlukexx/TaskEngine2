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
    
    events
        SelectionChanged
        MultipleSessionSelection
        IsBusy
        IsNotBusy
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
            
%             obj.uiBtnBrowse = uibutton(...
%                 'Parent', obj.uiParent,...
%                 'Text', 'Browse',...
%                 'Position', pos.BtnBrowse,...
%                 'ButtonPushedFcn', @obj.UIBtnBrowse_Click);
            
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
            
%             obj.uiBtnBrowse.Position = pos.BtnBrowse;
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
                    case 'database'
                        obj.UITreeNodeScanDatabase(node)
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
            
                obj.SelectedItem = nodes;
                
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
        
        function UITreeNodeRefresh(obj, node)
            if length(node) > 1
                arrayfun(@obj.UITreeNodeRefresh, node)
                return
            end
            node.NodeData.needsUpdate = true;
            obj.UIHandleNodeSelectionSingle(node);
        end
                
        function UITreeNodeScanFolder(obj, node)
            
            obj.Busy('Scanning folder...')
            
            dat = node.NodeData;
            
            % get folders in path
            d = dir(dat.path);
            idx_rem = ~[d.isdir] | ismember({d.name}, {'.', '..'});
            d(idx_rem) = [];
            if isempty(d), return, end     
                        
            for i = 1:length(d)
                
                path_node = fullfile(d(i).folder, d(i).name);
                
                % we call teIsSession with the -includePrecombine switch
                % because we may want to inspect split sessions even after
                % they have been joined
                [isSes, ~, tracker] =...
                    teIsSession(path_node, '-includePrecombine');
                
                if isSes
                    % create session node
                    obj.UICreateTreeNode_session(node, path_node);
                else
                    % create folder node
                    obj.UICreateTreeNode_folder(node, path_node);                
                end
                
            end
            
            node.expand
            
            obj.NotBusy
            
        end
        
        function UITreeNodeScanSession(obj, node)
            
            obj.Busy('Scanning session...')
            
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
                
            % metadata (tepInspect)
            
                if isfield(dat, 'md') && ~isempty(dat.md)
                    obj.UICreateTreeNode_tepInspect(node, dat.md, []);
                end
                
            node.expand
            
            obj.NotBusy
            
        end
        
        function UITreeNodeScanTasks(obj, parent)
            
            obj.Busy('Scanning tasks...')
            
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
            
            obj.Busy('Scanning external data...')
            
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
            
            obj.NotBusy
            
        end
        
        function UITreeNodeScanDatabase(obj, node)
            
            obj.Busy('Scanning database query...')
            
            % get all metadata
            dat = node.NodeData;
            md = dat.client.Metadata;
            numMD = length(md);
            
            % if ID field is present, sort by it
            hasID = cellfun(@(x) isprop(x, 'ID'), md);
            id = repmat({'ZMISSING'}, numMD, 1);
            id(hasID) = cellfun(@(x) x.ID, md, 'UniformOutput', false);
            [~, so] = sort(id);
            md = md(so);
            
            for m = 1:numMD
            
                % create session node
                obj.UICreateTreeNode_DBsession(node, dat.client, md{m}.GUID);
                
            end
            node.expand
            
            obj.NotBusy
            
        end
        
        % node creation
        
        function node = UICreateTreeNode_folder(obj, parent, path)
                    
            if ~exist(path, 'dir')
                obj.Error('Path not found: %s', path)
                return
            end
            
            % if not parent specified, assume root node (i.e. use the tree
            % itself as the parent)
            if ~exist('parent', 'var') || isempty(parent)
                parent = obj.uiTree;
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
                'Icon', 'ico_folder02.png',...
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
            dat.data = teSession(path, '-includePrecombine');
            dat.path = path;
            dat.needsUpdate = true;
            
            % build name
            name = sprintf('%s | ', dat.data.DynamicValues{:});
            name(end - 2:end) = [];
            
            % detect precombine
            if contains(path, '.precombine')
                icon = 'ico_session_pc01.png';
            else
                icon = 'ico_session01.png';
            end
            
            % create note
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', icon,...
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
        
        function node = UICreateTreeNode_tepInspect(obj, parent, md, smry)
            
            obj.Busy('Inspecting session...')
            
            % setup node data
            dat = struct;
            dat.type = 'tepInspect';
            dat.md = md;
            dat.smry = smry;
            dat.needsUpdate = true;

            % build name
            name = 'Inspection';
            
            % find and delete any previous tepInspect nodes
            ch = parent.Children;
            types = arrayfun(@(x) x.NodeData.type, ch, 'UniformOutput',...
                false);
            idx_inspectType = strcmpi(types, 'tepInspect');
            delete(ch(idx_inspectType))

            % create node
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', 'ico_inspect.png',...
                'NodeData', dat);                        
            
            obj.NotBusy            
            
        end
        
        function node = UICreateTreeNode_database(obj, parent, client, holdQuery)
            
            % if not parent specified, assume root node (i.e. use the tree
            % itself as the parent)
            if ~exist('parent', 'var') || isempty(parent)
                parent = obj.uiTree;
            end
            
            if ~exist('holdQuery', 'var') 
                holdQuery = [];
            end
            
            dat = struct;
            dat.type = 'database';
            dat.client = client;
            dat.client.HoldQuery = holdQuery;
            dat.needsUpdate = true;
            name = sprintf('Database [%s]', holdQuery);
            
            % create node
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', 'ico_database.png',...
                'NodeData', dat);   
            
        end
        
        function node = UICreateTreeNode_DBsession(obj, parent, client, GUID)
            
            obj.Busy('Reading session...');
            
            % load data 
            dat.type = 'session';
            [dat.data, dat.md] = teDBSession(client, GUID);
            dat.GUID = GUID;
            dat.needsUpdate = true;
            
            % build name
            name = sprintf('%s | ', dat.data.DynamicValues{:});
            name(end - 2:end) = [];
            
            % detect precombine
            if contains(path, '.precombine')
                icon = 'ico_session_pc01.png';
            else
                icon = 'ico_session01.png';
            end
            
            % create node
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', icon,...
                'NodeData', dat);
            
            obj.NotBusy
        
        end
        
        function Busy(obj, msg)
            
            obj.uiTree.Enable = 'off';
            
            if nargin == 1
                % no message
                notify(obj, 'IsBusy');
            elseif nargin == 2
                % encode message in teEvent
                event = teEvent(msg);
                notify(obj, 'IsBusy', event)
            end
            
            
%             if exist('msg', 'var') && ~isempty(msg)
%                 if isempty(obj.prWaitBar)
%                     % create new
%                     obj.prWaitBar = waitbar(0, msg);
%                 else
%                     % update existing
%                     obj.prWaitBar = waitbar(0, obj.prWaitBar, msg);
%                 end
%             else
%                 obj.prWaitBar = [];
%             end
            
            drawnow;
            
        end
        
        function NotBusy(obj)
            
            obj.uiTree.Enable = 'on';
            notify(obj, 'IsNotBusy')
            
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
            
%             % get control width/height 
%             ch = obj.CONST_CONTROL_HEIGHT;
            
%             % browse button
%             pos.BtnBrowse = [0, h - ch, w, ch];      
            
            % tree
            pos.Tree = [0, 0, w, h];
            
        end
        
    end
    
end