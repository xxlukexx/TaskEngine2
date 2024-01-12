function [val, syncStructIsValid, sync] = teVideoHasValidSync(data_in)
% verifies that a) video sync data exists, and b) it is valid. Can take as
% an input argument:
%
%   1. .Sync struct
%   2. Path to a sync struct in a filesystem. 
%   3. Path to a video in a filesystem (in which case we search for the
%      sync struct with a matching name).
%   4. Path to a te session. 
%   5. A teExternalData_screenrecording instance. 
%   6. A teData instance (with a screenrecording loaded as external data).

% first determine the input type, and attemp to load/find a sync struct. No
% validation is done yet - the aim is to find a sync struct and have it
% loaded in memory, regardless of input type, then validate in the next
% step

    if ischar(data_in)
        
        % suspect file path, but is it to sync struct, video, or session
        if teIsSession(data_in)
            
            % load session into teData instanace
            tmp = teData(data_in);
            
            % try to find sync struct in teData
            sync = attemptFromTeData(tmp);
                    
        % if it is a folder which is not a valid session, throw an error
        % (since this is not a video without sync - the normal invalid
        % condition. i.e. it is not an entity capable of BEING synced.
        elseif isfolder(data_in)
            error('Passed folder was not a Task Engine 2 session.')
        
        % is it a file? Here we attempt to find and load a sync struct from
        % disk. We don't validate a this point, just populate the sync
        % variable. 
        elseif isfile(data_in)
            % determine extension
            [pth, fil, ext] = fileparts(data_in);
            if strcmpi(ext, '.mat') && instr(fil, '.sync')
                
                % assume sync struct
                file_sync = data_in;
                
            elseif ismember(strrep(ext, '.', ''), {'mov', 'mp4', 'm4v', 'avi'})
                % assume video file, try to build filename of struct .mat
                % file and load
                file_sync = teFindFile(pth, sprintf('%s*.sync.mat',...
                    fil));
                
                % no sync structure found
                if isempty(file_sync)
                    val = false;
                    syncStructIsValid = false;
                    return
                end
            else
                error('Passed file was not a valid sync structure.')
                
            end
            
            % attempt to load
            try
                tmp = load(file_sync);
                sync = tmp.sync;
            catch ERR
                val = false;
                syncStructIsValid = false;
                return
            end
                
        end
        
    elseif isa(data_in, 'teData')
        sync = attemptFromTeData(data_in);
        
    elseif isa(data_in, 'teExternalData_ScreenRecording')
        sync = attemptFromExternalData(data_in);
        
    elseif isstruct(data_in)
        sync = data_in;
        
    else
        error('Unrecognised data type.')
        
    end
    
% validate

    syncStructIsValid = validateSyncStruct(sync);
    hasSync = syncStructIsValid && ~ismember('NOT_FOUND', sync.GUID);
    val = syncStructIsValid && hasSync;

end

function sync = attemptFromTeData(data)

    % look for screenrecording external data
    ext = data.ExternalData('screenrecording');
    
    sync = attemptFromExternalData(ext);
            
end

function sync = attemptFromExternalData(ext)

    if ~isempty(ext)          
        % validate sync struct
        sync = ext.Sync;
    else
        % no external data
        sync = [];
    end

end

function val = validateSyncStruct(sync)

    val = teValidateSyncStruct(sync);

end