classdef teLogViewer < handle
    
    properties
        LogArray
        HideEmptyColumns = true
    end
    
    properties (Dependent, SetAccess = private)
        Variables
        Table
        Filters
    end
    
    properties (SetAccess = private)
        UniqueValues
    end
    
    properties (Access = private)
        prTable
        prFilters = {}
        fig
        pnlFilter
        pnlTable
        tbl
    end
    
    methods
        
        % constructor
        function obj = teLogViewer(logArray)
            % check input arg has been passed
            if ~exist('logArray', 'var') || isempty(logArray) ||...
                    ~iscell(logArray) || ~all(cellfun(@isstruct, logArray))
                error('Must pass a cell array of structs (at Task Engine log array)')
            end
            obj.LogArray = logArray;
            obj.Update
            obj.DrawUI
        end
        
        function Update(obj)
            obj.MakeTable
            set(obj.tbl, 'Data', obj.PrepareTableData)
            set(obj.tbl, 'ColumnName', obj.prTable.Properties.VariableNames)
        end
        
        function MakeTable(obj)
            % get table of all variables
            teEcho('Processing log array...\n');
            % get whole table, or filter
            if isempty(obj.prFilters)
                obj.prTable = teLogExtract(obj.LogArray);
            else
                enabled = logical(cell2mat(obj.prFilters(:, 1)));
                vars = obj.prFilters(enabled, 2)';
                vals = obj.prFilters(enabled, 3)';
                args = reshape([vars; vals], 1, []);
                obj.prTable = teLogFilter(obj.LogArray, args{:});
            end
            % get unique values
            obj.UniqueValues = teCollection;
            vars = obj.Variables;
            for v = 1:length(vars)
                % get values
                vals = obj.prTable.(vars{v});
                % remove empty
                if obj.HideEmptyColumns && iscell(vals)
                    empty = cellfun(@isempty, vals);
                    vals(empty) = [];
                end
                % ignore numeric
                if iscell(vals)
                    if ~all(cellfun(@ischar, vals))
                        vals_u = [];
                    else
                        vals_u = unique(vals);
                    end
                else
                    vals_u = [];
                end
                obj.UniqueValues(vars{v}) = vals_u';
            end
        end
        
        function DrawUI(obj)
            % make figure
            obj.fig = uifigure(...
                            'MenuBar', 'none',...
                            'ToolBar', 'none',...
                            'Units', 'normalized',...
                            'Position', [0.25, 0.75, 0.75, 0.75]);
                        
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

            obj.tbl = uitable(...
                            'units', 'normalized',...
                            'Parent', obj.pnlTable,...
                            'Position', [0, 0, 1, 1],...
                            'Data', obj.PrepareTableData,...
                            'ColumnName', obj.prTable.Properties.VariableNames);
        end
        
        function c = PrepareTableData(obj)
            c = table2cell(obj.prTable);
            idx_wrong = cellfun(@(x) ~isnumeric(x) &&...
                ~islogical(x) && ~ischar(x), c(:));
            idx_empty = cellfun(@isempty, c(:));
            idx = idx_wrong | idx_empty;
            c(idx_empty) = repmat({'<>'}, sum(idx_empty), 1);
            c(idx_wrong) = repmat({'<CANNOT DISPLAY>'}, sum(idx_wrong), 1);
        end
            
        % filter management
        function AddFilter(obj, var, val)
            if ~ischar(var)
                error('Variable must be char.')
            end
            if ~ischar(val) && ~isnumeric(val)
                error('Value must be char or numeric.')
            end
            obj.prFilters(end + 1, :) = {true, var, val};
            obj.Update;
        end
        
        function RemoveFilter(obj, varOrIdx)
            idx = obj.LookupFilterIdxFromVar(varOrIdx);
            % remove filter
            obj.prFilters(idx, :) = [];
            obj.Update;
        end
        
        function EnabledFilter(obj, varOrIdx)
            idx = obj.LookupFilterIdxFromVar(varOrIdx);
            % enabled filter
            obj.prFilters{idx, 1} = true;  
            obj.Update;
        end
        
        function DisableFilter(obj, varOrIdx)
            idx = obj.LookupFilterIdxFromVar(varOrIdx);
            % disable filter
            obj.prFilters{idx, 1} = false;  
            obj.Update;
        end
        
        function ClearFilters(obj)
            obj.prFilters = {};
            obj.Update
        end
        
        function idx = LookupFilterIdxFromVar(obj, var)
            % process input argument
            if ischar(varOrIdx)
                idx = obj.LookupFilterIdxFromVar(varOrIdx);
            elseif isnumeric(varOrIdx)
                idx = varOrIdx;
            else
                error('Must pass either a char variable name or numeric index.')
            end
            % lookup
            if isempty(obj.prFilters)
                idx = [];
            else
                idx = find(obj.prFilters(:, 2), var);
            end
            % check index
            if idx < 1 || idx > size(obj.prFilters, 1)
                error('Index %d out of bounds.', idx)
            end               
        end
        
        % get/set
        function val = get.Table(obj)
            val = obj.prTable;
        end
        
        function val = get.Variables(obj)
            val = obj.prTable.Properties.VariableNames;
        end
        
        function val = get.Filters(obj)
            if isempty(obj.prFilters)
                val = table;
            else
                val = cell2table(obj.prFilters, 'VariableNames',...
                    {'Enabled', 'Variable', 'Value'});
            end
        end
        
        function set.HideEmptyColumns(obj, val)
            % check inout arg
            if ~islogical(val) || ~isscalar(val)
                error('HideEmptyColumns must be a logical scalar.')
            end
            % update property value
            obj.HideEmptyColumns = val;
            % update table
            obj.Update
        end

    end
    
end
        