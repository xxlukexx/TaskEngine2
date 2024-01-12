classdef teDataTree < handle
    
    properties (SetAccess = private)
        SelectedItem
        SelectedSession
        SelectedMetadata
    end
    
    properties (Dependent)
        Path_Root 
        Position 
    end
    
    properties (Dependent, SetAccess = private)
        SelectedType
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
                        obj.Busy('Reading folder contents...');
                        obj.UITreeNodeScanFolder(node)
                    case 'scanfolder'
                        obj.Busy('Reading folder scan results...');
                        obj.UITreeNodeScanFolderScan(node)                        
                    case 'session'
                        obj.Busy('Reading session...');
                        obj.UITreeNodeScanSession(node)
                    case 'tasks'
                        obj.Busy('Reading tasks...');
                        obj.UITreeNodeScanTasks(node)
                    case 'external_data'
                        obj.Busy('Reading external data...');
                        obj.UITreeNodeScanExternalData(node)
                    case 'database'
                        obj.UITreeNodeScanDatabase(node)
                        obj.Busy('Querying database...');
                    case 'metadata'
                        obj.Busy('Reading inspection results...');
                        obj.UITreeNodeScanInspection(node)
                    case 'struct'
                        obj.Busy('Reading data...');
                        obj.UITreeNodeScanStruct(node)
                end

                % flag update as done
                node.NodeData.needsUpdate = false;
                
            end
            
            % store selection
            obj.SelectedItem = node;
            
            node_md = obj.UIFindParentOfType(...
                obj.SelectedItem, 'metadata');
            if isempty(node_md)
                obj.SelectedMetadata = [];
            else
                obj.SelectedMetadata = node_md.NodeData.md;
            end
            
            % attempt to find a child session underneath the selected node
            % and set the .SelectedSession property 
            node_ses = obj.UIFindParentOfType(...
                obj.SelectedItem, 'session');
            if isempty(node_ses) || length(node_ses) > 1
                % either no node is present, or multiple nodes. Either way
                % we cannot derive what the correct selected session is, so
                % we return empty
                obj.SelectedSession = [];
            else
                obj.SelectedSession = node_ses.NodeData.data;
            end
            
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
                
                % we call teIsSession with the includePrecombine switch
                % because we may want to inspect split sessions even after
                % they have been joined
                [isSes, ~, tracker] =...
                    teIsSession(path_node, 'includePrecombine');
                
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
        
        function UITreeNodeScanFolderScan(obj, node)
            
            obj.Busy('Reading sessions...')
            
            % get results
            dat = node.NodeData;
            if isempty(dat.trackers)
                return
            end
            
            % sort results by 1) ID (if available), or 2) dynamic vars
            vars = cellfun(@GetVariables, dat.trackers, 'UniformOutput', false);
            hasIDField = all(cellfun(@(x) ismember('ID', x), vars));
            if hasIDField
                
                % sort by the numeric contents of IDs
                ids = cellfun(@(x) x.ID, dat.trackers, 'UniformOutput', false);
                [~, so] = sort(cell2mat(extractNumeric(ids)));
                
            else

                % get values for all dynamic vars
                vals = cell(length(dat.trackers), 1);
                for i = 1:length(dat.trackers)
                    tmp = cellfun(@(x) dat.trackers{i}.(x), vars{i},...
                        'UniformOutput', false);
                    vals{i} = sprintf('%s', tmp{:});
                end
                
                % sort by numeric contents of values
                vals_num = cell2mat(extractNumeric(vals));
                [~, so] = sort(vals_num);
                
            end
            
            % do sort
            dat.trackers = dat.trackers(so);
            dat.exts = dat.exts(so);
            dat.mds = dat.mds(so);
            dat.path_sessions = dat.path_sessions(so);
            
            % create session node for each session in results
            for i = 1:length(dat.trackers)
                obj.Busy(sprintf('Reading sessions [%d of %d]...',...
                    i, length(dat.trackers)))
                obj.UICreateTreeNode_sessionFromTracker(node,...
                    dat.trackers{i}, dat.exts{i}, dat.mds{i},...
                    dat.path_sessions{i});
            end
            
            node.expand
            node.NodeData.needsUpdate = false;
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
            
                if isprop(dat.data, 'Metadata') && ~isempty(dat.data.Metadata)
                    obj.UICreateTreeNode_metadata(node, dat.data.Metadata, []);
                end
                if isfield(dat, 'md') && ~isempty(dat.md)
                    obj.UICreateTreeNode_metadata(node, dat.md, []);
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
        
        function UITreeNodeScanInspection(obj, node)
            
            st = node.NodeData.md.StructTree;
            obj.UITreeNodeScanStruct(node, st);
            
        end
        
        function UITreeNodeScanStruct(obj, node, s)
            
            if ~exist('s', 'var')
                s = node.NodeData.s;
            end
                        
            % get only struct field names
            fnames = fieldnames(s);
            idx_struct = cellfun(@(x) isstruct(s.(x)), fnames);
            fnames(~idx_struct) = [];
            numFields = length(fnames);
            
            % loop through struct fields
            for f = 1:numFields
                obj.UICreateTreeNode_struct(node, fnames{f}, s.(fnames{f}));
            end
            node.expand
            
        end
        
        % node creation
        
        function node = UICreateTreeNode_folder(obj, parent, path)
                    
            if ~exist(path, 'dir')
                obj.Error('Path not found: %s', path)
                return
            end
            
            % if no parent specified, assume root node (i.e. use the tree
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
        
        function node = UICreateTreeNode_scanFolder(obj, parent, path)
                    
            if ~exist(path, 'dir')
                obj.Error('Path not found: %s', path)
                return
            end
            
            % if no parent specified, assume root node (i.e. use the tree
            % itself as the parent)
            if ~exist('parent', 'var') || isempty(parent)
                parent = obj.uiTree;
            end
            
        % node
        
            obj.Busy('Scanning folder for valid Task Engine sessions...');
            
            name = sprintf('Folder scan: %s', path);
            [allSes, trackers, ~, exts, mds] = teRecFindSessions(path);
            
            % make node data
            dat.type = 'scanfolder';
            dat.path_sessions = allSes;
            dat.trackers = trackers;
            dat.exts = exts;
            dat.mds = mds;
            dat.path = path;
            dat.needsUpdate = true;
            
            % create node
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', 'ico_folder02.png',...
                'NodeData', dat);
            
            node.expand
            
            obj.NotBusy
                        
        end        
        
        function node = UICreateTreeNode_session(obj, parent, path)
            
            obj.Busy('Reading session...');
            
            if ~exist(path, 'dir')
                obj.Error('Path not found: %s', path)
                return
            end
            
            % load data 
            dat.type = 'session';
            dat.data = teSession(path, 'includePrecombine');
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
            
            % create node
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', icon,...
                'NodeData', dat);
            
            obj.NotBusy
        
        end
        
        function node = UICreateTreeNode_sessionFromTracker(obj,...
                parent, tracker, ext, md, path_session)
            
            % load data 
            dat.type = 'session';
            dat.data = teSession('tracker', tracker, 'external_data', ext,...
                'metadata', md);
            dat.path = path_session;
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
            
            % create child nodes
            obj.UICreateTreeNode_log(node);
            obj.UICreateTreeNode_events(node);
            obj.UICreateTreeNode_tasks(node);
            obj.UICreateTreeNode_externalData(node);
            obj.UICreateTreeNode_metadata(node, md, []);
            
            node.NodeData.needsUpdate = false;
            
            node.expand
                        
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
        
        function node = UICreateTreeNode_metadata(obj, parent, md, smry)
            
            obj.Busy('Inspecting session...')
            
            % setup node data
            dat = struct;
            dat.type = 'metadata';
            dat.md = md;
            dat.smry = smry;
            dat.needsUpdate = true;

            % build name
            name = 'Metadata';
            
            % find and delete any previous tepInspect nodes
            ch = parent.Children;
            types = arrayfun(@(x) x.NodeData.type, ch, 'UniformOutput',...
                false);
            idx_inspectType = strcmpi(types, 'metadata');
            delete(ch(idx_inspectType))

            % create node
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', 'ico_inspect.png',...
                'NodeData', dat);                        
            
            obj.NotBusy            
            
        end
        
        function node = UICreateTreeNode_struct(obj, parent, name, s)
            
            obj.Busy
            
            dat = struct;
            dat.type = 'struct';
            dat.s = s;
            dat.needsUpdate = true;
            
            % find and delete any previous tepInspect nodes
            ch = parent.Children;
            types = arrayfun(@(x) x.NodeData.type, ch, 'UniformOutput',...
                false);
            idx_inspectType = strcmpi(types, name);
            delete(ch(idx_inspectType))
            
            % look for any field names that include "success" with a
            % logical value. If that value is false, then use the error
            % icon
            fnames = fieldnames(s);
            idx_suc = cellfun(@(x) contains(lower(x), 'success'), fnames);
            idx_false = cellfun(@(x)...
                isscalar(s.(x)) && islogical(s.(x)) && ~s.(x), fnames);
            if any(idx_suc & idx_false)
                icon = 'ico_error.png';
            elseif any(idx_suc) && all(~idx_false(idx_suc))
                icon = 'ico_success.png';
            else
                icon = 'ico_inspect.png';
            end 
            
            % create node
            node = uitreenode(parent,...
                'Text', name,...
                'Icon', icon,...
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
            
            obj.Busy('Reading session from database...');
            
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
                        
            if nargin == 1
                % no message
                msg = 'Please wait...';
            end
            event = teEvent(msg);
            
            notify(obj, 'IsBusy', event)
            
            drawnow;
            
        end
        
        function NotBusy(obj)
            
            obj.uiTree.Enable = 'on';
            notify(obj, 'IsNotBusy')
            
        end
        
        % node traversal
        
        function node = UIFindParentOfType(obj, node_child, type_parent)
        % first finds the ancestor (session or folder) of node_child. This
        % is the top-level node under which we will search. Then search
        % recursively through all child nodes and return any that match
        % type_parent
            
            node_ancestor = obj.UIFindAncestor(obj.SelectedItem);
            node_allChildren = [node_ancestor; node_ancestor.Children];
            numChildren = length(node_allChildren);
            idx_match = false(numChildren, 1);
            for c = 1:numChildren
                idx_match(c) = isequal(lower(node_allChildren(c).NodeData.type),...
                        lower(type_parent));
            end
            node = node_allChildren(idx_match);
            
        end
        
        function node_ancestor = UIFindAncestor(obj, node_child)
        % finds the ancestor of a node. An ancestor in this context is 
        % defined as either a session or a folder (since we do not want to
        % traverse to a different dataset)
        
            % if this itself an ancestor node?
            if ismember(node_child.NodeData.type, {'session', 'folder'})
                node_ancestor = node_child;
                return
            end
                
            % find the parent. If this is an ancestor then return it.
            % Otherwise the method calls itself recursively. 
            if isa(node_child.Parent, 'matlab.ui.container.Tree')
                % the selected node IS the ancestor, so return it unchanged
                node_ancestor = node_child;
                return
            end
            node_ancestor = node_child.Parent;
            found = ismember(node_ancestor.NodeData.type,...
                    {'session', 'folder'});
            if ~found
                node_ancestor = obj.UIFindAncestor(node_ancestor);
            end
            
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
        
        function val = get.SelectedType(obj)
            
            sel = obj.SelectedItem;
            
            % ensure that the selected node has a NodeData struct with a 
            % type field
            if isprop(sel, 'NodeData') && isstruct(sel.NodeData) &&...
                    hasField(sel.NodeData, 'type')
                
                % using arrayfun to handle multiple selections, return the
                % type field of each node's NodeData property
                val = arrayfun(@(x) x.NodeData.type, sel, 'uniform', false);
                
                % if only a single item is selected, pull the scalar result
                % from the cell array that arrayfun returns
                if length(val) == 1
                    val = val{1};
                end
                
            else
                val = [];
            end
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
        
        function [val, found] = RecFindByType(obj, nodes_search, type_sought, level)
        % recursively searches child nodes of nodes_search for nodes of 
        % type type_sought. nodes_search can be an array of nodes.  
        
%             teEcho('Starting to search %d nodes for %s\n', length(nodes_search), type_sought);
        
            % fail if any element of nodes_search is not a uiTreeNode
            if ~isa(nodes_search, 'matlab.ui.container.TreeNode')
                error('Nodes being searched must be of type uiTreeNode (matlab.ui.container.TreeNode).')
            end
            
            if ~ischar(type_sought)
                error('Type being sought must be char.')
            end
            
            if ~exist('level', 'var') || isempty(level)
                level = 1;
            else
                level = level + 1;
            end
            
            val = [];
            found = false;
            
            numSearch = length(nodes_search);
            found = false(numSearch, 1);
            val = cell(numSearch, 1);
            for s = 1:numSearch
                                
                % check to see if this node is of the type being sought
                found(s) = isprop(nodes_search(s), 'NodeData') &&...
                        isstruct(nodes_search(s).NodeData) &&...
                        hasField(nodes_search(s).NodeData, 'type') &&...
                        isequal(nodes_search(s).NodeData.type, type_sought);
                    
                if found(s)
                    val{s} = nodes_search(s);
                end
                
%                 teEcho('\tNode %d: %s [%s]    FOUND: %d\n', s, nodes_search(s).Text, nodes_search(s).NodeData.type, found(s));

                
                % does the node have children? If so, recurse. 
                ch = nodes_search(s).Children; 
                if isa(ch, 'matlab.ui.container.TreeNode')
                    [tmpVal, tmpFound] = obj.RecFindByType(ch, type_sought, level);
                    if any(tmpFound)
                        
%                         % insert the newly-returned (child) sessions after
%                         % the parent in the flat output array (ensures
%                         % order is sensible)
%                         s1 = s - 1; 
%                         if s1 < 1, s1 = 1; end
%                         val_pre = val(1:s1);
%                         found_pre = found(1:s1);
%                         
%                         s2 = s + 1;
%                         if s2 > numSearch, s2 = numSearch; end
%                         val_post = val(s2:end);
%                         found_post = found(s2:end);
%                         
%                         val = [val_pre; tmpVal; val_post];
%                         found = [found_pre; tmpFound; found_post];

                        val = [val; tmpVal];
                        found = [found; tmpFound];
                        
                    end
                end
                
            end
                        
            % if we are at the root (i.e. this method was called by
            % something else, NOT itself) then remove non-found entries and
            % try to return an object (as opposed to cell) array
            if level == 1
                val = val(found);
                found = found(found);

                % if all results are of the same class (which they should be,
                % but best to check), convert from cell array to object array
                val_class = cellfun(@class, val, 'UniformOutput', false);
                if all(cellfun(@(x) isequal(x, val_class{1}), val_class))
                    val = cellfun(@(x) x, val);
                end
            end
            
        end
        
    end
    
end