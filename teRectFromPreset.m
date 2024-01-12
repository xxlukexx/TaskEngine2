function rect = teRectFromPreset(innerRect, outerRect, preset)
% Parses string varibale 'preset' for values such as 'bottomleft' and
% translates this to a position within a rect. Calculates new dimensions
% for 'innerRect', positioned at 'preset' location within 'outerRect'.

    showError = false;
    if ~ischar(preset)
        showError = true;
    end
    
    if ismember(preset, {'centre', 'center'})
        rect = teCentreRect(innerRect, outerRect);
        return
    end
    
    % get widths of inner and outer rects
    iw = innerRect(3) - innerRect(1);
    ih = innerRect(4) - innerRect(2);
    ow = outerRect(3) - outerRect(1);
    oh = outerRect(4) - outerRect(2);

    switch lower(preset)
        case 'topleft'
            x1 = 0;
            y1 = 0;
            x2 = iw;
            y2 = ih;
        case 'topright'
            x1 = ow - iw;
            y1 = 0;
            x2 = ow;
            y2 = ih;
        case 'bottomleft'
            x1 = 0;
            y1 = oh - ih;
            x2 = iw;
            y2 = oh;
        case 'bottomright'
            x1 = ow - iw;
            y1 = oh - ih;
            x2 = ow;
            y2 = oh;
        otherwise
            showError = true;
    end    
    
    if showError
        error('Invalid preset. Valid presets are: topleft, topright, bottomleft, bottomright.')
    end
    
    rect = [x1, y1, x2, y2];

end