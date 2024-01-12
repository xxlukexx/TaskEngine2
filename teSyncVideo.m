function allSync = teSyncVideo(path_in)

    warning('TODO: replace error checking around file loop')

    % add axing to java path (for processing QR codes)
    path_te = teFindRootFolder;
    path_zxing = fullfile(path_te, 'zxing');
    if ~exist(path_zxing, 'dir')
        error('Could not find zxing path at %s.', path_zxing)
    else
        javaaddpath(fullfile(path_zxing, 'core-3.3.3.jar'))
        javaaddpath(fullfile(path_zxing, 'javase-3.3.3.jar'))
    end

    % check input arg
    isList = iscellstr(path_in);
    isDir = ischar(path_in) && exist(path_in, 'dir');
    isFile = ischar(path_in) && exist(path_in, 'file');
    if ~isList && ~isDir && ~isFile 
        error('Path ''%s'' is neither a file nor a folder.', path_in);
    end
    
    % define valid video formats
    valFormats = {'avi', 'mp4', 'm4v', 'mov'};

    % if path_in is a folder, search it
    if isDir
        % get all files
        d = dir(path_in);
        % make full file paths
        allFiles = cellfun(@(filename) fullfile(path_in, filename),...
            {d.name}, 'uniform', false)';
        % get extensions
        [~, ~, ext] = cellfun(@fileparts, allFiles, 'uniform', false);
        % strip dot
        ext = cellfun(@(x) strrep(x, '.', ''), ext, 'uniform', false);
        % find files with valid extensions
        idx_valExt = ismember(ext, valFormats);
        % filter
        allFiles(~idx_valExt) = [];
        
    elseif isFile
        % just place the file into a cell array, so that it can be
        % processed in the same way as a list of files
        allFiles{1} = path_in;
        
    elseif isList
        % input is a cellstr of paths
        allFiles = path_in;
        
    end
    
    % check there are some files
    numFiles = length(allFiles);
    if numFiles == 0
        error('No files with valid extensions found.')
    end
    
    % process
    allSync = cell(numFiles, 1);
    for f = 1:numFiles
        
%         try
            % sync one video
            allSync{f} = syncOneVideo(allFiles{f});
%         catch ERR
%             allSync{f}.success = false;
%             allSync{f}.outcome = sprintf('%s', ERR.message);
%         end
        
        % write sync struct
        sync = allSync{f};
        [path_in, fil, ext] = fileparts(allFiles{f});
        file_out = fullfile(path_in, sprintf('%s%s#%s#.sync.mat',...
            fil, ext, sync.GUID{1}));
        save(file_out, 'sync')    

    end
    
    % if one single file, remove from cell array
    if numFiles == 1
        allSync = allSync{1};
    end
        
end

function sync = syncOneVideo(file_in)

    teEcho(sprintf('Processing [%s]\n', file_in));
    
    sync = struct;
    sync.file_in = file_in;
    sync.success = false;
    sync.outcome = 'unknown error';
    sync.GUID = {'UNKNOWN'};

% get video info. this is so that we can open a window that has the correct
% aspect ratio. Not important for processsing, but looks nicer. 

    % get video info
    try
        inf = mmfileinfo(file_in);
    catch ERR_vid
        sync.outcome = sprintf('Erroring getting video metadata. Error was:\n\n%s',...
            ERR_vid.message);
        return
    end
    % get width, height
    w = inf.Video.Width;
    h = inf.Video.Height;    
    if isempty(w) || isempty(h)
        ar = 16 / 9;
    else
        ar = w / h;
    end

% set up PTB window

    % max width of window is 500px, scale height according to video aspect
    % ratio
    sw = 500;
    sh = round(sw / ar);
    rect_screen = [0, 0, sw, sh];
   
    % skip PTB sync tests, and set verbosity to minimum
    old_skipSyncTests = Screen('Preference', 'SkipSyncTests', 2);
    old_verbosity = Screen('Preference', 'Verbosity', 0);
    
    % open PTB window
    screenNum = max(Screen('Screens'));
    w = Screen('OpenWindow', screenNum, [], rect_screen, [], [], [], [],...
        [], kPsychGUIWindow);
    Screen('TextFont', w, 'Arial');
    
    % set font for drawing timecode
    old_fontName = Screen('TextFont', w, 'menlo');
    old_fontSize = Screen('TextSize', w, 24);    
    
% set up PTB video
    
    % open video 
    try
        [m, dur, fps] = Screen('OpenMovie', w, file_in);
    catch ERR_PTB_vid
        sync.outcome = sprintf('Erroring loading video. Error was:\n\n%s',...
            ERR_PTB_vid.message);
        return
    end   
    
    % get inter-frame-interval
    ifi = 1 / fps; 
    
    % define duration of stamp - default is 5s
    dur_stamp = 5;
    
    % define sampling period
    sampPer = (dur_stamp - (2 * ifi));
    initSearchSpace = 0:sampPer:dur;
    numFrames = length(initSearchSpace);
    
    % flag vector to record which frames had a marker present (these will
    % form the basis of a more fine-grained search for the exact on/offset
    % of the edge markers in the next stage
    markerPresent       = false(size(initSearchSpace));
    
% now loop through the search space and look for markers

    for f = 1:numFrames
        
        % get time of current search frame
        t = initSearchSpace(f);
        
        % look for marker
        markerPresent(f) = findEdgeMarkers2(getFrame(t));
        if markerPresent(f)
            fprintf('Possible corner markers found at %.2fs\n', t);
        else
%             fprintf('No corner markers found at %.2fs\n', t);
        end
        
    end
    
% for all frames with markers present, define a new search space. Now we
% want to know the precise frame at which the marker onset occured, so we
% step through frame-by-frame. 
% the markers are stamped on the video for (default) 5s. Based on the
% previous step, we don't know whether the frame we found with a marker
% present was in the middle of this 5s, as the start, the end etc. Rather
% than checking all frames, we sample by splitting that 5s into two and
% searching there. If the marker is still found, we need to go back (so we
% now split 2.5s into two), if it is not found, we need to go forward (so
% we split 2.5s in a forward direction). This checks the least possible
% number of frames, making for the fastest possible search. 

    % get number of markers present
    numMarkers = sum(markerPresent);
    
    % get frame indices of markers
    idx_frame = find(markerPresent);
    
    % get timestamps of those frames
    t_known = initSearchSpace(idx_frame);
    
    % storage for time onsets
    markers = struct;
    for mrk = 1:numMarkers
        
        step = dur_stamp / 2;
        direction = -1;
        t_search = t_known(mrk);
        while abs(step) > (ifi / 2) 
            
            t_search = t_search + (direction * step);
            if t_search < 0
                t_search = 0;
            end
            [markersFound, markers(mrk).details] = findEdgeMarkers2(getFrame(t_search));
            if ~markersFound

                % marker not present - halve search space and try again
                step = step / 2;
                direction = 1;
                
            elseif markersFound && t_search ~= 0
                
                % marker present - search with same step but go backwards
                direction = -1;
                
            elseif markersFound && t_search == 0
                
                % marker preent and time at zero - we can stop now
                break
                
            end
            
        end
        
        % search ends on the frame before the onset, so add one frame to
        % the current search time and store it
        markers(mrk).time_video = t_search + ifi;
        
        % decode QR
        msg = decode_qr(imresize(getFrame(markers(mrk).time_video), 2));
        
        % if we could not decode the QR, try OCR instead
        if isempty(msg)
            tmp = ocr(getFrame(markers(mrk).time_video));
            if ~isempty(tmp.Text)
                ocr_guid = regexp(tmp.Text, '(?<=GUID: )(.*)(?=[\n\r])', 'match', 'dotexceptnewline');
                ocr_time_te = regexp(tmp.Text, '(?<=Task_Engine_Timestamp: )(.*)(?=[\n\r])', 'match', 'dotexceptnewline');
                if ~isempty(ocr_guid) && ~isempty(ocr_time_te)
                    msg = sprintf('%s#%s', ocr_guid{1}, ocr_time_te{1});
                else
                    msg = [];
                end
            end 
        end
            
        % split QR message
        if ~isempty(msg) 
            c = strsplit(msg, '#');
            markers(mrk).GUID = c{1};
            markers(mrk).time_te = str2double(c{2});
            markers(mrk).valid = true;
        else
            markers(mrk).valid = false;
        end
        
    end
    
    % close movie
    Screen('CloseAll')

    % restore PTB sync skip and verbosity setting
    Screen('Preference', 'SkipSyncTests', old_skipSyncTests);
    Screen('Preference', 'Verbosity', old_verbosity);
    
    % report results
    sync.numMarkers = numMarkers;
    tab = struct2table(markers, 'AsArray', true);
    
    % calculate frame numbers, frame time, and te timstamps (per frame)
    sync.frames = ceil(dur * fps);
    sync.frameTimes = 0:ifi:dur;
    
    if numMarkers == 0
        sync.success = false;
        sync.outcome = 'no edge markers found';
        teEcho('No edge markers found.\n');
        return
    elseif numMarkers > 0 && all(~tab.valid)
        sync.success = false;
        sync.outcome = 'manual sync needed (could not decode QR)';
        teEcho('Manual sync needed (edge markers found but could not decode QR.')
        return
    end
        
    % remove invalid and duplicates
    tab(~tab.valid, :) = [];
    sig = makeSig(tab, {'GUID', 'time_te'});
    [~, i] = unique(sig);
    tab = tab(i, :);
    markers = table2struct(tab);
    numMarkers = length(markers);    

    % report results
    sync.teTime = [markers.time_te];
    sync.videoTime = [markers.time_video];
    sync.GUID = {markers.GUID};
    
    % sort times
    if numMarkers > 1
        sync.teTime = sort(sync.teTime);
        sync.videoTime = sort(sync.videoTime);
    end
    
    % intercept 
    if numMarkers == 1
        % intercept only
        a = sync.teTime(1) - sync.videoTime(1);
        sync.timestamps = sync.frameTimes + a;
        sync.intercept = a;
        sync.video2te = str2func(sprintf('@(x) x + %.12f', a));
        sync.te2video = str2func(sprintf('@(x) x - %.12f', a));
    end
    
    if numMarkers > 1
        % intercept
        a = sync.teTime(1) - sync.videoTime(1);
        % slope
        b = (sync.teTime - a) / sync.videoTime;
        sync.timestamps = a + (sync.frameTimes * b);
        sync.intercept = a;
        sync.b1 = b;
        sync.video2te = str2func(sprintf('@(x) %.12f + (x * %.12f)', a, b));
        sync.te2video = str2func(sprintf('@(x) (x - %.12f) / %.12f', a, b));
    end
    
    sync.success = true;
    sync.outcome = '';
    
    function img = getFrame(t)

        % set movie time
        Screen('SetMovieTimeIndex', m, t);

        % get a frame, convert to image matrix
        tex = Screen('GetMovieImage', w, m);
        if tex ~= -1
            img = Screen('GetImage', tex);
        else
            % no more frames (eof or sof), so return blank image
            img = zeros(h, w, 3);
        end

        % draw to screen
        Screen('DrawTexture', w, tex, [], rect_screen);
        Screen('Close', tex);
        
        % draw timecode
        elap = datestr(t / 86400, 'HH:MM:SS.fff');
        tot = datestr(dur / 86400, 'HH:MM:SS.fff');
        str = sprintf('%s / %s', elap, tot);
        DrawFormattedText(w, str, 'center', 30, [255, 000, 255]);
        
        % flip
        Screen('Flip', w, [], [], 1);
        
    end
    
end

function [found, s] = findEdgeMarkers2(img)

    % resize image to 700px wide
    w = size(img, 2);
    h = size(img, 1);
    ar = w / h;
    ow = 700;
    oh = round(ow / ar);
    img = imresize(img, [oh, ow]);
    img = im2single(img) .* 255;

    % define corner colours
    col_mrk(1:4, 1:3) = [...
        255, 000, 000   ;...
        000, 255, 000   ;...
        000, 000, 255   ;...
        255, 255, 255   ;...
        ];
    numMrk = size(col_mrk, 1);
    
    % scan the image for each expected marker (defined by its colour)
    tol = 50;
    mrk_found = false(numMrk, 1);
    s = cell(numMrk, 1);
    for c = 1:numMrk
        [s{c, 1}, mrk_found(c)] = findOneEdgeMarker(img, col_mrk(c, :), tol);
    end
    
    numMarkersPerChan = cellfun(@height, s);
    if any(numMarkersPerChan > 1)
        
        % multiple candidate edge markers found. A quick check here is to
        % make sure that at least two (colour) channels have markers found.
        % For example, if a bunch of white squares are found then they can
        % only be markers if at least a red, green or blue square is also
        % found
        if sum(numMarkersPerChan > 0) == 1
            % only one marker found, not enough
            found = false;
            return
        else
            % todo - handle more than one marker found
            error('Multiple candidate markers found.')
        end
        
    elseif ~any(mrk_found)
        found = false; 
        return
    end
    
    % relate individual results to unique corner markers
    mrk_r = s{1};
    mrk_g = s{2};
    mrk_b = s{3};
    mrk_w = s{4};
    
    % if only one marker is present, short-circuit spatial relationships
    % checks for speed
    numPresent = sum([~isempty(mrk_r), ~isempty(mrk_g), ~isempty(mrk_b),...
        ~isempty(mrk_w)]);
    
    if numPresent > 1
        % check spatial configuration of corner markers    
        val_r = checkMarkerSpatialRelations(mrk_r,...
            mrk_g, 'x>', 'y=',...
            mrk_b, 'x=', 'y>',...
            mrk_w, 'x>', 'y>');

        val_g = checkMarkerSpatialRelations(mrk_g,...
            mrk_r, 'x<', 'y=',...
            mrk_b, 'x<', 'y>',...
            mrk_w, 'x=', 'y>');

        val_b = checkMarkerSpatialRelations(mrk_b,...
            mrk_r, 'x=', 'y<',...
            mrk_g, 'x>', 'y<',...
            mrk_w, 'x>', 'y=');

        val_w = checkMarkerSpatialRelations(mrk_w,...
            mrk_r, 'x<', 'y<',...
            mrk_g, 'x=', 'y<',...
            mrk_b, 'x<', 'y=');
        
        found = sum([val_r, val_g, val_b, val_w]) >= 2;
%         fprintf('%d corner markers found and look to be correct, ', sum([val_r, val_g, val_b, val_w]));
        
    else
        found = false;
    end
    
%     if found
%         fprintf('VALID\n');
%     else
%         fprintf('INVALID\n');
%     end
    
end

function val = checkMarkerSpatialRelations(mrk_target, varargin)

    % if target marker is empty (not found) then spatial relationships are
    % by definition not valid, so return
    if isempty(mrk_target)
        val = false;
        return
    else
        val = true;
    end

    % comparisons are passed as three input arguments per comp, the marker
    % that we are comparing to (mrk_rel), the x relationship (rel_x) and
    % the y relationship (rel_y). Loop through each comparisons
    numComp = length(varargin) / 3;
    cnt = 1;
    val_present = true(numComp, 1);
    val_comp = true(numComp, 1);
    for c = 1:numComp
       
        % get the marker and the x/y relationship
        mrk_rel = varargin{cnt};
        rel_x = varargin{cnt + 1};
        rel_y = varargin{cnt + 2};
        cnt = cnt + 3;
        
        % if the comparison marker is not found, the relationships for this
        % comparison are by definition not valid, so continue in the loop
        % to the next comparison
        if isempty(mrk_rel)
            val_comp(c) = false;
            val_present(c) = false;
            continue
        end        
        
        % get the x, y, w, h of each marker
        x_tar = mrk_target.Centroid(1);
        y_tar = mrk_target.Centroid(2);
        w_tar = mrk_target.MajorAxisLength;
        h_tar = mrk_target.MinorAxisLength;
        
        x_rel = mrk_rel.Centroid(1);
        y_rel = mrk_rel.Centroid(2);
        w_rel = mrk_rel.MajorAxisLength;
        h_rel = mrk_rel.MinorAxisLength;
        
        % check that widths/heights are close
        val_comp(c) = val_comp(c) &&...
            abs(w_tar - w_rel) < (w_tar / 2) &&...
            abs(h_tar - h_rel) < (h_tar / 2);
        
        switch rel_x
            case 'x<'
                val_comp(c) = val_comp(c) &&...
                    (x_tar - x_rel) > (w_tar * 2);
            case 'x>'
                val_comp(c) = val_comp(c) &&...
                    (x_rel - x_tar) > -(w_tar * 2);
            case 'x='
                val_comp(c) = val_comp(c) &&...
                    abs(x_rel - x_tar) < w_tar;
        end
        
        switch rel_y
            case 'y<'
                val_comp(c) = val_comp(c) &&...
                    (y_tar - y_rel) > (h_tar * 2);
            case 'y>'
                val_comp(c) = val_comp(c) &&...
                    (y_rel - y_tar) > -(h_tar * 2);
            case 'y='
                val_comp(c) = val_comp(c) &&...
                    abs(y_rel - y_tar) < h_tar;
        end

    end
            
    % return whether ANY comparisons are valid (for now we assume that
    % at least one is enough, since markers can be missing etc -- need
    % to check this is correct against many datasets)
    % - actually we want at least 1 markers to be present and valid (I
    % think)
    val = sum(val_present & val_comp) >= 1;

end

function [details, found] = findOneEdgeMarker(img, col, tol)
        
        w = size(img, 2);
        h = size(img, 1);
        area = w * h;        
        
        idx = ...
            abs(img(:, :, 1) - col(1)) < tol &...
            abs(img(:, :, 2) - col(2)) < tol &...
            abs(img(:, :, 3) - col(3)) < tol;
        
        % find rectangular regions, calculate proportionate area and aspect
        % ratio for each
        details = regionprops('table', idx(:, :), 'Centroid', 'MajoraxisLength',...
            'MinoraxisLength', 'Area', 'Circularity', 'Orientation');
        details.AreaProp = details.Area ./ area;
        details.AspectRatio = details.MajorAxisLength ./ details.MinorAxisLength;        

        % remove non-candidates
        idx_tooSmall = details.AreaProp < .002;
        idx_ar = details.AspectRatio < .5 | details.AspectRatio > 1.5;
        idx_circ = details.Circularity > 0.2;
        idx_angle = abs(details.Orientation) > 5;
        
        % remove non-square aspect ratio
        details(idx_tooSmall | idx_ar | idx_angle, :) = [];     
        
        % ensure candidates are solid blocks of colour
        if ~isempty(details)
            details = removeNonContigMarkers(idx, details);
        end
   
        % store result
        found = ~isempty(details);

    end

function details = removeNonContigMarkers(idx, details)

    w = size(idx, 2);
    h = size(idx, 1);

    idx_rem = false(size(details, 1), 1);
    for c = 1:size(details, 1)

        % find centroid and width/height of region, dilate because
        % regionprops seems to return inprecise bounding boxes
        cx = details.Centroid(c, 1);
        cy = details.Centroid(c, 2);
        rw = details.MajorAxisLength(c) - 15;
        rh = details.MinorAxisLength(c) - 15;
        
        % construct indices in binary image, correct out of bounds
        rect = round([cx - (rw / 2), cy - (rh / 2), cx + (rw / 2), cy + (rh / 2)]);
        idx_neg = rect < 1;
        rect(idx_neg) = ones(sum(idx_neg), 1);
        
        idx_wide = rect > w;
        idx_wide([2, 4]) = false;
        rect(idx_wide) = repmat(w, 1, sum(idx_wide));
        
        idx_height = rect > h;
        idx_height([1, 3]) = false;
        rect(idx_height) = repmat(h, 1, sum(idx_height));
        
        % grab block of image 
        block = idx(rect(2):rect(4), rect(1):rect(3));    
        
        % calc SD and compare to criterion, which is 0.1
        sd_calc = std(block(:));
        idx_rem(c) = sd_calc > .1;
        if idx_rem(c)
%             fprintf('\tRemoving region %d, SD=%.2f (crit_SD = .1)\n', c, sd_calc);
        end
        
    end
    
    % remove non-contig
    details(idx_rem, :) = [];

end

% define the search strategy for finding the edge markers. These are most
% likely to be at the start or the end of the video. So first search the
% the beginning 10% of frames, then the final 10%, then the remaining
% middle 80%

%     first10             = 0:sampPer:dur * .10;
%     last10              = dur - (dur * .10):sampPer:dur;
%     middle80            = (dur * .10) + sampPer:sampPer:dur - (dur * .10);
%     initSearchSpace     = [first10, last10, middle80];
%     numFrames           = length(initSearchSpace);
%     
%     first10             = 0:sampPer:dur * .10;
%     last10              = dur - (dur * .10):sampPer:dur;
    
%     search_f1(:, 1)     = 0.00:0.05:0.95;
%     search_f2(:, 1)     = 0.05:0.05:1.00;
%     numSearch           = length(search_f1);
%     initSearchSpace     = [];
%     for se = 1:numSearch
%         if mod(se, 2) ~= 0
%             idx = se;
%         else
%             idx = numSearch - se + 1;
%         end
%         initSearchSpace = [initSearchSpace, search_f1(idx) * dur:sampPer:dur * search_f2(idx)];
%     end



        
%         if ~isempty(s)
%             
%             scatter(s{4}.Centroid(:, 1), s{4}.Centroid(:, 2))
%             hold on
% 
%             for i = 1:size(details, 1)
%                 cx = details.Centroid(i, 1);
%                 cy = details.Centroid(i, 2);
%                 rw = details.MajorAxisLength(i);
%                 rh = details.MinorAxisLength(i);
%                 rect = [cx - (rw / 2), cy - (rh / 2), rw, rh];
%                 rectangle('Position', rect, 'EdgeColor', 'm', 'FaceColor', 'none')
% 
%                 text(details.Centroid(i, 1), details.Centroid(i, 2), num2str(details.AspectRatio(i)), 'Color', 'm')
%             end      
%             
%         end



% function found = findEdgeMarkers(img)
% 
%     found = findEdgeMarkers2(img);
%     return
% 
% % define corner markers - these are fairly large on the original screen,
% % but since the video may be downscaled by an unknown amount, we will, take
% % a relatively small patch at each corner and read the mode colour value
% 
%     % corner marker width/height
%     w_mrk = 30;
%     % gap from edge
%     gap = 10;
%     % image width, height
%     w = size(img, 2) - gap;
%     h = size(img, 1) - gap;    
%     % rects
%     rect_mrk(1:4, 1:4) = [...
%         gap,        gap,        w_mrk,      w_mrk       ;...    % top left
%         w - w_mrk,  gap,        w,          w_mrk       ;...    % top right
%         gap,        h - w_mrk,  w_mrk,      h           ;...    % bottom left
%         w - w_mrk,  h - w_mrk,  w,          h           ];      % bottom right
%     % colours
%     col_mrk(1:4, 1:3) = [...
%         255, 000, 000   ;...
%         000, 255, 000   ;...
%         000, 000, 255   ;...
%         255, 255, 255];
%     % tolerance when searching for marker
%     tol = 60;
%     
% % loop through each rect and look for markers in image
% 
%     numCorners = size(rect_mrk, 1);
%     cornerFound = false(numCorners, 1);
%     for c = 1:numCorners
%         % get patch of image inside rect
%         patch = img(rect_mrk(c, 2):rect_mrk(c, 4), rect_mrk(c, 1):rect_mrk(c, 3), :);
%         % find mode for each colour channels
%         md_r = mode(mode(patch(:, :, 1)));
%         md_g = mode(mode(patch(:, :, 2)));
%         md_b = mode(mode(patch(:, :, 3)));
%         md_rgb = double([md_r, md_g, md_b]);
%         % compare to marker colours
%         cornerFound(c) = all(abs(md_rgb - col_mrk(c, :)) <= tol);
% %         % if not found, don't look at other corners
% %         if ~found, break, end
%     end
%     
%     % we define found as at least two corner markers present
%     found = sum(cornerFound) >= 3;
% 
% end
% 

