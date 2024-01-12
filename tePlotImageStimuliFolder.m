function tePlotImageStimuliFolder(path_stim)
% loads all images in a folder in a subplot

    % check path
    if ~exist(path_stim, 'dir')
        error('Path not found.')
    end
    
    % attempt to find image files
    file_formats = {'.png', '.jpg', '.jpeg', '.gif', '.bmp', '.tiff'};
    d = [];
    for i = 1:length(file_formats)
        d = [d; dir(sprintf('%s%s*%s', path_stim, filesep, file_formats{i}))];
    end
    if isempty(d)
        error('No image files found.')
    end

    
    % determine number of subplots needed
    nsp = numSubplots(length(d));
    newFigNeeded = true;
    idx_sp = 1;
    if nsp(1) > 6 
        nsp(1) = 6;
    end
    if nsp(2) > 6
        nsp(2) = 6;
    end

    for f = 1:length(d)
        
        if newFigNeeded
            figure('color', 'w', 'position', [0, 0, 1763, 1205])
            newFigNeeded = false;
        end
        
        subplot(nsp(1), nsp(2), idx_sp)
        if idx_sp + 1 > nsp(1) * nsp(2)
            idx_sp = 1;
            newFigNeeded = true;
            tightfig
        else
            idx_sp = idx_sp + 1;
        end
        
        % load image and alpha
        [img, ~, alpha] = imread(fullfile(path_stim, d(f).name));
        
        % show image
        im = imshow(img, 'border', 'tight');
        
        % apply alpha
        if ~isempty(alpha)
            set(im, 'alphadata', alpha)
        end

        title(d(f).name, 'Interpreter', 'none', 'FontName', 'menlo',...
            'fontsize', 11)
        
    end
    
    tightfig

end