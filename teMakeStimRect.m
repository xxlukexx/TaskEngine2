function rect = teMakeStimRect(stim, x, y, w, h)

    % if w and h are specified, then we fit the stim into a rect with those
    % dimensions, adjusting for aspect ratio. If w or h are missing, we use
    % the dim that is present and create the missing dim by reference to
    % the aspect ratio
    
    % width
    if isempty(w)
        w = h * stim.AspectRatio;
    end
    
    % height
    if isempty(h)
        h = w  / stim.AspectRatio;
    end
        
    % check aspect ratio against stim 
    ar = w / h;
    if ar ~= stim.AspectRatio
        if stim.AspectRatio > 1
            % wider than tall, reduce height
            h = w / stim.AspectRatio;
        elseif stim.AspectRatio < 1
            % taller than width, reduce width
            w = h * stim.AspectRatio;
        end
    end
    
    % make rect
    rect = [x - (w / 2), y - (h / 2), x + (w / 2), y + (h / 2)];
    
end