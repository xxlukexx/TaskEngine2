function [suc, oc, tab_pres] =...
    teCalculateEyeTrackingValidityFromMatchedTrials(logArray, tab_pres)

    suc = false;
    oc = 'unknown error';
    
    % get trial log data with trial guids. this contains the et looking
    % time data for each trial
    tab_log_data = teLogFilter(logArray, 'topic', 'trial_log_data');
    if isempty(tab_log_data)
        oc = 'trial log data not found';
        return
    end
    
    % filter for only vars of interest
    tab_log_data = tab_log_data(:, {'task', 'et_looking_prop', 'et_looking_time', 'trialguid'});
    
    % join to presence table
    tab_pres = outerjoin(tab_pres, tab_log_data, 'Keys', 'trialguid', 'Type', 'left');
    
    suc = true;
    oc = '';

end