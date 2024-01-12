function [trl, eventLabels] = teFT_enobio_defineTrial(cfg, data, event)
% Defines a fieldtrip trial structure (trl). Paramteres are passed in a cfg
% struct. 
%
% Unlike other fieldtrip pipelines, this function requires that the raw,
% continuous EEG data is already loaded and passed in. This is achieved by
% loading the .easy and .info files into eegEnobio2Fieldtrip. 
%
% Like any fieldtrip "definetrial" function, this returns a list of samples
% indices corresponding to the onset and offset of each trial, as well as
% a third offset that defines the marker position relative to the trial
% onset. See FT_DEFINETRIAL for more info.
%
% This function is designed to work with Task Engine 2, and will not
% operate on Enobio data in isolation. This means that te2 registered
% events are used to allow the use of text labels for events, which are
% translated to eeg-system-specific codes. 
%
% Input arguments:
%
%   data - raw, continuous data in fieldtrip format (the output of
%   eegEnobio2Fieldtrip)
%
%   event - a fieldtrip event structure containing the events from the
%   enobio file (the second output argument of eegEnobio2Fieldtrip)
%
%   cfg - a configuration struct
%
% cfg struct fields:   
%
%   cfg.trialdef.prestim - number of seconds to segment before the trigger
%
%   cfg.trialdef.poststim - number of seconds to segment after the trigger
%
%   cfg.registeredevents - a teEvents collection (from the tracker.mat
%   file)
%
%   cfg.selectedevents - a cell array of strings containing all event
%   labels to be segmented

% setup
    
    % if only one event is selected, put it in to a cell array (so that one
    % or many events can be processed in the same way for the rest of the
    % function)
    if ischar(cfg.selectedevents)
        cfg.selectedevents = {cfg.selectedevents};
    end    
    
% the prestim and poststim fields define the length of the segement,
% relative to the trigger. These are passed in seconds. Convert them to
% samples
    
    % determine the number of samples before and after the trigger
    pretrig  = round(cfg.trialdef.prestim  * data.fsample);
    posttrig = round(cfg.trialdef.poststim * data.fsample);
    
% process registered events. Here we use the event labels that the user
% selected in the cfg.selectedevents field, and use the
% cfg.registeredevents collection to look up the numeric event code that
% corresponds to each event label

    % get values of all events in the dataset
    ev = [event.value];
    
    % convert the text labels 
    codes = cellfun(@(x) cfg.registeredevents(x).eeg, cfg.selectedevents);

% use the numeric event codes to search the events in the raw data file.
% Construct a logical vector for all events in the raw data file, flagging
% whether each one is wanted or not for segmentation
    
    wanted = ismember(ev, codes);
    
% in the raw eeg data, look up the sample indices of each event. Then
% adjust these sample values to find the on/offset of each trial (using the
% pre/poststim variables)

    % get sample indices of each event
    samp_wanted = [event(wanted).sample];
    
    % adjust to find the on/offset
    onsets = samp_wanted' + pretrig;
    offsets = samp_wanted' + posttrig;
    
% Look up the labels for each eeg code that is going into the trial 
% definition

    % get master list of eeg codes 
    codes_re = cell2mat(cfg.registeredevents.Summary{:, 2});
    
    % use that list as a lookup table to find the indices of each segmented
    % event in the master list
    idx_re = arrayfun(@(x) find(x == codes_re, 1), ev(wanted));
    
    % look up the corresponding label for each eeg code
    eventLabels = cfg.registeredevents.Summary{idx_re, 1};
    
% make trl

    trl = [...
        onsets,...
        offsets,...
        repmat(pretrig, sum(wanted), 1),...
        ev(wanted)',...
        ];

end