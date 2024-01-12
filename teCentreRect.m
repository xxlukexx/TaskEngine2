function inner = teCentreRect(inner, outer)

    % get width and height of both rects
    w_inner = inner(3) - inner(1);
    h_inner = inner(4) - inner(2);
    w_outer = outer(3) - outer(1);
    h_outer = outer(4) - outer(2);
    
    % calculate width/height differece between inner and outer
    wd = w_outer - w_inner;
    hd = h_outer - h_inner;
    
    % calculate offset
    woff = wd / 2;
    hoff = hd / 2;
    
    % apply offset
    inner([1, 3]) = inner([1, 3]) + woff;
    inner([2, 4]) = inner([2, 4]) + hoff;
    
end