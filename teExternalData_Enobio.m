classdef teExternalData_Enobio < teExternalData_EEG

%     properties 
%         Ext2Te = @(x) x
%         Te2Ext = @(x) x
%     end
    
    properties (SetAccess = protected)
%         NumChannels
%         NumSamples
%         SampleRate
%         Duration      
%         Valid = false
        RawData = []
%         T1 = nan
%         T2 = nan
        EEGSystem = 'enobio';
%         Fieldtrip
%         NumEvents
    end
    
    properties (SetAccess = protected)
        Type = 'enobio'        
    end
    
    methods
        
        function obj = teExternalData_Enobio(path_easy, path_info)
            
            % call superclass constructor to do common initiation
            obj = obj@teExternalData_EEG;
            
            % default to failure 
            obj.InstantiateSuccess = false;
            obj.InstantiateOutcome = 'unknown error';
            
            findInfoFile = ~exist('path_info', 'var') || isempty(path_info);
            pathIsFolder = exist(path_easy, 'dir');
            
            % handle path is file/folder
            if pathIsFolder    
            % if a folder was passed, try to find the easy and (optionally)
            % the info file
                
                % look for .easy file, warn and give up if none found or more
                % than one
                file_easy = teFindFile(path_easy, '*.easy');
                if isempty(file_easy)
                    obj.InstantiateOutcome = '.easy file not found in enobio folder';
                    return
                elseif iscell(file_easy) && length(file_easy) > 1
                    obj.InstantiateOutcome = 'Multiple .easy files found';
                    return
                else
                    obj.Paths('enobio_easy') = file_easy;
                end
                
                if findInfoFile
                    
                    % optionally attempt to find the info file in the same
                    % folder as the easy file
                    file_info = teFindFile(path_easy, '*.info');
                    if isempty(file_info)
                        obj.InstantiateOutcome = '.info file not found in enobio folder';
                        return
                    elseif iscell(file_info) && length(file_info) > 1
                        obj.InstantiateOutcome = 'Multiple .info files found';
                        return
                    else
                        obj.Paths('enobio_info') = file_info;
                    end               
                   
                else
                    file_info = [];
                end
                
            else
            % if the path to an easy file was passed, check it exists.
            % Optionally look for the .info file in the same folder as the
            % .easy file
            
                if ~exist(path_easy, 'file') == 2
                    error('File not found: %s', path_easy);
                else
                    file_easy = path_easy;
                end
                
                % don't search for the .easy file, used the passed path as
                % the .easy file
                obj.Paths('enobio_easy') = file_easy;
                    
                if findInfoFile
     
                    % assume the .info file has the same path with a .info
                    % instead of a .easy extension
                    file_info = strrep(file_easy, '.easy', '.info');
                    obj.Paths('enobio_info') = file_info;
                    if ~exist(file_info, 'file')
                        error('.info file not found at: %s',...
                            file_info)
                    end  
                    
                else
                    
                    % path to info file was supplied
                    obj.Paths('enobio_info') = path_info;
                
                end
                
            end
                
        % attempt to load header
        
            % load
            if ~exist(obj.Paths('enobio_info'), 'file')
                error('Info file not found: %s', obj.Paths('enobio_info'))
            end
            try
                hdr = eegEnobioReaderHeaderFile(obj.Paths('enobio_info'));
            catch ERR_loadHeader
                obj.InstantiateOutcome = sprintf('Error loading header:\n\n%s',...
                    ERR_loadHeader.message);
                return
            end
            
            % calculate duration
            numSamples = hdr.Number_of_records_of_EEG;
            obj.SampleRate = extractNumeric(hdr.EEG_sampling_rate);
            obj.Duration = numSamples / obj.SampleRate;
            obj.NumSamples = numSamples;
            obj.T1 = hdr.StartDate__firstEEGtimestamp_ / 1e3;
            obj.T2 = obj.T1 + obj.Duration;
            
            % load raw data and events
            [obj.Fieldtrip, obj.Events] = obj.ToFieldtrip;
%             obj.NumEvents = length(obj.Events);
            
            % set valid
            obj.Valid = true;
            obj.InstantiateSuccess = true; 
            obj.InstantiateOutcome = '';
            
        end
        
        function [ft, events, t] = ToFieldtrip(obj)
            
            [ft, events, t] = eegEnobio2Fieldtrip(obj.Paths('enobio_easy'));
            
        end
        
        function Load(obj)
          
            if ~obj.Valid
                error('Cannot load when object is not in a valid state.')
            end
            
            obj.RawData = load();
            
        end
       
    end
    
    
    
end