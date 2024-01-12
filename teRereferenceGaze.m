function gaze = teRereferenceGaze(gaze, monitorSize, windowSize)

    if isempty(gaze), return, end
    
    if ~all(size(monitorSize) == [1, 2])
        error('Monitor size must be a 1 x 2 vector [width, height].')
    end

    if ~all(size(windowSize) == [1, 2])
        error('Monitor size must be a 1 x 2 vector [width, height].')
    end

    % put dimensions in easily read variables
    mw = monitorSize(1);
    mh = monitorSize(2);
    ww = windowSize(1);
    wh = windowSize(2);
    
    % work out scaling factors for x and y
    scaleX = mw / ww;
    scaleY = mh / wh;
        
    % subtract mid-point from data
    gaze(:, 2) = gaze(:, 2) - .5;
    gaze(:, 3) = gaze(:, 3) - .5;
    gaze(:, 17) = gaze(:, 17) - .5;
    gaze(:, 18) = gaze(:, 18) - .5;   

    % scale gaze data
    gaze(:, 2) = gaze(:, 2) * scaleX;
    gaze(:, 3) = gaze(:, 3) * scaleY;
    gaze(:, 17) = gaze(:, 17) * scaleX;
    gaze(:, 18) = gaze(:, 18) * scaleY;
    
    % re-centre
    gaze(:, 2) = gaze(:, 2) + .5;
    gaze(:, 3) = gaze(:, 3) + .5;
    gaze(:, 17) = gaze(:, 17) + .5;
    gaze(:, 18) = gaze(:, 18) + .5;
    
end