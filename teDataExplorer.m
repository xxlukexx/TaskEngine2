classdef teDataExplorer < handle
    
    properties (Dependent)
        Position
    end
    
    properties (Dependent, SetAccess = private)
        SelectedItem
        SelectedItemType
        SelectedSession
        SelectedMetadata
        SelectedType
        DataTree
    end
    
    properties (Access = private)
        prRecentPath = pwd
        prBusy = false
        prClient
        % UI
        uiFig
        uiDataTree teDataTree
        uiPnlData
        uiStatus
        uiToolbar
        uiBtnConnectToDatabase
        uiLblDatabaseStatus
        uiBtnAddFolder
        uiBtnAddScanFolder
        uiBtnAddDatabase
        uiBtnJoin
        uiBtnRefreshBranch
        uiBtnInspect
        uiBtnIngest
        uiProgessBar
    end
    
    methods
        
        function obj = teDataExplorer(path_root)
            
            % if not root path supplied, use pwd
            if ~exist('path_root', 'var') 
                path_root = pwd;
            end
            if ~exist(path_root, 'dir')
                warning('Path not found, will use current working directory: %s',...
                    path_root)
                path_root = pwd;
            end
            
            % create empty database client instance
            try
                obj.prClient = tepAnalysisClient;
            catch ERR
                warning(ERR.identifier, 'Error creating database client:\n\n%s', ERR.message)
            end
            
            obj.UICreate(path_root)
            
            % add listeners
            addlistener(obj.uiDataTree, 'SelectionChanged',...
                @obj.SelectionChanged);
            addlistener(obj.uiDataTree, 'MultipleSessionSelection',...
                @obj.JoinableSelectionMade);
            addlistener(obj.uiDataTree, 'IsBusy', @obj.Busy);            
            addlistener(obj.uiDataTree, 'IsNotBusy', @obj.NotBusy);
%             addlistener(obj.prClient, 'StatusChanged', @obj.DBStatusChanged);
            
            % store recent path
            obj.prRecentPath = path_root;
            
            % make UI visible
            obj.uiFig.Visible = 'on';

        end
        
        function SelectionChanged(obj, src, ~)
        % fired by a selection change on the data tree. We process the
        % NodeData property to determine what to do about it.
        
            obj.ClearSummary
            sel = src.SelectedItem;
            
            % join button disabled for single selections
            obj.uiBtnJoin.Enable = 'off';
            
            % enable other buttons if a selection has been made
            if ~isempty(sel.NodeData)
                obj.uiBtnRefreshBranch.Enable = 'on';
            end
            
            % certain buttons are only enabled if a session is selected
            selIsSession = ~isempty(sel.NodeData) &&...
                isfield(sel.NodeData, 'type') &&...
                isequal(sel.NodeData.type, 'session');
            selIsFolderScanHeader = ~isempty(sel.NodeData) &&...
                isfield(sel.NodeData, 'type') &&...
                isequal(sel.NodeData.type, 'scanfolder');
            if selIsSession || selIsFolderScanHeader
                obj.uiBtnInspect.Enable = 'on';
                obj.uiBtnIngest.Enable = 'on';
            else
                obj.uiBtnInspect.Enable = 'off';
                obj.uiBtnIngest.Enable = 'off';                
            end
            
            w = obj.uiPnlData.Position(3);
            h = obj.uiPnlData.Position(4);
        
            dat = sel.NodeData;
            switch dat.type
                case 'folder'
                case 'session'
                    teDataSummary_session(obj.uiPnlData, dat, [0, 0, w, h]);
                case 'tasks'
                    teDataSummary_tasks(obj.uiPnlData, dat, [0, 0, w, h]);
                case 'task'
                    teDataSummary_task(obj.uiPnlData, dat, [0, 0, w, h]);
                case 'events'
                    teDataSummary_events(obj.uiPnlData, dat,  [0, 0, w, h]);
                case 'external_data'
                    teDataSummary_externalData(obj.uiPnlData, dat,  [0, 0, w, h]);
                case 'eyetracking_detail'
                    teDataSummary_eyetrackingDetail(obj.uiPnlData, dat,  [0, 0, w, h]);
                case 'tepInspect'
                    teDataSummary_tepInspect(obj.uiPnlData, dat,  [0, 0, w, h]);
                case 'database'
                    teDataSummary_database(obj.uiPnlData, dat,  [0, 0, w, h]);
                case 'struct'
                    teDataSummary_struct(obj.uiPnlData, dat,  [0, 0, w, h]);
            end
            
        end
        
        function JoinableSelectionMade(obj, src, ~)
            
            obj.uiBtnJoin.Enable = 'on';
            obj.uiBtnInspect.Enable = 'on';
            obj.uiBtnIngest.Enable = 'on';
        
        end
        
        function ClearSummary(obj)
            
            % delete any existing summaries
            delete(obj.uiPnlData.Children)
            
        end
        
        function Busy(obj, ~, event)
            
            if ~exist('event', 'var') 
                event = [];
            end
            
            if isa(event, 'teEvent')
                msg = event.Data;
            elseif ischar(event)
                msg = event;
            else
                msg = 'Please wait...';
            end
            
            if obj.prBusy
                if ~isequal(obj.uiProgessBar.Message, msg)
                    obj.uiProgessBar.Message = msg;
                end
                return
            end
            obj.prBusy = true;
            
            obj.uiStatus.Text = msg;
            
            if ~obj.prBusy && ~isempty(obj.uiPnlData)
                ch = [obj.uiPnlData.Children; obj.uiToolbar.Children];
                if ~isempty(ch)
                    for c = 1:length(ch)
                        if isprop(ch(c), 'Enable')
                            ch(c).Tag = ch(c).Enable;
                            ch(c).Enable = 'off';
                        end
                    end
                end
            end
            
            obj.uiProgessBar = uiprogressdlg(obj.uiFig, 'Message', msg,...
                'Indeterminate', 'on');
                        
        end
        
        function NotBusy(obj, ~, ~)
            
            obj.uiStatus.Text = '';
            
            if ~isempty(obj.uiPnlData)
                ch = [obj.uiPnlData.Children; obj.uiToolbar.Children];
                if ~isempty(ch)
                    for c = 1:length(ch)
                        if isprop(ch(c), 'Enable') && ~isempty(ch(c).Tag) &&...
                                strcmpi(ch(c).Enable, 'off')
                            ch(c).Enable = ch(c).Tag;
                        end
                    end
                end
            end
            
            close(obj.uiProgessBar)
            
            obj.prBusy = false;
            
        end
        
        % UI
        function UICreate(obj, path_root)
            
            % create figure
            obj.uiFig = uifigure(...
                'SizeChangedFcn', @obj.UIResize,...
                'Visible', 'off',...
                'AutoResizeChildren', 'off',...
                'Name', 'Data Explorer');
            
            % create UI elements
            pos = obj.UIGetPositions;
            
            % data tree
            obj.uiDataTree = teDataTree(obj.uiFig, path_root,...
                pos.uiDataTree);
            
            % summary panel
            obj.uiPnlData = uipanel(obj.uiFig, 'Position', pos.uiPnlData);
            
            % status 
            obj.uiStatus = uilabel(obj.uiFig, 'Position', pos.uiStatus,...
                'Text', '');
            
            % toolbar
            obj.uiToolbar = uipanel(obj.uiFig, 'Position', pos.uiToolbar);
            obj.uiBtnConnectToDatabase = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnConnectToDatabase,...
                'Text', '',...
                'Icon', 'ico_connectToDatabase.png',...
                'Tooltip', 'Connect to database',...
                'Enable', 'on',...       
                'ButtonPushedFcn', @obj.UIBtnConnectToDatabase_Click);
%             obj.uiLblDatabaseStatus = uilabel(obj.uiToolbar,...
%                 'Position', pos.uiLblDatabaseStatus,...
%                 'Text', sprintf('Database: %s', obj.prClient.Status),...
%                 'Tooltip', 'Database connection status',...
%                 'Enable', 'on');            
            obj.uiBtnAddFolder = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnAddFolder,...
                'Text', '',...
                'Icon', 'ico_addFolder.png',...
                'Tooltip', 'Add filesystem folder',...
                'Enable', 'on',...       
                'ButtonPushedFcn', @obj.UIBtnAddFolder_Click);
            obj.uiBtnAddScanFolder = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnAddScanFolder,...
                'Text', '',...
                'Icon', 'ico_addScanFolder.png',...
                'Tooltip', 'Scan folder for sessions',...
                'Enable', 'on',...       
                'ButtonPushedFcn', @obj.UIBtnAddScanFolder_Click);            
            obj.uiBtnAddDatabase = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnAddDatabase,...
                'Text', '',...
                'Icon', 'ico_addDatabase.png',...
                'Tooltip', 'Add database connnection',...  
                'Enable', 'off',...
                'ButtonPushedFcn', @obj.UIBtnAddDatabase_Click);
            obj.uiBtnJoin = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnJoin,...
                'Text', '',...
                'Icon', 'ico_join.png',...
                'Tooltip', 'Join sessions',...
                'Enable', 'off',...       
                'ButtonPushedFcn', @obj.UIBtnJoin_Click);
            obj.uiBtnRefreshBranch = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnRefreshBranch,...
                'Text', '',...
                'Icon', 'ico_refresh.png',...
                'Tooltip', 'Refresh current branch',...
                'Enable', 'off',...       
                'ButtonPushedFcn', @obj.UIBtnRefreshBranch_Click);            
            obj.uiBtnInspect = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnInspect,...
                'Text', '',...
                'Icon', 'ico_inspect.png',...
                'Tooltip', 'Inspect selected session(s)',...
                'Enable', 'off',...       
                'ButtonPushedFcn', @obj.UIBtnInspect_Click);               
            obj.uiBtnIngest = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnIngest,...
                'Text', '',...
                'Icon', 'ico_ingest.png',...
                'Tooltip', 'Ingest selected session(s)',...
                'Enable', 'off',...       
                'ButtonPushedFcn', @obj.UIBtnIngest_Click);     
  
        end
        
        function UIResize(obj, ~, ~)
        % Called when the uifigure is resized (via the SizeChangedFcn 
        % callback). Call UIGetPositions to get updated position of all
        % elements, then apply them.
            
            pos = obj.UIGetPositions;
            
            if ~isempty(obj.uiDataTree)
                obj.uiDataTree.Position = pos.uiDataTree;
            end
            
            obj.uiPnlData.Position = pos.uiPnlData;
            obj.uiStatus.Position = pos.uiStatus;
            obj.uiToolbar.Position = pos.uiToolbar;
            
        end
                
        function UIBtnConnectToDatabase_Click(obj, ~, ~)
            obj.ClearSummary
            teConnectToDatabaseUI(obj.prClient, obj.uiPnlData);
        end
        
        function UIBtnAddFolder_Click(obj, ~, ~)
            
            res = uigetdir(obj.prRecentPath);
            
            % detect cancel
            if isequal(res, 0)
                return
            end
            
            obj.uiDataTree.UICreateTreeNode_folder([], res)
            
            % store recent path
            obj.prRecentPath = res;

        end
        
        function UIBtnAddScanFolder_Click(obj, ~, ~)
            
            res = uigetdir(obj.prRecentPath);
            
            % detect cancel
            if isequal(res, 0)
                return
            end
            
            obj.uiDataTree.UICreateTreeNode_scanFolder([], res)
            
            % store recent path
            obj.prRecentPath = res;

        end
        
        function UIBtnAddDatabase_Click(obj, ~, ~)
            
             % for now, ask for DB hold query directly. will make a proper
             % GUI for this later
             resp = inputdlg('Enter database query (or leave empty for none)');
             if ~isempty(resp{1})
                 resp = eval(resp{1});
             else
                 resp = [];
             end
             obj.uiDataTree.UICreateTreeNode_database([], obj.prClient, resp);
             
        end
        
        function UIBtnJoin_Click(obj, ~, ~)
            
            % get current path of sessions in selected node. Store the path
            % in a new variable in each teSession, so that it is passed to
            % teJoinUI/teJoin. This ensures that we backup, delete, write
            % data etc. to the correct place
            numNodes = length(obj.uiDataTree.SelectedItem);
            data = cell(numNodes, 1);
            for n = 1:numNodes
                data{n} = obj.uiDataTree.SelectedItem(n).NodeData.data;
                data{n}.Paths('teJoin') =...
                    obj.uiDataTree.SelectedItem(n).NodeData.path;
            end
            
            % get path of subject folder from selected node's parent
            path_sub = obj.uiDataTree.SelectedItem(1).Parent.NodeData.path;
            
            teJoinUI(path_sub, data{:});
            
        end
        
        function UIBtnRefreshBranch_Click(obj, ~, ~)
        
            node = obj.uiDataTree.SelectedItem;
            obj.uiDataTree.UITreeNodeRefresh(node)
            
        end
        
        function UIBtnInspect_Click(obj, ~, ~)
        % inspect all selected items. First loop through selected nodes
        % and ensure that all are sessions. Assuming they are, find the
        % path to each session and extract, then pass to tepInspect
                
            % ensure that only sessions are selected
            sel = obj.SelectedItem;
            type = obj.SelectedType;
            if ~iscell(type), type = {type}; end
            numSel = length(sel);
            
            % if the header node of the results of a folder scan is
            % selected, change the selection to all child session
            if numSel == 1 && isequal(type, {'scanfolder'})
                sel = sel.Children;
                numSel = length(sel);
                type = arrayfun(@(x) x.NodeData.type, sel, 'UniformOutput', false);
            end
            
            if ~all(isequal('session', type{:}))
                errordlg('Only sessions can be inspected. Select only sessions and try again.')
            end
            
            obj.Busy('Inspecting session...');
            sel = obj.DoInspection(sel);

            % loop through selected sessions and inspect
%             parfor n = 1:3
                
%                 if strcmpi(type{n}, 'session')
%                     sel(n) = obj.DoInspection(sel(n));
%                 end
                
%             end
            
            obj.NotBusy

        end
        
        function report = UIBtnIngest_Click(obj, ~, ~)
            
            obj.Busy('Ingesting sessions...')
            
            switch obj.SelectedType
                case 'scanfolder'
                    sel = obj.SelectedItem.Children;
                    type = arrayfun(@(x) x.NodeData.type, sel,...
                        'UniformOutput', false);
                otherwise
                    sel = obj.SelectedItem;
                    type = obj.SelectedType;
            end
            numSel = length(sel);
            
            suc = false(numSel, 1);
            oc = repmat({'unknown error'}, numSel, 1);
            
            for s = 1:numSel
                
                % if a child node of a session (e.g. inspect) is selected,
                % then change that selection to its parent session
                if isa(sel(s).Parent, 'matlab.ui.container.TreeNode') &&...
                        strcmpi(sel(s).Parent.NodeData.type, 'session')
                    sel(s) = sel(s).Parent;
                    type{s} = 'session';
                end
                
                % if a session is not selected, skip
                if ~strcmpi(type{s}, 'session')
                    oc{s} = 'not a te session';
                    continue
                end
                
                % determine whether the session has been scanned (and so
                % metadata loaded)
                if sel(s).NodeData.needsUpdate
                    delete(sel(s).Children)
                    obj.uiDataTree.UITreeNodeScanSession(sel(s))
                end
                
                % determine whether this session has already been inspected
                % or not
                ch = sel(s).Children;
                ch_type = arrayfun(@(x) x.NodeData.type, ch,...
                    'UniformOutput', false);
                idx_insp = strcmpi(ch_type, 'metadata');
                
                % if not already inspected, do it now
                if ~any(idx_insp)
                    
                    [~, md] = obj.DoInspection(sel(s));
                    if isempty(md)
                        oc{s} = 'DoInspection returned empty metadata';
                        continue
                    end
%                     obj.uiDataTree.UICreateTreeNode_metadata(sel(s));
                    
%                     % update children
%                     ch = sel(s).Children;
%                     ch_type = arrayfun(@(x) x.NodeData.type, ch,...
%                         'UniformOutput', false);
%                     idx_insp = strcmpi(ch_type, 'tepInspect');
                
                else
                
                    % extract metadata from inspect node
                    md = ch(idx_insp).NodeData.md;
                    if isempty(md)
                        oc{s} = 'Getting metadata from node failed';
                        continue
                    end
                    
                end
                
                % check that this session doesn't already exist in the
                % database
                if ~isempty(obj.prClient.GetGUID('GUID', md.GUID))
                    errordlg(sprintf(...
                        'GUID [%s] already exists in database.', md.GUID));
                end
                    
                % ingest
                try
                    client = obj.prClient;
                    [suc_ingest, oc_ingest, guid] =...
                        client.IngestMetadata(md, 'uploadLocalPaths');
                    if ~suc_ingest
                        allOc_ingest = cellfun(@(x) x.outcome, oc_ingest, 'UniformOutput', false);
                        oc{s} = sprintf('Ingest error: %s', allOc_ingest{:});
                    else
                        oc{s} = 'success';
                        suc(s) = true;
                    end
                catch ERR
                    suc(s) = false;
                    oc{s} = ERR.message;
                end
                
            end
            
            obj.NotBusy
            
            % report 
            report = table;
            report.session_path = arrayfun(@(x) x.NodeData.path, sel,...
                'UniformOutput', false);
            report.success = suc;
            report.outcome = oc;
            
        end
        
        function pos = UIGetPositions(obj)
        % Calculate positions of all UI elements, relative to the size of
        % the parent uifigure. Most likely called during class constructor
        % or uifigure resize. 
            
            % get width/height in normalised coords
            w = obj.uiFig.InnerPosition(3);
            h = obj.uiFig.InnerPosition(4);
                        
            h_status = 20;
            h_toolbar = 40;
            h_btn = h_toolbar - 4;
            off_btn = 2;
            w_dbStat = 150;
            
            pos.uiDataTree = [0, 0, w * .3, h - h_toolbar];
            pos.uiPnlData = [w * .3, h_status, w * .7, h - h_status - h_toolbar];
            
            pos.uiStatus = [w * .3, 0, w * .7, h_status];
            
            pos.uiToolbar = [0, h - h_toolbar, w, h_toolbar];
            
            bx = 0;
            pos.uiBtnConnectToDatabase  = [bx, off_btn, h_btn, h_btn];
            bx = bx + h_btn + off_btn;
            pos.uiLblDatabaseStatus     = [bx, off_btn, w_dbStat, h_btn];
            bx = bx + w_dbStat + off_btn;
            
            pos.uiBtnAddFolder          = [bx, off_btn, h_btn, h_btn];
            bx = bx + h_btn + off_btn;
            pos.uiBtnAddScanFolder      = [bx, off_btn, h_btn, h_btn];
            bx = bx + h_btn + off_btn;            
            pos.uiBtnAddDatabase        = [bx, off_btn, h_btn, h_btn];
            bx = bx + h_btn + off_btn;
            pos.uiBtnRefreshBranch      = [bx, off_btn, h_btn, h_btn];
            
            bx = bx + h_btn + (off_btn * 5);
            pos.uiBtnJoin               = [bx, off_btn, h_btn, h_btn];
            bx = bx + h_btn + off_btn;
            pos.uiBtnInspect            = [bx, off_btn, h_btn, h_btn];
            bx = bx + h_btn + off_btn;
            pos.uiBtnIngest             = [bx, off_btn, h_btn, h_btn];
            
        end
        
        % reporting
        function tab = SummariseMetadata(obj)
            
            if ~ismember(obj.SelectedType, {'folder', 'scanfolder', 'session'})
                % todo - proper error checking here 
                tab = [];
                return
            end
            
            % recursively find sessions
            node_md = obj.DataTree.RecFindByType(obj.SelectedItem, 'metadata');
            
            % extract teMetadata objects
            md = arrayfun(@(x) x.NodeData.md.Struct, node_md, 'UniformOutput', false);
            tab = teLogExtract(md);
            
        end
        
        % db
        function DBStatusChanged(obj, ~, ~)
            obj.uiLblDatabaseStatus.Text =...
                sprintf('Database: %s', obj.prClient.Status);
            if strcmpi(obj.prClient.Status, 'connected')
                obj.uiBtnAddDatabase.Enable = 'on';
            else
                obj.uiBtnAddDatabase.Enable = 'off';
            end
        end
        
        % set/get
        function val = get.Position(obj)
            val = obj.uiFig.Position;
        end
        
        function set.Position(obj, val)
            obj.uiFig.Position = val;
        end
        
        function val = get.SelectedItem(obj)
            val = obj.uiDataTree.SelectedItem;
        end
        
%         function val = get.SelectedItemType(obj)
%             sel = obj.SelectedItem;
%             val = arrayfun(@(x) x.NodeData.type, sel, 'uniform', false);
%             if length(val) == 1
%                 val = val{1};
%             end
%         end
        
        function val = get.SelectedSession(obj)
            val = obj.DataTree.SelectedSession;
        end
        
        function val = get.SelectedMetadata(obj)
            val = obj.DataTree.SelectedMetadata;
        end
        
        function val = get.SelectedType(obj)
            val = obj.DataTree.SelectedType;
        end
        
        function val = get.DataTree(obj)
            val = obj.uiDataTree;
        end
        
        % utils
        function [node, md, smry] = DoInspection(obj, node, varargin)
        % pass this function a node and if it is a session it will inspect
        % it and create a metadata object in the tree. Only here in a util
        % so that multiple parts of the UI code can call it. 
        
            doRefresh = ~ismember('-noRefresh', varargin);
            
            numNodes = length(node);
            
            % 1. extract session paths from each node
            obj.Busy('Preprocessing before inspection...')
            path_ses = cell(numNodes, 1);
            for n = 1:numNodes
                if isfield(node(n).NodeData, 'path') &&...
                        ~isempty(node(n).NodeData.path)
                    path_ses{n} = node(n).NodeData.path;
                end
            end
            
            % 2. inspect loop
            obj.Busy(sprintf('Inspecting %n sessions...', numNodes))
            md = cell(numNodes, 1);
            smry = cell(numNodes, 1);
            suc = false(numNodes, 1);
            oc = repmat({'success'}, numNodes, 1);
            parfor n = 1:numNodes
                try
                    [md{n}, smry{n}] = tepInspect(path_ses{n}, '-ignoreScreenRecording');
                    oc(n) = true;
                catch ERR
                    suc(n) = false;
                    oc{n} = ERR.message;
                end
            end
            
            % 3. store metadata back into nodes
            obj.Busy('Postprocessing after inspection...')
            if doRefresh
                obj.DataTree.UITreeNodeRefresh(node.Parent);
            end
%             for n = 1:numNodes
%                 node(n).NodeData.data.Metadata = md{n};
%                 obj.DataTree.UITreeNodeRefresh(node)
%             end
            
            obj.NotBusy
            
%                 % if the node is a session, extract its path, otherwise return
%             % an error
%             if isfield(node.NodeData, 'path') &&...
%                     ~isempty(node.NodeData.path)
%                 path_data = node.NodeData.path;
%             else
%                 errordlg('No path field for selected session.')
%                 return
%             end
%                     
%             % inspect
%             [md, smry] =...
%                 tepInspect(path_data);                    
% %                     [md, smry] =...
% %                         tepInspect(path_data, '-ignoreScreenRecording');

%             % update session in memory with metadata
%             node.NodeData.data.Metadata = md;
%             
%             % refresh node to create metadata child
%             obj.DataTree.UITreeNodeRefresh(node)

%             % create metadata node as a child to the session node
%             obj.uiDataTree.UICreateTreeNode_metadata(node, md, smry);
%             
%             % refresh whole branch -- todo check if this is necessary
%             node_branch = obj.SelectedItem.Parent;
%             obj.DataTree.UITreeNodeRefresh(node_branch);            
        end
        
    end
    
end