classdef teEyeTracker_keyboard < teEyeTracker
    
    properties (Dependent)
        MouseWindowPtr
        MouseWindowRes
    end
    
    properties (Access = private)
        prMouseWindowPtr = 10
        prMouseWindowRes 
        prTargetPresenter
    end
    
    properties (Constant)
        KB_LOOKING = 'Space'
    end
    
    methods
        
        % constructor
        function obj = teEyeTracker_keyboard
            
            % call superclass constructor for general et init
            obj = obj@teEyeTracker;            
            % find instance of tePresenter - this will be used to query the
            % keyboard
            targetPresenter = teFindPresenter;
            if isempty(targetPresenter)
                error('No tePresenter instance found in the global workspace. Cannot continue.')
            else
                obj.prTargetPresenter = targetPresenter;
            end
            % set tracker type
            obj.TrackerType = 'keyboard';
            obj.Initialise
            
        end
                
        function Initialise(obj)
        % the only thing we do here is to set the sample rate to a nominal
        % 60Hz, roughly the rate at which the presenter will refresh the
        % screen on most monitors. This isn't guaranteed and the timestamps
        % will not be regular. Also set the conversion variables to convert
        % between "eye tracker" and teGetSecs so that no conversion is
        % applied (since all timestamps will come directly from teGetSecs)
            
            % if the sample rate has not been set already, set it
            % to 60Hz. This is fairly meaningless when using the
            % keyboard. 
            if isempty(obj.SampleRate) || isnan(obj.SampleRate)
                obj.SampleRate = 60;
            end
            
            % set conversion variables for times
            obj.prET2GS_offset = 0;
            obj.prET2GS_scale = 1;
            
            % set valid flag
            obj.Valid = true;
            
            teEcho(sprintf('using keyboard at nominal refresh rate of %dHz.\n',...
                obj.SampleRate));
        end
        
        function gaze = UpdateGaze(obj)
            
            % store last update timestamp, so that we can compute how much
            % time has passed since the last update
            oBufferLastUpdate = obj.prBufferLastUpdate;
            
            % get current key state
            [keyIsDown, ~, keyCode, ~] =...
                KbCheck(obj.prTargetPresenter.ActiveKeyboard);
            
            % check for 'looking' keypress
            pressed = keyIsDown && keyCode(KbName(obj.KB_LOOKING));
            
            % set buffer update time
            obj.prBufferLastUpdate = teGetSecs;
            
            % if key is pressed, then gaze is at the centre of the screen.
            % If not pressed, then it's offscreen
            if pressed
                x = 0.5;
                y = 0.5;
            else
                x = nan;
                y = nan;
            end
            
            % calculate intersample delta 
            isd = 1 / obj.SampleRate;
            
            % calculate time elapsed since last update
            elapsed_secs = obj.prBufferLastUpdate - oBufferLastUpdate;
            
            % if less than one sample has been passed, don't return
            % any data (i.e. we're looping faster than 60Hz). Otherwise...
            if elapsed_secs >= isd
                % ...caluclate the number of samples of data that are
                % expected
                elapsed_samps = floor(elapsed_secs * obj.SampleRate);
                
                % if elapsed times are empty, this is because we
                % haven't had any buffer updates yet, in which case we
                % only need one sample
                if isempty(elapsed_samps), elapsed_samps = 1; end
                
                % repeat mouse coords to fake multiple samples of gaze
                % data
                if elapsed_samps > 1
                    x = repmat(x, elapsed_samps, 1);
                    y = repmat(y, elapsed_samps, 1);
                end
                
            % calculate timestamps
            
                % if this is the first update, then we go back one
                % inter-sample-distance
                if isempty(oBufferLastUpdate)
                    oBufferLastUpdate = obj.prBufferLastUpdate - isd;
                end
                
                % make a time buffer using last update time, to current
                % update time, with isd as the increment
                time = oBufferLastUpdate + isd:isd:obj.prBufferLastUpdate;
                
                % convert the gaze to Task Engine 2 format, and store in
                % buffer
                gaze = teConvertGaze([x, y], time', 'xyt', 'taskengine2');
                obj.StoreNewGaze(gaze);
%                 numSamps = size(gaze, 1);
%                 if ~isempty(gaze)
%                     s1 = obj.prBufferIdx;
%                     s2 = obj.prBufferIdx + numSamps - 1;
%                     obj.prBuffer(s1:s2, :) = gaze;
%                     obj.prBufferIdx = s2 + 1;     
%                 end                
            else
                % no "new" gaze since last update (refresh > 60Hz) so
                % return empty (same as an eye tracker would)
                gaze = [];
                
            end
                    
            % set HasGaze flag to notify other parts of Task Engine that
            % new gaze is available
            obj.HasGaze = obj.prBufferIdx > 1;            
            
        end
               
        function BeginCalibration(~)
            teEcho('Calibration skipped when using keyboard as eye tracker.\n');
        end
        
        function success = ComputeCalibration(~)
            success = true;
            teEcho('Calibration skipped when using keyboard as eye tracker.\n');
        end
        
    end
    
end