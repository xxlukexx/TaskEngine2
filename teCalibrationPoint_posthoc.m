classdef teCalibrationPoint_posthoc < teCalibrationPoint

    methods
        
        function HandleRunningSchedule(obj)
            
            switch obj.prState
                                   
                case 'acquiring_gaze'
                    
                    % get gaze data
                    from = obj.prSchedule.t_onset(obj.prScheduleIdx);
                    to = obj.prSchedule.t_offset(obj.prScheduleIdx);
                    gazeBuffer =...
                        obj.prPresenter.EyeTracker.GetGaze(from, to);
                    gaze = etGazeDataBino('te2', gazeBuffer);
                    
                    % use virtual window size to calculate gaze in degrees
                    % of visual angle. We assume 60cm from the screen,
                    % since this is roughly the centre of most head boxes.
                    % We could use head pos from the gaze data but 1) not
                    % all eye trackers support this, and 2) the data can be
                    % noisy and only works on bino data, which is not
                    % guaranteed
                    gaze.ScreenDimensions = obj.prPresenter.MonitorSize;
                    gaze.DistanceFromScreen = 60;
                    
                    % calculate accuracy/precision, first in normalised
                    % (ET) coords, then in degrees
                    pt_x = obj.prSchedule.x(obj.prScheduleIdx);
                    pt_y = obj.prSchedule.y(obj.prScheduleIdx);
                    [acc, prec] = etCalculateDrift(pt_x, pt_y, gaze.X,...
                        gaze.Y);
                    
                    sw = obj.prPresenter.MonitorSize(1);
                    sh = obj.prPresenter.MonitorSize(2);
                    [pt_x_deg, pt_y_deg] = norm2deg(pt_x, pt_y, sw, sh, 60);
                    [acc_deg, prec_deg] = etCalculateDrift(pt_x_deg,...
                        pt_y_deg, gaze.XDeg, gaze.YDeg);                    
                    
                    % summarise 
                    timeStamp = teGetSecs;
                    tmp = table(timeStamp, pt_x, pt_y, true, {gaze}, acc, prec,...
                        acc_deg, prec_deg, 'VariableNames',...
                        {'Timestamp', 'PointX', 'PointY', 'Measured', 'Gaze',...
                        'Accuracy', 'Precision', 'AccuracyDeg',...
                        'PrecisionDeg'});
                    obj.prResults(end + 1, :) = tmp;
                    
                    % make log item
                    li = struct(...
                        'Source', 'posthoc_calibration',...
                        'Topic', 'phc_measurement',...
                        'TimeStamp', timeStamp,...
                        'PointX', pt_x,...
                        'PointY', pt_y,...
                        'Accuracy', acc,...
                        'AccuracyDeg', acc_deg,...
                        'Precision', prec,...
                        'PrecisionDeg', prec_deg);
                    obj.prPresenter.AddLog(li);
                    
                    obj.prState = 'finished';
                    
                otherwise
                    
                    % not PHC-specific, call superclass method
                    HandleRunningSchedule@teCalibrationPoint(obj)   
                    
            end
            
        end
        
    end
    
end