function pres = teFindPresenter
    % get all workspace vars
    w = evalin('base', 'whos');
    % look for presenter
    found = strcmpi({w.class}, 'tePresenter');
    if ~any(found)
        pres = [];
    elseif sum(found) == 1
        pres = evalin('base', sprintf('%s', w(found).name));
    else
        error('Multiple objects of tePresenter class found.')
    end
end