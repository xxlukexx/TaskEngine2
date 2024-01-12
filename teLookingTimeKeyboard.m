classdef teLookingTimeKeyboard < handle
    
    properties
        MinimumLookDuration = 1
        KeyboardDeviceIndex = -1
        KeyToMonitor = 'space'
    end
    
    properties (Dependent, SetAccess = private)
        LookingMetCriterion
        LookingInstant 
        NumLooks
        LookOnsets
        LookOffsets
        LookDurations
        PeakLook
        MeanLook
        MinLook
        LookTable
    end
    
    properties (SetAccess = private)
        Event = [];
    end
    
    properties (Access = private)
        currentlyLooking = false
        currentLookOnset = nan
        currentLookOffset = nan
        smoothedCurrentlyLooking = false;
        smoothedLookOnset = nan
        smoothedLookOffset = nan
        allLookOnsets = []
        allLookOffsets = []
        keyIsDown
    end
    
    methods
        
        function obj = teLookingTimeKeyboard(pres)
            
            % optionally take the device index from a tePresenter instance
            if exist('pres', 'var') && ~isempty(pres)
                if ~isa(pres, 'tePresenter')
                    error('Input argument (if not omitted) must be tePresenter object.')
                end
                obj.KeyboardDeviceIndex = pres.ActiveKeyboard;
            end
            
            % check if queue has been created
            try
                KbQueueCheck(obj.KeyboardDeviceIndex);
            catch ERR
                error('Could not check queue -- has it been started with KbQueueStart?')
            end
                
        end
        
        function Reset(obj)
             
            obj.currentlyLooking = false;
            obj.smoothedCurrentlyLooking = false;
            obj.UpdateLookStats;
                        
        end
        
        function Update(obj)
            
            obj.Event = [];
            
            [keyPressed, t_keyDown, t_keyUp] = KbQueueCheck(obj.KeyboardDeviceIndex);
            keysDown = KbName(t_keyDown);
            keysUp = KbName(t_keyUp);
            targetKeyIsDown = keyPressed && ~isempty(keysDown) && any(contains(keysDown, obj.KeyToMonitor));
            targetKeyIsUp = ~keyPressed && ~isempty(keysUp) && any(contains(keysUp, obj.KeyToMonitor));
            
            % handle absolute keypressed -- has a key been pressed or
            % released since we last checked?
            if targetKeyIsDown && ~obj.currentlyLooking
                obj.currentlyLooking = true;
                obj.currentLookOnset = teGetSecs;
                obj.Event = 'key_down_instant';
                fprintf('Key down\n');
            elseif targetKeyIsUp && obj.currentlyLooking
                obj.currentlyLooking = false;
                obj.currentLookOffset = teGetSecs;
                obj.Event = 'key_up_instant';
                fprintf('Key up\n');
            end
            
            % check in-progress key presses against minimum look duration
            if obj.currentlyLooking && ~obj.smoothedCurrentlyLooking
                if teGetSecs - obj.currentLookOnset >= obj.MinimumLookDuration
                    obj.smoothedCurrentlyLooking = true;
                    fprintf('Key down -- met criterion\n');
                    obj.smoothedLookOnset = obj.currentLookOnset;
                    obj.Event = 'key_down_criterion';
                end
            end
            
            if ~obj.currentlyLooking && obj.smoothedCurrentlyLooking
                if teGetSecs - obj.currentLookOffset >= obj.MinimumLookDuration
                    obj.smoothedCurrentlyLooking = false;
                    obj.smoothedLookOffset = obj.currentLookOffset;
                    fprintf('Key up -- met criterion\n');
                    obj.Event = 'key_up_criterion';
                    obj.UpdateLookStats
                end
            end
                
        end
        
        function UpdateLookStats(obj)
            
            obj.allLookOnsets(end + 1) = obj.smoothedLookOnset;
            obj.allLookOffsets(end + 1) = obj.smoothedLookOffset;
            obj.currentLookOnset = nan;
            obj.currentLookOffset = nan;
            obj.smoothedLookOnset = nan;
            obj.smoothedLookOffset = nan;
            disp(obj.LookTable)
            
        end
        
        % get/set
        function val = get.LookingMetCriterion(obj)
            val = obj.smoothedCurrentlyLooking;
        end
        
        function val = get.LookingInstant(obj)
            val = obj.currentlyLooking;
        end
        
        function val = get.NumLooks(obj)
            val = length(obj.allLookOnsets);
        end
        
        function val = get.LookOnsets(obj)
            val = obj.allLookOnsets;
        end
        
        function val = get.LookOffsets(obj)
            val = obj.allLookOffsets;
        end
        
        function val = get.LookDurations(obj)
            val = obj.allLookOffsets - obj.allLookOnsets;
        end
        
        function val = get.PeakLook(obj)
            val = max(obj.LookDurations); 
        end
        
        function val = get.MeanLook(obj)
            val = mean(obj.LookDurations);
        end
        
        function val = get.MinLook(obj)
            val = min(obj.LookDurations);
        end
        
        function val = get.LookTable(obj)
            if isempty(obj.NumLooks) 
                val = [];
                return
            end
            
            val = table;
            val.Number = [1:obj.NumLooks]';
            val.Duration = obj.LookDurations';
            val.Onset = obj.LookOnsets';
            val.Offset = obj.LookOffsets';
        end
        
    end        
    
end

    
    
   