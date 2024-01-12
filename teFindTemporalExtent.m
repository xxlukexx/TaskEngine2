function extent = teFindTemporalExtent(data)
    
    extent = table;
    
    % log
    s = struct;
    s.type = {'log'};
    lg = teSortLog(data.Log.LogArray);
    s.s1 = lg{1}.timestamp;
    s.s2 = lg{end}.timestamp;
    extent = [extent; struct2table(s)];
    
    % external data
    for e = 1:data.ExternalData.Count
        
        ext = data.ExternalData(e);
        switch ext.Type
            
            case 'enobio'
            
                extent = findEnobio(ext, extent);
                
            case 'eyetracking'
                
                extent = findEyeTracking(ext, extent);
                
%             case 'screenrecording'    
%         
%                 extent = findScreenRecording(ext, extent);
        
        end

    end

end

function extent = findEnobio(ext, extent)

    % load raw data
    file_easy = ext.Paths('enobio_easy');
    if isempty(file_easy)
        % no enobio data
        return
    end
    tmp = load(file_easy);
    
    s = struct;
    s.type = {'enobio'};
    s.s1 = tmp(1, end) / 1e3;
    s.s2 = tmp(end, end) / 1e3;
    
    extent = [extent; struct2table(s)];

end

function extent = findEyeTracking(ext, extent)
    
    if isempty(ext.TrackerType)
        div = 1e6;
        warning('This needs looking at - blank trackertype')
    else
        % timestamps for teEyeTracker_keyboard are in secs, not microsecs, so
        % we use a different denominator 
        switch ext.TrackerType
            case {'keyboard', 'mouse'}
                div = 1;
            otherwise
                div = 1e6;
        end
    end

    s = struct;
    s.type = {'eyetracking'};
    s.s1 = ext.Buffer(1, 33) / div;
    s.s2 = ext.Buffer(end, 33) / div;
    
    extent = [extent; struct2table(s)];

end

