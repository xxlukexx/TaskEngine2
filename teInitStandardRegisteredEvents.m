function teInitStandardRegisteredEvents(events)

    events('SYNC')                      = struct('eeg', 247);
    events('SKIPPED')                   = struct('eeg', 248);
    events('ATTENTION_GETTER_AUDITORY') = struct('eeg', 249);
    events('ATTENTION_GETTER_VISUAL')   = struct('eeg', 250);            
    events('PAUSE_ONSET')               = struct('eeg', 251);
    events('PAUSE_OFFSET')              = struct('eeg', 252);
    events('GC_FIXATION_ONSET')         = struct('eeg', 253);
    events('GC_FIXATION_OFFSET')        = struct('eeg', 254);

end