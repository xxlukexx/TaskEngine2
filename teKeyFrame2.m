classdef teKeyFrame2 < handle
    
    properties
        TimeFormat = 'absolute'
        Duration = 1
    end
    
    properties (Dependent)
        Data
%         StartTime
        DataNorm
        DataAbs
    end
    
    properties (Access = private)
%         prStartTime = 0
        prData
    end

    methods 
        
        function val = GetValue(obj, time)
            % check input args
            if ~isnumeric(time) || ~isscalar(time) || time < 0
                error('''time'' must be a positive numeric scalar.')
            end        
            switch obj.TimeFormat
                case {'normalised', 'normalized'}
%                     if time > 1.5
%                         error('''time'' must be < 1.5.')
%                     end
                case 'absolute'
                    if time > obj.Duration
                        error('''time'' must be < Duration.')
                    end
                    % convert to norm
                    time = time / obj.Duration; 
            end
            % interpolate
            val = interp1(obj.DataNorm(:, 1), obj.DataNorm(:, 2), time);
        end
            
        % get / set
        function set.TimeFormat(obj, val)
            % check input args
            if ~ismember(lower(val), {'normalised', 'absolute'})
                error('TimeFormat must be ''normalised'' or ''absolute''')
            end
            % store
            obj.TimeFormat = lower(val);
        end
        
%         function set.StartTime(obj, val)
%             % check input args
%             if ~isnumeric(val) || ~isscalar(val) || val < 0 ||...
%                     val > obj.Duration
%                 error('StartTime must be a positive numeric scalar less than Duration.')
%             end
%             obj.prStartTime = val;
%         end
%         
%         function val = get.StartTime(obj)
%             val = obj.prStartTime;
%         end
        
        function set.Data(obj, val)
            % check input args
            if ~isnumeric(val) || size(val, 2) ~= 2 || ~ismatrix(val)
                error('Data must be a numeric matrix of [time, value].')
            end
            % if absolute, check time doesn't exceed duration
            if strcmpi(obj.TimeFormat, 'absolute')
                if any(val(:, 1) > obj.Duration)
                    error('Absolute time values must be less than Duration.')
                end
            end
            % sort by time
            [~, so] = sort(val(:, 1));
            val = val(so, :);
            % store
            obj.prData = val;
        end
        
        function val = get.Data(obj)
            val = obj.prData;
        end
        
        function val = get.DataNorm(obj)
            switch obj.TimeFormat
                case {'normalised', 'normalized'}
                    val = obj.Data;
                case 'absolute'
                    val = obj.Data;
                    val(:, 1) = val(:, 1) ./ obj.Duration;
            end
        end
        
        function val = get.DataAbs(obj)
            switch obj.TimeFormat
                case {'normalised', 'normalized'}
                    val = obj.Data;
                    val(:, 1) = val(:, 1) .* obj.Duration
                case 'absolute'
                    val = obj.Data;
            end
        end
        
    end
    
end
        
            
            
    