function data = teTrial2ECKExportData(trial)

    if ~iscell(trial)
        trial = {trial};
    end
    
    num_trials = length(trial);
    
    if num_trials > 1
        warning('Multiple trials passed. These will be treated all belonging to the same participant. Metadata (e.g ID) will be taken from the first element.')
    end

    % metadata
    
        warning('teTrial property -> export data field mapping is hard-coded and may throw errors in future')

        data = struct;
        data = try_to_get_property(data, 'Task', trial{1}, 'Task');
        data = try_to_get_property(data, 'JobLabel', trial{1}, 'Task');
        data = try_to_get_property(data, 'ParticipantID', trial{1}, 'ID');
        data = try_to_get_property(data, 'Schedule', trial{1}, 'wave');
        data = try_to_get_property(data, 'Site', trial{1}, 'Site');
        data = try_to_get_property(data, 'Battery', trial{1}, 'Battery');
        data = try_to_get_property(data, 'Counterbalance', trial{1}, 'Counterbalance');
        data = try_to_get_property(data, 'FamilyID', trial{1}, 'FamilyID');
        data = try_to_get_property(data, 'SessionGUID', trial{1}, 'SessionGUID');

    % segments
    
        for i = 1:num_trials
            
            [mb, tb, eb] = trial{i}.Gaze.ExportTobiiAnalytics;
            data.Segments(i).MainBuffer = mb;
            data.Segments(i).TimeBuffer = tb;
            data.Segments(i).EventBuffer = eb;
            data.Segments(i).FixationBuffer = [];
            data.Segments(i).AddData = [];
            data.Segments(i).Label = sprintf('Segment_%04d', i);
            
        end
        
end

function data = try_to_get_property(data, field_name, trial, prop_name)

    try
        data.(field_name) = trial.(prop_name);
    catch ERR
        data.(field_name) = '<missing>';
    end
    
end
