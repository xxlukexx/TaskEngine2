classdef teExternalData_EyeTracking < teExternalData
    
    properties 
        Buffer
        Ext2Te = @(x) x
        Te2Ext = @(x) x
    end
    
    properties (SetAccess = protected)
        TargetSampleRate
        Notepad
        TrackerType
        Calibration
    end
    
    properties (Dependent, SetAccess = protected)
        Duration
        Valid     
        T1
        T2
    end
    
    properties (SetAccess = protected)
        Type = 'eyetracking'
    end
    
    methods
        
        function obj = teExternalData_EyeTracking(path)
            
            % check input args, to ensure that a path has been passed, and
            % that the path exists
            if ~exist('path', 'var') || isempty(path)
                error('Must supply a path to eye tracking data.')
            end
            
            % handle file/folder paths
            if exist(path, 'dir')
                
                % if a path to a folder was passed, try to find eye tracking
                % data inside that folder                
                file = teFindFile(path, 'eyetracking*.mat');
                if isempty(file)
                    obj.InstantiateOutcome = sprintf('No eye tracking file found in %s.', path);
                    return
                elseif iscell(file) && length(file) > 1
                    obj.InstantiateOutcome = sprintf('Multiple files matched the pattern ''eyetracking*'' in path:\n%s',...
                        path);
                    return
                end
                
            elseif exist(path, 'file')
                
                file = path;
                
            else

                obj.InstantiateOutcome = 'Path does not exist';
                return
                
            end
                       
            % attempt to load
            try
                tmp = load(file);
            catch ERR_load
                obj.InstantiateOutcome = sprintf('Error occurred when reading eye tracking data. Error was:\n\n%s',...
                    ERR_load.message);
                return
            end
            
            % check for serialised eye tracker, and convert if necessary
            if isa(tmp.eyetracker, 'uint8')
                tmp.eyetracker = getArrayFromByteStream(tmp.eyetracker);
            end
            
            % store
            obj.Paths('eyetracking') = file;
            obj.Buffer = tmp.eyetracker.Buffer;
            if isprop(tmp.eyetracker, 'SampleRate')
                obj.TargetSampleRate = tmp.eyetracker.SampleRate;
            elseif isprop(tmp.eyetracker, 'TargetSampleRate')
                obj.TargetSampleRate = tmp.eyetracker.TargetSampleRate;
            end
            obj.Notepad = tmp.eyetracker.Notepad;
            obj.TrackerType = tmp.eyetracker.TrackerType;
            obj.Calibration = tmp.eyetracker.Calibration;
            
            obj.InstantiateSuccess = true; 
            obj.InstantiateOutcome = '';
            
        end
        
        % get/set
        function val = get.Duration(obj)
            if ~obj.Valid
                val = [];
            else
                val = obj.Buffer(end, 1) - obj.Buffer(1, 1);
            end
        end
        
        function val = get.Valid(obj)
            val = ~isempty(obj.Buffer);
        end
        
        function val = get.T1(obj)
            val = obj.Buffer(1, 1);
        end
        
        function val = get.T2(obj)
            val = obj.Buffer(end, 1);
        end
        
    end
    
end