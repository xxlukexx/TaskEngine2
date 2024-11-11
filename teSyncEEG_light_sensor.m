function [sync, tracker] = teSyncEEG_light_sensor(tracker, data_ft, varargin)

% parse input args

    parser          =   inputParser;
    addParameter(       parser, 'wantedevents',          [],      @isnumeric)
    parse(              parser, varargin{:});
    wanted_codes    =   parser.Results.wantedevents;
    

    crit_pair = 0.050; % 50 ms

    % extract events
    [tab_te, num_te] = extractTaskEngineEvents(tracker, wanted_codes);
    [tab_ls, num_ls] = extractLightSensorEvents(data_ft);
    
%     tab_te = tab_te(1:6, :);
%     tab_ls = tab_ls(1:3, :);
    
    % calculate event delta
    tab_te.delta = [nan; diff(tab_te.timestamp)];
    tab_ls.delta = [nan; diff(tab_ls.timestamp)];
    num_te = size(tab_te, 1);
    num_ls = size(tab_ls, 1);
    
    % calculate padding. to slide light sensor events (from first to last)
    % against te events (from last to first, in reverse), we need to pad
    % the te events with nans
    %
    % e.g. start with:
    %    
    %   TE1     x       nan
    %   TE2     x       nan 
    %   TE3     -       LS1
    %   nan     x       LS2
    %   nan     x       LS3
    %
    % end with:
    %
    %   nan     x       LS1
    %   nan     x       LS2
    %   TE1     -       LS3
    %   TE2     x       nan
    %   TE3     x       nan
    %
    % so we need (num_ls - 1) nans at the start and end of the te events
    num_nan_needed = num_ls - 1;
    num_rows_needed = num_te + ((num_ls - 1) * 2);
    pairing = nan(num_rows_needed, 2);
    pairing(:, 1) = [nan(num_nan_needed, 1); tab_te.delta; nan(num_nan_needed, 1)];
    pairing(:, 2) = nan(size(pairing, 1), 1);
    
    % now that we have figured out padding, we simply count from the number
    % of te events backwards    
    idx_te = num_te;
    idx_mse = 1;
    stop = false;
    mse = [];
    
    % loop through all possible pairings of ls and te events, and calculate
    % mse on paired sample deltas for each pairing
    while ~stop
        
        % reset pairing
        pairing(:, 2) = nan(size(pairing, 1), 1);
        
        % find the row in the pairing matrix at which to insert the light
        % sensor data
        s1_ls = size(pairing, 1) - (num_te - idx_te) - num_ls + 1;
        s2_ls = s1_ls + num_ls - 1;
        
        % pair
        pairing(s1_ls:s2_ls, 2) = tab_ls.delta;
        
        % calculate MSE on difference between event deltas for light sensor
        % and task engine
        mse(idx_mse, 1) = nanmean(diff(pairing, [], 2));
        mse(idx_mse, 2) = idx_te;

        % move to previous te event, and increment mse storage counter
        idx_te = idx_te - 1;
        idx_mse = idx_mse + 1;
        
        % stop if we have run out of events
        stop = idx_te == -num_ls + 1;
                
    end
    
    % find best pairing for lowest mse
    idx_best = find(abs(mse(:, 1)) == min(abs(mse(:, 1))));
    fprintf('[teSyncEEG_light_sensor]: Found best pairing at event offset %d (%.3fs), with MSE of %.3fs\n',...
        mse(idx_best, 2), abs(mse(idx_best, 1)));
    best_offset_row = mse(idx_best, 2);
    
    % calculate common timecode
    tab_te.timecode = tab_te.timestamp - tab_te.timestamp(best_offset_row);
    tab_ls.timecode = tab_ls.timestamp - tab_ls.timestamp(1);
    
    % loop again, and attempt to indivdually pair each task engine event
    % with a corresponding light sensor event. Categorise outcomes and
    % record lag between event streams
    for e = 1:num_te
        
        event_te = tab_te(e, :);
        event_ls = tab_ls(e + best_offset_row, :);
        
        
        
        
        
        
        
        
        
        
    end

end
        
        
        
        
        
        
        
     


function [tab, num_events] = extractLightSensorEvents(data_ft)

    events = data_ft.events;
    tab = struct2table(events);
    tab.timestamp = tab.sample / data_ft.fsample;
    num_events = size(tab, 1);
    
    teEcho('Found %d light sensor events.\n', num_events);    
    
end
    

function [lg, num_events] = extractTaskEngineEvents(tracker, wanted_codes)

    lg = teLogFilter(tracker.Log, 'source', 'teEventRelay_Log');
    lg = sortrows(lg, 'timestamp');
    
    % convert registered events to codes
    codes = teRegisteredEvents2Codes(tracker.RegisteredEvents, lg.data, 'eeg');
    
    % filter for wanted codes only
    idx_wanted = ismember(codes, wanted_codes);
    lg = lg(idx_wanted, :);
    
    num_events = size(lg, 1);
    
    teEcho('Found %d Task Engine events.\n', num_events);    
    
end