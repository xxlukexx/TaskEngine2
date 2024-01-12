function vars = teFixation(pres, varargin)
    
    parser = inputParser;
    parser.addParameter('x', [], @(x) isnumeric(x) && isscalar(x) && x > 0);
    parser.addParameter('y', [], @(x) isnumeric(x) && isscalar(x) && x > 0);
    parser.addParameter('useeyetracker', false, @(x) islogical(x) && isscalar(x));
    parser.addParameter('transparentbg', false, @(x) islogical(x) && isscalar(x));    
    parser.parse(varargin{:});
    x = parser.Results.x;
    y = parser.Results.y;
    useET = parser.Results.useeyetracker;
    transBG = parser.Results.transparentbg;
    
    % if either/all [x, y] are empty, use the centre of the screen
    if isempty(x) || isempty(y)
        [x, y] = pres.DrawingCentre;
    end
    
    % update keyboard
    pres.KeyUpdate
    
    % get stim
    fix_img = pres.Stim.LookupRandom('Keys', 'fix_img');
    fix_snd = pres.Stim.LookupRandom('Keys', 'fix_snd');    
    
    % set size/pos
    size_min = 3;
    size_max = 5;
    rect = teRectFromDims(x, y, size_min, size_min);
    
    % AOI
    if useET
        aoi_rect_cm = teRectFromDims(x, y, size_max, size_max);
        aoi_rect_rel = pres.ScaleRect(aoi_rect_cm, 'cm2rel');
        aoi = teAOI(aoi_rect_rel, .050);
        pres.EyeTracker.AOIs('fixation') = aoi;
    end
    
    % keyframes
    kf = teKeyFrame;
    kf.Duration = 0.66;
    kf.Loop = true;
    kf.AddTimeValue(0.00, size_min);
    kf.AddTimeValue(0.50, size_max);
    kf.AddTimeValue(1.00, size_min);
    
    % if keep transparent background, take a copy of the current screen
    if transBG
        pres.RefreshDisplay;
        tex_bg = Screen('OpenOffscreenWindow', pres.PTBWindowPtr,...
            [], [0, 0, pres.Resolution]);
        Screen('CopyWindow', pres.CurrentDrawing, tex_bg);
%         img_bg = Screen('GetImage', tex_bg);
%         stim_bg = teStim;
%         stim_bg.ImportImage(img_bg);
%         Screen('CopyWindow', pres.WindowPtr, tex_bg);
    end
    
    % animation loop
    flipTime = nan;
    firstFrame = true;
    hasGaze = false;
    pres.KeyFlush
    pres.KeyUpdate
    pres.PlayStim(fix_snd);
    while ~hasGaze && ~pres.KeyPressed(pres.KB_MOVEON) &&...
            ~pres.ExitTrialNow && ~pres.SkipAllFixations
        
        % draw
        if transBG
            Screen('DrawTexture', pres.WindowPtr, tex_bg);
%             pres.DrawStim(stim_bg)
        end
        pres.DrawStim(fix_img, rect)
        flipTime = pres.RefreshDisplay;
        
        % update time if first frame
        if firstFrame
            % send event
            pres.SendRegisteredEvent('GC_FIXATION_ONSET', flipTime);
            % set key frame start time
            kf.StartTime = flipTime;
            % set first frame flag to false
            firstFrame = false;
        end
        
        % update size
        newSize = kf.Value;
        rect = teRectFromDims(x, y, newSize, newSize);                                                                                                  
        
        % check gaze
        if useET
            hasGaze = aoi.Hit;
        end
        
    end
    
    % if the fixation has been skipped, the time of the last flip
    % (flipTime) may be missing. In that case, set it to the current time
    % (since no stimuli have been displayed, this is the best estimate of
    % when the fixation ended - even though it never really began)
    if isnan(flipTime), flipTime = teGetSecs; end
    
    % send markers
    if pres.KeyPressed(pres.KB_MOVEON) 
        pres.SendRegisteredEvent('SKIPPED', flipTime - .05);
        pres.SendEvent('GC_FIXATION_SKIPPED_MOVEON', flipTime - .05, 'log');
    elseif pres.ExitTrialNow
        pres.SendRegisteredEvent('SKIPPED', flipTime - .05);
        pres.SendEvent('GC_FIXATION_SKIPPED_EXIT', flipTime - .05, 'log');
    elseif pres.SkipAllFixations
        pres.SendRegisteredEvent('SKIPPED', flipTime - .05);
        pres.SendEvent('GC_FIXATION_SKIPPED_ALLFIX', flipTime - .05, 'log');
    end 
    pres.SendRegisteredEvent('GC_FIXATION_OFFSET', flipTime);
    
    % delete AOI
    if useET
        pres.EyeTracker.AOIs.RemoveItem('fixation');
    end
    
    % flush keyboard
    pres.KeyFlush
    pres.KeyUpdate
    
end
        
        
  