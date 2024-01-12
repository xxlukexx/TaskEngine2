% Create an instance of the presenter class. This handles most of the
% functions that task engine offers, including opening windows, drawing to
% the screen, and logging data

    pres = tePresenter;
    
    % skip sync tests (these almost always fail on any modern Apple
    % hardware)
    pres.SkipSyncTests = true;
    
    % set the monitor on which to open the window to draw stimuli. If no
    % external monitor, use 0, which will open in a smaller window on the
    % main screen. 
    pres.MonitorNumber = 0;
    
    % set the size of the monitor. Dimensions of all stimului draw by te2
    % are specified in cm, and automatically scaled to pixels at runtime
    % (allowing for multisite operation with different monitor
    % sizes/resolutions). First arg is the diagonal size of the monitor,
    % followed by x aspect ratio, then y aspect ratio. Final argument
    % specifies that the diagonal measurement is in inches, rather than the
    % default cm - this is easier becase most monitors are marketed in
    % inches)
    pres.SetMonitorDiagonal(24, 16, 9, 'inches')
    
    % set the position of the preview window
    pres.SetPreviewPositionFromPreset('bottomleft')
    
    % scale the preview window to 1/4 of the screen size
    pres.PreviewScale = 0.25;
    
    % open the main window and preview window
    pres.OpenWindow
    
% We can load a video in exactly the same way as we loaded an image, using
% the teStim object. However, since we want the presenter to handle finding
% the next frame, we first add it to the presenter's .Stim collection. 

    % load the video into the presenter's .Stim collection, name it 'vid'
    pres.LoadStim(...
        fullfile(pres.CONST_PATH_ET, 'infant', 'et_calib_vid.mp4'), 'vid');
    
    % start playing, then loop until the video stops, or until Tab is
    % pressed
    pres.PlayStim('vid');
    while vid.Playing && ~pres.KeyPressed('Tab')
        
        % draw the stimulus to the screen in the same way as we did for the
        % image. This time we don't specify the size of the stimulus - it
        % will default to fullscreen
        pres.DrawStim('vid')
        pres.RefreshDisplay;
        
    end
    
    % stop playing (ends the sound)
    pres.StopStim('vid');
        

    