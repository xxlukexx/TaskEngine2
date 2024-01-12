function [dc] = checkDataIn(data)

    % Hi!
    
    % take an input argument and attempt to make sense of it. if it is a
    % string, treat it as a path and attempt to load it into an
    % ECKDataContainer. if is an ECKData, package it up into a data
    % container. If it is a data container then return it. 
    
    if exist('data', 'var')                     % does data exist?
        if isa(data, 'ECKData')                 
            dc = ECKDataContainer;              % create DC
            dc.AddData(data);                   % add this data to it
        elseif isa(data, 'ECKDataContainer')    
            dc = data;                          % if it is already a DC, return
            clear data;
        elseif ischar(data) && exist(data, 'dir') 
            dc = ECKDataContainer(data);        % if char, attempt to load
        elseif isstruct(data) 
            data = ECKStruct2ECKData(data);     % attempt to convert
            dc = ECKDataContainer;              % create DC
            dc.AddData(data);                   % add this data to it
        else
            error('data argument passed in wrong format - must be string path, ECKData or ECKDataContainer.')
        end
    else
        error('No data passed.')
    end

end