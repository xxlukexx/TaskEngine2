function res = teSelectMonitorNumberVisually

    try
        AssertOpenGL
    catch ERR
        error('Error initialising Psychtoolbox. Is it installed?\n\n\t%s',...
            ERR.message)
    end
    
    old_prefs = Screen('Preference', 'SkipSyncTests', 2);
    sca
    
    all_screens = Screen('Screens');
    cols = round(lines(length(all_screens)) * 255);
    for s = 1:length(all_screens) 
        
        fprintf('Opening on %d\n', all_screens(s))
        win_ptr(s) = Screen('OpenWindow', all_screens(s), cols(s, :));
        Screen('TextSize', win_ptr(s), 48);
        
    end
        
    dur = 5;
    onset = GetSecs;
    elap = 0;
    while elap < 5
        
        elap = GetSecs - onset;
        
        for s = 1:length(all_screens) 

            str = sprintf('Monitor Number = %d\nClosing in %d seconds', all_screens(s), round(dur - elap));
            DrawFormattedText(win_ptr(s), str, 'center', 'center', [255, 255, 255])
            Screen('Flip', win_ptr(s));
            
        end

    end
       
    sca
    Screen('Preference', 'SkipSyncTests', old_prefs);
    
    happy = false;
    while ~happy

        res = input(sprintf('Enter the monitor number to use (between 0 and %d)\n', max(all_screens)), 's');
        res = str2double(res);

        if isnan(res) 
            fprintf(2, 'Invalid screen number entered.\n')
        elseif ~ismember(res, all_screens)
            fprintf(2, 'Select a screen between 0 and %d.\n', max(all_screens))
        else
            happy = true;
        end
        
    end

end