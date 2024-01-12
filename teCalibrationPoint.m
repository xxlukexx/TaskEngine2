classdef teCalibrationPoint < handle
    
    properties
        Active = false
        MoveSpeed = 1;     
        ScaleSpeed = .05;    
        RotateSpeed = 250           % deg per sec
        Diameter
    end
    
    properties (Dependent)
        Schedule
    end
    
    properties (SetAccess = protected)
        X
        Y
        Rotation = 0
        Stim
        Sound
        IsMoving = false
        IsScaling = false;
        IsRotating = true
        LastCalibrationOutcome = 'not_run'
    end
    
    properties (Dependent, SetAccess = private)
        ScheduleRunning 
        Results
    end
    
    properties (Access = protected)
        % general
        prPresenter
        prStim
        prLastUpdateTime
        prScheduleIdx = 1
        prResultsIdx = 1
        prRunning = false
        prState = 'idle'
        prSchedule = [0.5, 0.5; 0.1, 0.9; 0.1, 0.1; 0.9, 0.1; 0.9, 0.9]
        prScheduleOnset
        prScheduleOffset
        prScheduleElap
        prResults
        % movement
        prXChangePerS = 0
        prYChangePerS = 0
        prMoveTarget = []
        % scale
        prDiaChangePerSec = 0
        prDiameterTarget = []
        % rotation
        prRotChangePerSec = 0
    end
    
    methods
        
        function obj = teCalibrationPoint(pres, calibDef)
            obj.prPresenter = pres;
            obj.Diameter = 0.1;
            obj.prLastUpdateTime = teGetSecs;
            obj.ClearAndInitResults
            if ~exist('calibDef', 'var') || isempty(calibDef)
                obj.CreateSchedule(5);
            elseif size(calibDef, 2) ~= 2 || ~isnumeric(calibDef)
                error('Calibration definition must be a [n x 2] matrix of [x, y] pairs representing the location of each calibration stimulus.')
            else
                obj.InitSchedule(calibDef)            
            end
        end
        
        % handle schedule
        
        function InitSchedule(obj, calibDef)
        % takes a calib def ([n x 2] matrix of [x, y] coords) and creates
        % storage for calibration in a table        
        
            numPoints = size(calibDef, 1);
            obj.prSchedule = table;
            obj.prSchedule.x = calibDef(:, 1);
            obj.prSchedule.y = calibDef(:, 2);
            obj.prSchedule.measured = false(numPoints, 1);
            obj.prSchedule.valid = false(numPoints, 1);
            obj.prSchedule.t_onset = nan(numPoints, 1);
            obj.prSchedule.t_offset = nan(numPoints, 1);
            obj.prSchedule.gaze = repmat({[nan, nan, nan, nan]}, numPoints, 1);
            
            obj.prSchedule.accuracy_l = nan(numPoints, 1);
            obj.prSchedule.accuracy_r = nan(numPoints, 1);
            obj.prSchedule.precision_l = nan(numPoints, 1);
            obj.prSchedule.precision_r = nan(numPoints, 1);
            obj.prSchedule.accuracy_deg_l = nan(numPoints, 1);
            obj.prSchedule.accuracy_deg_r = nan(numPoints, 1);
            obj.prSchedule.precision_deg_l = nan(numPoints, 1);
            obj.prSchedule.precision_deg_r = nan(numPoints, 1);
            obj.prSchedule.offset_l_x = repmat({nan}, numPoints, 1);
            obj.prSchedule.offset_l_y = repmat({nan}, numPoints, 1);
            obj.prSchedule.offset_r_x = repmat({nan}, numPoints, 1);
            obj.prSchedule.offset_r_y = repmat({nan}, numPoints, 1);
            obj.prSchedule.offset_l = repmat({nan}, numPoints, 1);
            obj.prSchedule.offset_r = repmat({nan}, numPoints, 1);
            obj.prSchedule.centroid_l_x = nan(numPoints, 1);
            obj.prSchedule.centroid_l_y = nan(numPoints, 1);
            obj.prSchedule.centroid_r_x = nan(numPoints, 1);
            obj.prSchedule.centroid_r_y = nan(numPoints, 1);
            
        end
        
        function [suc, oc] = RunSchedule(obj)
            
            suc = false;
            oc = 'unknown error';
            
            % find the first non-valid point in the schedule, this will be
            % the first that we (re)calibrate
            obj.findNextPointInSchedule;
            
            if isempty(obj.prScheduleIdx)
                suc = false;
                oc = 'no_points_to_calibrate';
                return
            end
            
            % set up presenter for calibration            
            pres = obj.prPresenter;
            pres.DrawCalibrationResults;
            pres.DrawCalibOnPreview = true;
            pres.BackColour = pres.ETCalibBackgroundColour;
            pres.RefreshDisplay;        
            pres.KeyFlush;            
            
            % start schedule
            obj.Active = true;
            obj.prRunning = true; 
            obj.prState = 'init';
            obj.prScheduleOnset = teGetSecs;
            
            % loop until schedule is complete
            while obj.prRunning
                
                obj.Update;
                pres.DrawCalibPoint(obj)
                pres.RefreshDisplay;
                
                % exit if key pressed
                if pres.KeyPressed(pres.KB_MOVEON)
                    obj.StopSchedule
                    suc = false;
                    oc = 'skipped';
                    return
                elseif pres.KeyPressed(pres.KB_MOVEBACK)
                    obj.StopSchedule;
                    suc = false;
                    oc = 'get_eyes';
                    return
                end

            end
            
            switch obj.LastCalibrationOutcome
                case 'success'
                    suc = true;
                    oc = 'The calibration completed successfully';
                case 'ongoing'
                    suc = false;
                    oc = 'The calibration ended before all points were successfully calibrated';
                case 'skipped'
                    suc = false;
                    oc = 'The calibration was skipped';
                case 'failed'
                    suc = false;
                    oc = 'The calibration failed, probably because the collected data up to this point was too poor';
                otherwise
                    suc = false;
                    oc = 'unknown calibration state';
            end
            
        end
        
        function StopSchedule(obj)
            obj.Active = false;
            obj.prRunning = false;
            obj.prState = 'finished';
            obj.prScheduleOffset = teGetSecs;
        end
        
        function HandleRunningSchedule(obj)
            
            if ~obj.prRunning, return, end
            obj.prScheduleElap = teGetSecs - obj.prScheduleOnset;
            
            switch obj.prState
                
                case 'init'
                    obj.Stim = obj.prPresenter.Stim.LookupRandom...
                        ('key', 'et_calib_spiral*');
                    obj.Sound = obj.prPresenter.Stim.LookupRandom...
                        ('key', 'et_calib_snd*');
                    obj.prPresenter.PlayStim(obj.Sound)
                    obj.StartSpinning
                    obj.X = obj.prSchedule.x(obj.prScheduleIdx);
                    obj.Y = obj.prSchedule.y(obj.prScheduleIdx);   
                    obj.Diameter = 0.7;
                    obj.prState = 'init_spinning';
                    
                case 'init_spinning'
                    if obj.prScheduleElap > 1
                        obj.ScaleTo(0.01, .7)
                        obj.prState = 'shrinking';
                    end
                    
                case 'shrinking'
                    if ~obj.IsScaling
                        obj.prScheduleOnset = teGetSecs;
                        obj.prSchedule.t_onset(obj.prScheduleIdx) = teGetSecs;
                        obj.prState = 'wait_to_measure';
                    end
                    
                case 'wait_to_measure'
                    
                    if teGetSecs - obj.prScheduleOnset >= 1
                        obj.prState = 'measuring';
                        obj.prSchedule.t_offset(obj.prScheduleIdx) = teGetSecs;
                    end
                        
                case 'measuring'                  

                    obj.prState = 'acquiring_gaze';
                        
                case 'init_next_point'
                    
                    obj.findNextPointInSchedule               
                    
                    % if no points are left, finish the schedule, otherwise
                    % scale the point back up, move on to next etc.
                    if isempty(obj.prScheduleIdx)
                        % end of schedule
                        obj.prScheduleIdx = 1;
                        obj.prState = 'finished';
                    else
                        % prepare the next calib point
                        obj.ScaleTo(0.3, 2.5)
                        obj.prState = 'scaling_back_up';
                    end
                    
                case 'scaling_back_up'
                    
                    if ~obj.IsScaling 
                        x_new = obj.prSchedule.x(obj.prScheduleIdx);
                        y_new = obj.prSchedule.y(obj.prScheduleIdx);
                        
                        % if we are already at the new location, skip the
                        % moving step
                        if isequal(obj.X, x_new) && isequal(obj.Y, y_new)
                            obj.prState = 'init_spinning';
                        else
                            obj.MoveTo(x_new, y_new, .9)
                            obj.prState = 'moving_to_next';
                        end
                    end
                    
                case 'moving_to_next'

                    if ~obj.IsMoving
                        obj.prState = 'init_spinning';
                    end 
                    
                case 'finished'
                    
                    % stop running schedule
                    obj.StopSchedule
                    obj.prRunning = false;
                    obj.Active = false;
                    
                    % stop sound
                    obj.prPresenter.StopStim(obj.Sound);
                    
                    obj.prState = 'idle';

            end
            
        end
        
        function CreateSchedule(obj, numPoints)
            
            if mod(sqrt(numPoints), 1) ~= 0
                numPoints_adj = round(sqrt(numPoints)) ^ 2;
                warning('Cannot create a grid with %d points, will adjust to %d points.',...
                    numPoints, numPoints_adj)
                numPoints = numPoints_adj;
            end
            numSteps = sqrt(numPoints);
            xgs = 0.8 / (numSteps - 1);
            ygs = 0.8 / (numSteps - 1);
            [xg, yg] = meshgrid(0.1:xgs:0.9, 0.1:ygs:0.9);
            % convert to vector of [x, y] coords
            calibDef = [xg(:), yg(:)];
            % randomise order
            so = randperm(numPoints);
            calibDef = calibDef(so, :);
            obj.InitSchedule(calibDef);
            
        end
        
        % drawing & update
        
        function StartSpinning(obj)
            obj.IsRotating = true;
        end
        
        function StopSpinning(obj)
            obj.IsRotating = false;
        end
        
        function MoveTo(obj, x, y, speed)
            if nargin == 3
                speed = obj.MoveSpeed;
            end
            obj.prMoveTarget = [x, y];
            dis_x = x - obj.X;
            dis_y = y - obj.Y;
            dis = sqrt((dis_x ^ 2) + (dis_y ^ 2));
            obj.prXChangePerS = (dis_x / dis) * speed;
            obj.prYChangePerS = (dis_y / dis) * speed;
            obj.IsMoving = true;
        end
        
        function ScaleTo(obj, dia, speedCmPerS)
            if ~exist('speedCmPerS', 'var') || isempty(speedCmPerS)
                speedCmPerS = .5;
            end
            obj.prDiameterTarget = dia;
            obj.ScaleSpeed = speedCmPerS;
            dis = dia - obj.Diameter;
            obj.prDiaChangePerSec = dis * obj.ScaleSpeed;
            obj.IsScaling = true;
        end
        
        function Update(obj)
            
            % time elapsed since last update
            elap = teGetSecs - obj.prLastUpdateTime;
           
            obj.UpdateMovement(elap);
            obj.UpdateRotation(elap);
            obj.UpdateScale(elap);
            obj.HandleRunningSchedule

            obj.prLastUpdateTime = teGetSecs;
            
        end
        
        function UpdateMovement(obj, elap)
            if obj.IsMoving
                % calculate x- and y-change since last update. Calculate
                % new x and y coords
                xc = obj.prXChangePerS * elap;
                yc = obj.prYChangePerS * elap;
                xn = obj.X + xc;
                yn = obj.Y + yc;
                
                % caluclate distance from current point to target, and from
                % new position to target
                dis_x = obj.prMoveTarget(1) - xn;
                dis_y = obj.prMoveTarget(2) - yn;
                dis_cur = sqrt(((obj.prMoveTarget(1) - obj.X) ^ 2) + ((obj.prMoveTarget(2) - obj.Y) ^ 2));
                dis_new = sqrt((dis_x ^ 2) + (dis_y ^ 2));
                
                % if current distance is closer than new distance, stop
                % moving. Otherwise update x, y
                if dis_cur < dis_new
                    xn = obj.prMoveTarget(1);
                    yn = obj.prMoveTarget(2);
                    obj.IsMoving = false;
                    obj.prMoveTarget = [nan, nan];
                    obj.prXChangePerS = 0;
                    obj.prYChangePerS = 0;
                end
                obj.X = xn;
                obj.Y = yn;
            end
        end
        
        function UpdateRotation(obj, elap)
            if obj.IsRotating
                obj.Rotation = obj.Rotation + (obj.RotateSpeed * elap);
            end
        end
        
        function UpdateScale(obj, elap)
            if obj.IsScaling
                % calculate diameter change since last update. Calculate
                % new diameter
                dc = obj.prDiaChangePerSec * elap;
                dn = obj.Diameter + dc;
                
                % calculate current and new distance from target
                dis_cur = abs(obj.prDiameterTarget - obj.Diameter);
                dis_new = abs(obj.prDiameterTarget - dn);
                
                % if current distance is closer to target than new
                % distance, stop scaling. Otherwise update diameter 
                if dis_cur < dis_new
                    dn = obj.prDiameterTarget;
                    obj.IsScaling = false;
                    obj.prDiameterTarget = nan;
                    obj.prDiaChangePerSec = 0;
                end
                obj.Diameter = dn;
            end
        end        
        
        function ClearAndInitResults(obj)
            obj.prResults = table;
        end
        
        function val = get.Schedule(obj)
            val = obj.prSchedule;
        end
        
        function set.Schedule(obj, val)
            obj.ClearAndInitResults
            % if no 3rd valid column has been passed, assume all invalid
            % (i.e. initial calibration) and create a vector of false
            if size(val, 2) == 2
                val(:, 3) = zeros(size(val, 1), 1);
            end            
            obj.prScheduleIdx = 1;
            obj.prSchedule = val;
            obj.X = obj.prSchedule(1, 1);
            obj.Y = obj.prSchedule(1, 2);
        end
        
        function val = get.Results(obj)
            val = obj.prResults;
        end
        
        function val = get.ScheduleRunning(obj)
            val = obj.prRunning;
        end
        
        function set.prDiaChangePerSec(obj, val)
            obj.prDiaChangePerSec = val;
        end
        
%         function set.prState(obj, val)
%             
%             obj.prState = val;
%             
%             
%             
%         end
        


%         function set.prSchedule(obj, val)
%             
%             dbs = dbstack;
%             if any(cellfun(@(x) contains(x, 'InitSchedule'), {dbs.name}))
%             
%             else
%                 
%                 if ismember('gaze', val.Properties.VariableNames)
%                     sz = cellfun(@(x) size(x, 2), val.gaze)
%                 end
%                 
%                 disp(val.gaze)
%                 arrayfun(@disp, dbstack)
%                 
%             end
%                 
%                 obj.prSchedule = val;
% 
%             
%         end

    end
    
    methods (Access = private)
        
        function findNextPointInSchedule(obj)
            
            % if any points are yet to be measured, prioritise those. If
            % all points are measured, move through those than are not
            % valid
            if ~all(obj.prSchedule.measured)
                
                % not all measured, find next unmeasured
                obj.prScheduleIdx = find(~obj.prSchedule.measured, 1);
                
                if obj.prPresenter.FullDebugOutput
                    teEcho('teCalibrationPoint:findNextPointInSchedule: not all points measured yet, next unmeasured is %d\n',...
                        obj.prScheduleIdx);
                end
                
            elseif ~all(obj.prSchedule.valid)
                
                % all measured, find next point that is measured but not
                % valid
                
                % find all possible next points
                idx_all = find(~obj.prSchedule.valid);
                if length(idx_all) == 1
                    % only one possible point left, so that is the next one
                    obj.prScheduleIdx = idx_all;
                else
                    % remove the current point index (to prevent endlessly
                    % repeating one point), then pick a random point from
                    % any that are left
                    idx_all(idx_all == obj.prScheduleIdx) = [];
                    obj.prScheduleIdx = idx_all(randi(length(idx_all)));
                end
                    
                if obj.prPresenter.FullDebugOutput
                    teEcho('teCalibrationPoint:findNextPointInSchedule: all points measured, but some not valid, next invalid points is %d',...
                        obj.prScheduleIdx);
                end                
                
            else
                
                % no unmeasured or invalid points left, so return empty
                % (i.e. we are finished)
                obj.prScheduleIdx = [];
                
                if obj.prPresenter.FullDebugOutput
                    teEcho('teCalibrationPoint:findNextPointInSchedule: all points are measured and valid, no points left.',...
                        obj.prScheduleIdx);
                end                
                
                
            end

        end
        
    end
            
    
end