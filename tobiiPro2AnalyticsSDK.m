function [mb, tb] = tobiiPro2AnalyticsSDK(data_pro)

    numSamps = length(data_pro.device_time_stamp);
    mb = zeros(numSamps, 26);
    tb = zeros(numSamps, 2, 'int64');
    
    % recode validity
    left_val = repmat(4, size(mb, 1), 1);
    left_val(data_pro.left_gaze_point_validity) = 0;
    right_val = repmat(4, size(mb, 1), 1);
    right_val(data_pro.right_gaze_point_validity) = 0;    

    mb(:, 1:3)      =   data_pro.left_gaze_origin_in_user_coordinate_system;
    mb(:, 4:6)      =   data_pro.left_gaze_origin_in_trackbox_coordinate_system;
    mb(:, 7:8)      =   data_pro.left_gaze_point_on_display_area;
    mb(:, 9:11)     =   data_pro.left_gaze_point_in_user_coordinate_system;
    mb(:, 12)       =   data_pro.left_pupil_diameter;
    mb(:, 13)       =   left_val;
    
    mb(:, 14:16)    =   data_pro.left_gaze_origin_in_user_coordinate_system;
    mb(:, 17:19)    =   data_pro.left_gaze_origin_in_trackbox_coordinate_system;
    mb(:, 20:21)    =   data_pro.left_gaze_point_on_display_area;
    mb(:, 22:24)    =   data_pro.left_gaze_point_in_user_coordinate_system;
    mb(:, 25)       =   data_pro.left_pupil_diameter;
    mb(:, 26)       =   right_val;   
    
    tb(:, 1)        =   data_pro.device_time_stamp;
    
    
%     for s = 1:numSamps
%         % convert validity 
%         if data_pro(s).LeftEye.GazePoint.Validity, val = 0; else val =4; end
%         % left eye
%         mb(s, 1:3)      =   data_pro(s).LeftEye.GazeOrigin.InUserCoordinateSystem;
%         mb(s, 4:6)      =   data_pro(s).LeftEye.GazeOrigin.InTrackBoxCoordinateSystem;
%         mb(s, 7:8)      =   data_pro(s).LeftEye.GazePoint.OnDisplayArea;
%         mb(s, 9:11)     =   data_pro(s).LeftEye.GazePoint.InUserCoordinateSystem;
%         mb(s, 12)       =   data_pro(s).LeftEye.Pupil.Diameter;
%         mb(s, 13)       =   val;
%         % right eye
%         mb(s, 14:16)    =   data_pro(s).RightEye.GazeOrigin.InUserCoordinateSystem;
%         mb(s, 17:19)    =   data_pro(s).RightEye.GazeOrigin.InTrackBoxCoordinateSystem;
%         mb(s, 20:21)    =   data_pro(s).RightEye.GazePoint.OnDisplayArea;
%         mb(s, 22:24)    =   data_pro(s).RightEye.GazePoint.InUserCoordinateSystem;
%         mb(s, 25)       =   data_pro(s).RightEye.Pupil.Diameter;
%         mb(s, 26)       =   val;
%         % timestamps
%         tb(s, 1)        =   data_pro(s).DeviceTimeStamp;
%     end
    
end