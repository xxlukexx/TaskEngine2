classdef teJoinUI < handle
    
    properties
    end
   
%    properties (SetAccess = private)
%        Selected

    properties (Access = private)
       prData 
       prMatchingMetadata
       prTable
       prPlotElements
       prSelRow
       prExtent
       prPath_out
       % UI
       uiFig
       uiList
%        uiDataPanel
       uiDataPlot
       uiStatus
       uiToolbar
       uiBtnMoveDown
       uiBtnMoveUp
       uiBtnSortByDate
       uiBtnJoin
    end
   
    methods
    
        function obj = teJoinUI(path_out, varargin)
            
            obj.prPath_out = path_out;
            
            % check inputs. Can be either a path (in which case a recursive
            % search for TE sessions will be done) or a list of teSession
            % objects
            if length(varargin) == 1 && ischar(varargin{1})
                
                % assume that the second input arg is a path
                path_search = varargin{1};
                if ~exist(path_search, 'dir')
                    error('Assumed path [%s] does not exist.', path_search)
                end
                
                % search recursively for valid TE sessions
                [paths_sessions, trackers, vars, ext, md, ses] =...
                    teRecFindSessions(path_search, '-silent');
                
            elseif ~isempty(varargin) && all(cellfun(@(x) isa(x, 'teSession'), varargin))
                
                % read sessions from input args
                ses = varargin;
                
            else
                
                error('Second input argument must be a search path, or comma-separated list of teSession objects.')
                
            end
           
            % check inputs (should be list of teSessions)
            if ~all(cellfun(@(x) isa(x, 'teSession'), ses))
                errordlg('All input arguments must be teSession instances.')
                return
            else
                obj.prData = ses;
            end
           
            obj.UICreate
            
            obj.Busy('Scanning external data...')
            wb = waitbar(0, 'Scanning external data...');
            numData = length(obj.prData);
            obj.prExtent = cell(numData);
            for d = 1:numData
                msg = sprintf('Scanning external data (%d/%d)...',...
                    d, numData);
                wb = waitbar(d / numData, wb, msg);
                obj.prExtent{d} = teFindTemporalExtent(obj.prData{d});
            end
            delete(wb)
            obj.UIUpdatePlot
            obj.NotBusy
           
       end
       
        function UICreate(obj)
           
            % try to find location of data explorer, to open join window on
            % top of it
            h = findall(0, 'HandleVisibility', 'off', 'Type', 'Figure',...
                'Name', 'Data Explorer');
            if ~isempty(h)
                pos = get(h, 'Position');
                pos(1:2) = pos(1:2) + [50, -50];
            else
                res = get(0, 'screensize');
                pos = magnifyRect(res, 0.8);
            end
            
            % create figure
            obj.uiFig = uifigure(...
                'SizeChangedFcn', @obj.UIResize,...
                'Visible', 'off',...
                'AutoResizeChildren', 'off',...
                'Name', 'Join sessions',...
                'Position', pos);
            
            % create UI elements
            pos = obj.UIGetPositions;
            
            % status 
            obj.uiStatus = uilabel(obj.uiFig, 'Position', pos.uiStatus,...
                'Text', '');
            
            % toolbar
            obj.uiToolbar = uipanel(obj.uiFig, 'Position', pos.uiToolbar);
            obj.uiBtnMoveUp = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnMoveUp,...
                'Text', '',...
                'Icon', 'ico_moveUp02.png',...
                'Tooltip', 'Move session up',...
                'ButtonPushedFcn', @obj.UIBtnMoveUp_Click);
            obj.uiBtnMoveDown = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnMoveDown,...
                'Text', '',...
                'Icon', 'ico_moveDown02.png',...
                'Tooltip', 'Move session down',...
                'ButtonPushedFcn', @obj.UIBtnMoveDown_Click);            
            obj.uiBtnSortByDate = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnSortByDate,...
                'Text', '',...
                'Icon', 'ico_sort.png',...
                'Tooltip', 'Sort by session start time',...
                'ButtonPushedFcn', @obj.UIBtnSortByDate_Click);               
            obj.uiBtnJoin = uibutton(obj.uiToolbar,...
                'Position', pos.uiBtnJoin,...
                'Text', '',...
                'Icon', 'ico_join.png',...
                'Tooltip', 'Join selected sessions',...
                'ButtonPushedFcn', @obj.UIBtnJoin_Click);   

            % data plot
            obj.uiDataPlot = uipanel(obj.uiFig, 'Position', pos.uiDataPlot);
            
            % session list
            obj.uiList = uitable(obj.uiFig, 'Position', pos.uiList,...
                'CellSelectionCallback', @obj.UIList_Select,...
                'CellEditCallback', @obj.UIList_Edit);
            obj.CreateSessionList
            
            obj.uiFig.Visible = 'on';
            obj.uiFig.AutoResizeChildren = 'off';
            
            drawnow
            
       end

        function UIList_Select(obj, src, event)
            obj.prSelRow = event.Indices(:, 1);
        end

        function UIBtnMoveUp_Click(obj, src, event)
            obj.MoveSelectedRow(-1)
        end

        function UIBtnMoveDown_Click(obj, src, event)
            obj.MoveSelectedRow(1)
        end       
       
        function UIBtnSortByDate_Click(obj, src, event)
            [~, so] = sort(obj.prTable.SessionStartNum);     
            obj.prTable = obj.prTable(so, :);
            obj.prData = obj.prData(so);
            obj.UIUpdateSessionList
        end
       
        function MoveSelectedRow(obj, direction)
            
            numRows = size(obj.prTable, 1);
            
            % current linear sort order
            so_cur = 1:numRows;
            
            % get index of current row, and of row that we would like to
            % swap with. Moving up means swapping with the row above,
            % moving down means swapping with the row below
            s_cur = obj.prSelRow;
            s_swap = s_cur + direction;
            
            % check for top/bottom of list
            if s_swap < 1 || s_swap > numRows
                return
            end
            
            % swap
            so_new = so_cur;
            so_new(s_cur) = so_cur(s_swap);
            so_new(s_swap) = so_cur(s_cur);
            
            % reorder
            obj.prTable = obj.prTable(so_new, :);
            obj.prData = obj.prData(so_new);
            
            % update
            obj.UIUpdateSessionList
            
%             % set new selection
%             obj.SetSelectedRow(obj.prSelRow + direction)
           
        end
       
        function UIResize(obj, ~, ~)
        % Called when the uifigure is resized (via the SizeChangedFcn 
        % callback). Call UIGetPositions to get updated position of all
        % elements, then apply them.
            
            pos = obj.UIGetPositions;
            
            obj.uiList.Position = pos.uiList;
%             obj.uiDataPanel.Position = pos.uiDataPanel;
            obj.uiDataPlot.Position = pos.uiDataPlot;
            obj.uiStatus.Position = pos.uiStatus;
            obj.uiToolbar.Position = pos.uiToolbar;
            obj.uiBtnMoveUp.Position = pos.uiBtnMoveUp;
            obj.uiBtnMoveDown.Position = pos.uiBtnMoveDown;
            obj.uiBtnSortByDate.Position = pos.uiBtnSortByDate;
            
            obj.uiFig.AutoResizeChildren = 'off';
            
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

            pos.uiList = [0, h * .75, w, (h * .25) - h_toolbar];
            pos.uiDataPanel = [0, h * .5, w, (h * .25)];
            pos.uiDataPlot = [0, h_status, w, (h * .75) - h_status];

            pos.uiStatus = [0, 0, w, h_status];

            pos.uiToolbar = [0, h - h_toolbar, w, h_toolbar];

            pos.uiBtnMoveUp      = [off_btn + (0 * (h_btn + off_btn)), off_btn, h_btn, h_btn];
            pos.uiBtnMoveDown    = [off_btn + (1 * (h_btn + off_btn)), off_btn, h_btn, h_btn];
            pos.uiBtnSortByDate  = [off_btn + (2 * (h_btn + off_btn)), off_btn, h_btn, h_btn];           
            pos.uiBtnJoin        = [off_btn + (3 * (h_btn + off_btn)), off_btn, h_btn, h_btn];           

        end    

        function CreateSessionList(obj)

            numData = length(obj.prData);

            % loop through data and record dynamic props (aka session
            % metadata)
            s = cell(numData, 1);
            for d = 1:numData

                % dynamic props
                s{d} = cell2struct(obj.prData{d}.DynamicValues,...
                    obj.prData{d}.DynamicProps, 2);

                % GUID
                s{d}.GUID = obj.prData{d}.GUID;

                % session start 
                s{d}.SessionStartFormatted =...
                    obj.prData{d}.SessionStartTimeString;
                s{d}.SessionStartNum = obj.prData{d}.SessionStartTime;

            end

            % check for non-matching metadata
            fnames = cellfun(@fieldnames, s, 'UniformOutput', false);
            obj.prMatchingMetadata = all(isequal(fnames{1}, fnames{:}));

            % put into table, if there is an ID variable put that first,
            % and remove the logIdx variable
            obj.prTable = teLogExtract(s);
            if ismember('logIdx', obj.prTable.Properties.VariableNames)
                obj.prTable.logIdx = [];
            end
            if ismember('ID', obj.prTable.Properties.VariableNames)
                obj.prTable = movevars(obj.prTable, 'ID', 'Before',...
                    obj.prTable.Properties.VariableNames{1});
            end    
            
            % add join flag
            obj.prTable.Join = true(numData, 1);
            obj.prTable = movevars(obj.prTable, 'Join', 'Before',...
                obj.prTable.Properties.VariableNames{1});

            % sort by session date
            [~, so] = sort(obj.prTable.SessionStartNum);     
            obj.prTable = obj.prTable(so, :);
            obj.prData = obj.prData(so);
            obj.UIUpdateSessionList

        end
        
        function CreateParts(obj)
            
%         % filter data, table and extents according to join flags
%         
%             setToJoin = obj.uiList.Data{:, 1};
%             data_filt = obj.prData(setToJoin);
%             extent_filt = obj.prExtent(setToJoin);
            
        % combine temporal extents across datasets
        
            % label each extent table with the dataset index
            s = {};
            numData = length(obj.prExtent);
            for d = 1:numData
                
                % add dataset index to all rows of the table
                obj.prExtent{d}.idx = repmat(d, size(obj.prExtent{d}, 1), 1); 
                
                % add join filter
                obj.prExtent{d}.join =...
                    repmat(obj.prTable.Join(d), size(obj.prExtent{d}, 1), 1);
                
                % convert to struct
                tmp = table2struct(obj.prExtent{d});
                
                % break struct array apart and store each struct in a cell
                % array, so that we can...
                s = [s; arrayfun(@(x) x, tmp, 'UniformOutput', false)];

            end
            
            %...use teLogExtract to turn the whole thing into one table
            tab = flipud(teLogExtract(s));
            
            % store
            obj.prPlotElements = tab;
            
        end
        
        function UIUpdateSessionList(obj)
            obj.uiList.Data = obj.prTable;
            obj.uiList.ColumnEditable =...
                [true, false(1, size(obj.prTable, 2) - 1)];
            obj.UIUpdatePlot
        end
        
        function UIUpdatePlot(obj)
            
            if isempty(obj.prExtent), return, end
            if isempty(obj.prPlotElements)
                obj.CreateParts
            end
            tab = obj.prPlotElements;
            tab(~tab.join, :) = [];

        % make axes 
        
            delete(obj.uiDataPlot.Children)
            w = obj.uiDataPlot.Position(3);
            h = obj.uiDataPlot.Position(4);
            ax = uiaxes(obj.uiDataPlot, 'Position', [0, 0, w, h]);
            ax.YAxis.Visible = 'off';
            ax.Color = obj.uiDataPlot.BackgroundColor;
            ax.YTick = 0:1 / size(tab, 1):1;

        % find unique data types, determine y pos for each. The axes are
        % split into equal sections for each data type, and then each
        % section is subdivided into sections for each session
        
            tab = sortrows(tab, {'type', 'idx'}, {'ascend', 'ascend'});
            [type_u, ~, type_s] = unique(tab.type, 'stable');
            [ses_u, ~, ses_s] = unique(tab.idx, 'stable');
            numSes = length(ses_u);
            numTypes = length(type_u);
            
            h_type = 1 / 3;
            h_ses = h_type / numSes;
            
            cols = lines(numTypes);
            
            for t = 1:numTypes
                
                tab_type = tab(type_s == t, :);
                
                for s = 1:numSes
                    
                    % find current type/ses combo
                    idx = type_s == t & ses_s == s;
                    if ~any(idx), continue, end
                    
                    % find y pos
                    y_type = (t - 1) * h_type;
                    y_ses = y_type + ((s - 1) * h_ses);
                    % find x1, x2 (termporal extent of this type/ses)
                    x1 = tab.s1(idx);
                    x2 = tab.s2(idx) - x1;
                    
                    % make rect
                    pos = [x1, y_ses, x2, 0.8 * h_ses];
                    
                    rectangle(ax, 'Position', pos,...
                        'FaceColor', cols(t, :),...
                        'ButtonDownFcn', @obj.UIPlot_Click,...
                        'LineStyle', 'none',...
                        'Tag', num2str(find(idx)));
                    
                end
                
                % label type
                h_labType = ax.InnerPosition(4) / numTypes;
                y_labType = ax.InnerPosition(2) + ((t - 1) * h_labType);
                x1 = 0;
                x2 = ax.InnerPosition(1);
                y1 = y_labType;
                y2 = h_labType;
                uilabel(obj.uiDataPlot, 'Position', [x1, y1, x2, y2],...
                    'Text', type_u{t}, 'HorizontalAlignment', 'right');

                % indicate join
                x1 = min(tab_type.s1);
                y1 = y_type;
                x2 = max(tab_type.s2) - x1;
                y2 = (numSes * h_ses) - (0.2 * h_ses);
                rectangle(ax, 'Position', [x1, y1, x2, y2],...
                    'EdgeColor', cols(t, :),...
                    'LineStyle', '--',...
                    'LineWidth', 1,...
                    'FaceColor', [cols(t, :), .1]);
                
            end
            
            ax.XTickLabel = datestr(datetime(ax.XTick, 'ConvertFrom',...
                'posixtime'), 'dd-mmm HH:MM:SS');
            ax.XTickLabelRotation = 45;
            
        end
        
        function UIPlot_Click(obj, src, event)
            
            
            
        end
        
        function UIList_Edit(obj, src, event)
            
            obj.prTable = obj.uiList.Data;
            obj.CreateParts
            obj.UIUpdatePlot     
            
        end
        
        function UIBtnJoin_Click(obj, src, event)
            
            obj.Busy('Joining sessions...')
                        
            % filter data for selected
            idx_sel = obj.prTable.Join;
            data_filt = obj.prData(idx_sel);
            [suc, oc, ~, report] = teJoin(obj.prPath_out, data_filt{:});
            
            obj.NotBusy
            msgbox('Join operation completed.')
            
        end
        
        function Busy(obj, msg)
            
            if exist('msg', 'var')
                obj.uiStatus.Text = msg;
            else
                obj.uiStatus.Text = [];
            end
            
            obj.uiBtnMoveDown.Enable = 'off';
            obj.uiBtnMoveUp.Enable = 'off';
            obj.uiBtnSortByDate.Enable = 'off';
            obj.uiList.Enable = 'off';
            ch = obj.uiDataPlot.Children;
%             arrayfun(@(x) set(x, 'Enable', 'off'), ch);
            
            drawnow
            
        end
        
        function NotBusy(obj)
            
            obj.uiStatus.Text = '';
            
            obj.uiBtnMoveDown.Enable = 'on';
            obj.uiBtnMoveUp.Enable = 'on';
            obj.uiBtnSortByDate.Enable = 'on';
            obj.uiList.Enable = 'on';
            ch = obj.uiDataPlot.Children;
%             arrayfun(@(x) set(x, 'Enable', 'on'), ch);    
            
        end
            
   end
    
end