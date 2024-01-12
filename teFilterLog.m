classdef teFilterLog < handle
    
    properties (SetAccess = private)
        Log
        Filters teCollection
        SelectedRow
        SelectedTimestamp        
    end
    
    properties (Dependent, SetAccess = private)
        Table
    end
    
    properties (Access = protected)
        fig
        pnlFilter
        pnlTable
        tbl
        prDirty = true
        prTable
    end
    
    properties (Dependent)
        prFilteredTopics
        prFilteredSources
        prFilteredTasks
    end
    
    methods
        
        function obj = teFilterLog(lg)
            if nargin == 0 || ~isa(lg, 'teLog')
                error('Must pass a teLog object to create this object.')
            end
            obj.Log = lg;
            obj.Filters = teCollection('cell');
            addlistener(obj.Filters, 'ItemChanged', @obj.FiltersChanged)
        end
        
        function delete(obj)
            if ~isempty(obj.fig) && isgraphics(obj.fig)
                close(obj.fig)
            end
        end
        
        function DrawUI(obj)
            
            pos = obj.UIPositions;
            
            % make figure
            obj.fig = uifigure(...
                            'MenuBar', 'none',...
                            'ToolBar', 'none',...
                            'Units', 'pixels',...
                            'Position', pos.fig)
                        
            % make panels
            posPnlFilter = [0.00, 0.75, 1.00, 0.25];
            obj.pnlFilter = uipanel('parent', obj.fig,...
                            'Units', 'normalized',...
                            'Position', posPnlFilter,...
                            'BorderType', 'none',...
                            'BackgroundColor', 'r');
            
            posPnlTable = [0.00, 0.00, 1.00, 0.75];
            obj.pnlTable = uipanel(...
                            'parent', obj.fig,...
                            'Units', 'normalized',...
                            'Position', posPnlTable,...
                            'BackgroundColor', 'b',...
                            'BorderType', 'none');    
                        
            % make filters
            
            
            
            
            
            % make table
            tab = obj.Table;
            obj.tbl = uitable(...
                            'units', 'normalized',...
                            'Parent', obj.pnlTable,...
                            'Position', [0, 0, 1, 1],...
                            'Data', tab,...
                            'CellSelectionCallback', @obj.UITable_Select,...
                            'SelectionType', 'row',...
                            'ColumnName', tab.Properties.VariableNames);
        end
        
        % get/set
        function val = get.Table(obj)
            if obj.prDirty
                val = obj.MakeTable;
                obj.prTable = val;
            end
            val = obj.prTable;
        end
        
        function set.Log(obj, val)
            obj.Log = val;
            obj.prDirty = true;
        end
        
        function set.Filters(obj, val)
            obj.Filters = val;
            obj.prDirty = true;
        end
        
        function val = get.prFilteredTopics(obj)
            tab = obj.Table;
            val = unique(tab.topic);
        end
        
        function val = get.prFilteredSources(obj)
            tab = obj.Table;
            val = unique(tab.source);
        end
        
        function val = get.prFilteredTasks(obj)
            tab = obj.Table;
            val = unique(tab.task);
        end
        
    end
    
    methods (Hidden, Access = protected)
        
        function tab = MakeTable(obj)
            
            if isempty(obj.Filters)
                tab = obj.Log.LogTable;
                return
            end
            
            % build filter terms
            cmd = {};
            for f = 1:obj.Filters.Count
                cmd = [cmd, obj.Filters.Items(f)];
            end
                
            tab = teLogFilter(obj.Log.LogArray, cmd{:});
            
            obj.prDirty = false;
                        
        end
        
        function UITable_Select(obj, src, event)
            sel = event.Indices(1, 1);
            obj.SelectedRow = sel;
            obj.SelectedTimestamp = src.Data.timestamp(sel);
        end
        
        function FiltersChanged(obj, ~, ~)
            obj.prDirty = true;
            if ~isempty(obj.tbl) && isgraphics(obj.tbl)
                tab = obj.Table;
                obj.tbl.Enable = 'off';
                obj.tbl.Data = tab;
                obj.tbl.ColumnName = tab.Properties.VariableNames;
                obj.tbl.Enable = 'on';
            end
        end
        
        function pos = UIPositions(obj)
            
            % figure out monitors
            sc = get(0, 'MonitorPosition');
            sc = sc(size(sc, 1), :);
            mw = sc(3);
            mh = sc(4);
            
            pos.fig = [...
                sc(1) + (mw / 4),...
                sc(2) + (mh / 4),...
                mw * .75,...
                mh * .75];
            pos.fig = sc;
            pos.fig = sc .* .8;
            
            
            
            
        end
            
    end
    
end