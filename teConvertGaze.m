function [conv, timeBuffer, eventBuffer] = teConvertGaze(gaze, time, from, to, goFast)
% conv = TECONVERTGAZE(gaze, from, to) converts eye tracking data GAZE
% using FROM and TO as instructions on how to manage the conversion. Valid
% formats are:
%
% taskEngine2           -   as documented in the Task Engine 2
%                           documentation
%       
% tobiiAnalytics        -   the [n x 26] format returned by the Tobii
%                           Analytics SDK. If using this format, you must
%                           pass/accept an additional timeBuffer argument
%                           containing the timestamp data
%
% tobiiPro              -   the format returned by the Tobii Pro SDK. Note
%                           that this must be in the format returned by the
%                           get_gaze_data command using the 'flat' input
%                           argument. Failure to use this argument will
%                           return a more complex structure of data which
%                           is a) very slow to acquire; and b) not
%                           compatible with this function
% 
% xyt                   -   ignoring all other measures (e.g. pupil
%                           diameter, eye pos), this takes x, y, and time
%                           data and puts it into the Task Engine 2 format.
%                           This is useful if you have x, y and timestamp
%                           triplets from an unsupported eye tracker and
%                           want to convert the data to a common format. 
%
% goFast tells the function to skip some data format checking, in order to
% run as quickly as it can (for example, during stimulus presentation).
% Also assumes that output is taskEngine2. This should not be used in
% normal situations. 

    % check input args
    if nargin < 3
        error('Not enough input arguments.')
    elseif nargin < 5
        goFast = false;
    end
    if ~goFast
        validFormats = {'taskEngine2', 'te2', 'tobiiAnalytics', 'tobiiPro', 'xyt'};
        if ~any(strcmpi(from, validFormats))
            error('Invalid format of from argument.')
        end
        if ~any(strcmpi(to, validFormats))
            error('Invalid format of to argument.')
        end

        % check time 
        timeBuffer = [];
        if ~isempty(time) && any(strcmpi(from, {'taskEngine2', 'tobiiAnalytics'}))
            % if coming from analytics, time variable may be a "time
            % buffer" (in the Task Engine 1 sense) with two colunmns. The
            % first column will have timest amps, and the second will have
            % trigger inputs (e.g. from stimtracker). If this is the case
            % then strip off the triggers and use just the timestamps
            if strcmpi(from, 'tobiiAnalytics') && size(time, 2) == 2
                timeBuffer = time(:, 1);
                time = timeBuffer(:, 1);
            end
            % check format of time variable 
            if ~isnumeric(time) || ~isvector(time)
                error('time argument must be a numeric vector.')
            end
        end
    end
    
    % first convert all formats to te2
    switch lower(from)
        case 'tobiipro'
            % check format
            if ~goFast, AssertTobiiPro(gaze), end
            numSamps = size(gaze.device_time_stamp, 1);
            % default to nan
            te2 = nan(numSamps, 33);   
            % insert time (if passed)
            if ~isempty(time)
                [gaze, time] = checkAndTruncateTime(gaze, time, 'tobiipro');
                if isempty(gaze) || isempty(time)
                    conv = [];
                    return
                end                
                % put time column into te2 style gaze matrix
                te2(:, 1) = time;
            end
            % left
            te2(:, 2:3)    = gaze.left_gaze_point_on_display_area;
            te2(:, 4)      = gaze.left_gaze_point_validity;
            te2(:, 5)      = gaze.left_pupil_diameter;
            te2(:, 6)      = gaze.left_pupil_validity;
            te2(:, 7:9)    = gaze.left_gaze_point_in_user_coordinate_system;
            te2(:, 10:12)  = gaze.left_gaze_origin_in_user_coordinate_system;
            te2(:, 13:15)  = gaze.left_gaze_origin_in_trackbox_coordinate_system;
            te2(:, 16)     = gaze.left_gaze_origin_validity;
            % right
            te2(:, 17:18)  = gaze.right_gaze_point_on_display_area;
            te2(:, 19)     = gaze.right_gaze_point_validity;
            te2(:, 20)     = gaze.right_pupil_diameter;
            te2(:, 21)     = gaze.right_pupil_validity;
            te2(:, 22:24)  = gaze.right_gaze_point_in_user_coordinate_system;
            te2(:, 25:27)  = gaze.right_gaze_origin_in_user_coordinate_system;
            te2(:, 28:30)  = gaze.right_gaze_origin_in_trackbox_coordinate_system;
            te2(:, 31)     = gaze.right_gaze_origin_validity;
            % tobii time
            te2(:, 32)     = gaze.device_time_stamp;
            te2(:, 33)     = gaze.system_time_stamp;
            % short circuit in case of converting to te2 for performance
            if goFast, conv = te2; return, end
        case 'xyt'
            if ~size(gaze, 2) == 2 || ~isnumeric(gaze)
                error('xyt gaze data must be a [n x 2] numeric matrix. Pass the timestamps in a separate time argument.')
            end
            % check for gaze/time size mismatch and correct
            [gaze, time] = checkAndTruncateTime(gaze, time, 'xyt');
            if isempty(gaze) || isempty(time)
                conv = [];
                return
            end
            numSamps = size(gaze, 1);
            % build te2 gaze matrix
            te2            = nan(numSamps, 33);
            val            = ~any(isnan(gaze), 2);
            te2(:, 1)      = time;          % te2 time
            te2(:, 2:3)    = gaze;          % left gaze x, y
            te2(:, 4)      = val;           % left gaze val
            te2(:, 6)      = false;         % left pupil val
            te2(:, 16)     = false;         % left eye pos val
            te2(:, 17:18)  = gaze;          % right gaze x, y
            te2(:, 19)     = val;           % right gaze val
            te2(:, 21)     = false;         % left pupil val
            te2(:, 31)     = false;         % right eye pos val
            te2(:, 32)     = time;          
            te2(:, 33)     = time;
        case 'tobiianalytics'
            % get number of samples and make empty te2 buffer
            numSamps        = size(gaze, 1);
            te2             = nan(numSamps, 33);
            % zero time buffer, convert from us to secs
            te2(:, 1)       = double(time - time(1)) / 1e6;
            % left eye
            val_left        = gaze(:, 13) ~= 4;
            te2(:, 2:3)     = gaze(:, 7:8);
            te2(:, 4)       = val_left;         % note only one validity 
            te2(:, 5)       = gaze(:, 12);      % code for gaze, pupil
            te2(:, 6)       = val_left;         % and eye pos
            te2(:, 7:9)     = gaze(:, 9:11);
            te2(:, 10:12)   = gaze(:, 1:3);
            te2(:, 13:15)   = gaze(:, 4:6);
            te2(:, 16)      = val_left;
            % replace missing samples with NaNs - left eye
            te2(~val_left, [2:3, 5, 7:15]) = nan;
            % right eye
            val_right       = gaze(:, 26) ~= 4;
            te2(:, 17:18)   = gaze(:, 20:21);
            te2(:, 19)      = val_right;
            te2(:, 20)      = gaze(:, 25);
            te2(:, 21)      = val_right;
            te2(:, 22:24)   = gaze(:, 22:24);
            te2(:, 25:27)   = gaze(:, 14:16);
            te2(:, 28:30)   = gaze(:, 17:19);
            te2(:, 31)      = val_right;
            % replace missing samples with NaNs - right eye
            te2(~val_right, [17:18, 20, 22:30]) = nan;
            % device timestamps (if available)
            if ~isempty(timeBuffer)
                te2(:, 32)  = timeBuffer(:, 1);
            end            
        case {'taskengine2', 'te2'}
            % no conversion needed
            numSamps = size(gaze, 1);
            te2 = gaze;
        otherwise 
            error('Unsupported ''from'' format.')
    end
    
    % now convert from te2 to whatever format
    switch lower(to)
        case 'tobiipro'
            error('Not yet implemented.')
        case 'xyt'
            if nargout > 2
                error('Converting to xyz gaze returns only two output arguments.')
            end
            % average L+R eyes
            x               = nanmean([te2(:, 2), te2(:, 17)], 2);
            y               = nanmean([te2(:, 3), te2(:, 18)], 2);
            conv            = [x, y];
            timeBuffer      = te2(:, 1);
        case 'tobiianalytics'
            if nargout > 3
                error('Converting to Tobii Analytics returns only three output arguments.')
            end
            % left
            conv            = nan(numSamps, 26);
            conv(:, 1:3)    = te2(:, 10:12);
            conv(:, 4:6)    = te2(:, 13:15);
            conv(:, 7:8)    = te2(:, 2:3);
            conv(:, 9:11)   = te2(:, 7:9);
            conv(:, 12)     = te2(:, 5);
            val             = repmat(4, numSamps, 1);
            val(logical(te2(:, 4))) = 0;            
%             val(logical(te2(:, 6))) = 0;          % this was using pupil validity instead of gaze val   
            conv(:, 13)     = val;
            % right
            conv(:, 14:16)  = te2(:, 25:27);
            conv(:, 17:19)  = te2(:, 28:30);
            conv(:, 20:21)  = te2(:, 17:18);
            conv(:, 22:24)  = te2(:, 22:24);
            conv(:, 25)     = te2(:, 20);
            val             = repmat(4, numSamps, 1);
            val(logical(te2(:, 19)))= 0;            
%             val(logical(te2(:, 21)))= 0;          % this was using pupil validity instead of gaze val       
            conv(:, 26)     = val;    
            % time
            if nargout >= 2
                timeBuffer      = zeros(numSamps, 2);
                timeBuffer(:, 1)= te2(:, 32) * 1e6;
            end
            % events
            if nargout == 3
                eventBuffer = [];
            end
        case {'taskengine2', 'te2'}
            conv = te2;
        otherwise
            error('Unsupported ''to'' format.')
    end
    
end

function [gaze, time] = checkAndTruncateTime(gaze, time, type)
% if the number of gaze samples doesn't match the number of
% time samples, we previously threw an error, which stopped
% the whole battery. Instead now truncate gaze/time
% accordingly and throw a warning

    % determine number of samples differently according to data format
    switch type
        case 'tobiipro'
            numSamps = size(gaze.device_time_stamp, 1);
        case 'xyt'
            numSamps = size(gaze, 1);
        otherwise
            error('Unsupported data format %s', type)
    end
        
    if size(time, 1) ~= numSamps
        warning('Gaze/time size mismatch - will be truncated.')
        if size(time, 1) > numSamps
            time = time(1:numSamps);
        elseif size(time, 1) < numSamps
            gaze = gaze(1:size(time, 1), :);
        end
    end

end