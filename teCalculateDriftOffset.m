function [loff, roff] = teCalculateDriftOffset(drift)

    % calculate x, y offset between point and gaze
    loffx = abs(drift.PointX - drift.LeftGazeX);
    loffy = abs(drift.PointY - drift.LeftGazeY);
    roffx = abs(drift.PointX - drift.RightGazeX);
    roffy = abs(drift.PointY - drift.RightGazeY);
    
    % distance
    loff = sqrt((loffx .^ 2) + (loffy .^ 2));
    roff = sqrt((roffx .^ 2) + (roffy .^ 2));

end