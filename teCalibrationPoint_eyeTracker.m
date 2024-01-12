classdef teCalibrationPoint_eyeTracker < teCalibrationPoint
    
    properties (SetAccess = private)
        Eyetracker
        ETLastCalibrationSuccess = false
        ETLastCalibrationResults = struct
%         ETLastCalibrationOnset 
%         ETLastCalibrationOffset
    end
    
    methods
        
        function obj = teCalibrationPoint_eyeTracker(varargin)
            if nargin <= 2 || ~isa(varargin{3}, 'teEyeTracker')
                error('Third input argument must be a teEyeTracker object.')
            end
            et = varargin{3};
            varargin = varargin(1:2);
            obj = obj@teCalibrationPoint(varargin{:});
            obj.Eyetracker = et;

        end
        
        function InitSchedule(obj, calibDef)
        % most of the work here is done by the superclass to define generic 
        % storage for each calib point. We add a column to store
        % tobii-specific data
        
            % superclass method
            InitSchedule@teCalibrationPoint(obj, calibDef);
        
            numPoints = size(calibDef, 1);
            obj.prSchedule.tobii_data = cell(numPoints, 1);
            
        end        
        
        function [suc, oc] = RunSchedule(obj)
            obj.Eyetracker.BeginCalibration;
            [suc, oc] = RunSchedule@teCalibrationPoint(obj);
        end

        function HandleRunningSchedule(obj)
            
%             if isnan(obj.ETLastCalibrationOnset(obj.prScheduleIdx))
%                 obj.ETLastCalibrationOnset(obj.prScheduleIdx) = teGetSecs;
%             end
%             % set the calibration offset here in case an external function
%             % or class cancels the calibration midway through. If the
%             % calibration runs its course, this timestamp will indeed then
%             % by the "proper" offset 
%             if isnan(obj.ETLastCalibrationOffset(obj.prScheduleIdx))
%                 obj.ETLastCalibrationOffset(obj.prScheduleIdx) = teGetSecs;
%             end

            switch obj.prState
                
                case 'measuring'
                    
                    % if using an eye tracker, call it's
                    % .CalibratePoint method to do whatever that eye
                    % tracker needs to
                    onset = teGetSecs;
                    pt = obj.Eyetracker.CalibratePoint(obj.X, obj.Y);  
                    offset = teGetSecs;
                    
                    % store onset, offset, gaze data between on/offset, and
                    % tobii calib data into the schedule
                    obj.prSchedule.t_onset(obj.prScheduleIdx) = onset;
                    obj.prSchedule.t_offset(obj.prScheduleIdx) = offset;
                    obj.prSchedule.tobii_data{obj.prScheduleIdx} = pt;
                    obj.prSchedule.measured(obj.prScheduleIdx) = true;
                    
                    % determine what to do after measuring according to the
                    % current state and quality of the calibration
                    if ~all(obj.prSchedule.measured)
                        % not all points yet measured, do these first
                        obj.prState = 'init_next_point';       
                    else
                        
                        if all(obj.prSchedule.valid)
                            
                            % if all points are valid, we are done
                            obj.prState = 'finished';
                            obj.Eyetracker.EndCalibration;
                            
                        else
                            
                            % all points are measured, but some were not
                            % valid. At this point, Tobii has computed what
                            % it thinks is a valid calibration, but we
                            % think we can do better. Keep trying until the
                            % user interrupts by pressing Tab. 
                            teEcho('%d of %d points do not meet criteria, retrying, press %s to stop and move on...\n',...
                                sum(~obj.prSchedule.valid),...
                                size(obj.prSchedule, 1),...
                                obj.prPresenter.KB_MOVEON);
                            obj.prState = 'init_next_point';     
                            
                        end
                    end
                    
                    % compute the calibration that we have so far
                    [suc, ~, calib] =...
                        obj.Eyetracker.ComputeCalibration;  
                    
                    % check whether it was successful
                    if suc
                        
                        % successful so far, parse tobii data and calculate
                        % validity for all measured points
                        obj.parseTobiiCalibData(calib)
                        obj.calcCalibValidity
                        
                        % if we have measured all points, then the
                        % calibration was a success, or it might be
                        % 'ongoing' which means 'so far so good, but more
                        % points to measure'
                        if all(obj.prSchedule.measured & obj.prSchedule.valid)
                            obj.LastCalibrationOutcome = 'success';
                        else
                            obj.LastCalibrationOutcome = 'ongoing';
                        end
                        
                    elseif ~suc && all(obj.prSchedule.measured)
                        
                        % if the calibration failed at this point then the
                        % data we collected so far is not good enough, so
                        % mark it as failed, and set state to finished,
                        % meaning we won't try to get any more points
                        obj.LastCalibrationOutcome = 'failed';
                        obj.prState = 'finished';
                        
                        % set all points to not-measured
                        obj.prSchedule.measured =...
                            false(size(obj.prSchedule, 1), 1);
                        
                    end
                        
                    % draw latest results
                    obj.prPresenter.DrawCalibrationResults(obj);
                    
                otherwise
                    
                    % not ET-specific, call superclass method
                    HandleRunningSchedule@teCalibrationPoint(obj)
                    
            end
            
        end

    end
    
    methods (Access = private)
        
        function parseTobiiCalibData(obj, calib)
        % parses an array of tobii calib data containing several points and
        % stores the results in the schedule
        
            if ~isa(calib, 'CalibrationResult')
                error('Must pass a Tobii Pro SDK ''CalibrationResults'' object.')
            end
            
            % check for valid calib data
            if ~calib.Status.Success
                error('Tobii calibratioon was not successful.')
            end
            
            numPoints = length(calib.CalibrationPoints);
            if numPoints == 0
                warning('No calibration points in Tobii calibration data.')
                return
            end
            
            sh = obj.prSchedule;
            
            for p = 1:numPoints
                
                % get position of calib point
                x_p = calib.CalibrationPoints(p).PositionOnDisplayArea(1);
                y_p = calib.CalibrationPoints(p).PositionOnDisplayArea(2);
                
                % look up position in schedule
                idx = abs(sh.x - x_p) < 1e-5 & abs(sh.y - y_p) < 1e-5;
                if ~any(idx)
                    error('Calib point reported by Tobii at [%.3f, %.3f] not found in schedule.',...
                        x_p, y_p);
                end
               
                % get validity for each eye
                idx_val_l = logical(arrayfun(@(x) x.Validity.value,...
                    calib.CalibrationPoints(p).LeftEye));
                idx_val_r = logical(arrayfun(@(x) x.Validity.value,...
                    calib.CalibrationPoints(p).RightEye));

                % get gaze for each eye, filter for valid only
                gaze_l = arrayfun(@(x) x.PositionOnDisplayArea,...
                    calib.CalibrationPoints(p).LeftEye, 'uniform', false);
                gaze_l = vertcat(gaze_l{:});
                gaze_l(~idx_val_l, :) = nan;

                gaze_r = arrayfun(@(x) x.PositionOnDisplayArea,...
                    calib.CalibrationPoints(p).RightEye, 'uniform', false);
                gaze_r = vertcat(gaze_r{:});     
                gaze_r(~idx_val_r, :) = nan;

                % store
                sh.gaze{idx} = [gaze_l, gaze_r];
%                 disp(sh.gaze{idx});
                    
            end
            
            obj.prSchedule = sh;
                        
        end
        
        function calcCalibValidity(obj)
             
            sh = obj.prSchedule;
            numPoints = size(sh, 1);
            
            w = obj.prPresenter.DrawingSize(1);
            h = obj.prPresenter.DrawingSize(2);
                
            for p = 1:numPoints
                
                if ~sh.measured(p), continue, end
                
                % calculate median distance to screen for this point, in
                % order to convert accurately to degrees
                gaze = obj.Eyetracker.GetGaze(sh.t_onset(p), sh.t_offset(p));
                dist = nanmean(gaze(:, [12, 27]), 2);
                sh.dist_med(p) = nanmedian(dist) / 10;
                
                % if distance could not be calculated, use 60cm
                if isnan(sh.dist_med(p))
                    sh.dist_med(p) = 60;
                    warning('Head distance could not be calculated (too many missing samples), assumiming 60cm viewing distance.')
                end
                
                % centroid of gaze
                lx_cent = nanmean(sh.gaze{p}(:, 1));
                ly_cent = nanmean(sh.gaze{p}(:, 2));
                rx_cent = nanmean(sh.gaze{p}(:, 3));
                ry_cent = nanmean(sh.gaze{p}(:, 4));
                
                % accuracy - distance from gaze centroid to calib point
                l_acc = sqrt(((lx_cent - sh.x(p)) .^ 2) + ((ly_cent - sh.y(p)).^ 2));
                r_acc = sqrt(((rx_cent - sh.x(p)) .^ 2) + ((ry_cent - sh.y(p)).^ 2));
                
                % offset from each gaze point to calib point
                lx_off = sh.gaze{p}(:, 1) - lx_cent;
                ly_off = sh.gaze{p}(:, 2) - ly_cent;
                rx_off = sh.gaze{p}(:, 3) - rx_cent;
                ry_off = sh.gaze{p}(:, 4) - ry_cent;    
                l_off = sqrt((lx_off .^ 2) + (ly_off .^ 2));
                r_off = sqrt((rx_off .^ 2) + (ry_off .^ 2));
                
                % precision - distance from each gaze point to calib point
                l_off = sqrt((lx_off .^ 2) + (ly_off .^ 2));
                r_off = sqrt((rx_off .^ 2) + (ry_off .^ 2));
                l_prec = nanrms(l_off);
                r_prec = nanrms(r_off);
                
                % calculate in degrees -- accuracy
                [lx_cent_deg, ly_cent_deg] = norm2deg(lx_cent, ly_cent, w, h, sh.dist_med(p));
                [rx_cent_deg, ry_cent_deg] = norm2deg(rx_cent, ry_cent, w, h, sh.dist_med(p));
                [x_calib_deg, y_calib_deg] = norm2deg(sh.x(p), sh.y(p), w, h, sh.dist_med(p));
                l_acc_deg = sqrt(((lx_cent_deg - x_calib_deg) .^ 2) + ((ly_cent_deg - y_calib_deg).^ 2));
                r_acc_deg = sqrt(((rx_cent_deg - x_calib_deg) .^ 2) + ((ry_cent_deg - y_calib_deg).^ 2));
                
                % precision
                [lx_off_deg, ly_off_deg] = norm2deg(lx_off, ly_off, w, h, sh.dist_med(p));
                [rx_off_deg, ry_off_deg] = norm2deg(rx_off, ry_off, w, h, sh.dist_med(p));
                l_off_deg = sqrt((lx_off_deg .^ 2) + (ly_off_deg .^ 2));
                r_off_deg = sqrt((rx_off_deg .^ 2) + (ry_off_deg .^ 2));
                l_prec_deg = nanrms(l_off_deg);
                r_prec_deg = nanrms(r_off_deg);
                
                % store in schedule
                sh.accuracy_l(p) = l_acc;
                sh.accuracy_r(p) = r_acc;
                sh.precision_l(p) = l_prec;
                sh.precision_r(p) = r_prec;                
                sh.accuracy_deg_l(p) = l_acc_deg;
                sh.accuracy_deg_r(p) = r_acc_deg;
                sh.precision_deg_l(p) = l_prec_deg;
                sh.precision_deg_r(p) = r_prec_deg;   
                sh.offset_l_x{p} = lx_off;
                sh.offset_l_y{p} = ly_off;
                sh.offset_r_x{p} = rx_off;
                sh.offset_r_y{p} = ry_off;
                sh.offset_l{p} = l_off;
                sh.offset_r{p} = r_off;
                sh.centroid_l_x(p) = lx_cent;
                sh.centroid_l_y(p) = ly_cent;
                sh.centroid_r_x(p) = rx_cent;
                sh.centroid_r_y(p) = ry_cent;
                
            end
            
            % calc validity against crit
            crit_acc = obj.prPresenter.ETCalibMinValidAccuracyDeg;
            crit_prec = obj.prPresenter.ETCalibMinValidPrecisionDeg;
            sh.val_left = sh.accuracy_deg_l < crit_acc & sh.precision_deg_l < crit_prec;
            sh.val_right = sh.accuracy_deg_r < crit_acc & sh.precision_deg_r < crit_prec;
            sh.valid = sh.val_left | sh.val_right;

            obj.prSchedule = sh;
            
        end
                
    end
    
end