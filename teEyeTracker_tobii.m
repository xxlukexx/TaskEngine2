classdef teEyeTracker_tobii < teEyeTracker
    
%     properties (Dependent)
%         SampleRate
%     end
    
    properties (SetAccess = private)
        prTobii
        prOperations
        prCalib
    end
    
    methods
        
        % constructor
        function obj = teEyeTracker_tobii
            % call superclass constructor for general et init, and set the
            % tracker type to Tobii
            obj = obj@teEyeTracker('tobii');            
            obj.Initialise
            
        end
        
        % destructor
%         function delete(obj)
%             delete('obj.prTobii')
%             delete('obj.prOperations')
%         end
        
        function Initialise(obj)
        % connect to any tobii eye tracker using the tobii pro SDK. Will
        % repeatedly try to connect, up to a maximum number of tries
        % (default 50). 
        
        % general init - check for tobii pro SDK, and create a tobii eye
        % tracker operations class 
        
            teEcho('Initialising eye tracker...\n');
            
            % check for SDK
            if ~exist('EyeTrackingOperations', 'class')
                error('Tobii Pro SDK not found.')
            end
            
            % create eye tracker operations instance from Tobii SDK
            obj.prOperations = EyeTrackingOperations; 
            
            % log SDK version
            version = obj.prOperations.get_sdk_version();
            eventLogData = teLogEventData(...
                'source', 'teEyeTracker_tobii', 'topic', 'sdk_version',...
                'data', version);
            notify(obj, 'AddLog', eventLogData)
                
        % search for eye tracker. In theory this can return more than
        % one tracker, if multiple exist on the same network. This is
        % not current handled other than by throwing an error.
        
            % set default number of tries, and wait between tries
            numTries = 50; 
            tryWait = 5;
            curTry = 1;
            
            % start searching. Keep trying until max retries is reached
            while curTry < numTries && isempty(obj.prTobii) 
                
                % search for trackers and return results. Here we rely upon
                % the Tobii SDK so wrap it all up in a try/catch statement
                % so that we can semi-gracefully handle any errors the SDK
                % may throw
                try
                    obj.prTobii = obj.prOperations.find_all_eyetrackers;
                catch ERR
                    switch ERR.message
                        case {'Dot indexing is not supported for variables of this type.',...
                                'Index in position 1 is invalid. Array indices must be positive integers or logical values.'}
                            warning('The Tobii SDK threw an error. This is a known bug in v1.5 of the SDK that Tobii claim will fix in future. Retrying...')
                        otherwise
                            error('The Tobii SDK threw an error:\n\n%s',...
                                ERR.message)
                    end
                end         

                % validate search results. If no eye tracker found,
                % increment the counter and keep trying until max number of
                % tries
                if isempty(obj.prTobii)
                    teEcho('\tSearching for eye tracker, try %d of %d...\n',...
                        curTry, numTries);
                    % wait for x seconds between retries
                    WaitSecs(tryWait);
                end
                curTry = curTry + 1;
                
            end
            
            % if no eye trackers found after x number of retries, or if
            % multiple trackers returned, throw an error
            if isempty(obj.prTobii) 
                error('No eye trackers found.')
            elseif length(obj.prTobii) > 1
                error('Multiple eye trackers found - not supported.')
            end
            
        % it is necessary to compensate for any overhead when communicating
        % with the tobii pro SDK. tobii_MeasureClockOffset measures offsets
        % and produces an offset for converting times from PTB teGetSecs time
        % and the internal clock of the eye tracker. In principle any lag
        % should be dealt with by the time correction algorithm that Tobii
        % use, but that does not take SDK overhead into account
        
            obj.tobii_MeasureClockOffset
            
        % message success, set flags, send updates to other parts of Task
        % Engine
        
            % set valid flag
            obj.Valid = true;
            
            % include eye tracker model, serial number, and sample rate
            msg = sprintf('Connected to Tobii %s eye tracker (%s) at %dHz\n',...
                obj.prTobii.Model, obj.prTobii.SerialNumber,...
                obj.prTobii.get_gaze_output_frequency);
            
            % echo to command window and send log
            teEcho(msg);
            logData = teLogEventData('source',...
                'eyetracker', 'topic', 'init', 'data', msg);
            notify(obj, 'AddLog', logData)
            
            % todo - set sample rate
            
            % intialise the tobii calibration class
            obj.prCalib = ScreenBasedCalibration(obj.prTobii);
            
            % get sample rate from SDK and store in class
            try
                obj.prSampleRate = obj.prTobii.get_gaze_output_frequency;
            catch ERR
                error('Tobii Pro SDK threw an error:\n\%s',...
                    ERR.message)
            end
            
        end
        
        function gaze = UpdateGaze(obj)
        % get the latest gaze from the eye tracker. This will be all
        % samples since the last update - so could be nothing, or could be
        % a very large amount of data. Time is converted to a PTB teGetSecs
        % timeframe, and gaze data is converted to the generic Task Engine
        % 2 format. Buffers are increased accordingl. 
        
            if ~obj.Valid
                error('Eye tracker not in a valid state.')
            end            

            % get data from SDK
            gaze = obj.prTobii.get_gaze_data('flat');
            % record last buffer update
            obj.prBufferLastUpdate = teGetSecs;
            
            % if no gaze was available, return an empty variable and give
            % up
            if isempty(gaze), return, end
            
            % convert tracker time to teGetSecs
            time = obj.TrackerTime2System(gaze.system_time_stamp);
            
%             % convert teGetSecs time to posix
%             time = time + obj.PosixTimeOffset;
            
            % convert gaze to te2 format
            gaze = teConvertGaze(gaze, time, 'tobiipro',...
                'taskengine2', true);
            obj.StoreNewGaze(gaze);
            
        end
        
        function ClearCalibPoints(obj)
            % there is not tobii API call to delete all calib points, nor
            % one to get a list of current calib points (which would allow
            % us to delete them one at a time). So wrap the command to
            % delete points in try/catch and hope for the best
            try
                obj.prCalib.discard_data
            catch ERR
                warning('Error trying to delete existing calibration: %s',...
                    ERR.message)
            end
            ClearCalibPoints@teEyeTracker(obj);
        end
               
        function BeginCalibration(obj)
        % put the tracker into calibration mode. 
        
            % if already calibrating, throw a warning and return
            if obj.Calibrating
                warning('Already calibrating.')
                return
            end
            
            % clear current calibration 
            obj.ClearCalibPoints

            % attempt to enter calibration mode. Here we are in the hands
            % of the SDK and weird shit can sometimes happen, so handle
            % errors by throwing a higher-level error and reporting the
            % error from the SDK. 
            % to-do: handle errors from the SDK as they are found - none so
            % far 20180827
            try
                obj.prCalib.enter_calibration_mode
%                 teEcho('Tobii entered calibration mode.\n');
            catch ERR
                % first handle known errors. If the error is not known,
                % throw a generic error reporting that the problem came
                % from the SDK, so that it can be troubleshooted in future
                switch ERR.message
                    case 'EnterCalibrationMode (error-204): The connection to the eye tracker failed.'
                        error('The Tobii SDK reported that it lost connection to the eye tracker. Please power cycle the eye tracker and try again.')
                    otherwise
                    error('Tobii Pro SDK threw an error:\n\n%s',...
                        ERR.message)
                end
            end
            
            % set flag 
            obj.prIsCalibrating = true;
            % note onset of calibration
            obj.prCalibOnset = teGetSecs;
            
        end
        
        function EndCalibration(obj)
        % take the eye tracker out of calibration mode
        
            % if not calibrating, throw a warning and return
            if ~obj.Calibrating
                warning('Not currently calibrating.')
                return
            end      
            
            try
                obj.prCalib.leave_calibration_mode
%                 teEcho('Tobii exited calibration mode.\n');    
            catch ERR
                error('Tobii Pro SDK threw an error:\n\n%s',...
                    ERR.message)
            end
            
            % unset flag
            obj.prIsCalibrating = false;

            % record calibration offset time
            obj.prCalibOffset = teGetSecs;
            
        end
        
        function pt = CalibratePoint(obj, x, y)
        % begin to calibrate a point. If this point has already been
        % calibrated, delete its calibration in the CalibrationPoints
        % collection, as this will be overwritten by the results we obtain
        % here
        
            % use the [x, y] coords to make a key in the form of 'x_y'.
            % This is used to refer to calib points in the
            % CalibrationPoints collection. 
            key = obj.xy2key(x, y);
            
            % if the calib point exists, delete it, since we are going to
            % overwrite it with the new measurement
            if ~isempty(obj.CalibrationPoints(key))
                obj.DeleteCalibPoint(x, y);
            end        
            
            % store the [x, y] coords in the calib point structure
            pt.x = x;
            pt.y = y;
            
            % catch tobii errors
            try
                % discard data from this calib point in the eye tracker's calib
                % buffer
                obj.prCalib.discard_data([x, y]);
                % collection data at calibration point
                pt.result = obj.prCalib.collect_data([x, y]);
%                 teEcho('Tobii calibrated a point at [%.1f, %.1f].\n', x, y);
                
            catch ERR
                error('Tobii Pro SDK threw an error:\n\n%s',...
                    ERR.message)
                
            end

            % store the result in the CalibrationPoints collection
            obj.CalibrationPoints(key) = pt;
            
        end
        
        function [success, tab, calib] = ComputeCalibration(obj)
        % process the results of a calibration. First step is to use the
        % SDK to compute a tobii calibration within the eye tracker itself.
        % After that, take the data that it returns and produce various
        % summary statistics. The purpose of these is twofold: 1) to
        % provide metrics that the calibration routine in tePresenter can
        % use to decided whether to continue calibrating; and, 2) to store
        % these as a measure of data quality with the datafile. 
            
            tab = [];
        
            if isempty(obj.CalibrationPoints)       
                error('No calibration points have been added.')
            end
            
            % get SDK to compute calibration
            try
                calib = obj.prCalib.compute_and_apply;
            catch ERR
                error('Tobii Pro SDK threw an error:\n\n%s',...
                    ERR.message)
            end
            
            % calculate the number of calib points that were valid, and
            % check the outcome flag from the SDK. If at least one point
            % was calibrated successfully, then  we call this success. This
            % may seem generous, but we want the class to function even in
            % the very worst possible calibrations - it is the user who
            % decides how bad is bad. 
            numPoints = length(calib.CalibrationPoints);
            success = isequal(calib.Status.Success, 1) && numPoints > 0;
%             success = strcmpi(calib.Status, 'Success') &&...
%                 numPoints ~= 0;
                    
            % if the class hasn't been calibrated before, note the success
            % or otherwise
            if ~obj.Calibrated, obj.Calibrated = success; end
            
            % if not successful, there's no computation to be done, so
            % return
            if ~success, return, end
            
            % start with a blank table to hold results, and a matrix of
            % calibration positions
            tab = table;
            pos = zeros(numPoints, 2);
            
            % loop through each point and compute stats. This is mostly a
            % case of reformatting the data that we get from the SDK
            for p = 1:numPoints
                
                % get the calib point from the collection
                pt = calib.CalibrationPoints(p);
                % get number of gaze samples
                if length(pt.LeftEye) ~= length(pt.RightEye)
                    error('Left and Right eye gaze sample counts do not match!')
                end
                numGazeSamples = length(pt.LeftEye);
                
                % get the [x, y] coords of this calib point. Replicate
                % these values for each sample of measured data
                pos(p, :) = calib.CalibrationPoints(p)...
                    .PositionOnDisplayArea;
                x = repmat(pos(p, 1), numGazeSamples, 1);
                y = repmat(pos(p, 2), numGazeSamples, 1);
                
                % get point of gaze for each sample of measured data. Do
                % this separately for each eye, and vertcat the results
                % (because the data is returned in cell arrays)
                gpos_l = arrayfun(@(x)...
                    x.PositionOnDisplayArea, pt.LeftEye',...
                    'uniform', false);
                gpos_l = vertcat(gpos_l{:});
                gpos_r = arrayfun(@(x)...
                    x.PositionOnDisplayArea, pt.RightEye',...
                    'uniform', false);
                gpos_r = vertcat(gpos_r{:});                   
                
                % split the gaze position in to [x, y] for each eye
                gx_l = gpos_l(:, 1);
                gy_l = gpos_l(:, 2);
                gx_r = gpos_r(:, 1);
                gy_r = gpos_r(:, 2);
                
                % get gaze validity, on a per-sample basis, for each eye
                gval_l = arrayfun(@(x) x.Validity == 1,...
                    pt.LeftEye);
                gval_r = arrayfun(@(x) x.Validity == 1,...
                    pt.RightEye);   
                
                % for both x and y axes, calulate the offset between each
                % sample and the calib point that it was elicited by
                xoffset_l = x - gx_l;
                yoffset_l = y - gy_l;
                xoffset_r = x - gx_r;
                yoffset_r = y - gy_r;
                
                % convert this to a euclidean distance (again, separately
                % for each eye). This is a measure of accuracy for each eye
                offset_l = sqrt(((x - gx_l) .^ 2) +...
                    ((y - gy_l) .^ 2));
                offset_r = sqrt(((x - gx_r) .^ 2) +...
                    ((y - gy_r) .^ 2));
                
                % put all fo the data into a table. Here we are
                % representing each sample of measured data with one row. 
                tab = [tab; array2table([...
                        x,...
                        y,...
                        gx_l,...
                        gy_l,...
                        gx_r,...
                        gy_r,...
                        gval_l,...
                        gval_r,...
                        xoffset_l,...
                        yoffset_l,...
                        xoffset_r,...
                        yoffset_r,...
                        offset_l,...
                        offset_r...
                    ],...
                    'variablenames', {...
                        'PointX',...
                        'PointY',...
                        'LeftX',...
                        'LeftY',...
                        'RightX',...
                        'RightY',...
                        'LeftValidity',...
                        'RightValidity',...
                        'LeftOffsetX',...
                        'LeftOffsetY',...
                        'RightOffsetX',...
                        'RightOffsetY',...
                        'LeftOffset',...
                        'RightOffset'...
                    })]; 
            end
            
            % store the calibration table, and the positions of all calib
            % points, in class properties
            obj.Calibration.Table = tab;
            obj.Calibration.Points = pos;

        end
        
        function Disconnect(obj)
        % the Tobii Pro SDK doesn't really have a "connected/disconnected"
        % metaphor, but we can at least stop the acquisition of gaze data
        
            if ~obj.Valid, return, end

            try
                obj.prTobii.stop_external_signal_data
                obj.prTobii.stop_eye_image
                obj.prTobii.stop_gaze_data
                obj.prTobii.stop_hmd_gaze_data
                obj.prTobii.stop_time_sync_data
            catch ERR
                error('Tobii Pro SDK threw an error:\n\n%s',...
                    ERR.message)
            end
            
            % unset valid flag
            obj.Valid = false;
            
        end      
        
        function ChangeSampleRate(obj, val)
        % tobii eye trackers only support certain sample rates (if changing
        % is even allowed - e.g. x2-60). So first get a list of possible
        % sample rates, and check that the requested rate is one of them.
            
            % get possible sampling rates
            rates = obj.prTobii.get_all_gaze_output_frequencies;
            if ismember(val, rates)
                try
                    obj.prTobii.set_gaze_frequency(val);
                    obj.prSampleRate = val;
                catch ERR
                    rethrow ERR
                end
            else
                error('Invalid sampling rate for this tracker.')
            end
            
        end
        
        function UpdateWindowLimit(obj, varargin)
            
            % call superclass method first to handle inputs
            UpdateWindowLimit@teEyeTracker(obj, varargin{:})
            
            % set Tobii display area with new drawing pane size
            
                offset_y = 10;          % ET is 10mm below screen 
                offset_z = 10;          % ET is 10mm in front of screen
                
                sz_monitor = obj.prMonitorSize;
                if obj.prWindowLimitEnabled
                    % if window limits are enabled, we will work to the
                    % internal virtual window
                    sz_drawing = obj.prWindowSize;
                else
                    % if window limits not enabled, we set the drawing size
                    % to the monitor size (we are using the full screen)
                    sz_drawing = sz_monitor;
                end
                [mw, mh] = teWidthHeightFromRect([0, 0, sz_monitor]);
                [dw, dh] = teWidthHeightFromRect([0, 0, sz_drawing]);
                
                % construct a rect to represent the monitor, sitting at
                % offset_y mm above the eye tracker, and offset_z mm in
                % front of the eye tracker. Note that the eye tracker is
                % located at [0, 0, 0] ([x, y, x])
                x1 = -(mw / 2) * 10;
                x2 = (mw / 2) * 10;
                y1 = offset_y;
                y2 = offset_y + (mh * 10);
                rect_monitor = [x1, y1, x2, y2];
                
                % using the monitor rect, construct a rect representing the
                % drawing pane, centred inside the monitor
                rect_drawing = [0, 0, sz_drawing * 10];
                rect_drawing = teCentreRect(rect_drawing, rect_monitor);
                
%                 % construct a Tobii SDK DisplayArea struct
%                 s_display = struct;
%                 s_display.bottom_left = rect_drawing(
%                 s_display.top_left
%                 s_display.top_right
%                 da = DisplayArea(s_display)
            
        end
        
        function PlotDisplayArea(obj)
            
            da = obj.prTobii.get_display_area;
            figure
            
            % get x, y, z coords of each of the four corners of the da
            [x, y, z] = obj.tobii_DisplayArea2xyz(da);
            
            % make eye tracker x, y, z
            etx = [-92, 92, 92, -92];
            ety = [-30, -30, 0, 0];
            etz = [0, 0, 0, 0];
            
            clf
            h_monitor = fill3(x, y, z, 'b');
            hold on
            h_tracker = fill3(etx, ety, etz, 'k');
            view(3)
            view(165, 75)
            set(gca, 'ydir', 'reverse')
            xlabel('x')
            ylabel('y')
            zlabel('z')
            zlim([-60, 60])
            
            legend('screen', 'eye tracker')
            
        end
        
        function [w, h] = DisplayAreaSize(obj)
            
            da = obj.prTobii.get_display_area;
            [x, y, ~] = obj.tobii_DisplayArea2xyz(da);
            w = (x(2) - x(1)) / 10;
            h = (y(3) - y(1)) / 10;
            
        end
         
        % utilities
        
        function tobii_MeasureClockOffset(obj)
            teEcho('Measuring clock offsets...');
            
        % measure offset
            
            % number of samples to take
            numSamps = 1e5;
            % store the results twice, one in each order (tracker first,
            % then teGetSecs first)
            et = int64(nan(numSamps * 2, 1));
            gs = nan(numSamps * 2, 1);
            % tracker first
            for s = 1:numSamps
                et(s) = obj.prOperations.get_system_time_stamp;
                gs(s) = teGetSecs;
            end
            % teGetSecs first
            for s = numSamps + 1:numSamps * 2
                gs(s) = teGetSecs;
                et(s) = obj.prOperations.get_system_time_stamp;
            end
            
        % calculate latency in ms
            
            % convert to ms
            et_ms = double(et) / 1000;
            gs_ms = gs * 1000;
            % zero
            et_ms = et_ms - et_ms(1);
            gs_ms = gs_ms - gs_ms(1);
            % calculate delay 
            obj.Notepad.time_units = 'ms';
            obj.Notepad.tobii_clock_offset_numsamps = numSamps * 2;
            obj.Notepad.tobii_latency_store_mean = mean(abs(et_ms - gs_ms)); 
            obj.Notepad.tobii_latency_store_5pc =...
                quantile(abs(et_ms - gs_ms), .05);
            obj.Notepad.tobii_clock_corr = corr(et_ms, gs_ms);
            
        % calculate offset
        
            et = double(et);
            allOffsets = (et / 1e6) - gs;
            % take the mean of the lowest 5% offsets
            offset = mean(quantile(allOffsets, .05));
            % check accuracy
            et_calc = (gs + offset) * 1e6;
            obj.Notepad.tobii_clock_offset_accuracy =...
                mean(et - et_calc) / 1e3;
            
            % store
            obj.prET2GS_scale = 1e6;
            obj.prET2GS_offset = offset;
            obj.Notepad.tobii_et2gs_scale = 1e6;
            obj.Notepad.tobii_et2gs_offset = offset;
            
            teEcho('done\n');
        end
        
        function tobii_MeasureClockDrift(obj, duration)
        % repeatedly poll GetSecs, teGetSecs and tobii's internal clock for 
        % a set duration (default 10s) and plot the results. Measures
        % offsets between the different clocks, and any drift over time. 
            
            % if duration not supplied, use default of 10s
            if ~exist('duration', 'var') || isempty(duration)
                duration = 10;
            end
            
            % calculate rough number of samples, assuming ~10ms per sample,
            % then add 50% for headroom
            num = (duration * 1e2) * 1.5;
            
            % set up storage vars
            onset = teGetSecs;
            gs = zeros(num, 1);
            posix = zeros(num, 1);
            et = zeros(num, 1);
            wall = zeros(num, 1);
            
            % loop for duration
            i = 1;
            while teGetSecs - onset <= duration
                
                % poll GetSecs and teGetSecs
                [gs(i), posix(i), wall(i)] = GetSecs('AllClocks');
                
                % poll tobii
                et(i) = double(obj.prOperations.get_system_time_stamp) / 1e6;
                
                % update tobii
                obj.prTobii.get_gaze_data('flat');
                
                % increment and wait 1ms
                i = i + 1;
                WaitSecs(.01);
                
                if mod(i, 1e2) == 0
                    fprintf('%.1fs of %.1fs...\n', teGetSecs - onset, duration)
                end
                
            end
            
            % remove unused 
            posix(i:end) = [];
            et(i:end) = [];
            gs(i:end) = [];
            wall(i:end) = [];
            
            % zero
            posix = posix - posix(1);
            et = et - et(1);
            gs = gs - gs(1);
            wall = wall - wall(1);
            
            % offsets
            offset_posix = gs - posix;
            offset_et = gs - et;
            offset_wall = gs - wall;
            
            figure
            subplot(1, 3, 1:2)
            plot([offset_posix * 1e3, offset_et * 1e3, offset_wall * 1e3])
            xlabel('Iteration')
            ylabel('Offset (clock - GetSecs, ms)')
            legend('posix', 'tobii', 'wall')
            
            subplot(1, 3, 3)
            histogram(offset_posix, 'EdgeColor', 'none')
            hold on
            histogram(offset_et * 1e3, 'EdgeColor', 'none')
            histogram(offset_wall * 1e3, 'EdgeColor', 'none')
            xlabel('Offset (clock - GetSecs, ms)')
            ylabel('Frequency')
            legend('posix', 'tobii', 'wall')

            fprintf('Posix: %.4fms, Tobii: %.4fms, Wall: %.4fms\n',...
                mean(offset_posix * 1e3), mean(offset_et * 1e3),...
                mean(offset_wall * 1e3))
            
        end
        
        function [x, y, z] = tobii_DisplayArea2xyz(~, da)
            x = [da.BottomLeft(1), da.BottomRight(1), da.TopRight(1),...
                da.TopLeft(1)];
            y = [da.BottomLeft(2), da.BottomRight(2), da.TopRight(2),...
                da.TopLeft(2)];
            z = [da.BottomLeft(3), da.BottomRight(3), da.TopRight(3),...
                da.TopLeft(3)];
        end
                
    end
    
end