function tePlotVideoStimuliFolder(path_stim)
% loads all images in a folder in a subplot

    % check path
    if ~exist(path_stim, 'dir')
        error('Path not found.')
    end
    
    % attempt to find image files
    d = dir(sprintf('%s%s*.mp4', path_stim, filesep));
    if isempty(d)
        error('No .mp4 files found.')
    end
    
    % determine number of subplots needed
    nsp = numSubplots(length(d));
    figure('color', 'w')

    for f = 1:length(d)
        
        subplot(nsp(1), nsp(2), f)
        
        % load image and alpha
        vr = VideoReader(fullfile(path_stim, d(f).name));
        vr.CurrentTime = 0;
        
        % get frame
        img = readFrame(vr);
        
        % show image
        im = imshow(img, 'border', 'tight');
        
    end

end