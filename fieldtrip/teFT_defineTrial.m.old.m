function trl = teFT_defineTrial(cfg)

    % output var
    trl = [];  
    
    % read the header information to get the sampling rate 
    hdr   = ft_read_header(cfg.dataset);
   
    % determine the number of samples before and after the trigger
    pretrig  = round(cfg.trialdef.prestim  * fs);
    posttrig = round(cfg.trialdef.poststim * fs);
    
    % if only one event is selected, put it in to a cell array 
    if ischar(cfg.events)
        cfg.events = {cfg.events};
    end
    
    % get indices of relevant events
    ev = [cfg.event.value];
    
    % get eeg codes, convert to string
    codes = cellfun(@(x) cfg.registeredevents(x).eeg, cfg.events);
    codes_str = arrayfun(@num2str, codes, 'uniform', false);
    
    % find wanted codes from eeg file
    wanted = ismember(ev, codes);
    
    % get onset/offset
    onsets = [cfg.event(wanted).sample]' + pretrig;
    offsets = [cfg.event(wanted).sample]' + posttrig;
    
    % make trl
    trl = [...
        onsets,...
        offsets,...
        repmat(pretrig, sum(wanted), 1),...
        ev(wanted)',...
        ];

end