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
    
% draw some stimuli using psychtoolbox (i.e. without using any te2
% functions). 

    % read an image
    img = imread(fullfile(pres.CONST_PATH_FIXATIONS, 'infant',...
        'fix_img_baby_00001.png'));

    % set background colour to black
    Screen('FillRect', pres.PTBWindowPtr, [100, 100, 100])

    % create PTB texture, passing it the te2 window pointer of the open
    % screen via the presenter's .PTBWindowPtr property
    tex = Screen('MakeTexture', pres.PTBWindowPtr, img);

    % draw & flip
    fprintf('Drawing fully manually via PTB - note preview window doesn''t update...\n');
    Screen('DrawTexture', pres.PTBWindowPtr, tex, [], [100, 100, 300, 300])
    Screen('Flip', pres.PTBWindowPtr);

    KbWait;

    % note that the stimulus has not appeared on the preview window. This
    % is because we bypassed te2 and drew straight to the PTB window. We
    % can however still use PTB directly whilst drawing to the preview
    % window. Instead of drawing to pres.PTBWindowPtr, we draw to
    % pres.WindowPtr instead. And, instead of calling Screen('Flip')
    % directly, we call pres.RefreshDisplay - ensuring that the preview is
    % upated. 
    %
    %   pres.PTBWindowPtr   -   the actual PTB window pointer of the open
    %                           onscreen window. Rarely used in normal te2
    %                           operation, but essential for - e.g. -
    %                           manually creating a texture from a loaded
    %                           image matrix 
    %
    %   pres.WindowPtr      -   the "drawing pane" that te2 uses for
    %                           everything. Technicallly a PTB offscreen
    %                           window (so an Open GL texture that we can
    %                           draw to). When pres.Refresh is called, this
    %                           is drawn to both the main stimulus window,
    %                           and also to the preview window. Note that
    %                           this pointer cannot be used to - e.g. -
    %                           create a texture, as PTB requires an actual
    %                           onscreen window to do this. But after
    %                           you've made the texture, you can draw it to
    %                           this window. 
    fprintf('Drawing manually via PTB but to the darwing pane - note the preview now updates...\n');
    Screen('DrawTexture', pres.WindowPtr, tex, [], [100, 100, 300, 300])
    pres.RefreshDisplay

    KbWait;

% now perform the same drawing operation fully in te2. First we create a
% stimulus object, load the image matrix into it, then use that for all
% drawing. Note that unlike in the previous examples, the image is now
% drawn with a transparent background. That's because we didn't manually
% shift the alpha channel (optionally returned by imread) into the fourth
% (alpha) element of the third (colour) dimension of the image matrix (!).
% te2 handles this inside the stim class, so we don't have to bother
% faffing around with it here. 

    % create a stim object, name it 'img'
    stim = teStim(fullfile(pres.CONST_PATH_FIXATIONS, 'infant',...
        'fix_img_baby_00001.png'), 'img');

    % draw it. Note that dimensions are specifed in cm. If using only one
    % monitor, bear in mind that the dimensions are relative to the entir   e
    % screen, but scaled down to the smaller window at the top left. If
    % drawing to a second monitor in fullscreen, the dimensions should be
    % totally correct)
    % nb. the preview window hasn't updated - this is because it's
    % always one frame behind the main stimulus drawing. This is a
    % compromise that trades of one frame of latency on the preview
    % window for better timing on the main window. 
    fprintf('Drawing with te2...\n');
    pres.DrawStim(stim, [3, 3, 6, 6]);
    pres.RefreshDisplay

        

    