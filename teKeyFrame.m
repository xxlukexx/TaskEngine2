classdef teKeyFrame < dynamicprops
    
    properties
        Duration
        StartTime
        Loop = false
        debug
    end
    
    properties (Dependent)
        TimeMode
        TimeValues
    end
    
    properties (Dependent, SetAccess = private)
        Value
        EndTime
        CurrentTime
        Valid
        ValidationErrors
        Started
        Finished
    end
    
    properties (Access = private)
        prTimeMode = 'normalized'
        prValid = false
        prValidationErrors
        prTimeValues
    end
    
    methods
        
        function AddTimeValue(obj, time, val)
            if ~isnumeric(time) || ~isvector(time) || any(time < 0)
                error('time must be a positive numeric scalar or vector.')
            end
            if ~isnumeric(val) || ~isvector(val) || any(val < 0)
                error('value must be a positive numeric scalar or vector.')
            end
            if ~isequal(size(time), size(val))
                error('''time'' and ''value'' must be the same length.')
            end
            % convert to normalized
            if strcmpi(obj.prTimeMode, 'absolute')
                if isempty(obj.Duration)
                    error('When using ''absolute'' TimeMode, must set Duration property before adding TimeValues.')
                end
                time = time / obj.Duration;
            end
            % store
            num = size(time, 1);
            obj.prTimeValues(end + 1:end + num, 1:2) = [time, val];
            % sort by time
            [~, so] = sort(obj.prTimeValues(:, 1));
            obj.prTimeValues = obj.prTimeValues(so, :);
        end
            
        % get/set
        function val = get.TimeMode(obj)
            val = obj.prTimeMode;
        end
        
        function set.TimeMode(obj, val)
            if ~any(strcmpi(val, {'normalized', 'absolute'}))
                error('TimeMode must be ''normalized'' or ''absolute''.')
            end
            obj.prTimeMode = val;
        end
        
        function val = get.TimeValues(obj)
            val = obj.prTimeValues;
        end
        
        function set.TimeValues(obj, val)
            if ~isnumeric(val) || size(val, 2) ~= 2
                error('TimeValues must be a [n x 2] matrix.')
            end
            obj.prTimeValues = val;
        end
        
        function set.Duration(obj, val)
            if ~isnumeric(val) || ~isscalar(val) || val < 0
                error('Duration must be a positive numeric scalar.')
            end
            obj.Duration = val;
        end
        
        function set.StartTime(obj, val)
            if ~isnumeric(val) || ~isscalar(val) || val < 0
                error('StartTime must be a positive numeric scalar.')
            end
            obj.StartTime = val;
        end
        
        function val = get.EndTime(obj)
            val = obj.StartTime + obj.Duration;
        end
        
        function val = get.CurrentTime(obj)
            val = teGetSecs - obj.StartTime;
        end
        
        function val = get.Valid(obj)
            val = false;
            if isempty(obj.Duration)
                obj.prValidationErrors = 'Empty or invalid Duration';
            elseif isempty(obj.StartTime)
                obj.prValidationErrors = 'Empty or invalid StartTime';
            elseif isempty(obj.prTimeValues)
                obj.prValidationErrors = 'No time values defined.';
            else
                val = true;
            end
            if val ~= obj.prValid
                % this stops us setting the property each time
                obj.prValid = val;
                if val, obj.prValidationErrors = []; end
            end
        end
        
        function val = get.ValidationErrors(obj)
            val = obj.prValidationErrors;
        end
        
        function val = get.Started(obj)
            val = obj.Valid && ~obj.Finished && teGetSecs >= obj.StartTime;
        end
        
        function val = get.Finished(obj)
            val = obj.Valid && teGetSecs > obj.EndTime;
        end
        
        function set.Loop(obj, val)
            if ~islogical(val) || ~isscalar(val)
                error('Loop must be a logical scalar.')
            end
            obj.Loop = val;
        end
        
        function val = get.Value(obj)
            if ~obj.Valid 
                val = nan;
                return
            end
            % record time now
            time_now = teGetSecs;
            % get time values
            tv = obj.prTimeValues;
            % calculate proportion of time passed
            elapsed = time_now - obj.StartTime;
            time_prop = elapsed / obj.Duration;
            if time_prop >= 1 && obj.Loop
                time_prop = mod(elapsed, obj.Duration);
            end
            % are we before the first time value, or after the last one?
            if time_prop > 0 && time_prop < tv(1, 1)
                % before first - don't yet know a value, so return empty
                val = tv(1, 2);      
                return
            elseif ~obj.Loop && (time_prop >= tv(end, 1) || time_prop < 0)
                % after last, use last available 
                val = tv(end, 2);
                return
            end
            % find time values that we are between
            t1 = find(time_prop >= tv(:, 1), 1, 'last');
            t2 = t1 + 1;
            % calculate distance to neighbouring time values
            dis = time_prop - tv(t1, 1);
            % calculate total distance between times
            total_dist = tv(t2, 1) - tv(t1, 1);
            % distance to neighbour as prop of total distance
            dis_prop = dis / total_dist;
            % value change between neighbouring times
            change = tv(t2, 2) - tv(t1, 2);
            % scale change according to time distance between time values
            value_change = change * dis_prop;
            % add change to left-hand neighbour to get current value
            val = tv(t1, 2) + value_change;
            
            obj.debug(end + 1, 1:2) = [time_prop, val];
        end
        
    end
    
end