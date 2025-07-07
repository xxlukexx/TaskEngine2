function [ext, md] = teDiscoverExternalData(path_session, md, varargin)
% Discovers external data within a Task Engine 2 session folder. Returns
% subclasses of the teExternalData object for each discovered data type.
% ext is a struct containing fieldnames pertaining to each type of external
% data, and values in the form of an instance of a teExternalData subclass

% default empty struct as output arg

%     ext = struct;
    ext = teCollection('teExternalData');
    
% check input args

    if ~exist('path_session', 'var') || isempty(path_session)
        error('Must provide a path to a session folder.')
    end
    
    if ~exist(path_session, 'dir')
        error('Path not found.')
    end
    
    % check session folder
    if ~teIsSession(path_session, varargin{:})
        error('Not a valid session')
    end
    
% find subfolders

    % get all files and folders within session folder, and filter for only
    % (sub)folders
    d = dir(path_session);
    d(~[d.isdir]) = [];
    
    % remove OSX crap from list of folders
    idx_crap = ismember({d.name}, {'.', '..'});
    d(idx_crap) = [];
    
    % get number of folders, and give up if no folders found
    numFolders = length(d);
    if numFolders == 0
        return
    end
    
    % compare subfolder names to lookup table
    lookup = {...
    %   folder name         % prop name         % class/fcn
        'eyetracking',      'EyeTracking',      'teExternalData_EyeTracking'        ;...
        'enobio',           'Enobio',           'teExternalData_Enobio'             ;...
        'eeg',              'EEG',              'teDiscoverExternalData_EEG'        ;...
        'screenrecording',  'ScreenRecording',  'teExternalData_ScreenRecording'    ;...
        'fieldtrip',        'Fieldtrip',        'teExternalData_Fieldtrip'          ;...
        };
    
    for f = 1:numFolders
        
        % search for folder name in lookup
        found = find(strcmpi(d(f).name, lookup(:, 1)));
        
        % if found, create a field in the output struct (ext), and make its
        % value an instance of the appropriate teExternalData_ subclass (as
        % found in the second col of the lookup table)
        if found
            
            type = lookup{found, 1};
            className = lookup{found, 3};
                
            % build an absolute path to the external data folder
            path_ext = fullfile(path_session, d(f).name);
            
            % check folder is not empty
            d_tmp = dir(path_ext);
            emptyFolder = length(d_tmp) == 2 &&...
                all(ismember({d_tmp.name}, {'.', '..'}));
            
            if ~emptyFolder
                
                % create a teExternalData instance of the appropriate
                % sub-type for the type of external data (e.g.
                % teExternalData_Enobio)
                ext_tmp = feval(className, path_ext);
                
                % this may fail 
                if isempty(ext_tmp)
                    suc = false;
                    oc = sprintf('required files missing [type:%s, className: %s]',... 
                    type, className);
                else
                    ext(type) = ext_tmp;
                    suc = ext(type).InstantiateSuccess;
                    oc = ext(type).InstantiateOutcome;
                end
                
                % if teExternalData subclass did not instantiate correctly,
                % report this in the metadata
                if nargout == 2
                    field_suc = sprintf('%s_load_success', type);
                    field_oc = sprintf('%s_load_outcome', type);
                    md.(field_suc) = suc;
                    md.(field_oc) = oc;
                end
                    
            end
    
        end
        
    end
    
end