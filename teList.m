% todo 
% allow pause -> move to presenter
% allow calib -> move to presenter
% allow job -> move to presenter
% echo keyboard -> move to presenter
% progress report - move to presenter
% resumable - rewrite module
% disable save on trial - check
% name change listener to sync list name with list collection key

classdef teList < dynamicprops
    
    properties (SetObservable = true)
        Name = 'New List'
        RecalculateSamplingEachTime = false
    end
    
    properties (Dependent)
        Count
        StartSample 
        NumSamples
        Table
        SampleTable
        ControlRepeats
        OrderType
    end
    
    properties (Dependent, SetAccess = private)
        Order
        RandSeed = dbrng;
    end
    
    properties (Access = private)
        prTable
        prNumSamplesChanged = false
        prOrderType = 'SEQUENTIAL';
        prOrder 
        prCalculationEnabled = true
        prDoConRep
        prConRepVars
        prConRepMax
        prIsCompiled = false
    end
    
    properties (Access = ?tePresenter)
        prNumSamples
        prStartSample = 1
    end
    
    properties (Constant)
        AvailableTypes = ...
            {'trial', 'function', 'nestedlist', 'eck'}
    end
    
    properties (Dependent, Hidden, SetAccess = private)
        TreeviewNode
    end
    
    % these properties are set by the presenter when the list is compiled.
    % We store compiled results here so that the list can be saved/loaded
    % with a valid state, even if mid-session
    properties (Dependent, SetAccess = {?tePresenter})
        IsCompiled
    end
    
    properties (Access = {?tePresenter, ?teCollection, ?teTracker, ?teData})
        prComp
        prMap
        prMapList
        prTaskKey
        prCompIdx = 1
    end
    
    events 
        teListNameChanged
    end
    
    methods
        
        function obj = teList
            % init internal table, create one blank row
            obj.prTable = table;
            obj.AddRow(1)
        end
        
        function AddRow(obj, numRowsToAdd, atRow)
            % check whether numRowsToAdd was specified, if not assume 1
            if nargin > 1
                newSize = [1, 1];
            else
                newSize = [numRowsToAdd, 1];
            end
            % check whether atRow was specified, if not assume add at end
            if nargin <= 2
                atRow = [];
            else
                oldSize = size(obj.prTable, 1);
            end
            % check that atRow does not exceed table dimensions
            if atRow > size(obj.prTable, 1) + 1
                error('Table is %d rows, cannot add row at position %d.',...
                    size(obj.prTable, 1), atRow)
            end 
            % temp table containing new rows
            tmp             = table;
            tmp.Enabled     = true(                 newSize);
            tmp.Type        = repmat({'trial'},     newSize);
            tmp.Target      = repmat({''},          newSize);
            tmp.Task        = repmat({''},          newSize);
            tmp.StartSample = nan(                  newSize);
            tmp.NumSamples  = nan(                  newSize);
            tmp.Key         = repmat({''},          newSize);
            if isempty(obj.prTable)
                obj.prTable = tmp;
            else
                obj.prTable = vertcatMismatchedTables(obj.prTable, tmp);
            end
            % if necessary, reorder the table so that the new row is added
            % in the correct position (atRow)
            if ~isempty(atRow)
                % find current position of new row(s) in the table
                cur1 = oldSize + 1;             % current start row
                cur2 = oldSize + size(tmp, 1);  % current end row
                % if current position does not match, move the new row(s)
                if atRow ~= cur1
                    % insert at the top of the table?
                    if atRow == 1
                        obj.prTable = [obj.prTable(cur1:cur2, :);...
                            obj.prTable(1:end - size(tmp, 1), :)];
                    else
                        topHalf = obj.prTable(1:atRow - 1, :);
                        bottomHalf = obj.prTable(atRow:end - size(tmp, 1), :);
                        obj.prTable =...
                            [topHalf; obj.prTable(cur1:cur2, :); bottomHalf];
                    end
                end
            end
            obj.CalculateSampling
        end
        
        function CloneRow(obj, rowIdx, numClones)
            if rowIdx > obj.Count
                error('rowIdx out of bounds.')
            end
            if ~exist('numClones', 'var') || isempty(numClones)
                numClones = 1;
            end
            obj.prTable(end + 1:end + numClones, :) =...
                repmat(obj.prTable(rowIdx, :), numClones, 1);
        end
        
        function DeleteRow(obj, rowIdx)
            % check this is not the final row
            if obj.Count == 1
                error('Lists must have at least one row.')
            end
            if rowIdx > size(obj.prTable, 1) || rowIdx < 1
                error('Row index out of bounds.')
            end
            obj.prTable(rowIdx, :) = [];
            obj.CalculateSampling
        end
        
        function MoveRowUp(obj, row)
            % check that row is within bounds
            if row > size(obj.prTable)
                errordlg(sprintf('Table is %d rows, cannot move row %d up.',...
                    size(obj.prTable, 1), row))
            end
            if row == 1
                errordlg(sprintf('Cannot move row %d up - already at top.',...
                    row))
            end
            % move up
            idx = (1:size(obj.prTable, 1))';
            cur = idx(row);
            prev = idx(row - 1);
            idx(row) = prev;
            idx(row - 1) = cur;
            obj.prTable = obj.prTable(idx, :);
            obj.CalculateSampling
        end
        
        function MoveRowDown(obj, row)
            % check that row is within bounds
             if row > size(obj.prTable)
                error('Table is %d rows, cannot move row %d down.',...
                    size(obj.prTable, 1), row)
            end
            if row == size(obj.prTable, 1)
                error('Cannot move row %d down - already at end.',...
                    row)
            end
            % move up
            idx = (1:size(obj.prTable, 1))';
            cur = idx(row);
            next = idx(row + 1);
            idx(row) = next;
            idx(row + 1) = cur;
            obj.prTable = obj.prTable(idx, :);
            obj.CalculateSampling
        end
        
        function AddVariable(obj, varName)
            % check variable name is legal
            if ~isvarname(varName)
                error('Illegal variable name %s.', varName)
            end
            % add a new column to the table, set it's content to empty 
            obj.prTable.(varName) = repmat({''}, size(obj.prTable, 1), 1);
            obj.CalculateSampling;
        end
        
        function DeleteVariable(obj, val)
            % val can be a variable name or column index
            if ischar(val) 
                idx = find(strcmpi(obj.prTable.Properties.VariableNames, val));
                if isempty(idx)
                    error('Variable name %s now found.', val);
                end
            elseif isnumeric(val)
                if val > size(obj.prTable, 2) || val < 1
                    error('Column index is out of bound.')
                end
                idx = val;
            end
            % cannot delete internal variables
            if idx <= 5
                error('Cannot delete required internal variables.')
            end
            obj.prTable(:, idx) = [];
        end
        
        function CalculateSampling(obj)
            
            % if calculation is turned off, break out
            if ~obj.prCalculationEnabled, return, end
            
            % check that there are some items
            if obj.Count == 0
                obj.prOrder = [];
                return
            end
            
            % if controlling repeats, loop until we have a sampling order
            % that respects the constraints for each variable
            
            % sample
            obj.prOrder =...
                obj.SampleFromList(obj.StartSample, obj.NumSamples);
        end
        
        function [order, samples] = SampleFromList(obj, startSample,...
                numSamples)
            
            % check input args
            if ~exist('startSample', 'var') || isempty(startSample)
                startSample = obj.StartSample;
            end
            if ~exist('numSamples', 'var') || isempty(numSamples)
                numSamples = obj.NumSamples;
            end
            % loop through the list and sample from it
            order = nan(1, numSamples);
            % determine the ordering strategy
            isSeq = strcmpi(obj.prOrderType, 'SEQUENTIAL');
            isRand = strcmpi(obj.prOrderType, 'RANDOM');
            isSpec = isnumeric(obj.prOrderType);
            % starting pos
            if isSeq 
                % sequential - start at first sample
                listPos = startSample;                    
            elseif isRand
                % random - generate permutation of all orders, which
                % effectively also sets the start sample to a random
                % position in the list
                randOrd = obj.RandpermNoRepeats;
                randPos = 1;
                listPos = randOrd(randPos);
            elseif isSpec
                % specified - start at first entry in the specified order
                specPos = 1;
                listPos = obj.prOrderType(specPos);
            end
            % loop through list, sampling as we go
            samplePos = 0;                            
            while samplePos < numSamples
                samplePos = samplePos + 1;
                order(samplePos) = listPos;
                if isSeq
                    % move to next sequential index in the list
                    listPos = listPos + 1;
                    if listPos > obj.Count, listPos = 1; end
                elseif isRand
                    % select a random sample
                    randPos = randPos + 1;
                    if randPos > length(randOrd), randPos = 1; end
                    listPos = randOrd(randPos);
                    % control repeats
                elseif isSpec
                    specPos = specPos + 1;
                    if specPos > length(obj.prOrderType), specPos = 1; end
                    listPos = obj.prOrderType(specPos);
                end
            end
            % if requested, return - in addition to the numeric order
            % vector - the actual list samples
            samples = obj.prTable(order, :);
            
        end
        
        function Reset(obj)
            obj.prCompIdx = 1;
            obj.IsCompiled = false; 
        end
        
        function AddEnabledColumn(obj)
        % an .Enabled column was added to the table, to allow for a list
        % item to be temporarily en/disabled without deleting it. Legacy
        % lists do not have this column. This method adds it (defaulting to
        % true for all rows)
        
            % check that an .Enabled column does not already exist
            if ismember('Enabled', obj.prTable.Properties.VariableNames)
                error('An .Enabled column already exists in this table.')
            end
            
            % add the column
            obj.prTable.Enabled = true(size(obj.prTable, 1), 1);
            
            % move the column to the start
            numCols = size(obj.prTable, 2);
            idx = [numCols, 1:numCols - 1];
            obj.prTable = obj.prTable(:, idx);
            
        end
            
        % overloaded methods
        function obj = subsasgn(obj, s, varargin)
            switch s(1).type
                case '.'
                    if length(s) == 1
                        if strcmpi(s(1).subs, 'Table')
                            obj.CustomSetTable(varargin{:});
                         else
                            % pass to builtin
                            [~] = builtin('subsasgn', obj, s, varargin{:});
                        end
                    elseif length(s) == 2
                        % we are looking for obj.VAR{idx}, where VAR is a
                        % table variable name, and idx is a vald row index
                            
                            if strcmpi(s(1).subs, 'Table') && ischar(s(2).subs)
                                idx = 1:obj.Count;
                                var = s(2).subs;
                            elseif iscell(s(2).subs)
                                idx = s(2).subs{1};
                                var = s(1).subs;
                            else
                                idx = s(2).subs;
                                var = s(1).subs;
                            end
                            valIsScalar = isscalar(idx);
                            
                            % catch non-numeric/logical index
                            if ~isnumeric(idx) && ~islogical(idx)
                                error('Index must be numeric or logical.')
                            end
                            
                            % catch negative/zero scalar index
                            if valIsScalar && idx < 1
                                error('Scalar indices must be >0.')
                            end
                            
                            % expand list if indices are longer than
                            % current count
                            if length(idx) > size(obj.prTable, 1)
                                obj.Count = length(idx);
                            end
                            
                            % check that the value being assigned is legal
                            obj.checkValueIsLegal(var, varargin{1}, idx); 
                            
                            % assign the value
                            obj.prTable.(var)(idx) = varargin{1};
                            
%                                 % check that the second sub is a numeric scalar
%                             if isnumeric(s(2).subs{1}) &&...
%                                     (~isscalar(val) || val > 0)                            
%                             
% %                             if isscalar(s(2).subs{1}) &&...
% %                                     isnumeric(s(2).subs{1}) &&...
% %                                     s(2).subs{1} > 0
%                                 idx = val;
%                                 % if the requested row index is less than
%                                 % the number of rows, add rows to make room
%                                 if idx > size(obj.prTable, 1)
%                                     obj.Count = idx;
%                                 end
%                                 % check that the value being assigned is legal
%                                 obj.checkValueIsLegal(var, varargin{1}, idx);                                
%                                 % set the table variable use either () or
%                                 % {} dpeending upon what format the second
%                                 % sub was in
%                                 switch s(2).type
%                                     case '()'
%                                         obj.prTable.(var)(idx) = varargin{1};
%                                     case '{}'
%                                         obj.prTable.(var){idx} = varargin{1};
%                                 end
%                             else
%                                 error('Must provide a positive numeric scalar as a row index when assigning a value to a variable.')
%                             end
                    end
            end

        end
        
        % I/O
        function ImportECKList(obj, list)
            if ~exist('list', 'var') || isempty(list) ||...
                    ~isa(list, 'ECKList')
                error('Input must be ECKList.')
            end
            % disable sampling calculation, otherwise it will be called
            % each time an item is added, which is slow and wasteful
            obj.prCalculationEnabled = false;
            % extract data from ECKList
            obj.Name = list.Name;
            % make (matlab) table of current list
            tab = cell2table(...
                list.Table(2:end, :), 'variablenames', list.Table(1, :));
            % remove nested variable
            tab.Nested = [];
            % extract interval vars - function first
            target = tab.Function;
            tab.Function = [];
            % if NumTrials is specified, extract, otherwise set to NaN
            if any(strcmpi(tab.Properties.VariableNames, 'NumTrials'))
                num = tab.NumTrials;
                tab.NumTrials = [];
            else
                num = nan(size(tab, 1), 1);
            end
            % if StartSample is specified, extract, otherwise set to NaN
            if any(strcmpi(tab.Properties.VariableNames, 'StartTrial'))
                start = tab.StartTrial;
                tab.StartTrial = [];
            else 
                start = nan(size(tab, 1), 1);
            end
            % make a type variable, which will be all ECK
            type = repmat({'ECK'}, size(tab, 1), 1);
            % make a blank task variable
            task = repmat({''}, size(tab, 1), 1);
            % put into internal list
            cell_internal = [...
                type,...
                target,...
                task,...
                num2cell(start),...
                num2cell(num)];
            tab_internal = cell2table(cell_internal, 'variablenames',...
                {'Type', 'Target', 'Task', 'StartSample', 'NumSamples', 'Key'});
            % store as internal table
            obj.prTable = [tab_internal, tab];
            % randomisation/ordering
            obj.OrderType = list.Order;
            obj.ControlRepeats = list.ControlRepeats;
            % renable calculation, and calculate
            obj.prCalculationEnabled = true;
            obj.CalculateSampling
        end
        
        % get/set
        function val = get.Count(obj)
            val = size(obj.prTable, 1);
        end
        
        function set.Count(obj, numRowsWanted)
            % increase number of rows to match new count
            numRowsNow = size(obj.prTable, 1);
            if numRowsWanted == numRowsNow
                % do nothing
                return
            elseif numRowsWanted < numRowsNow
                % delete some rows
                obj.prTable(numRowsWanted + 1:end, :) = [];
            elseif numRowsWanted > numRowsNow
                % add some blank rows
                obj.AddRow(numRowsWanted - numRowsNow)
            end
        end
        
        function val = get.NumSamples(obj)
            % if num samples has never been changed, default to number of
            % items in the list. Otherwise, use the private value
            if ~obj.prNumSamplesChanged
                val = obj.Count;
            else
                val = obj.prNumSamples;
            end
        end
        
        function set.NumSamples(obj, val)
            % once this has been set onece, prNumSamplesChanged becomes true
            % and the value is stored in prNumSamples. 
            if ~isnumeric(val) || ~isscalar(val) 
                error('NumSamples must be a numeric scalar.')
            end
            if val < 1
                error('NumSamples must be > 0.')
            end
            obj.prNumSamples = val;
            obj.prNumSamplesChanged = true;
            obj.CalculateSampling
        end
        
        function val = get.StartSample(obj)
            val = obj.prStartSample;
        end
        
        function set.StartSample(obj, val)
            if ~isnumeric(val) || ~isscalar(val) || val < 1
                error('StartSample must be a positive numeric scalar.')
            end
            if val > obj.Count
                error('StartSample exceeds NumTrials.')
            end
            obj.prStartSample = val;
            obj.CalculateSampling
        end
        
        function set.ControlRepeats(obj, val)
            if isempty(val)
                obj.prDoConRep = false;
                return
            end
            % check for a n x 2 array
            if size(val, 2) ~= 2
                error('ControlRepeats must be a n x 2 cell array, in the form of [variable, maxRepeats].')
            end
            % check for valid variable names
            if ~all(cellfun(@(x) ismember(...
                    x, obj.prTable.Properties.VariableNames), val(:, 1)))
                error('ControlRepeats must contain variable names already defined in the list.')
            end
            % store
            obj.prConRepVars = val(:, 1);
            obj.prConRepMax = cell2mat(val(:, 2));
            obj.prDoConRep = true;
            obj.CalculateSampling
        end
        
        function val = get.ControlRepeats(obj)
            val = [obj.prConRepVars, num2cell(obj.prConRepMax)];
        end
        
        function val = get.OrderType(obj)
            val = obj.prOrderType;
        end
        
        function set.OrderType(obj, val)
            % for some reason this input is sometimes a cell array? if so
            % unpack it, but would be good to know why this happens
            
            if iscell(val), val = val{1}; end
            % Order cal be either a char (SEQUENTIAL or RANDOM), or a
            % numeric vector of row indices
            if isnumeric(val) && isvector(val) 
                % check that no values exceed the maximum row index
                if any(val) > obj.Count
                    error('Order vector exceeds number of list items.')
                elseif any(val) < 1
                    error('All elements of the order vector must be > 0')
                else
                    obj.prOrderType = val;
                    obj.prNumSamples = length(obj.prOrderType);
                    obj.prNumSamplesChanged = true;
                end
            elseif ischar(val)
                if ~any(strcmpi({'SEQUENTIAL', 'RANDOM'}, val))
                    error('Order must be SEQUENTIAL or RANDOM.')
                end
                obj.prOrderType = lower(val);
            end
            obj.CalculateSampling
        end
        
        function val = get.Order(obj)
            val = obj.prOrder;
        end
        
        function set.Order(obj, val)
            obj.prOrder = val;
        end
        
        function val = get.Table(obj)
            if obj.Count == 0
                val = [];
                return
            end
            val = obj.prTable;
        end
        
        function set.Table(obj, val)
            obj.CustomSetTable(val)
        end
        
        function CustomSetTable(obj, val)
            % check args
            if ~istable(val)
                error('Value must be a table.')
            end
            % check for required variables
            reqVars = {'enabled', 'type', 'target', 'task', 'startsample',...
                'numsamples', 'key'};
            varsPresent = all(cellfun(@(x)...
                ismember(x, lower(val.Properties.VariableNames)),...
                reqVars));
            if ~varsPresent
                fprintf(2, 'Required table variables are: ');
                fprintf(2, '%s ', reqVars{:});
                fprintf('\n')
                error('Missing required variables.')
            else
                obj.prTable = val;
                obj.CalculateSampling
            end
        end
        
        function val = get.SampleTable(obj)
            val = obj.Table(obj.prOrder, :);
        end 
        
        function set.Name(obj, val)
            obj.Name = val;
%             notify(obj, 'teListNameChanged')
        end
        
        function val = get.IsCompiled(obj)
            val = obj.prIsCompiled;
        end
        
        function set.IsCompiled(obj, val)
            % check input arg
            if ~islogical(val) || ~isscalar(val)
                error('IsCompiled must be a logical scalar.')
            end
            % if settings this property to false, we also want to delete
            % the compiled data for the list. This means that other code
            % that uses this data but fail to check the IsCompiled property
            % won't erroneously execute an invalid compiled state
            if ~val
                obj.prComp = [];
                obj.prMap = [];
                obj.prTaskKey = [];
                obj.prCompIdx = 1;
            end
            obj.prIsCompiled = val;
        end
        
    end
    
    methods (Access = private)
        
        % sampling        
        function r = RandpermNoRepeats(obj)
            tic
            iter = 1;
            r = obj.GenerateRandPerm;
            if obj.prDoConRep
                
                % get var names and max repeats per var
                vars = obj.prConRepVars;
                maxr = obj.prConRepMax;
                
                % default flags to indicate whether we are happy with
                % randomisation, both overall and for each var
                repHappy = false;
                varHappy = false(size(vars));
                
                % loop until happy about repeats
                while ~repHappy
                    
                    % compute temp sampling table using current randperm
                    % order
                    tab = obj.Table(r, :);
                    
                    % for each var, calculate the number of consecutive
                    % repeats, and calculate whether or not this is
                    % acceptable
                    for v = 1:length(vars)
                        
                        % get unique values of the current variable, as a
                        % numeric index (e.g. face = 1, object = 2 etc.)
                        [~, ~, s] = unique(tab.(vars{v}));
                        
                        % make a logical index representing whether the
                        % previous entry in the list of values is the same
                        % or different to the previous entry
                        s_diff = [false; s(2:end) == s(1:end - 1)];
                        
                        % find contiguous runs of the same value. the order
                        % is valid if none of the runs are > the maximum
                        % set in maxr. Note that we subtract one, because
                        % the differencing step above only starts counting
                        % runs from the first value that matches the
                        % preceeding value (so it undercounts the run
                        % length by 1)
                        ct = findcontig2(s_diff);
                        varHappy(v) = isempty(ct) ||...
                            all(ct(:, 3) <= maxr(v) - 1);
                        
                        % break out of loop if not happy (since any
                        % variables having illegal repeats forces a new
                        % permutation)
                        if ~varHappy(v)
                            break
                        end
                        
                    end
                    
                    % we're happy overall if we're happy about all vars
                    % individually
                    repHappy = all(varHappy);
                    
                    % if not happy, calculate a new permutation order and
                    % increment the iteration counter
                    if ~repHappy
                        r = obj.GenerateRandPerm; 
                        iter = iter + 1;
                        if iter > obj.NumSamples * 1000
                            error('Tried %d order permutations and could not meet control repeats contraints.', obj.NumSamples * 100)
                        end
                    end
                    
                end
            end
%             fprintf('Spent %.3fs doing %d iteration.\n', toc, iter);
        end
        
        function r = GenerateRandPerm(obj)
            % calculate how many samples are needed - this is obj.Count
            % repeated enough times to satisfy obj.NumSamples. First we'll
            % overshoot with an integer number of repeats of obj.Count,
            % then we'll chop the end off the bring it back in line with
            % obj.NumSamples
            fullRepsNeeded = ceil(obj.NumSamples / obj.Count);
            remainder = (obj.Count * fullRepsNeeded) - obj.NumSamples;
            % generate permutation over full repeats
            r = [];
            for rep = 1:fullRepsNeeded
                r = [r, randperm(obj.Count)];
            end
            % chop off remainder
            r(end - remainder + 1:end) = [];
        end
        
        function checkValueIsLegal(obj, var, val, rowIdx)
            if iscell(val), val = val{1}; end
            switch lower(var)
                case 'type'
                    % compare type with available types - error if not
                    % member
                    if ~ismember(lower(val), lower(obj.AvailableTypes))
                        error('%s is not a valid type - see AvailableTypes property.', val)
                    end
                case {'target', 'task'}
                    if ~ischar(val)
                        error('%s must be char.', var)
                    end
                case {'startsample', 'numsamples'}
                    % these variables can only be set for type nestedList
                    % or ECK. If type has not been set, set it now (assume
                    % nestedList, as this is a more common choice than
                    % ECK). If type has been set, and is not legal, throw
                    % an error
                    if isempty(obj.prTable.Type{rowIdx})
                        % set the type
                        obj.prTable.Type{rowIdx} = 'NestedList';
                    elseif ~ismember(lower(obj.prTable.Type{rowIdx}),...
                            {'nestedlist', 'eck'})
                        % throw an error
                        error('Cannot set %s when type is not NestedList or ECK.', var)
                    end
                otherwise
                    % the requested variable is not one of the required
                    % internal variables, which means that it is a dynamic
                    % variable. It may already exist, in which case we do
                    % nothing, allow this method to return to subsasgn,
                    % which will set the value. If it doesn't exist, we
                    % check whether it is a valid variable name, then allow
                    % execution to return to subsasgn to create the
                    % variable and set it's value
                    if ~ismember(var, obj.prTable.Properties.VariableNames)
                        % check valid variable name
                        if ~isvarname(var)
                            error('%s is not a valid variable name', var)
                        end
                    end
                        
                    
            end
            
        end
        
%         function newKey = getNextKey(obj)
%             if isempty(obj.prTable) ||...
%                     ~ismember('Key', obj.prTable.Properties.VariableNames)
%                 newKey = {1};
%                 return
%             end
%             keys = obj.prTable.Key;
%             % find numeric
%             isNum = cellfun(@(x) ~isnan(str2double(x)), keys);
%             if ~any(isNum)
%                 newKey = {1};
%             else
%                 % convert to double
%                 keyNum = cellfun(@str2double, keys(isNum));
%                 newKey = {num2str(max(keyNum) + 1)};
%             end
%         end
        
    end
    
end