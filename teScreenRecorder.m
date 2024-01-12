classdef teScreenRecorder < handle
    
    properties
        CaptureFPS = 30
    end
    
    properties (Dependent)
        RecordScreen@logical
        RecordWebcam@logical
        ScreenWebcamDivider
        MonitorNumber 
        OutputResolution
        WindowResolution
        ScreenCaptureDeviceID
        WebcamCaptureDeviceID
        OutputFilename
        WebcamCaptureFilename
    end
    
    properties (Dependent, SetAccess = private)
        CaptureDevices
        Timing
    end
    
    properties (Access = private)
        prRecordScreen = true
        prRecordWebcam = true
        prScreenWebcamDivider = .7
        prMonitorNumber
        prOutputResolution = [1080, 1920]
        prWindowResolution = [1080, 1920]
        prScreenCaptureDeviceID 
        prWebcamCaptureDeviceID = 0
        prOutputFilename
        prWebcamCaptureFilename
        prScreenRect
        prWebcamRect
        prWindowPtr
        prScreenCapturePtr
        prWebcamCapturePtr
        prWindowOpen = false
        prScreenCaptureOpen = false
        prWebcamCaptureOpen = false
        prRecordingStarted = false
        prOutputPtr
        prLib
        prInlet
        prSyncEstablished = true
        prSkipSyncTests
        prVerbosity
        prCaptureDevices
        prFrame = 1
        prTiming 
    end
    
    properties (Hidden, Constant)
        CONST_DEF_BUFFER_SIZE   = 648000    % 3 hrs @ 60fps
        % colours
        COL_BG                  = [128, 128, 128]
        COL_LABEL_BG            = [030, 000, 080]
        COL_LABEL_FG            = [210, 210, 230] 
        COL_LABEL_HIGHLIGHT     = [250, 210, 040]
        COL_ET_LEFT             = [066, 133, 244]
        COL_ET_RIGHT            = [125, 179, 066]
        COL_ET_AVG              = [213, 008, 000]
        COL_ICON_LIST           = [175, 175, 175]
        COL_ICON_TRIAL          = [001, 155, 229]
        COL_ICON_FUNCTION       = [125, 180, 065]
        COL_ICON_ECK            = [240, 147, 000]
        COL_ICON_NESTEDLIST     = [189, 106, 229]
        COL_AOI_LIGHT           = [245, 145, 110]
        COL_AOI_DARK            = [247, 202, 024]
        COL_TE_PURPLE           = [154, 018, 179]
        COL_TE_DARKPURPLE       = [102, 012, 119]
    end
    
    methods
        
        function obj = teScreenRecorder
            % check for ptb
            AssertOpenGL
            % check for lsl
            if ~exist('lsl_loadlib', 'file')
                error('Cannot find lsl_loadlib in the path.')
            end
            % get capture devices
            obj.prCaptureDevices = Screen('VideoCaptureDevices');
            % default monitor number
            obj.prMonitorNumber = max(Screen('Screens'));
            % init timing
            obj.prTiming = nan(obj.CONST_DEF_BUFFER_SIZE, 3);
            obj.prFrame = 1;
        end
        
        function delete(obj)
            if obj.prRecordingStarted
                obj.StopRecording
            end
            if obj.prScreenCaptureOpen
                obj.CloseScreenCapture
            end
            if obj.prWebcamCaptureOpen
                obj.CloseWebcamCapture
            end
            if obj.prWindowOpen
                obj.CloseWindow
            end
            Screen('CloseAll')
            % put old PTB settings back
            Screen('Preference', 'SkipSyncTests', obj.prSkipSyncTests);
            Screen('Preference', 'Verbosity', obj.prVerbosity);
        end
        
        function OpenWindow(obj)
            % ensure that capture device IDs have been set
            if obj.prRecordScreen && isempty(obj.prScreenCaptureDeviceID)
                error('Must set ScreenCaptureDeviceID first.')
            end
            if obj.prRecordWebcam && isempty(obj.prWebcamCaptureDeviceID)
                error('Must set WebcamCaptureDeviceID first.')
            end
            teEcho('Opening window...\n');
            % skip sync tests, and set verbosity to nothing
            obj.prSkipSyncTests = Screen('Preference', 'SkipSyncTests', 2);
            obj.prVerbosity = Screen('Preference', 'Verbosity', 0);
            % open window
            if ~isempty(obj.prOutputResolution)
                res = [0, 0, obj.prOutputResolution];
            else 
                res = [];
            end
            [obj.prWindowPtr, rect] = PsychImaging('OpenWindow',...
                obj.prMonitorNumber, [], res);
            % if no output res given (i.e fullscreen), then set the res
            % accordin to the screen res
            if isempty(obj.prOutputResolution)
                obj.prOutputResolution = rect(3:4);
            end
            obj.prWindowOpen = true;
            % open capture device(s)
            if obj.prRecordScreen
                obj.OpenScreenCapture
                tex_screen = Screen('GetCapturedImage', obj.prWindowPtr,...
                    obj.prScreenCapturePtr, 1);
                res_screen = Screen('Rect', tex_screen);
                ar_screen = res_screen(3) / res_screen(4);
            end
            if obj.prRecordWebcam
                obj.OpenWebcamCapture
                tex_webcam = Screen('GetCapturedImage', obj.prWindowPtr,...
                    obj.prWebcamCapturePtr, 1);
                res_webcam = Screen('Rect', tex_webcam);
                ar_webcam = res_webcam(3) / res_webcam(4);
            end
            % figure out placement - div is the right hand edge of the
            % screen texture, and the left hand edge of the webcam
            if obj.prRecordScreen && ~obj.prRecordWebcam
                % just screen
                div = 1;
            elseif obj.prRecordWebcam && ~obj.prRecordScreen
                % just webcam
                div = 0;
            elseif obj.prRecordWebcam && obj.prRecordScreen
                % both
                div = obj.ScreenWebcamDivider;
            end
            % convert div to pixels
            div = round(div * obj.OutputResolution(1));
            % borders
            if obj.prRecordScreen
                if ar_screen > 1
                    % wider than tall
                    rect_screen = [0, 0, div, div / ar_screen]; 
                else
                    % taller than wide
                    rect_screen = [0, 0, div / ar_screen, div];
                end
                frame_screen = [0, 0, div, obj.prOutputResolution(2)];
                obj.prScreenRect = CenterRect(rect_screen, frame_screen);
            end
            if obj.prRecordWebcam
                if ar_webcam > 1
                    % wider than tall
                    w = obj.prOutputResolution(1) - div;
                    rect_webcam = [0, 0, w, w / ar_webcam]; 
                else
                    % taller than wide
                    rect_webcam = [0, 0, div / ar_webcam, div];
                end
                frame_webcam = [div, 0, obj.OutputResolution(1),...
                    obj.OutputResolution(2)];
                obj.prWebcamRect = CenterRect(rect_webcam, frame_webcam);
            end
            % set fonts
            Screen('TextFont', obj.prWindowPtr, 'menlo');
            Screen('TextSize', obj.prWindowPtr, 20);
        end
        
        function OpenScreenCapture(obj)
            obj.AssertWindowOpen
            teEcho('Opening screen capture...\n');
            obj.prScreenCapturePtr = Screen('OpenVideoCapture',...
                obj.prWindowPtr, obj.prScreenCaptureDeviceID, [], 3);
            teEcho('Starting screen capture...\n');
            Screen('StartVideoCapture', obj.prScreenCapturePtr, obj.CaptureFPS, 1);
            obj.prScreenCaptureOpen = true;
        end
        
        function OpenWebcamCapture(obj)
            obj.AssertWindowOpen
            teEcho('Opening webcam...\n');
            obj.prWebcamCapturePtr = Screen('OpenVideoCapture',...
                obj.prWindowPtr, obj.prWebcamCaptureDeviceID, [], 1);
            teEcho('Starting webcam capture...\n');
            Screen('StartVideoCapture', obj.prWebcamCapturePtr, obj.CaptureFPS, 1);
            obj.prWebcamCaptureOpen = true;            
        end
        
        function CloseWindow(obj)
            obj.AssertWindowOpen
            Screen('Close', obj.prWindowPtr)
            obj.prWindowOpen = false;
        end
        
        function CloseScreenCapture(obj)
            if ~obj.prScreenCaptureOpen
                error('Screen capture not open.')
            end
            Screen('CloseVideoCapture', obj.prScreenCaptureDeviceID);
            obj.prScreenCaptureOpen = false;
        end
        
        function CloseWebcamCapture(obj)
            if ~obj.prWebcamCaptureOpen
                error('Webcam capture not open.')
            end
            Screen('CloseVideoCapture', obj.prWebcamCaptureDeviceID);
            obj.prWebcamCaptureOpen = false;            
        end
        
        function EstablishSync(obj)
            if obj.prSyncEstablished
                error('Sync already established.')
            end
        end
        
        function StartRecording(obj)
            obj.AssertWindowOpen
            obj.AssertSyncEstablished
            if obj.prRecordingStarted
                error('Recording already started.')
            end
            % check screen capture has started
            if ~obj.prScreenCaptureOpen && ~obj.prWebcamCaptureOpen
                error('Screen/webcam capture not started.')
            end
            % check filename
            if isempty(obj.prOutputFilename)
                error('OutputFilename not set.')
            end
            teEcho('Starting recording...\n');
            % open output file
            w = obj.prOutputResolution(1);
            h = obj.prOutputResolution(2);
            obj.prOutputPtr = Screen('CreateMovie', obj.prWindowPtr,...
                obj.OutputFilename, w, h, obj.CaptureFPS, ':CodecType=huffyuv'); 
            % set flag
            obj.prRecordingStarted = true;
        end
        
        function StopRecording(obj)
            obj.AssertRecordingStarted
            Screen('FinalizeMovie', obj.prOutputPtr);
            obj.prRecordingStarted = false;
        end
        
        function Update(obj)
            % get latest frames
            if obj.RecordScreen
                [texScreen, tsScreen] = Screen('GetCapturedImage', obj.prWindowPtr,...
                    obj.prScreenCapturePtr);
                Screen('DrawTexture', obj.prWindowPtr, texScreen, [], obj.prScreenRect)
                Screen('Close', texScreen);
            end
            if obj.RecordWebcam
                [texWebcam, tsWebcam] = Screen('GetCapturedImage', obj.prWindowPtr,...
                    obj.prWebcamCapturePtr);
                Screen('DrawTexture', obj.prWindowPtr, texWebcam, [], obj.prWebcamRect)
                Screen('Close', texWebcam);
            end
            % take timestamp from screen if possible, otherwise from webcam
            if obj.RecordScreen, tsLocal = tsScreen; else, tsLocal = tsWebcam; end
            % update timing 
            if obj.prFrame == 1
                ifi = nan;
                frameDuration = 1;
            else
                ifi = (tsLocal - obj.prTiming(obj.prFrame, 1)) * 1000;
                frameDuration = ifi / (1000 / obj.CaptureFPS);
            end
            tsRemote = nan;
            obj.prTiming(obj.prFrame, :) = [tsLocal, ifi, tsRemote];
            % inc buffer
            curSize = size(obj.prTiming, 1);
            if obj.prFrame >= curSize
                obj.prTiming(curSize + obj.CONST_DEF_BUFFER_SIZE, 1) = nan;
            end            
            % draw timing info
            strDate = datestr(datetime('now'), 'yyyy-mm-ddTHHMMss');
            timeElapsed = obj.prTiming(obj.prFrame, 1) - obj.prTiming(1, 1);
            strFrame = sprintf('Frame: %.2f | Video time: %s', obj.prFrame,...
                datestr(timeElapsed / 86400, 'HH:MM.SS.fff'));
%             DrawFormattedText(obj.prWindowPtr, strDate, 0, 0, [0, 0, 0]);
            
            ny = 0;
            th = 0;
            [~, ny, th] = Screen('DrawText', obj.prWindowPtr, strDate,    0, ny + th, [255, 255, 255], [0, 0, 0]);
            [~, ny, th] = Screen('DrawText', obj.prWindowPtr, strFrame,     0, ny + th, [255, 255, 255], [0, 0, 0]);
            
            
            
            if frameDuration >= 1
                Screen('AddFrameToMovie', obj.prWindowPtr, [], [], [],...
                    round(frameDuration));
                % draw
                tsFlip = Screen('Flip', obj.prWindowPtr, [], [], 2);
                obj.prFrame = obj.prFrame + 1;
            end
        end
        
        function Start(obj)
            if ~obj.prWindowOpen
                obj.OpenWindow
            end
            if ~obj.prRecordingStarted
                obj.StartRecording
            end
            % loop until keypress
%             profile on
            while ~KbCheck(-1)
                obj.Update
            end
%             profile off
            obj.StopRecording
            obj.CloseWindow
%             profile viewer
        end
        
        % get/set
        function set.MonitorNumber(obj, val)
            if obj.prWindowOpen
                error('Cannot set MonitorNumber when window is open.')
            elseif val > max(Screen('Screens'))
                error('Requested MonitorNumber is greater than the numebr of connected monitors.')
            else
                obj.prMonitorNumber = val;
            end
        end
        
        function val = get.MonitorNumber(obj)
            val = obj.prMonitorNumber;
        end
        
        function set.ScreenCaptureDeviceID(obj, val)
            if obj.prRecordingStarted
                error('Cannot change this property when recording has started.')
            end
            obj.AssertValidCaptureDeviceID(val)
            obj.prScreenCaptureDeviceID = val;
        end
        
        function val = get.ScreenCaptureDeviceID(obj)
            val = obj.prScreenCaptureDeviceID;
        end
        
        function set.WebcamCaptureDeviceID(obj, val)
            if obj.prRecordingStarted
                error('Cannot change this property when recording has started.')
            end            
            obj.AssertValidCaptureDeviceID(val)
            obj.prWebcamCaptureDeviceID = val;
        end
        
        function val = get.WebcamCaptureDeviceID(obj)
            val = obj.prWebcamCaptureDeviceID;
        end
        
        function val = get.CaptureDevices(obj)
            val = obj.prCaptureDevices;
        end
        
        function set.OutputFilename(obj, val)
            if obj.prRecordingStarted
                error('Cannot change this property when recording has started.')
            end  
            if ~ischar(val)
                error('OutputFilename must be char.')
            end
            obj.prOutputFilename = val;
        end
        
        function val = get.OutputFilename(obj)
            val = obj.prOutputFilename;
        end
        
        function set.WebcamCaptureFilename(obj, val)
            if obj.prRecordingStarted
                error('Cannot change this property when recording has started.')
            end  
            if ~ischar(val)
                error('WebcamCaptureFilename must be char.')
            end
            obj.prWebcamCaptureFilename = val;
        end
        
%         function set.ScreenCaptureResolution(obj, val)
%             if obj.prRecordingStarted
%                 error('Cannot set this property when recording has started.')
%             end
%             obj.AssertValidResolution(val)
%             obj.prScreenCaptureResolution = val;
%         end
%         
%         function val = get.ScreenCaptureResolution(obj)
%             val = obj.prScreenCaptureResolution;
%         end
%         
%         function set.WebcamCaptureResolution(obj, val)
%             if obj.prRecordingStarted
%                 error('Cannot set this property when recording has started.')
%             end
%             obj.AssertValidResolution(val)
%             obj.prWebcamCaptureResolution = val;
%         end
%         
%         function val = get.WebcamCaptureResolution(obj)
%             val = obj.prWebcamCaptureResolution;
%         end
        
        function set.OutputResolution(obj, val)
%             if ~isnumeric(val) || ~isscalar(val) || val < 100
%                 error('OutputResolution must be a numeric scalar greater than 100.')
%             end
            obj.AssertValidResolution(val)
            obj.prOutputResolution = val;
        end
        
        function val = get.OutputResolution(obj)
            val = obj.prOutputResolution;
        end
        
        function set.WindowResolution(obj, val)
%             if ~isnumeric(val) || ~isscalar(val) || val < 100
%                 error('WindowResolution must be a numeric scalar greater than 100.')
%             end
            obj.AssertValidResolution(val)
            obj.prWindowResolution = val;
        end
        
        function val = get.WindowResolution(obj)
            val = obj.prWindowResolution;
        end       
        
        function set.RecordScreen(obj, val)
            if ~val && ~obj.prRecordWebcam
                error('Must record at least screen or webcam.')
            end
            obj.prRecordScreen = val;
        end
        
        function val = get.RecordScreen(obj)
            val = obj.prRecordScreen;
        end
        
        function set.RecordWebcam(obj, val)
            if ~val && ~obj.RecordScreen
                error('Must record at least screen or webcam.')
            end
            obj.prRecordWebcam = val;
        end
        
        function val = get.RecordWebcam(obj)
            val = obj.prRecordWebcam;
        end
        
        function set.ScreenWebcamDivider(obj, val)
            if ~isnumeric(val) || ~isscalar(val) || val < 0.1 || val > .9
                error('ScreenWebcamDivider must be a numeric scalar between 0.1 and 0.9.')
            end
            obj.prScreenWebcamDivider = val;
        end
        
        function val = get.ScreenWebcamDivider(obj)
            val = obj.prScreenWebcamDivider;
        end
        
        function val = get.Timing(obj)
            if obj.prFrame == 1
                val = [];
            end
            dat = obj.prTiming(1:obj.prFrame - 1, :);
            val = array2table(dat, 'variablenames', {'CaptureTime',...
                'InterFrameInterval', 'TaskEngineTime'});
        end 
        
    end
    
    methods (Hidden)
        
        function AssertWindowOpen(obj)
            if ~obj.prWindowOpen
                error('Window not open.')
            end
        end
        
        function AssertSyncEstablished(obj)
            if ~obj.prSyncEstablished
                error('Sync not established.')
            end
        end
        
        function AssertRecordingStarted(obj)
            if ~obj.prRecordingStarted
                error('Recording not started.')
            end
        end
        
        function AssertValidCaptureDeviceID(obj, val)
            if ~ismember(val, [obj.prCaptureDevices.DeviceIndex])
                error('%d is not a valid capture device ID.', val)
            end
        end
        
        function AssertValidResolution(obj, val)
            if ~isempty(val) && (~isnumeric(val) || ~isvector(val) || length(val) ~= 2)
                error('Resolutions must be 2-element numeric vectors [w, h].')
            end
        end
        
    end
    
end
        