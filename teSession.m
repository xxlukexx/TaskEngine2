classdef teSession < teData
    
    properties
        Tracker
    end
    
    properties (SetAccess = ?teData)
        SessionStartTimeString
        SessionStartTime
    end
    
    properties (Dependent, SetAccess = private)
        Trials teTrial
    end
    
    methods
        
        function [obj, tracker] = teSession(varargin)
        % initalise either with a) a path to a sesion folder, or 2) a
        % tracker and -- optionally -- external data and metadata
        
            % call superclass constructor to init the general teData stuff
            obj = obj@teData;
        
        % handle input args
        
            % support legacy format, with just one input arg which is the
            % session path (no key/value pairs). todo this is a bit
            % tortuous and should probably be removed once all calling
            % functions are udpated to use the key/value format. 
            if nargin == 1 && ischar(varargin{1}) ||...
                    (nargin == 2 && ischar(varargin{1}) &&...
                    isequal(varargin{2}, 'includePrecombine'))
                
                path_session = varargin{1};
                includePrecombine = nargin == 2 &&...
                    isequal(varargin{2}, 'includePrecombine');
                
            else
        
                parser = inputParser;
                parser.addParameter('path_session', []);
                parser.addParameter('tracker', []);
                parser.addParameter('external_data', []);
                parser.addParameter('metadata', []);
                parser.addOptional('includePrecombine', false);
                parser.parse(varargin{:});

                path_session = parser.Results.path_session;
                tracker = parser.Results.tracker;
                ext = parser.Results.external_data;
                md = parser.Results.metadata;
                includePrecombine = parser.Results.includePrecombine;
                
            end
            
            if ~isempty(path_session)
                tracker = obj.ReadFromSessionPath(path_session, includePrecombine);
            elseif ~isempty(tracker)
                obj.ReadFromTracker(tracker)
                if ~isempty(ext)
                    obj.ExternalData = ext;
                end
                if ~isempty(md)
                    obj.Metadata = md;
                end
            else
                error('Must instantiate this object with either 1) a path to a session folder [e.g. teSession(''path_session'', <path>)], or 2) a teTracker [teSession(''tracker'', <tracker>)].')
            end
            obj.Tracker = tracker;
        
        end
        
        function tracker = ReadFromSessionPath(obj, path_session, includePrecombine)     
            
        % check input args and session data to ensure it can be loaded
            
            % check input args
            if ~exist('path_session', 'var') 
                error('You must initialise this instance by passing the path to a session folder.')
            elseif ~exist(path_session, 'file')
                error('Session path not found.')
            end
            
            % do format check on session
            if includePrecombine
                [passed, reason, file_tracker, tracker] =...
                    teIsSession(path_session, '-includePrecombine');
            else
                [passed, reason, file_tracker, tracker] =...
                    teIsSession(path_session);         
            end
            
            if ~passed
                error('Path [%s] does not refer to a valid Task Engine 2 session. Reason was:\n\n%s',...
                    path_session, reason)
            end
            
        % store main fields from the teTracker into teData properties
        
            % store session path
            obj.Paths('session') = path_session; 
            
            % find subject folder and store its path
            parts = strsplit(path_session, filesep);
            obj.Paths('subject') = [filesep, fullfile(parts{1:end - 1})];
            
            % store tracker path, and tracker
            obj.Paths('tracker') = file_tracker;
            
            % call superclass to read tracker properties
            obj.ReadFromTracker(tracker);
    
        % discover external data
        
            ext = obj.DiscoverExternalData;
            
        % attempt to read metadata from disk
        
            obj.ReadMetadata(tracker, ext);
            
%         % look for, and deal with, multiple sessions in the same subject
%         % folder
%         
%             if checkMultipleSessions
% %                 warning('Checking for multiple sessions currently disabled.')
% %                 obj.HandleMultipleSessions
%             end
            
        end
        
        function HandleMultipleSessions(obj)
        % find multiple sessions in the current subject folder    
            
        % find subfolders in the subject folder
        
            d = dir(obj.Path_Subject);
            
            % only folders
            d(~[d.isdir]) = [];
            
            % remove . and .. crap
            idx_crap = ismember({d.name}, {'.', '..'});
            d(idx_crap) = [];
            
        % make full absolute paths
            
            path_folders = cellfun(@(path, name) fullfile(path, name),...
                {d.folder}, {d.name}, 'UniformOutput', false);
            
        % filter for session folders
        
            idx_ses = cellfun(@teIsSession, path_folders);
            path_ses = path_folders(idx_ses);
            
        % remove currently-loaded session from session folders
        
            idx_current = strcmpi(obj.Path_Session, path_ses);
            path_ses(idx_current) = [];
            
        % make teData instance for each multiple session
        
            mData = cellfun(@(pth) teData(pth, 'dontCheckMultipleSessions'),...
                path_ses, 'UniformOutput', false);
            
        % filter out non-matching GUIDs from sessions
        
            mGUIDs = cellfun(@(x) x.GUID, mData, 'UniformOutput', false);
            idx_guidMatch = isequal(obj.GUID, mGUIDs);
            path_ses(~idx_guidMatch) = [];
            mData(~idx_guidMatch) = [];
            numSes = length(mData);
            
        end
        
        function ext = DiscoverExternalData(obj, varargin)
        % attempt to discover external data in the session folder. If any
        % external data is found, add an instance of the appropriate
        % teExternalData_ subclass to the teData instance as a dynamic
        % prop
        
            % find external data, and return teExternalData instnace(s)
            ext = teDiscoverExternalData(obj.Paths('session'), [], varargin{:});
            
            % add to object
            obj.ExternalData = [obj.ExternalData, ext];
            
        end
        
        function ReadMetadata(obj, tracker, ext)
            
            path_session = obj.Paths('session');
            md = teReadMetadataFromSessionFolder(path_session, tracker, ext);
            if ~isempty(md)
                obj.Metadata = md;
            end
            
%             path_md = fullfile(obj.Paths('session'), 'metadata');
%             if exist(path_md, 'dir')
%                 file_md = teFindFile(path_md, '*.metadata.mat', '-latest');
%                 if ~isempty(file_md)
%                     tmp = load(file_md);
%                     if ~isempty(tmp.metadata.Hash)
%                         % hash the tracker and external data and compare to
%                         % the has in the metadata file. If they match, load
%                         % the metadata. If they don't warn and continue
%                         % without the metadata (will have to run tepInspect
%                         % again to generate new metadata). 
%                         hash_disk = lm_hashClass(tracker, ext);
%                         if isequal(hash_disk, tmp.metadata.Hash)
%                             obj.Metadata = tmp.metadata;
%                         else
%                             warning('Metadata on disk did not match, and was not loaded (run tepInspect to create and save updated metadata): %s',...
%                                 file_md)
%                         end
%                     end
%                 end
%             end
            
        end
        
    end
    
end