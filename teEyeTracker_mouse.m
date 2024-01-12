
classdef teEyeTracker_mouse < teEyeTracker
    
    properties (Dependent)
        MouseWindowPtr
        MouseWindowRes
    end
    
    properties (Access = private)
        prMouseWindowPtr = 10
        prMouseWindowRes 
    end
    
    methods
        
        % constructor
        function obj = teEyeTracker_mouse
            % call superclass constructor for general et init and set the
            % tracker type to mouse
            obj = obj@teEyeTracker('mouse');            
            obj.Initialise
            
        end
                
        function Initialise(obj)
        % check that PTB is installed and make some checks to ensure we can
        % read mouse position. Then fake the sample rate to 60Hz - this is
        % not really the rate at which data will accrue, but assuming a
        % 60Hz screen refresh in tePresenter it is roughly how often the
        % update method will get called
            
            % check for PTB
            try
                AssertOpenGL
            catch ERR
                error('Requires Psychtoolbox, which doesn''t seem to be installed.')
            end
            
            % check we can get a sample from the mouse
            if isempty(obj.MouseWindowPtr)
                error('Must specify a Psychtoolbox window pointer for the screen you want mouse coordinates from.')
            end
            if isempty(obj.MouseWindowRes)
                error('Psychtoolbox window resolution not set, or I could not get it automatically.')
            end
            
            % if the sample rate has not been set already, set it
            % to 60Hz. This is fairly meaningless when using the
            % mouse. 
            if isempty(obj.SampleRate) || isnan(obj.SampleRate)
                obj.SampleRate = 60;
            end
            
            % set conversion variables for times
            obj.prET2GS_offset = 0;
            obj.prET2GS_scale = 1;
            
            % set valid flag
            obj.Valid = true;
            
            teEcho(sprintf('using mouse at nominal refresh rate of %dHz.\n',...
                obj.SampleRate));
        end
        
        function gaze = UpdateGaze(obj)
            
            % store last update timestamp, so that we can compute how much
            % time has passed since the last update
            oBufferLastUpdate = obj.prBufferLastUpdate;
            
            % get mouse coords in pixels
            [mx, my] = GetMouse(obj.prMouseWindowPtr);
            obj.prBufferLastUpdate = teGetSecs;
            
            % normalise pixel coords 
            x = mx / obj.MouseWindowRes(3);
            y = my / obj.MouseWindowRes(4);  
            
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
                t1 = oBufferLastUpdate + isd;
                t2 = t1 + (isd * (elapsed_samps - 1));
                time = (t1:isd:t2)';
%                 time = oBufferLastUpdate + isd:isd:obj.prBufferLastUpdate;
                
%                 % convert teGetSecs time to posix
%                 time = time + obj.PosixTimeOffset;
                
                % convert the gaze to Task Engine 2 format, and store in
                % buffer
                gaze = teConvertGaze([x, y], time, 'xyt', 'taskengine2');
                gaze = obj.StoreNewGaze(gaze);
%                 s1 = obj.prBufferIdx;
%                 s2 = obj.prBufferIdx + elapsed_samps - 1;
%                 obj.Buffer(s1:s2, :) = gaze;
%                 obj.prBufferIdx = s2 + 1;     
                
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
            teEcho('Calibration skipped when using mouse as eye tracker.\n');
        end
        
        function success = ComputeCalibration(~)
            success = true;
            teEcho('Calibration skipped when using mouse as eye tracker.\n');
        end
        
        % get / set
        function val = get.MouseWindowPtr(obj)
            val = obj.prMouseWindowPtr;
        end
        
        function set.MouseWindowPtr(obj, val)
            obj.prMouseWindowPtr = val;
        end
        
        function val = get.MouseWindowRes(obj)
            if isempty(obj.prMouseWindowPtr)
                val = [];
            else
                val = Screen('Rect', obj.prMouseWindowPtr);
            end
        end
        
    end
    
end