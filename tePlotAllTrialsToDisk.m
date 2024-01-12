function tePlotAllTrialsToDisk(data)

    if nargin == 0 || ~isa(data, 'teData')
        error('Invalid data format.')
    end
    
    if ~isprop(data, 'EyeTracking') || ~data.EyeTracking.Valid
        error('No valid eye tracking data.')
    end
    
    % segment into trials
    trials = teAutoSegment(data);
    numTrials = length(trials);
    
    % make output folder
    path_out = fullfile(data.EyeTracking.Path, 'trialplots');
    mkdir(path_out)
    data.Path_TrialPlots = path_out;
    
    for t = 1:numTrials
        
        try
            tePlotTrial(trials{t});
        
            file_label =  sprintf('%s_trial%03d.png', trials{t}.Task, t);
            path_task = fullfile(path_out, trials{t}.Task);
            if ~exist(path_task, 'dir')
                mkdir(path_task);
            end
            file = fullfile(path_task, file_label);
            export_fig(file, '-r100')
            
            catch ERR
        end
        
        close(gcf)
        
    end

end