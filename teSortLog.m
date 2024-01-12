function la = teSortLog(la)
    
    % get timestamps
    ts = cellfun(@(x) x.timestamp, la);
    
    % sort
    [~, so] = sort(ts);
    la = la(so);
    
end