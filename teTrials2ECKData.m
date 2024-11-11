function data = teTrials2ECKData(varargin)

    if nargin == 0 || isempty(varargin)
        error('Must pass at least one teTrial object.')
    elseif ~all(cellfun(@(x) isa(x, 'teTrial'), varargin))
        error('All inputs must be teTrial objects.')
    end
    
    trials = varargin;        
%     if iscell(trials) && length(trials) > 1
%         data = cellfun(@teTrials2ECKData, trials, 'UniformOutput', false);
%         return
%     end
    
    data = ECKData;
    props = properties(trials{1});

    % ID
    idx_id = find(strcmpi('id', props), 1);
    if ~isempty(idx_id)
        id = trials{1}.(props{idx_id});
    else
        id = trials{1}.GUID;
    end

    % timepoint
    idx_tp = find(...
        strcmpi('wave', props) | strcmpi('timepoint', props), 1);
    if ~isempty(idx_tp)
        tp = trials{1}.(props{idx_tp});
    else
        tp = 'NONE';
    end

    % battery
    idx_bat = find(strcmpi('battery', props), 1);
    if ~isempty(idx_bat)
        bat = trials{1}.(props{idx_bat});
    else
        bat = 'NONE';
    end

    % site
    idx_site = find(strcmpi('site', props), 1);
    if ~isempty(idx_site)
        site = trials{1}.(props{idx_site});
    else
        site = 'NONE';
    end     

    % demographics
    data.ParticipantID = id;
    data.TimePoint = tp;
    data.Battery = bat;
    data.Site = site;
    
    % eye tracking
    numTrials = length(trials);
    tmp_log = cell(numTrials, 1);
    data.Segments(1).JobLabel = [trials{1}.Task, '_trial'];
    data.Segments(1).Task = [trials{1}.Task, '_trial'];    
    for t = 1:numTrials
        [mb, tb, eb] = trials{t}.Gaze.ExportTobiiAnalytics;
        data.Segments(1).Segment(t).MainBuffer = mb;
        data.Segments(1).Segment(t).TimeBuffer = tb;
        data.Segments(1).Segment(t).EventBuffer = eb;
        if isfield(data.Segments(1).Segment(t), 'Label')
            data.Segments(1).Segment(t).Label = trials{t}.OnsetLabel;
        end
        if isfield(data.Segments(1).Segment(t), 'AddData')
            data.Segments(1).Segment(t).AddData = trials{t}.OnsetLabel;        
        end
        tmp_log{t} = teLogFilter(trials{t}.Log.LogArray, 'topic', 'trial_log_data');
    end
    
    % log
    tab_log = vertcat(tmp_log{:});
    if ~isempty(tab_log)
        data.Log = ECKTable2Log(tab_log, [trials{1}.Task, '_trial']);
    end
    
    varargout{1} = data;
    
end