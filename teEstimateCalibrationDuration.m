function dur = teEstimateCalibrationDuration(path_data)

    if ~exist(path_data, 'dir')
        error('Path not found: %s', path_data)
    end
    if ~teIsSession(path_data)
        error('Path is not Task Engine session folder: %s', path_data)
    end
    
    try
        ses = teSession(path_data);
    catch ERR
        error('Error loading session. Error was:\n\n%s', ERR.message)
    end
    
    fprintf('Searching log for events...\n')
    
    tab_calib = teLogFilter(ses.Log.LogArray, 'data', '*calib*');
    if isempty(tab_calib)
        error('No calibration events found in data.')
    end
    tab_calib = sortrows(tab_calib, 'timestamp');
    tab_calib = tab_calib(1, :);
    fprintf('Found first calib event: %s [%s]\n', tab_calib.data{1},...
        datestr(datetime(tab_calib.timestamp(1), 'ConvertFrom', 'posixtime')));

    tab_ses = teLogFilter(ses.Log.LogArray, 'data', 'session_onset');
    if isempty(tab_ses)
        error('Session onset event not found in data.')
    end
    fprintf('Found session onset event: %s [%s]\n', tab_ses.data{1},...
        datestr(datetime(tab_ses.timestamp(1), 'ConvertFrom', 'posixtime')));
    
    dur = tab_ses.timestamp(1) - tab_calib.timestamp(1);
    fprintf('Estimated calibration duration: %.1fs\n', dur)
    
end
    