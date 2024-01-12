classdef teData_enobio < teData
    
    properties (SetAccess = private)
        Path_Enobio
        File_Enobio_Easy
        File_Enobio_Info
        NumberOfChannels
        SampleRate
        Duration
    end
    
    methods
        
        % constructor
        function obj = teData_enobio(path_session)
        % loads data. First calls the superclass teData constructor to load
        % all the general stuff. Then calls an enobio-specific function to
        % read the header (.info) file
        
            % load generic 
            obj = obj@teData(path_session);
            
        % look for external data in the session's 'enobio' folder
        
            % make path to putative folder
            path_enobio = fullfile(path_session, 'enobio');
            % if no folder, throw warning and give up
            if ~exist(path_enobio, 'dir')
                warning('Cannot find /enobio folder in session.')
                return
            end
            
            % look for .easy file, warn and give up if none found or more
            % than one
            file_easy = teFindFile(path_enobio, '*.easy');
            if isempty(file_easy)
                warning('.easy file not found in enobio folder.')
                return
            elseif iscell(file_easy) && length(file_easy) > 1
                warning('Multiple .easy files found.')
                return
            end
            
            % same for .info file
            file_info = teFindFile(path_enobio, '*.info');
            if isempty(file_info)
                warning('.info file not found in enobio folder.')
                return
            elseif iscell(file_info) && length(file_info) > 1
                warning('Multiple .info files found.')
                return
            end
            
        % attempt hash check
        
            % build filenames
            file_easy_hash = sprintf('%s.md5', file_easy);
            file_info_hash = sprintf('%s.md5', file_info);
            
            % check
            if exist(file_easy_hash, 'file')
                % check hash
                if ~teCheckHash(file_easy)
                    warning('Hash check failed for %s', file_easy)
                    return
                end
            end
            if exist(file_info_hash, 'file')
                % check hash
                if ~teCheckHash(file_info)
                    warning('Hash check failed for %s', file_info)
                    return
                end
            end 
            
        % attempt to load header
        
            % load
            try
                [obj.NumberOfChannels, obj.SampleRate, ~, numSamples] =...
                    NE_ReadInfoFile(file_info, 0); 
            catch ERR_loadHeader
                warning('Error loading header:\n\n%s',...
                    ERR_loadHeader.message)
                return
            end
            
            % calculate duration
            obj.Duration = numSamples / obj.SampleRate;
            
        % store paths
        
            obj.Path_Enobio = path_enobio;
            obj.File_Enobio_Easy = file_easy;
            obj.File_Enobio_Info = file_info;
 
        end 
        
    end
    
end

    