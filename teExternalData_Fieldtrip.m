classdef teExternalData_Fieldtrip < teExternalData_EEG
    
%     properties 
%         Ext2Te = @(x) x
%         Te2Ext = @(x) x
%     end
    
    properties (SetAccess = protected)
%         Fieldtrip
%         Events
%         SampleRate
%         Valid 
%         T1
%         T2
        EEGSystem = 'unknown_fieldtrip';
    end
    
    properties (SetAccess = protected)
        Type = 'fieldtrip'        
    end
    
    methods
        
        function obj = teExternalData_Fieldtrip(path_ft)
            
            % call superclass constructor to do common initiation
            obj = obj@teExternalData_EEG;
            
            % check input args, to ensure that a path has been passed, and
            % that the path exists
            if ~exist('path_ft', 'var') || isempty(path_ft)
                error('Must supply a path to Enobio data.')
            end
                        
            % handle path is file/folder
            if exist(path_ft, 'dir')    
            % if a folder was passed, try to find the fieldtrip data in it
                
                % look for fieldtrip file
                file_ft = teFindFile(path_ft, '*.mat');
                if isempty(file_ft)
                    warning('Fieldtrip file not found in fieldtrip folder.')
                    return
                elseif iscell(file_ft) && length(file_ft) > 1
                    warning('Multiple fieldtrip files found.')
                    return
                end
                
            elseif exist(path_ft, 'file') == 2
                
                file_ft = path_ft;
                
            else
                
                error('File not found: %s', path_ft)
                
            end
            
            % check file exists
            if ~exist(file_ft, 'file')
                error('File not found: %s', path_ft)
            else
                % store path
                obj.Paths('fieldtrip') = file_ft;
            end
            
        % attempt to load 
        
            % load
            try
                tmp = load(obj.Paths('fieldtrip'));
                fnames = fieldnames(tmp);
                
                % data can be 1) a single fieldtrip struct inside the file,
                % or 2) a struct holding .data and .events fields
                if all(ismember({'data', 'events'}, fnames))
                    ft_data = tmp.data;
                    events = tmp.events;
                elseif length(fnames) > 1
                    error('Multiple variables found in fieldtrip file.')
                elseif length(fnames) == 1
                    ft_data = tmp.(fnames{1});
                    if isfield(ft_data, 'events')
                        events = ft_data.events;
                    else
                        events = [];
                    end
                end
            catch ERR
                error('Error loading (%s): %s', obj.Paths('fieldtrip'),...
                    ERR.message)
            end
            
            obj.Fieldtrip = ft_data;
            obj.Events = events;
            
            % calculate duration
            obj.SampleRate = ft_data.fsample;
            
            if isfield(ft_data, 'abstime')
                obj.T1 = ft_data.abstime(1);
                obj.T2 = ft_data.abstime(2);
            else
                obj.T1 = ft_data.time{1}(1);
                obj.T2 = ft_data.time{1}(end);
            end
            
            % set valid
            obj.Valid = true;      
            
            obj.InstantiateSuccess = true;
            obj.InstantiateOutcome = '';
                
        end
        
        function [ft, events, t] = ToFieldtrip(obj)
            
            ft = obj.Fieldtrip;
            if isfield(ft, 'events')
                events = ft.events;
            end
            if isfield(ft, 'abstime')
                t = ft.abstime;
            else
                t = [];
            end
            
        end        
        
        function data = Load(obj)
            
            path_ft = obj.Paths('fieldtrip');
            if isempty(path_ft) 
                error('No fieldtrip path defined.')
            elseif ~exist(path_ft, 'file')
                error('File not found: %s', path_ft)
            else
                tmp = load(path_ft);
                data = tmp.ft_data;
                teEcho('Loaded fieldtrip data from: %s\n', path_ft);
            end
            
        end
       
    end
    
    
    
end