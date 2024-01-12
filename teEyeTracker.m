classdef teEyeTracker < handle
    
    properties
        AOIs teCollection
        % window limits
        prWindowLimitEnabled
        prMonitorSize
        prWindowSize        
        
    end
    
    properties 
        TrackerType 
        Valid = false
        Calibration
    end
    
    properties (SetAccess = protected)
        HasGaze = false
    end
    
    properties (Access = private)
        prBuffer 
    end
    
    properties (Access = protected)
%         prValid = false
        prConnected = false
        % calibration
        prCalibOnset = nan
        prCalibOffset = nan        
        prIsCalibrating = false
        prSampleRate
        prBufferIdx
        prBufferLastUpdate 
        prET2GS_scale
        prET2GS_offset
        prAOITable    
    end
    
    properties (SetAccess = protected)
        AOITable
        CalibrationPoints
        Calibrated = false
        Notepad = struct
    end
    
    properties (SetAccess = protected)
    end
    
    properties (Dependent)
        SampleRate
    end
    
    properties (Dependent, SetAccess = protected)
        Connected
        Calibrating 
        Buffer
        DriftSamples
        Data
    end
    
    properties (SetAccess = {?tePresenter})
%         PosixTimeOffset
    end
    
    properties (Access = private)
        % listeners
        lsAddAOI
        % drift measurement
        prDriftSamples
        prDriftIdx        
    end
    
    properties (Constant)
        CONST_DEF_BUFFER_SIZE = 1e6 / 2;    % approx 30mins @ 300Hz
        CONST_BUFFER_COL_HEADINGS = {...
            'Timestamp',...
            'LeftGazeX',...
            'LeftGazeY',...
            'LeftGazeValidity',...
            'LeftPupilDiameter',...
            'LeftPupilValidity',...
            'LeftGazeX_UCS',...
            'LeftGazeY_UCS',...
            'LeftGazeZ_UCS',...
            'LeftEyePosX_UCS',...
            'LeftEyePosY_UCS',...
            'LeftEyePosZ_UCS',...
            'LeftEyePosX_TCS',...
            'LeftEyePosY_TCS',...
            'LeftEyePosZ_TCS',...
            'LeftEyePosValidity',...
            'RightGazeX',...
            'RightGazeY',...
            'RightGazeValidity',...
            'RightPupilDiameter',...
            'RightPupilValidity',...
            'RightGazeX_UCS',...
            'RightGazeY_UCS',...
            'RightGazeZ_UCS',...
            'RightEyePosX_UCS',...
            'RightEyePosY_UCS',...
            'RightEyePosZ_UCS',...
            'RightEyePosX_TCS',...
            'RightEyePosY_TCS',...
            'RightEyePosZ_TCS',...
            'RightEyePosValidity',...
            'DeviceTime',...
            'SystemTime',...
            }
        CONST_DRIFT_COL_HEADINGS = {...
            'Timestamp',...
            'PointX',...
            'PointY',...
            'LeftGazeX',...
            'LeftGazeY',...
            'RightGazeX',...
            'RightGazeY',...
            'Moving',...
            };
    end
        
    events
        AddLog
    end
    
    methods
        
        % constructor
        function obj = teEyeTracker(varargin)
            if ~isempty(varargin) && ~isempty(varargin{1})
                obj.TrackerType = varargin{1};
            end
            % init buffer
            obj.prBuffer = nan(obj.CONST_DEF_BUFFER_SIZE,...
                length(obj.CONST_BUFFER_COL_HEADINGS));
            obj.prBufferIdx = 1;
            % init calibration points
            obj.CalibrationPoints = teCollection;
            % init drift samples
            obj.prDriftSamples = nan(obj.CONST_DEF_BUFFER_SIZE,...
                length(obj.CONST_DRIFT_COL_HEADINGS));
            obj.prDriftIdx = 1;
            % init AOIs
            obj.AOIs = teCollection('teAOI');
            % add AOI listener
            addlistener(obj.AOIs, 'ItemAdded',...
                @obj.AddAOI_Listener);
        end
        
        % destructor
        function delete(obj)
            obj.Disconnect
        end
        
        function Initialise(~)
        % initialise the eye tracker. This code is model-specific so will
        % be in a subclass. If this method is called then it means someone
        % is trying to use the superclass as an eye tracker. This is not
        % allowed so throw an error
            error('teEyeTracker is a superclass and can only be used as a template for subclasses. It does not acquire any data itself.')
        end
        
        function Disconnect(~)
        % initialise the eye tracker. This code is model-specific so will
        % be in a subclass 
        end
        
        function Update(obj)
            
            % TEEYETRACKER.UPDATE gets the latest gaze data from the eye
            % tracker. All available gaze samples since the last update
            % will be stored in the prBuffer property. The mechanics are
            % handled by the relevant subclass
            
            if ~obj.Valid
                error('Eye tracker not in a valid state.')
            end
            % get gaze data
            gaze = obj.UpdateGaze;
            % update AOIs
            obj.UpdateAOIs(gaze);
            
        end
        
        function gaze = UpdateGaze(obj)
        % all of the action here happens in tracker-specific subclasses
        
            if ~obj.Valid
                error('Eye tracker not in a valid state.')
            end        
            gaze = [];
            
        end
       
        function gaze = StoreNewGaze(obj, gaze)
            
            if obj.prWindowLimitEnabled
                gaze = teRereferenceGaze(gaze, obj.prMonitorSize,...
                    obj.prWindowSize);
            end            

            % count number of new samples and insert into the internal
            % class buffer
            numSamps = size(gaze, 1);
            s1 = obj.prBufferIdx;
            s2 = obj.prBufferIdx + numSamps - 1;
            if s2 > size(obj.prBuffer, 1)
                curSize = size(obj.prBuffer, 1) + s2 - 1;
                % calculate new size
                curSize = curSize + obj.CONST_DEF_BUFFER_SIZE;
                % increase
                obj.prBuffer(curSize, 1) = nan;
                % log
                eventLogData = teLogEventData(...
                    'source', 'presenter', 'topic', 'buffering', 'data',...
                    sprintf('Buffer EyeTracker increased to %d', curSize));
                notify(obj, 'AddLog', eventLogData)
            end
            obj.prBuffer(s1:s2, :) = gaze; 
            % update the buffer index pointer
            obj.prBufferIdx = s2 + 1;

%         % increment buffer (if needed)
%         
%             % get size of current buffer, and of pointer
%             curIdx = obj.prBufferIdx;
%             
%             % if pointer is out of bounds, then increase the size of the
%             % buffer. This is computationally expensive, so should be
%             % avoided whenever possible. This check is also done on a
%             % tePresenter.FlushBuffer, and if that method is called
%             % regularly, the code below should not be needed
%             changed = curIdx >= curSize;
%             if changed
%                 % calculate new size
%                 curSize = curSize + obj.CONST_DEF_BUFFER_SIZE;
%                 % increase
%                 obj.prBuffer(curSize, 1) = nan;
%                 % log
%                 eventLogData = teLogEventData(...
%                     'source', 'presenter', 'topic', 'buffering', 'data',...
%                     sprintf('Buffer EyeTracker increased to %d', curSize));
%                 notify(obj, 'AddLog', eventLogData)
%             end
            
            % set HasGaze flag to notify other parts of Task Engine that
            % new gaze is available
            obj.HasGaze = obj.prBufferIdx > 1; 
            
        end
        
        function UpdateAOIs(obj, gaze)
            if ~obj.Valid
                error('Eye tracker not in a valid state.')
            end            
            if ~isempty(obj.AOIs) && ~isempty(gaze)
                % loop to update
                numAOIs = obj.AOIs.Count;
                % init AOI table
                if numAOIs ~= size(obj.prAOITable, 1)
                    obj.prAOITable = nan(numAOIs, 6);
                end
                % loop through AOIs and update
                for a = 1:numAOIs
                    aoi = obj.AOIs.Items(a);
                    if aoi.Active
                        % send gaze to AOI for processing
                        aoi.ReceiveGaze(gaze);        
%                         % store in table for quick access by presenter
%                         obj.prAOITable(a, :) = [active, rect, prop];
                    end
                end
            end            
        end
        
        function FlushBuffer(obj)
        % increase the size of the eye tracker internal buffer so that
        % dynamic resizing of the array doesn't happen during the update
        % method
        
            newSize = obj.CONST_DEF_BUFFER_SIZE +...
                obj.prBufferIdx;
            obj.prBuffer(newSize, 1) = nan;
            % log
            eventData = teLogEventData(...
                'source', 'presenter', 'topic', 'buffering', 'data',...
                sprintf('Buffer EyeTracker increased to %d', newSize));   
            notify(obj, 'AddLog', eventData)
            
        end
        
        function ReceiveGazeFromResumedSession(obj, gaze)
        % this method is called when resuming a previous session. The gaze
        % data (essentially the entire teEyeTracker.Buffer) is passed and
        % stored in this session's (current) Buffer. It is only possible to
        % do this when the current Buffer is empty.
        
            % check that the size of gaze data is correct ([n x 33], n =
            % number of samples)
            if ~ismatrix(gaze) || size(gaze, 2) ~= 33
                error('gaze must be a [n x 33] matrix, with n = number of samples.')
            elseif isempty(gaze)
                warning('Attempted to resume with empty gaze data.')
            end
            
            % check that the current buffer is empty
            if obj.prBufferIdx ~= 1
                error('Can only receive previous session gaze data if current session gaze data is empty.')
            end
            
            % fill the first n samples in the buffer with the previous
            % gaze. First find the sample numbers
            s1 = 1;
            s2 = size(gaze, 1);
            obj.prBuffer(s1:s2, :) = gaze;
            
            % update the buffer cursor 
            obj.prBufferIdx = s2 + 1;
            
            teEcho('Eye tracker received %d samples of gaze data from a previous session.',...
                size(gaze, 1));
            
        end
        
        function BeginCalibration(~)  
        % tracker-specific - see subclasses
        end
        
        function EndCalibration(~)
        % tracker-specific - see subclasses
        end
        
        function CalibratePoint(~, ~, ~)
        % tracker-specific - see subclasses
        end
        
        function DeleteCalibPoint(obj, x, y)
            % form key from x, y coord
            key = obj.xy2key(x, y);
            obj.CalibrationPoints.RemoveItem(key);
        end
        
        function RecalibratePoint(~, x, y)
            DeleteCalibPoint(x, y)
            CalibratePoints(x, y)
        end
        
        function ClearCalibPoints(obj)
            obj.CalibrationPoints.Clear;
            obj.Calibration = struct;
            obj.Calibrated = false;
        end
        
        function [] = ComputeCalibration(~)
        % tracker-specific - see subclasses
        end
        
        function MeasureDrift(obj, x, y, moving)
            % check inputs
            if nargin < 3
                error('Must provide x and y coords.')
            elseif nargin == 3
                % default moving to false
                moving = false;
            end
            % store measurement
            gaze = obj.GetGazeLatest;
            if ~isempty(gaze)
                t       = gaze(:, 1);
                gx_l    = gaze(:, 2);
                gy_l    = gaze(:, 3);
                gx_r    = gaze(:, 17);
                gy_r    = gaze(:, 18);
                val     = [t, x, y, gx_l, gy_l, gx_r, gy_r, moving];
                obj.prDriftSamples(obj.prDriftIdx, :) = val;
                obj.prDriftIdx = obj.prDriftIdx + 1;
                % resize if necessary
                curSize = size(obj.prDriftSamples, 1);
                curIdx  = obj.prDriftIdx;
                changed = curIdx >= curSize;
                if changed
                    % calculate new size
                    curSize = curSize + obj.CONST_DEF_BUFFER_SIZE;
                    % increase
                    obj.prDriftSamples{curSize} = [];
                end
            end
        end
        
        function ChangeSampleRate(obj, val)
            obj.prSampleRate = val;
        end
        
        function UpdateWindowLimit(obj, enabled, monitorSize, windowSize)
            % receive updated window limit status (from the presenter)
            obj.prWindowLimitEnabled = enabled;
            obj.prMonitorSize = monitorSize;
            obj.prWindowSize = windowSize;
        end
        
        function val = GetGaze(obj, from, to, varargin)
            % check on/offsets
            if nargin == 1
                from = -inf;
            end
            if nargin <= 2
                to = inf;
            end
            % check that on/offsets in bounds with each other
            if from > to
                error('from time (%.3f) is before to time (%.3f).',...
                    from, to)
            end
            % can return the full buffer, or just the xy (averaged) eye
            % coords. Full is the default, but 'xy' can be specified as an
            % input argument
            if ismember(varargin, 'xy')
                cols = [2, 3, 17, 18];
                outputFormat = 2;
            else
                cols = 1:33;
                outputFormat = 1;
            end
            % can treat timestamps as time in secs (default), ET system
            % time ('system'), ET device time ('device') or 'samples'
            if ismember(varargin, 'system')
                timeFormat = 2;
                time = obj.prBuffer(1:obj.prBufferIdx, 33);
            elseif ismember(varargin, 'device')
                timeFormat = 3;
                time = obj.prBuffer(1:obj.prBufferIdx, 32);
            elseif ismember(varargin, 'samples')
                timeFormat = 4;
                s1 = from;
                if s1 < 1, s1 = 1; end
                if s1 > obj.prBufferIdx - 1, s1 = obj.prBufferIdx - 1; end
                s2 = to;
                if s2 < 1, s2 = 1; end
                if s2 > obj.prBufferIdx - 1, s2 = obj.prBufferIdx - 1; end
            else
                % use te2 timestamps
                timeFormat = 1;
                time = obj.prBuffer(1:obj.prBufferIdx -1, 1);
            end
            % if in a time (not samples) format, lookup the sample indices
            if timeFormat ~= 4
                % check that some data is available
                if all(isnan(time))
                    val = [];
                    return
                end
                % clamp s1 and s2 to buffer end
                if from > time(end), from = time(end); end
                if to   > time(end), to   = time(end); end
                % look up samples
                s1 = find(time >= from, 1, 'first');
                s2 = find(time >= to, 1, 'first');
                % check data
                if isempty(s1)
                    error('from value is greater than buffer end.')
                elseif isempty(s2)
                    error('to value is greater than buffer end.')
                end
            end
            % get data
            val = obj.prBuffer(s1:s2, cols);
            % convert to xyz if required
            if outputFormat == 2
                x = mean(val(:, [1, 3]), 2);
                y = mean(val(:, [2, 4]), 2);
                val = [x, y];
            end  
        end
        
        function val = GetGazeLatest(obj, varargin)
            latest = obj.prBufferIdx - 1;
            % if empty, return 
            if latest == 0, val = []; return, end
            val = obj.GetGaze(latest, latest, 'samples', varargin{:});
        end
        
        function val = GetQCMetrics(obj, from, to)
        % calculates time/proportion looking to the screen between two
        % timestamps. Useful for summarising data quality across, e.g., one
        % trial
        
            % if eye tracker is not valid, or buffer is empty, return empty
            if ~obj.Valid || obj.prBufferIdx == 1
                val = [];
            end
        
            % if from/to not specified, then set to -inf/inf, will be
            % clamped to first/last available sample in the next stage
            if ~exist('from', 'var') || isempty(from)
                from = -inf;
            end
            if ~exist('to', 'var') || isempty(to)
                to = inf;
            end
        
            % check from/to values. From cannot be after to, but any other
            % values will be silently clamped to the first/last sample of
            % the eye tracker buffer
            if from > to
                error('''from'' must be before ''to''.')
            end
            firstTime = obj.prBuffer(1, 1);
            s1 = obj.prBufferIdx - 1;
            if s1 < 1, s1 = 1; end
            lastTime = obj.prBuffer(s1, 1);
            if from < firstTime, from = firstTime; end
            if from > lastTime, from = lastTime; end
            if to < firstTime, to = firstTime; end
            if to > lastTime, to = lastTime; end
            buf = obj.GetGaze(from, to);
            
        % calculate a vector of a) valid gaze samples, and b) looking
        % at the screen
        
            % gaze validity
            if isempty(buf)
                val = [];
                return
            end
            valid = buf(:, 4) | buf(:, 19);
            
            % left/right x, y
            lx = buf(:, 2);
            ly = buf(:, 3);
            rx = buf(:, 17);
            ry = buf(:, 18);
            
            % left/right on-screen looking
            osL = lx >= 0 & lx <= 1 & ly >= 0 & ly <= 1;
            osR = rx >= 0 & rx <= 1 & ry >= 0 & ry <= 1;
            os = osL | osR;
            
            % looking (valid gaze and onscreen)
            looking = valid & os;
            
            % calculate prop
            val.looking_prop = prop(looking);
            
            % calculate inter-sample delta
            isd = diff(buf(:, 1));
            
            % calculate looking time
            val.looking_time = sum(isd(looking(2:end)));
            
        end
        
        function gs = TrackerTime2System(obj, et)
            et = double(et);
            gs = (et / obj.prET2GS_scale) - obj.prET2GS_offset;
        end
        
        function et = SystemTime2Tracker(obj, gs)
            et = (gs + obj.prET2GS_offset) * obj.prET2GS_scale;
            et = int64(et);
        end
%                
        function Save(obj, path_save, speedMode)
            if nargin < 3
                speedMode = 'normal';
            end
            % can only save a valid tracker
            if obj.Valid 
                if strcmpi(speedMode, 'fast')
                    eyetracker = getByteStreamFromArray(obj.Data);
                    save(path_save, 'eyetracker', '-v6');
                else
                    eyetracker = obj.Data;
                    save(path_save, 'eyetracker', '-v7')
                end
            else
                warning('EyeTracker not valid - save failed.')
            end
        end        
        
        % set / get
%         function val = get.Valid(obj)
%             val = obj.Valid;
%         end
        
%         function set.TrackerType(obj, val)
%             obj.TrackerType = obj;
%             obj.Initialise
%         end
        
        function val = get.SampleRate(obj)
        % this will mostly happen in a tracker-specific subclass, but there
        % is a private property that can store a number, so we use that in
        % this class. This will be a good default for tracker types that
        % simply give the samplerate at connection and then leave it alone
        % (e.g. mouse)
            val = obj.prSampleRate;
        end
        
        function set.SampleRate(obj, val)
            % call the ChangeSampleRate method to implement a change. This
            % allows each subclass to overwrite this method with
            % tracker-speciifc code
            obj.ChangeSampleRate(val);
        end

        function val = get.Buffer(obj)
            if isempty(obj.prBuffer)
                val = [];
                return
            else
                val = obj.prBuffer(1:obj.prBufferIdx - 1, :);
            end
        end
        
        function set.Buffer(obj, val)
            % this setter method effectively catches gaze updates from
            % subclasses. If window limits are enabled, we transform the
            % ref frame of incoming gaze before it goes into the buffer
            if obj.prWindowLimitEnabled
%                 val = teRereferenceGaze(val, obj.prMonitorSize,...
%                     obj.prWindowSize);
            end
            obj.prBuffer = val;
        end
        
%         function set.prBuffer(obj, val)
%             obj.prBuffer = val;
%         end
        
        function val = get.Calibrating(obj)
            val = obj.prIsCalibrating;
        end
        
        function val = get.AOITable(obj)
            numAOIs = obj.AOIs.Count;
            val = nan(numAOIs, 6);
            for a = 1:obj.AOIs.Count
                aoi = obj.AOIs.Items(a);
                aoi.CalculateMetrics
                val(a, :) = [aoi.Active, aoi.Rect, aoi.Prop];
            end
        end
        
        function val = get.DriftSamples(obj)
            if obj.prDriftIdx == 1
                val = [];
            else
                buf = obj.prDriftSamples(1:obj.prDriftIdx - 1, :);
                val = array2table(buf, 'variablenames',...
                    obj.CONST_DRIFT_COL_HEADINGS);  
            end
        end
        
        function val = get.Data(obj)
        % the Data property contains those variables which will be saved.
        
            val.Calibration     = obj.Calibration;
            val.Buffer          = obj.Buffer;
            val.Notepad         = obj.Notepad;
            val.SampleRate      = obj.SampleRate;
            val.AOIs            = obj.AOIs;
            val.TrackerType     = obj.TrackerType;
            
%             % convert the entire teEyeTracker object to a struct and save
%             % this. First disable the Matlab warning that this generates,
%             % then renable it
%             warning off MATLAB:structOnObject
%             val.Object          = struct(obj);
%             warning on MATLAB:structOnObject
            
        end
%         
%         function set.prWindowLimitEnabled(obj, val)
%             switch val
%                 case true
%                     msg = 'ENABLED';
%                 otherwise
%                     msg = 'DISABLED';
%             end
%             fprintf('Window limits %s\n', msg)
%             obj.prWindowLimitEnabled = val;
%         end
                        
    end
    
    methods (Hidden, Access = protected)
        
        function key = xy2key(~, x, y)
            key = sprintf('%.4f_%.4f', x, y);
        end
        
        function AddAOI_Listener(obj, ~, event)
            % when an AOI is added, send it all gaze in the eye tracker
            % buffer. At this point by default we also reset the onset of
            % the AOI, so that it only starts counting gaze from when it
            % was added to the eye tracker's collection. If the AOI's
            % ResetOnsetWhenAddedToEyeTracker is set then don't do this (in
            % case one actually wants the AOI to start counting gaze from
            % some point in the past). 
            obj.UpdateGaze;
            aoi = obj.AOIs(event.Data);
            if aoi.ResetOnsetWhenAddedToEyeTracker
                aoi.Reset;  
            end
            gaze = obj.GetGaze;
            aoi.ReceiveGaze(gaze);
        end
        
    end
    
    methods (Hidden)
        
        function AddAoI(obj, rect, name, triggerThreshold)
            if nargin == 3
                triggerThreshold = 0;
            end
            obj.AOIs(name) = teAOI(rect, triggerThreshold);
        end
        
        function val = LookupAoI(obj, name)
            val = obj.AOIs(name);
        end
        
        function ClearAoIs(obj)
            % legacy ECK
            obj.AOIs.Clear
        end
        
        function [lTime, rTime] = SendEvent(obj, event)
           lTime = teGetSecs;
            rTime = obj.SystemTime2Tracker(lTime);
            eventData = teLogEventData('source', 'eyetracker',...
                'topic', 'event_marker', 'data', event);
            notify(obj, 'AddLog', eventData)
        end
        
        function [gaze, time] = GetDataChunk(obj, from, to, ~)
            % get gaze in te2 format
            te2 = obj.GetGaze(from, to);
            [gaze, time] =...
                teConvertGaze(te2, [], 'taskengine2', 'tobiiAnalytics');
        end
        
        function [valid, reason, prop] = HistoricAoI(obj, aoiName, from,...
                to, crit_prop, crit_contig)
            % todo - needs arg checks
            % update to ensure most recent data
            obj.Update
            % look up aoi
            aoi = obj.AOIs(aoiName);
            % convert uS to ms
            from = obj.TrackerTime2System(from);
            to = obj.TrackerTime2System(to);            
            % if AOI is empty, or from precedes first sample, fill it with
            % data from the eye tracker buffer
            if aoi.prIdx == 1 || from < aoi.prBuffer(1, 1)
                gaze = obj.GetGaze(from, to);
                aoi.ReceiveGaze(gaze);
            end
            % select AOI data by from and to
            [time, in, val] = aoi.SelectGaze(from, to);            
            % check prop val
            prop = sum(in) / sum(val);
            if prop < crit_prop
                valid = false;
                reason = sprintf('PROP VALID < %i', crit_prop);
                return
            end
            % zero time
            t = time - time(1);
            % check max data loss
            ct = findcontig2(~val);
            if ~isempty(ct)
                % convert from samples to time
                ctt = contig2time(ct, t);
                % some data loss, find contiguous runs and measure length
                % of each
                durs = ctt(:, 3);
                if any(durs) >= crit_contig
                    valid = false;
                    reason = sprintf('DATA LOSS > %i ms', crit_contig);
                    return
                end
            end
            % otherwise, set output args to valid
            valid = true;
            reason = 'valid';
        end
            
        function [didExit, when] = ExitAoI(obj, aoiName, from, to, tolerance)
            % update to ensure most recent data
            obj.Update            
            % convert uS to ms
            from = obj.TrackerTime2System(from);
            to = obj.TrackerTime2System(to);
            % select AOI data by from and to
            aoi = obj.AOIs(aoiName);
            % pass to AOI method
            [~, ~, didExit, when] = aoi.EntryExit(from, to, tolerance / 1e3);
        end
        
        function [dataReport] = DataReport(obj, from, to, aoi)
            % update to ensure most recent data
            obj.Update            
            % check start/endTime validity
            if from > to
                error('''from'' must be before ''to''.')
            end
            % convert uS to ms
            from = obj.TrackerTime2System(from);
            to = obj.TrackerTime2System(to);            
            % is no aoi passed, make an AOI that encompasses the entire
            % screen
            if ~exist('aoi','var') || isempty(aoi)
                aoi = teAOI([0, 0, 1, 1]);
            end
            % fill AOI with gaze
            gaze                        =   obj.GetGaze(from, to);
            aoi.ReceiveGaze(gaze);
            [~, ~, ~, buf]              =   aoi.SelectGaze(from, to);
            % BASIC METADATA
            dataReport.NumSamples       =   size(buf, 1);
            dataReport.StartTime        =   from;
            dataReport.EndTime          =   to;
            dataReport.Rect             =   aoi.Rect;
            dataReport.Duration         =   (to - from) * 1e6;
            % DATA LOSS  
            % samples
            dataReport.LostSamplesLeft  =   sum(1 - buf(:, 6));
            dataReport.LostSamplesRight =   sum(1 - buf(:, 7));
            dataReport.LostSamplesAvg   =   sum(1 - buf(:, 3));
            % proportions
            dataReport.LostPropLeft     =   dataReport.LostSamplesLeft / dataReport.NumSamples;
            dataReport.LostPropRight    =   dataReport.LostSamplesRight / dataReport.NumSamples;
            dataReport.LostPropAvg      =   dataReport.LostSamplesAvg / dataReport.NumSamples;
            % time (in microsecs)
            time_delta                  =   [nan; diff(buf(:, 1))];
            dataReport.LostTimeLeft  	=   nansum(time_delta(logical(1 - buf(:, 6)))) * 1e6;
            dataReport.LostTimeRight    =   nansum(time_delta(logical(1 - buf(:, 7)))) * 1e6;
            dataReport.LostTimesAvg     =   nansum(time_delta(logical(1 - buf(:, 3)))) * 1e6;
            % GAZE ON AOI
            % samples
            dataReport.OnAOISamples     =   sum(buf(:, 2));
            % proportion
            dataReport.OnAOIProp        =   sum(buf(:, 2)) / dataReport.NumSamples;
            % time
            dataReport.OnAOITime        =   nansum(time_delta(logical(1 - buf(:, 2)))) * 1e6;                      
        end      
        
        function Refresh(obj)
            obj.Update
        end
        
    end
    
end