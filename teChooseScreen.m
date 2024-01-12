function choice = teChooseScreen

    % temp disable sync tests
    oldPref = Screen('Preference', 'SkipSyncTests', 2);
    
    availScreens = Screen('Screens');
    availScreens(availScreens == 0) = [];
    num = length(availScreens);
    
    winPtr = zeros(num, 1);
    for s = 1:num
        
        winPtr(s) = Screen('OpenWindow', availScreens(s), [200, 200, 200]);
        DrawFormattedText(winPtr(s), sprintf('Screen %d', s),...
            'center', 'center', [0, 0, 0]);
        Screen('Flip', winPtr(s));
        
    end
        
    happy = false;
    while ~happy
    
        resp = input('Enter the screen number you wish to use > ', 's');

        choice = str2double(resp);
        if isnan(choice)
            fprintf(2, 'You must enter a number.\n')
            continue
        elseif ~ismember(choice, availScreens)
            fprintf(2, 'You must enter a valid screen number between %d and %d.\n',...
                min(availScreens), max(availScreens));
            continue
        else
            happy = true;
        end
    end
    
    % reenable sync tests
    Screen('Preference', 'SkipSyncTests', oldPref);  
    
end