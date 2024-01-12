classdef teExternalData_ScreenRecording < teExternalData
    
    properties 
        Ext2Te = @(x) x
        Te2Ext = @(x) x
    end
    
    properties (SetAccess = private)
        Resolution
        Duration      
        Valid 
    end
    
    properties (SetAccess = private)
        Type = 'screenrecording';
    end
    
%     properties (Dependent, SetAccess = private)
%         Synchronised
%         SyncVideoTime
%         SyncTaskEngineTime
%         GUID
%     end
%     
%     properties %(Access = protected)
%         prSync
%     end
    
    properties (Constant)
        CONST_FileTypes = {'mov', 'mp4', 'm4v', 'avi'}
    end
    
    methods
        
        function obj = teExternalData_ScreenRecording(path_screen)
            
            % check input args, to ensure that a path has been passed, and
            % that the path exists
            if ~exist('path_screen', 'var') || isempty(path_screen)
                obj.InstantiateOutcome = 'Must supply a path to screen recording data';
                return
            elseif ~exist(path_screen, 'dir')
                obj.InstantiateOutcome = 'Path does not exist';
                return
            else
                % store path in subclass
                obj.Paths('screenrecording') = path_screen;
            end
            
        % look for compatible video files
        
            % build file extension patterns (e.g. *.mp4) for all compatible
            % filetypes
            patterns = cellfun(@(x) sprintf('*.%s', x),...
                obj.CONST_FileTypes, 'uniform', false);
            
            % find files which match this pattern
            file_video = cellfun(@(x) teFindFile(path_screen, x),...
                patterns, 'uniform', false);
            
            % find empty and delete
            idx_empty = cellfun(@isempty, file_video);
            file_video(idx_empty) = [];
            
            % check number of files found
            if isempty(file_video)
                % no files found
                obj.InstantiateOutcome = 'No compatible video file not found in screenrecording folder';
                return    
                
            elseif length(file_video) > 1
                % more than one files found - can't load in this instance
                obj.InstantiateOutcome = 'More than one video file fount in screenrecording folder';
                return
                
            elseif length(file_video) == 1
                % remove from cell array
                file_video = file_video{1};
                % store path
                obj.Paths('screenrecording') = file_video;
                
            end
            
        % read video metadata
        
            try
                inf = mmfileinfo(file_video);
            catch ERR
                obj.InstantiateOutcome = sprintf('Error reading video metadata, error was:\n\n%s',...
                    ERR.message);
                return
            end
            
            % check video format
            if ~isfield(inf, 'Duration') ||...
                    ~isfield(inf, 'Video') ||...
                    ~isfield(inf.Video, 'Format') ||...
                    isempty(inf.Video.Format)
                warning('Screenrecording appears to be corrupted.')
            else
                obj.Resolution = [inf.Video.Width, inf.Video.Height];
                obj.Duration = inf.Duration;
            end
            
        % look for sync struct
        
            [~, fil, ext] = fileparts(file_video);
            file_sync = lm_findFilename('sync.mat', path_screen);
            if iscell(file_sync) && length(file_sync) > 1
                obj.InstantiateOutcome = 'More than one video sync files found, cannot continue';
                return
            end
            if ~isempty(file_sync)
                tmp = load(file_sync);
                obj.Sync = tmp.sync;
            end
            
        % set valid
        
            obj.Valid = true;
            obj.InstantiateSuccess = true; 
            obj.InstantiateOutcome = '';            
            
        end
        
        function ImportSync(obj, sync)
            
            if teValidateSyncStruct(sync)
                obj.Sync = sync;
            else
                error('Invalid sync structure.')
            end
            
        end
        
%         function SyncVideo(obj)
%             if ~obj.Valid
%                 error('Cannot sync when Valid is false.')
%             end
%             obj.prSync = teSyncVideo(obj.Path_Video);
%         end
%         
%         function val = get.SyncVideoTime(obj)
%             if ~obj.Synchronised
%                 val = [];
%             else
%                 val = obj.prSync.videoTime;
%             end
%         end
%         
%         function val = get.SyncTaskEngineTime(obj)
%             if ~obj.Synchronised
%                 val = [];
%             else
%                 val = obj.prSync.teTime;
%             end
%         end
%         
%         function val = get.GUID(obj)
%             if ~obj.Synchronised
%                 val = [];
%             else
%                 val = obj.prSync.GUID;
%             end
%         end
%         
%         function val = get.Synchronised(obj)
%             val = ~isempty(obj.prSync) &&...
%                 isfield(obj.prSync, 'videoTime') &&...
%                 isfield(obj.prSync, 'teTime') &&...
%                 isfield(obj.prSync, 'GUID') &&...
%                 ~isempty(obj.prSync.videoTime) &&...
%                 ~isempty(obj.prSync.teTime) &&...
%                 ~isempty(obj.prSync.GUID);
%         end
       
    end
    
    
    
end