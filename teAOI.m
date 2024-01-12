% todo implement Hit for backward compat with ECK
classdef teAOI < handle
    
    properties
        Rect = [0, 0, 1, 1]
        TriggerTolerance = 0
        ResetOnsetWhenAddedToEyeTracker = true
    end
    
    properties (Dependent)
        Active
    end
    
%     properties (SetAccess = {?teEyeTracker, ?tePresenter})
%         Valid
%     end
    
    properties (Dependent, SetAccess = {?teEyeTracker})
        InAOI
        Buffer
        Onset
        Offset
        TotalSamples
        TotalTime
        Prop
        PropLeft
        PropRight
        PropValid
        PropValidLeft
        PropValidRight   
        SamplesIn
        SamplesInLeft
        SamplesInRight
        TimeIn
        TimeInLeft
        TimeInRight
        LatestTimestamp
        EarliestTimestamp
    end
    
    properties (GetAccess = {?teEyeTracker, ?tePresenter, ?teCollection})
%     properties (Access = private)
        prBuffer
        prIdx = 1
    end
    
    properties (Hidden, Dependent, SetAccess = private)
        Hit
    end
    
    properties (Access = private)
        % metrics        
        prTotalSamples = 0
        prTotalIn = 0
        prTotalInLeft = 0
        prTotalInRight = 0
        prTotalValid = 0
        prTotalValidLeft = 0
        prTotalValidRight = 0
        prTotalTime
        prProp
        prPropLeft
        prPropRight
        prPropValid
        prPropValidLeft
        prPropValidRight
        prTime
        prTimeLeft
        prTimeRight
        prInstantHasGaze 
        prEarliestTimestamp = inf
        prLatestTimestamp = -inf
        % active/onsets/offsets
        prOnsets
        prOffsets
        prActive = false
        prActiveIdx = 1
        prMetrics
        prMetricsDirty = true
        prMetricsIdx = 1
    end
    
    properties (Constant)
        CONST_DEF_BUFFER_SIZE = 1e6 / 2;    % approx 30mins @ 300Hz
        CONST_BUFFER_COL_HEADINGS = {...
            'Time',...
            'InAOI',...
            'Valid',...
            'InAOI_LeftEye',...
            'InAOI_RightEye',...
            'Valid_LeftEye',...
            'Valid_RightEye',...
            'Active'};
        CONST_DEF_ACTIVE_BUFFER_SIZE = 1e3
    end
    
    events
        AddLog
    end
    
    methods
       
        function obj = teAOI(rect, triggerTol)
            if nargin >= 1  
                obj.Rect = rect;
            end
            if nargin == 2
                obj.TriggerTolerance = triggerTol;
            end
            % init storage
            obj.Reset
        end
        
        function [active, rect, propIn] = ReceiveGaze(obj, gaze)
        % [active, rect, propIn] = teAOI.RECEIVEGAZE(gaze) causes an
        % AOI to receive a chunk of gaze data. Gaze should be in
        % TaskEngine2 format. 
        %
        % This method is usually called upon an eye tracker update
        % event. It ensures that the AOI buffer is filled with all
        % available gaze data. 
        %
        % Gaze can only be appended to the buffer in correct time
        % order. This means that an AOI cannot receive gaze that is
        % older than the most recent sample in the buffer. Another way
        % to look at this is that new gaze can only be appended to the
        % eye tracker - you cannot insert historic samples of gaze into
        % the buffer. This is by design, to ensure that the the AOI
        % buffer has continuous data that matches exactly the buffer of
        % the eye tracker. 
        %
        % When an AOI is added to the eye tracker class, an event is
        % fired that causes the eye tracker to send all exisiting gaze
        % to the AOI. This means that the AOI will be initialised with
        % all available gaze data before it is touched by any task
        % code. 
        %
        % When the eye tracker updates, and new gaze is then sent to
        % the AOI and appended to the end of the buffer. This means
        % that the AOI buffer (assuming the AOI is attached to the eye
        % tracker via the AOIs collection of the teEyeTracker class) is
        % always up to date. 
        %
        % AOIs can be active or inactive. Their onset/offset properties
        % determine when the AOI will be active. The .Active property
        % reflect the current state. When gaze data is added to the AOI
        % buffer, a flag is set for each sample (in the 8th column of
        % the buffer) that indicates - for that sample - whether or not
        % the AOI was active. This means that automatically calculated
        % AOI metrics (prop gaze etc.) will represent only that time
        % for which the AOI was active. 
        %
        % By default, an AOI is active from the point at which it is
        % initialised, until infinity. Therefore metrics will be
        % calculated FROM the point of initialisation, TO the most
        % recent available gaze sample. If the .Onset and .Offset
        % properties are adjusted, then the active flag column in the
        % buffer will be updated to reflect this, and all calculcated
        % AOI metrics will also change. 
        %
        % An exception to these "active" rules of the AOI are when the
        % .SelectGaze function is called with a 'from' and 'to'
        % argument. In this case, the active flags will be ignored and
        % the AOI will return metrics based around the 'from' and 'to'
        % time. This will not affect the calculated metrics, as a
        % .SelectGaze call with 'from' and 'to' arguments is treated as
        % an exception to the active rules. 
            
        % check that some data has been passed, and that all of the
        % timestamps are later than the gaze already in the AOI buffer
        
            if isempty(gaze), return, end
            
%             % get the most recent timestamp in the buffer. If the buffer is
%             % empty, then set this to -inf (meaning that gaze data with any
%             % timestamps can be added)
%             if obj.prIdx > 1
%                 % buffer is not empty, get most recent timestamp
%                 mostRecentTimestamp = obj.prBuffer(obj.prIdx - 1, 1);
%                 
%             else
%                 % buffer is empty
%                 mostRecentTimestamp = -inf;
%                 
%             end
            
            % check the timestamps of the incoming gaze data against the
            % most recent timestamp in the buffer. If the new timestamps
            % are earlier than the existing ones, throw an error
            if any(gaze(:, 1) <= obj.prLatestTimestamp) 
                error('Incoming gaze has timestamps BEFORE the most recent timestamp in the AOI buffer - cannot add.')
            end
            
            % store earliest time stamp, if this is the first method call
            if obj.prEarliestTimestamp == inf
                obj.prEarliestTimestamp = gaze(1, 1);
            end
            
            % store latest (most recent) timestamp
            obj.prLatestTimestamp = gaze(end, 1);
            
        % process the gaze data. Split into separate eyes, and pull out
        % validity. Use this data to count the number of samples inside the
        % AOI
        
            % get gaze data x, y for both eyes
            lx = gaze(:, 2);
            ly = gaze(:, 3);
            rx = gaze(:, 17);
            ry = gaze(:, 18);
            
            % get missing data
            valid_l = gaze(:, 4);
            valid_r = gaze(:, 19);
            valid = valid_l & valid_r;            
            
            % find gaze in AOI
            in_l = lx >= obj.Rect(1) & ly > obj.Rect(2) &...
                lx <= obj.Rect(3) & ly <= obj.Rect(4);
            in_r = rx >= obj.Rect(1) & ry > obj.Rect(2) &...
                rx <= obj.Rect(3) & ry <= obj.Rect(4);
            in = in_l | in_r;     
            
        % AOIs can be active or inactive. Get a logical vector from the new
        % gaze data, with each sample representing whether or not the AOI
        % was valid 
            
            activeFlags = obj.CalculateActiveFlags(gaze(:, 1));
            
        % store the new gaze data, and whether the gaze was in the AOI, in
        % the buffer
        
            % get sample indices of where to put the new gaze 
            s1 = obj.prIdx;
            s2 = s1 + size(gaze, 1) - 1;
            
            % store
            obj.prBuffer(s1:s2, 1) = gaze(:, 1);    % time
            obj.prBuffer(s1:s2, 2) = in;            % in
            obj.prBuffer(s1:s2, 3) = valid;         % valid
            obj.prBuffer(s1:s2, 4) = in_l;          % in left
            obj.prBuffer(s1:s2, 5) = in_r;          % in right
            obj.prBuffer(s1:s2, 6) = valid_l;       % valid left
            obj.prBuffer(s1:s2, 7) = valid_r;       % valid right
            obj.prBuffer(s1:s2, 8) = activeFlags;   % active flags
            
            % store instaneous value for whether the AOI has gaze. Speeds
            % up hit detection. 
            obj.prInstantHasGaze = in(end);
            
            obj.prIdx = s2 + 1;
            
            % increment buffer if full
            curSize = size(obj.prBuffer, 1);
            curIdx = obj.prIdx;
            
            % if size is too small...
            changed = curIdx >= curSize;
            if changed
                % calculate new size
                curSize = curSize + obj.CONST_DEF_BUFFER_SIZE;
                % increase
                obj.prBuffer(curSize, 1) = false;
                % log
                eventLogData = teLogEventData(struct(...
                    'source', 'eyetracker', 'topic',...
                    'buffering', 'data',...
                    sprintf('Buffer AOI increased to %d', curSize)));
                notify(obj, 'AddLog', eventLogData)
                
            end 
            
        % to have accurate and up-to-date AOI metrics (e.g. for display
        % in the preview window) we need to know 1) total number of
        % samples, 2) total number of samples in AOI, 3) total number of
        % valid samples. We also need this for both left and right eyes.
        % Because it is slow to calculate this on a big AOI buffer, we
        % calculate it for each chunk of new gaze data, then add it to a
        % running total.
        % We use the activeFlags variable to ensure that we only count
        % samples where the AOI was active.
        
            % calculate for this gaze chunk
            metSamples              = sum(activeFlags);
            metIn                   = sum(in(activeFlags));
            metIn_l                 = sum(in_l(activeFlags));
            metIn_r                 = sum(in_l(activeFlags));
            metVal                  = sum(valid(activeFlags));
            metVal_l                = sum(valid_l(activeFlags));
            metVal_r                = sum(valid_r(activeFlags));
            
            % add metrics for this chunk to running totals
            obj.prTotalSamples      = obj.prTotalSamples + metSamples;
            obj.prTotalIn           = obj.prTotalIn + metIn;
            obj.prTotalInLeft       = obj.prTotalInLeft + metIn_l;
            obj.prTotalInRight      = obj.prTotalInRight + metIn_r;
            obj.prTotalValid        = obj.prTotalValid + metVal;
            obj.prTotalValidLeft    = obj.prTotalValidLeft + metVal_l;
            obj.prTotalValidRight   = obj.prTotalValidRight + metVal_r;
            
            % proportion in AOI
            obj.prProp              = obj.prTotalIn         / obj.prTotalValid;
            obj.prPropLeft          = obj.prTotalInLeft     / obj.prTotalValidLeft;
            obj.prPropRight         = obj.prTotalInRight    / obj.prTotalValidRight;

            % proportion valid
            obj.prPropValid         = obj.prTotalValid      / obj.prTotalSamples;
            obj.prPropValidLeft     = obj.prTotalValidLeft  / obj.prTotalSamples;
            obj.prPropValidRight    = obj.prTotalValidRight / obj.prTotalSamples;        

            % time in AOI
            time                    = sum(diff(gaze(in, 1)));
            time_l                  = sum(diff(gaze(in_l, 1)));
            time_r                  = sum(diff(gaze(in_r, 1)));
            obj.prTime              = obj.prTime + time;
            obj.prTimeLeft          = obj.prTimeLeft + time_l;
            obj.prTimeRight         = obj.prTimeRight + time_r;
                
            % mark metrics as dirty, so that they are recalculated when
            % next needed
            obj.prMetricsDirty = true;
            
            % output vars (saves caller function having to refer back to
            % AOI with slow get/set methods in order to get the key values)
            active = obj.Active;
            rect = obj.Rect;
        end
        
        function [time, in, val, buf] = SelectGaze(obj, from, to, tolerance)
            % default from and to times
            if nargin == 1 || isempty(from)
                from = obj.LatestTimestamp;
            end
            if nargin <= 2 || isempty(to)
                to = obj.LatestTimestamp;
            end
            % check validity of from/to
            obj.AssertFromToTimestamps(from, to)      
            % adjust requested period according to trigger tolerance
            if nargin == 4 && to - from < tolerance
                from = to - tolerance;
            end            
            % get buffer
            buf = obj.prBuffer(1:obj.prIdx - 1, :);
            % filter for samples between from and to
            s = buf(:, 1) >= from & buf(:, 1) <= to;
            time = buf(s, 1);       % timestamps
            in = buf(s, 2);         % in AOI
            val = buf(s, 3);        % valid
        end
        
        function [has_int, entryTime_int, duration_int, has_raw,...
                entryTime_raw, duration_raw] = HasGaze(obj, from, to)
            % if no gaze data, return
            if obj.prIdx == 1
                has_int = false;
                return
            end
            % if not active, can't have gaze
            if ~obj.Active
                has_int = false;
                return
            end
            % if no from and to times specified, we're being asked whether
            % the AOI has gaze right now. This instantaneous value is
            % stored during the ReceiveGaze method, so we can short circuit
            % everything else and just return this
            if nargin == 1 && nargout == 1
                has_int = obj.prInstantHasGaze;
                return
            end
                
            % check input args
            if nargin == 1
                from = [];
            end
            if nargin <= 2
                to = [];
            end
            % find samples
            [time, in, val] = obj.SelectGaze(from, to, obj.TriggerTolerance);
            % if trigger tolerance is not active, short circuit checking
            % for it
            mostRecentTimestamp = obj.prBuffer(obj.prIdx - 1, 1);
            if obj.TriggerTolerance == 0
                % both metrics (normal and raw) are the same here, since
                % we're only dealing with one sample of data
                has_int = in;
                has_raw = has_int;
                entryTime_int = time(1);
                entryTime_raw = entryTime_int;
                duration_int = entryTime_int - mostRecentTimestamp;
                duration_raw = duration_int;
            else
                % calculate raw first, because if there is no missing data
                % at all we can use that for the interpolated version
                has_raw = all(in);
                if has_raw
                    % find the first and calculate entry time and duration
                    entryTime_raw = time(1);
                    duration_raw = entryTime_raw - mostRecentTimestamp;
                    % no need to interpolate since the raw data is valid,
                    % so set the interp metrics to the same as raw
                    has_int = has_raw;
                    entryTime_int = entryTime_raw;
                    duration_int = duration_raw;
                else
                    % no gaze samples in the AOI so set raw entry time and
                    % duration to NaN
                    entryTime_raw = nan;
                    duration_raw = nan;
                    % was the first sample in the AOI?
                    if in(1)
                        % were all non-AOI samples missing?
                        in_int = in | ~val;
                        has_int = all(in_int);
                        if has_int
                            % find the first and calculate entry time and duration
                            entryTime_int = time(1);
                            duration_int = entryTime_int - mostRecentTimestamp;     
                        else
                            % no gaze in AOI, so no entry time/duration
                            entryTime_int = nan;
                            duration_int = nan;
                        end   
                    else
                        has_int = false;
                    end
                end
            end
        end
        
        function [didEnter, entryTime, didExit, exitTime] =...
                EntryExit(obj, from, to, tolerance)
            % defaults
            didEnter = false;
            entryTime = nan;
            didExit = false;
            exitTime = nan;
            duration = nan;
            % if no gaze data, return
            if obj.prIdx == 1, return, end
            % if not active, can't have gaze
            if ~obj.Active, return, end
            % default tolerance
            if nargin <= 3
                tolerance = obj.TriggerTolerance;
            end
            % find samples
            [time, in, val] = obj.SelectGaze(from, to, tolerance);            
            % find ct
            ct = findcontig2(in);
            ct = contig2time(ct, time);
            if ~isempty(ct)
                % remove runs less than tolerance
                belowTol = ct(:, 3) < tolerance;
                ct(belowTol, :) = [];
                % find most recent entry
                if ~isempty(ct) && ct(1, 1) > from
                    didEnter = true;
                    entryTime = ct(1, 1);
                end
                % most recent exit
                if ~isempty(ct) && ct(end, 2) < to
                    didExit = true;
                    exitTime = ct(end, 2);
                end
            end
        end
        
        function flags = CalculateActiveFlags(obj, time)
            if isempty(time)
                flags = [];
                return
            end
            % get timestamps for all on/offset pairs
            t1 = obj.prOnsets(1:obj.prActiveIdx - 1);
            t2 = obj.prOffsets(1:obj.prActiveIdx - 1);
            if length(t1) ~= length(t2)
                error('On/offset pair lengths do not match!')
            end
            numPairs = length(t1);
            % default to inactive for all times
            flags = false(size(time));
            % loop through each pair and set flag to active between
            % on/offsets
            for p = 1:numPairs
                s = time >= t1(p) & time <= t2(p);
                flags(s) = true;
            end
        end
        
        function metrics = GetMetrics(obj, from, to)
        % gets gaze (optionally between two specified timestamps) and
        % returns AOI metrics: 
        %   1) proportion looking time
        %   2) max gap length
        %
        % this method is primarily designed to conduct a historical query
        % on gaze data within the AOI, for the purposes of checking looking
        % time and gap length
        
            % check from/to validity
            obj.AssertFromToTimestamps(from, to)
        
            % get gaze
            [time, in, val] = obj.SelectGaze(from, to);
            
        % calculate gaps
        
            % check first to see whether there are any gaps - if not, then
            % we can short-circuit this for performance
            anyGaps = ~all(in);
            
            % process gaps
            if anyGaps
                % calculate gap lengths in samples, then convert to time
                ct = findcontig2(in, false);
                ctt = contig2time(ct, time);
                % number of gaps
                metrics.num_gaps = size(ctt, 1);
                % max length
                metrics.max_gap_length = max(ctt(:, 3));
                
            else 
                % no gaps
                metrics.max_gap_length = 0;
                metrics.num_gaps = 0;
                
            end
            
        % calculate looking time
        
            % prop looking
            metrics.prop_looking = sum(in) / sum(val);
            
        end
        
        function CalculateMetrics(obj)

%             if obj.prMetricsDirty
%                 
%                 % proportion in AOI
%                 propIn                  = obj.prTotalIn         / obj.prTotalValid;
%                 propIn_l                = obj.prTotalInLeft     / obj.prTotalValidLeft;
%                 propIn_r                = obj.prTotalInRight    / obj.prTotalValidRight;
%                 
%                 % proportion valid
%                 propVal                 = obj.prTotalValid      / obj.prTotalSamples;
%                 propVal_l               = obj.prTotalValidLeft  / obj.prTotalSamples;
%                 propVal_r               = obj.prTotalValidRight / obj.prTotalSamples;
%                 
%             % time in AOI
%             
%                 % we only look at data since we last calulcated metrics,
%                 % for speed. First find the sample indices of new data,
%                 % then pull the data
%                 s1 = obj.prMetricsIdx;
%                 s2 = obj.prIdx - 1;
%                 tic
%                 buf = obj.prBuffer(s1:s2, :);
%                 toc
%                 
% %                 buf                     = obj.prBuffer(1:obj.prIdx - 1, :);
%                 in                      = buf(:, 2);
%                 in_l                    = buf(:, 4);
%                 in_r                    = buf(:, 5);
%                 active                  = buf(:, 8);
%                 ts                      = buf(in & active, 1);
%                 ts_l                    = buf(in_l & active, 1);
%                 ts_r                    = buf(in_r & active, 1);
%                 time                    = sum(diff(ts));
%                 time_l                  = sum(diff(ts_l));
%                 time_r                  = sum(diff(ts_r));
%                 
%                 % store
%                 obj.prProp              = propIn;
%                 obj.prPropLeft          = propIn_l;
%                 obj.prPropRight         = propIn_r;
%                 obj.prPropValid         = propVal;
%                 obj.prPropValidLeft     = propVal_l;
%                 obj.prPropValidRight    = propVal_r;
%                 obj.prTime              = obj.prTime + time;
%                 obj.prTimeLeft          = obj.prTimeLeft + time_l;
%                 obj.prTimeRight         = obj.prTimeRight + time_r;
%                 
%             end
            % set flag to indicate metrics up to date
            obj.prMetricsDirty = false;

        end
        
        function Reset(obj)
        % resets the on/offsets to nan, essentially making the AOI like
        % new. Also cycles the .Active flag to create a new onset at the
        % current point in time
        
            obj.prBuffer            = nan(obj.CONST_DEF_BUFFER_SIZE,...
                                        length(obj.CONST_BUFFER_COL_HEADINGS));
            obj.prTotalSamples      = 0;
            obj.prTotalTime         = 0;
            obj.prProp              = 0;
            obj.prPropValid         = 0;
            % set Active
            obj.prOnsets            = nan(obj.CONST_DEF_ACTIVE_BUFFER_SIZE, 1);
            obj.prOffsets           = nan(obj.CONST_DEF_ACTIVE_BUFFER_SIZE, 1);
            obj.prActive            = true;
            obj.prOnsets(1)         = teGetSecs;
            obj.prOffsets(1)        = inf;
            obj.prActiveIdx         = 2;
            
        end
        
        % get/set
        function set.Rect(obj, val)
            % check input args
            if ~isnumeric(val) || ~isvector(val) || length(val) ~= 4
                error('Rect must be a four-element numeric vector.')
            end
            if any(val) < 0 || any(val) > 1
                error('Rect values must be between 0 and 1.')
            end
            % get coords
            x1 = val(1);
            y1 = val(2);
            x2 = val(3);
            y2 = val(4);
            % check coords
            if x2 < x1
                error('Impossible rect values - x2 was greater than x1.')
            elseif y2 < y1
                error('Impossible rect values - y2 was greater than y1.')
            end
            obj.Rect = val;
        end
        
        function val = get.Active(obj)
            val = obj.prActive;
        end
        
        function set.Active(obj, val)
            if ~islogical(val)
                error('Active must be logical (true/false).')
            end
            % has active state changes?
            changed = val ~= obj.prActive;
            if changed
                if val
                    % change from inactive to active - add new onset/offset
                    % and update active buffer idx
                    obj.prOnsets(obj.prActiveIdx) = teGetSecs;
                    obj.prOffsets(obj.prActiveIdx) = inf;
                    obj.prActiveIdx = obj.prActiveIdx + 1;
                elseif ~val
                    % change from active to inactive. If no gaze data is in
                    % the buffer, then we are setting the AOI to a starting
                    % state of inactive, otherwise we are setting a new
                    % onset/offset pair to indicate the AOI WAS active but
                    % now is not
                    if obj.prIdx == 1
                        % no gaze data, AOI was never active
                        obj.prOnsets(1) = nan;
                        obj.prOffsets(1) = nan;
                    else
                        % was active, now is not - new pair needed
                        obj.prOffsets(obj.prActiveIdx) = teGetSecs;                    
                        obj.prActiveIdx = obj.prActiveIdx + 1;
                    end
                end
                obj.prActive = val;
                % calculate active flags for entire buffer
                activeFlags = obj.CalculateActiveFlags(...
                    obj.prBuffer(1:obj.prIdx - 1, 8));
                % if any flags are returned (i.e. buffer is not empty),
                % store them in the buffer's active column
                if ~isempty(activeFlags)
                    obj.prBuffer(1:obj.prIdx - 1, 8) = activeFlags;
                end
                % need recalc on metrics
                obj.prMetricsDirty = true;                
            end
        end
        
        function set.TriggerTolerance(obj, val)
            if ~isnumeric(val) || ~isscalar(val) || val < 0
                error('TriggerTolerance must be a positive numeric scalar.')
            end
            obj.TriggerTolerance = val;
        end   
        
        % metrics
        function val = get.TotalSamples(obj)
            val = obj.prTotalSamples;
        end
        
        function val = get.TotalTime(obj)
            val = obj.prTotalTime;
        end
        
        function val = get.Prop(obj)
            val = obj.prProp;
        end
        
        function val = get.PropLeft(obj)
            val = obj.prPropLeft;
        end
        
        function val = get.PropRight(obj)
            val = obj.prPropRight;
        end
        
        function val = get.PropValid(obj)
            val = obj.prPropValid;
        end
        
        function val = get.PropValidLeft(obj)
            val = obj.prPropValidLeft;
        end
        
        function val = get.PropValidRight(obj)
            val = obj.prPropValidRight;
        end
        
        function val = get.SamplesIn(obj)
            val = obj.prTotalIn;
        end
        
        function val = get.SamplesInLeft(obj)
            val = obj.prTotalInLeft;
        end
        
        function val = get.SamplesInRight(obj)
            val = obj.prTotalInRight;
        end
        
        function val = get.TimeIn(obj)
            val = obj.prTime;
        end
        
        function val = get.TimeInLeft(obj)
            val = obj.prTimeLeft;
        end
        
        function val = get.TimeInRight(obj)
            val = obj.prTimeRight;
        end

        function val = get.Onset(obj)
            val = obj.prOnsets(obj.prActiveIdx - 1);
        end
        
        function val = get.Offset(obj)
            val = obj.prOffsets(obj.prActiveIdx - 1);
        end
        
%         function set.Onset(obj, val)
%             if  ~isnumeric(val) || ~isscalar(val) || val < 0
%                 error('Onset must be a positive numeric scalar.')
%             end
%             obj.Onset = val;
%         end
%         
%         function set.Offset(obj, val)
%             if  ~isnumeric(val) || ~isscalar(val) || val < 0
%                 error('Offset must be a positive numeric scalar.')
%             end
%             obj.Offset = val;
%         end        
        
        function val = get.InAOI(obj)
            if isempty(obj.prBuffer)
                val = [];
            else
                val = obj.prBuffer(1:obj.prIdx - 1, :);
            end
        end
        
        function val = get.Buffer(obj)
            val = array2table(obj.prBuffer(1:obj.prIdx - 1, :),...
                'variablenames', obj.CONST_BUFFER_COL_HEADINGS);
        end 
        
        function val = get.Hit(obj)
            val = obj.HasGaze;
        end
        
        function val = get.LatestTimestamp(obj)
        % returns the most recent timestamp in the buffer 
        
            % if no gaze data, return empty
            if obj.prIdx == 1
                val = [];
            else
                val = obj.prLatestTimestamp;
%                 val = obj.prBuffer(obj.prIdx - 1, 1);
            end
            
        end
        
        function val = get.EarliestTimestamp(obj)
        % returns the earliest timestamp in the buffer
        
            % if no gaze data, return empty
            if obj.prIdx == 1
                val = -inf;
            else
                val = obj.prEarliestTimestamp;
%                 val = obj.prBuffer(1, 1);
            end
            
        end
                
    end
    
    methods (Hidden)
        
        % utilities
        function AssertFromToTimestamps(obj, from, to)
        % check that from and to are valid data types, and do not exceed
        % the bounds of the buffer. If any of these conditions is not met,
        % then throw and error
        
            % check data types
            if ~isnumeric(from) || ~isnumeric(to)
                error('''from'' and ''to'' must be numeric.')
            end
            if ~isscalar(from) || ~isvector(from)
                error('''from'' must be a scalar timestamp, of vector of timestamps.')
            end
            if ~isscalar(from) || ~isvector(from)
                error('''from'' must be a scalar timestamp, or vector of timestamps.')
            end
            if ~isscalar(to) || ~isvector(to)
                error('''to'' must be a scalar timestamp, or vector of timestamps.')
            end
            
            % if from and to are vectors of timestamps, check that their
            % sizes match
            if ~isequal(size(from), size(to))
                error('''from'' and ''to'' must be of equal length.')
            end
            
            % check bounds of timestamps against buffer
            if any(from < obj.EarliestTimestamp) || any(to < obj.EarliestTimestamp)
                error('''from'' and ''to'' must be after the earliest timestamp (which is %.4f)',...
                    obj.EarliestTimestamp)
%             elseif any(from > obj.LatestTimestamp) || any(to > obj.LatestTimestamp)
%                 error('''from'' and ''to'' must be before the most recent timestamp (which is %.4f)',...
%                     obj.LatestTimestamp)
            end
            
            % check that 'from' comes before 'to'
            if from > to
                error('''from'' must come before ''to''.')
            end
            
        end
        
    end
    
end
            
            
            
