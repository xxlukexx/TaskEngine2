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
    % inches). 
    pres.SetMonitorDiagonal(34, 21, 9, 'inches')
    
    % set the position of the preview window
    pres.SetPreviewPositionFromPreset('bottomleft')
    
    % scale the preview window to 1/4 of the screen size
    pres.PreviewScale = 0.25;
    
    % open the main window and preview window
    pres.OpenWindow
    
% Set up the eye tracker. Only currently supports Tobii eye trackers, and
% two "fake" eye trackers:
%
%   teEyeTracker_mouse      -   uses the mouse to fake gaze data at ~60Hz
%   teEyeTracker_keyboard   -   when the space bar is pressed, fake gaze
%                               data is created at the centre of the screen
%                               ([0.5, 0.5]). When the button is released,
%                               fake missing gaze is created. This allowed
%                               for online attention coding (looking/not
%                               looking) using the same format of gaze data
%                               as a real eye tracker (allowing the same
%                               analysis code to handle both scenarios)

    % set the presenter's EyeTracker property to be a subclass of the
    % teEyeTracker class that specifically works with Tobii eye trackers.
    % Note that as soon as the .EyeTracker property is set, the class will
    % begin searching for a Tobii eye tracker. If you want to run this
    % script without an eye tracker, change the code below to set the
    % teEyeTracker_mouse subclass instead. 
    pres.EyeTracker = teEyeTracker_mouse;
%     pres.EyeTracker = teEyeTracker_tobii;
    
    % get eyes and calibrate (this will not do anything if using the
    % mouse)
    pres.ETGetEyesAndCalibrate;
    
% We want to create two AOIs, and we'll put them around two images on the
% screen. Before we create the AOIs, we'll load a folder of stimuli into
% the presenter's .Stim collection, then choose a couple to draw

    % by default, te2 loads a bunch of generic stimuli that it needs
    % internally, including some fixation stimuli. We'll use two of those.
    % To look up an element from the .Stim collection we refer to it by
    % name. If you don't know the name you can do:
    disp(pres.Stim.Keys')
    
    % ...or alternatively we can call the DrawStimThumbnails method to draw
    % them all to the current window
    pres.DrawStimThumbnails
    
    % find two stimuli and pull them out of the collection. We don't
    % actually need to do this to draw them, but it allows us to give them
    % sensible variable names
    left = pres.Stim('fix_img_adult_00001.png');
    right = pres.Stim('fix_img_adult_00002.png');
    
    % determine where on the screen we want to draw them. Recall that this
    % needs to be done in cm. To keep things simple, we'll place them 6 cm
    % from the horizontal edge of the screen, and have them centred
    % vertically (a la a paired vis pref task). The .DrawingSize property
    % is the dimensions of the screen in cm, in [width, height]:
    y = pres.DrawingSize(2) / 2;            % vertically centred
    x_left = 6;                             % 6cm from left
    x_right = pres.DrawingSize(1) - 6   ;   % 6cm from right
    
    % build rects centred on these [x, y] coords. The teRectFromDims
    % function will take [x, y] and [width, height] coords, and return a
    % rect of the appropriate size, centred on [x, y]:
    rect_left = teRectFromDims(x_left, y, 8, 8);        % 8cm square
    rect_right = teRectFromDims(x_right, y, 8, 8);   
    
    % the AOIs will be over the stimuli, but we'll make them a bit bigger
    % to account for noisy data/poor calibration
    rect_aoi_left = pres.MagnifyRect(rect_left, 1.2);
    rect_aoi_right = pres.MagnifyRect(rect_right, 1.2);
    
    % AOIs operate in a different coord system to stimuli. Stimuli are
    % specified in cm, but AOIs in normalised coords (0-1) relative to the
    % screen (because this is the format of the eye tracking data). Before
    % we create the AOIs, we need to convert their coords from cm to
    % normalised
    rect_aoi_left = pres.ScaleRect(rect_aoi_left, 'cm2rel');
    rect_aoi_right = pres.ScaleRect(rect_aoi_right, 'cm2rel');
    
    % create two AOI objects. For each, we'll set a trigger tolerance of
    % 50ms. This prevents random stray samples of noisy gaze data from
    % triggering the AOI erroneously. 
    aoi_left = teAOI(rect_aoi_left, 0.050);
    aoi_right = teAOI(rect_aoi_right, 0.050);
    
    % add these AOIs to the .EyeTracker property so that it can score them
    % against the ET data on each frame
    pres.EyeTracker.AOIs('left') = aoi_left;
    pres.EyeTracker.AOIs('right') = aoi_right;
    
% Now we'll loop until Tab is pressed, drawing each stimulus. For some
% simple gaze contingency, we'll rotate the stimuli when gaze falls upon
% them. 

    % store rotation value for each stim
    rot_left = 0;
    rot_right = 0;

    % flush the keyboard buffer to make sure there isn't an errant Tab
    % hiding in there
    pres.KeyFlush
    
    while ~pres.KeyPressed('Tab')
        
        % darw stim (including their rotation value) and refresh
        pres.DrawStim(left, rect_left, rot_left);
        pres.DrawStim(right, rect_right, rot_right)
        pres.RefreshDisplay;
        
        % if an AOI has gaze, increment the rotation value
        if aoi_left.HasGaze
            rot_left = rot_left + .7;
        elseif aoi_right.HasGaze
            rot_right = rot_right + .7;
        end
        
    end
    
% extract some basic AOI metrics

    figure
    bar([aoi_left.Prop, aoi_right.Prop])
    set(gca, 'xticklabel', {'Left', 'Right'})
    ylabel('Proportion Looking Time')
    ylim([0, 1])
