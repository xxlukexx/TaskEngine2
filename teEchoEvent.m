function teEchoEvent(event, when, task)

    % echo timestamp
    cprintf('Strings', '\n[');
    cprintf('Strings', '%.4f', when);
    cprintf('Strings', ']');
    % echo task
    if ~isempty(task)
        cprintf('SystemCommands', ' [');
        cprintf('SystemCommands', task)
        cprintf('SystemCommands', '] ');
    end
    
    if isnumeric(event)
        type = 1;
    elseif ischar(event)
        type = 2;
    elseif iscell(event)
        type = 3;
    else
        type = 0;
    end
    
    % depending upon type, echo to command window
    switch type
        case 1
            % numeric
            cprintf('text', '%d\n', event);
        case 2
            % char
            cprintf('text', '%s\n', event);
        case 3
            % not-neat
            cprintf('text', 'data event:\n');
            disp(event)
    end

end