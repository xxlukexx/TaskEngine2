classdef teStim < handle
    
    %TESTIM - general purpose class to hold image, sound and movie stimuli
    %   stim = teStim creates a blank instance of the teStim object. 
    %
    %   stim = teStim(filename) creates an instance and loads the stimulus
    %   referred to by filename. 
    %
    %   stim = teStim(filename, task) creates an instance, loads the
    %   stimulus referred to by filename, and associates the stimulus with
    %   task. 
    %
    %   stim.Load(filename, filetype) loads the stimulus referred to by
    %   filename, and optionally sets it's type to filetype. Loading of
    %   metadata is done by teStimBaker. If filetype is not specified,
    %   teStimBaker will attempt to determine the type from the file
    %   extension, and will return an error if not successful. Specifying
    %   filetype will skip this check and may lead to errors further down
    %   the line if, e.g., you attempt to load an image file as a movie. 
    %
    %   stim.State is the current state of the stimulus object. It can be:
    %       BLANK       - empty object, not metadata or data loaded
    %       LOADED      - metadata loaded, but not yet prepared for display
    %       PREPARED    - prepared for display
    %   Note that preparing means different things for different stimuli:
    %       Images: make PTB OpenGL texture from image data
    %       Movies/sounds: open through PTB/GStreamer
    %       Short sounds: to-do
    %   Preparation of stimuli is done by the presenter, since it needs
    %   access to the PTB window pointer, which only the presenter knows
    %   about. The preenter will call the SetPrepared method once this is
    %   done, and teStim will update it's state accordingly. 
    %
    %   stim.Close essentially "de-prepares" a stimulus, and releases its
    %   resources. For example, any PTB textures will be deleted,
    %   movies/sounds closed etc. 
    %
    %   stim.Play starts playing a movie/sound, and stim.Stop stops 
    %   playing. When a stimulus is stopped, it's state will revert back to
    %   PREPARED - i.e. no resources are released and it is ready to be
    %   resumed if the Play method is called again. Use stim.Close to
    %   really shut it down. 
    
    properties 
        Loop                = false
        PlaybackRate        = 1
    end
    
    properties (SetAccess = {?tePresenter})
        Task
        Filename        
        Duration            = nan
        Width               = nan
        Height              = nan
        AspectRatio         = nan
        ImageData           = nan
        ImageAlpha          = nan
        SampleRate          = nan
        TexturePtr          = nan
        MoviePtr            = nan
        SoundPtr            = nan   
        SoundBufferPtr      = nan
        SoundData           = []
        LastTouched         = nan
        DrawnTimestamp      = nan
        NeedsTimestamp      = false
    end
    
    properties (Dependent)
        Volume     
        SoundMode
        CurrentTime     
        Rect
    end
    
    properties (Dependent, SetAccess = private)
        Type
        State
        Prepared            
        Loaded              
        Playing             
        CanDraw
    end
    
    properties (Hidden)
        % used to allow the collection class to write the key of the item
        % in the collection as a name property, for backward compatibility
        % with ECK (where stim items had a name in their properties)
        Name
        PreviewTexturePtr
    end
    
    properties (Access = private)
        prType
        prState = 'BLANK'
        prVolume = 1
        prSoundMode = 'nextflip';
    end
    
    properties (Access = {?tePresenter})
        prCurrentTime = nan;
        gotNewFrame = false;
    end
    
    properties (Hidden, SetAccess = private)
        % performance optimisations for frequently called properties
        isImage = false
        isMovie = false
        isSound = false
        isShortSound = false
        isPrepared = false;
    end
    
    events
        AddLog
    end
    
    methods
        
        % contructor
        function obj = teStim(filename, task)
            % check PTB
            AssertOpenGL
            % check args
            if exist('filename', 'var') && ~isempty(filename)
                if ~exist('task', 'var') || isempty(task)
                    task = [];
                end
                obj.Load(filename, task)
            end
            % disable warning for Matlab bug in VideoReader
            warning off MATLAB:subscripting:noSubscriptsSpecified
        end
        
        function Load(obj, filename, task, type)
            % check filename
            if ~exist('filename', 'var') || isempty(filename)
                error('Must supply a path to a valid image, movie or sound file.')
            end
            
            % look for .baked file
            bakedPath = [filename, '.baked.mat'];
            % try to load file
            loadedFromBaked = false;
            if exist(bakedPath, 'file')
                try
                    % load
                    tmp = load(bakedPath);
                    % fill metadata
                    metadata = tmp.metadata;
                    % set type
                    type = metadata.type;
                    loadedFromBaked = true;
                catch
                end
            end
            
            % if we loaded from the .baked file, we need to ensure that the
            % stimulus media file has not changed since we last saw it
            bakedNeedsReload = false;            
            if loadedFromBaked
                % get file parts
                [~, metadata.File, metadata.Ext] = fileparts(filename);    
                % check for correct fields in metadata from .baked file
                hasCorrectFields = isfield(metadata, 'datenum') &&...
                    isfield(metadata, 'bytes');
                % if image type, check for data fields
                if strcmpi(type, 'IMAGE')
                    hasCorrectFields = hasCorrectFields ||...
                        ~isfield(metadata, 'image') ||...
                        ~isfield(metadata.image, 'Data') ||...
                        ~isfield(metadata.image, 'Map') ||...
                        ~isfield(metadata.image, 'Alpha');
                end                
                % if shortsound type, check for data fields
                if strcmpi(type, 'SHORTSOUND')
                    hasCorrectFields = hasCorrectFields ||...
                        ~isfield(metadata, 'sound') ||...
                        ~isfield(metadata.sound, 'Data') ||...
                        ~isfield(metadata.sound, 'fs');
                end           
                % get file details of target media file 
                d = dir(metadata.filepath);
                % determine whether file size OR file date have changed
                dateChanged = ~isempty(d) && ~isequal(d.datenum, metadata.datenum);
                sizeChanged = ~isempty(d) && ~isequal(metadata.bytes, d.bytes);
                changed = dateChanged || sizeChanged;
                bakedNeedsReload = changed || ~hasCorrectFields;
            end 
                
            % if we couldn't load the baked file, we get all the metadata
            % (and, if image or shotsound, load the actual data)
            if ~loadedFromBaked || bakedNeedsReload
                
                % empty metadata var
                metadata = struct;
                
                % default missing media flag
                useMissingMedia = false;
                
                % if not specified, determine type from filename
                if ~exist('type', 'var') || isempty(type)
                    type = teGetStimType(filename);
                end            
            
                % check that the file exists, otherwise load default
                % missing media stimuli. This prevents errors on load and
                % allows scripts to run, albeit with (obviously) wrong
                % stimuli
                if ~exist(filename, 'file')
                    % warn
                    warning('File %s does not exist, using missing media instead.',...
                        filename)          
                    useMissingMedia = true;
                end
                
                % if type is SHORTSOUND (in which case we will be using
                % PsychPortAudio) then make sure the sample rate is 48Khz.
                % PPA can't mix sampling rates, so we standardise on 48KHz
                % and require all sound files to be that frequency. If the
                % sample rate doesn't match, use missing media instead (so
                % that it's clear that something is wrong)
                if strcmpi(type, 'SHORTSOUND') && isfield(metadata, 'sound') &&...
                        isfield(metadata.sound, 'fs') &&...
                        metadata.sound.fs ~= 48000
                    warning('Stimuli of type SHORTSOUND must have a sampling rate of 48Khz. %s did not, so did not load.',...
                        filename)
                    useMissingMedia = true;
                end
                    
                if useMissingMedia
                    % get path to assets folder
                    [path_te, ~, ~] = fileparts(which('teStimBaker'));
                    path_assets = fullfile(path_te, 'assets');
                    % if assets folder is not found, we can't continue so throw
                    % an error
                    if ~exist(path_assets, 'dir')
                        error('File %s not found, and missing media could not be located in %s.',...
                            filename, path_assets)
                    end
                    % load appropriate missing media by type of the stim we
                    % attempted to load
                    switch upper(type)
                        case 'MOVIE'
                            filename = fullfile(path_assets, 'not_found.mp4');
%                             obj.Loop = true;
                        case 'IMAGE'
                            filename = fullfile(path_assets, 'not_found.png');
                        case {'SOUND', 'SHORTSOUND'}
                            filename = fullfile(path_assets, 'not_found.wav');
                    end   
                end
                
                % get file details, store in metadata
                d = dir(filename);
                metadata.bytes = d.bytes;
                metadata.datenum = d.datenum;
                metadata.type = type;
                metadata.filepath = filename;
                
                % check that file size is not zero - % todo merge with
                % useMissingMedia
                if metadata.bytes == 0
                    error('Media size is zero.')
                end
                
                % get metadata
                try
                    switch type
                        case 'MOVIE'
                            info = mmfileinfo(filename);
                        case 'IMAGE'
                            info = imfinfo(filename);
                            % also laod image data
                            [info.image.Data, info.image.Map,...
                                info.image.Alpha] = imread(filename);
                            % if this is a binary b&w image, Matlab will
                            % store it as logical. This is illegal for PTB,
                            % so detect and convert to uint8
                            if islogical(info.image.Data)
                                info.image.Data = uint8(255 *...
                                    info.image.Data);
                            end
                            % if this is greyscale, copy the luminance
                            % channel to RGB channels
                            if size(info.image.Data, 3) == 1
                                info.image.Data = repmat(info.image.Data,...
                                    1, 1, 3);
                            end
                        case 'SOUND'
                            info = audioinfo(filename);
                        case 'SHORTSOUND'
                            info = audioinfo(filename);                            
                            % also load sound data
                            [info.sound.Data, info.sound.fs] =...
                                audioread(filename);
                    end
                    % cat to metadata
                    metadata = catstruct(metadata, info);
                    % save .baked file
                    save(bakedPath, 'metadata')
                catch ERR_INF
                    error('Could not load metadata - invalid format? %s',...
                        filename);
                end
                
            end
        
            % store the metadata (whether it came from the .baked file, or
            % was read directly from the media file) and store it in the
            % appropriate props
            obj.Type = type;
            obj.Filename = filename;            
            switch obj.prType
                case 'MOVIE'
                    obj.Duration    = metadata.Duration;
                    obj.CurrentTime = 0;
                    obj.Width       = metadata.Video.Width;
                    obj.Height      = metadata.Video.Height;
                    obj.AspectRatio = obj.Width / obj.Height;
                case 'IMAGE'
                    obj.Width       = metadata.Width;
                    obj.Height      = metadata.Height;
                    obj.AspectRatio = obj.Width / obj.Height;
                    % put alpha in 4th channel
                    if ~isempty(metadata.image.Alpha)                    
                        metadata.image.Data(:, :, 4) = metadata.image.Alpha;
                    end
                    obj.ImageData   = metadata.image.Data;
                    obj.ImageAlpha  = 255 - metadata.image.Alpha; 
                case 'SOUND'
                    obj.Duration    = metadata.Duration;
                    obj.CurrentTime = 0;
                    obj.SampleRate  = metadata.SampleRate;
                case 'SHORTSOUND'
                    obj.Duration    = metadata.Duration;
                    obj.CurrentTime = 0;
                    obj.SampleRate  = metadata.SampleRate;
                    obj.SoundData   = metadata.sound.Data;
                    obj.SampleRate  = metadata.sound.fs;                    
            end
            % assign task
            if exist('task', 'var') && ~isempty(task)
                obj.Task = task;
            end
            obj.SetClosed
            % send a log event to the presenter
            logData = teLogEventData('source', 'stim',...
                'topic', 'stim', 'data', sprintf('Loaded %s', filename));
            notify(obj, 'AddLog', logData)
        end     
        
        function ImportImage(obj, img, task)
            
            % assign task
            if exist('task', 'var') && ~isempty(task)
                obj.Task = task;
            end
            
            % store the metadata (whether it came from the .baked file, or
            % was read directly from the media file) and store it in the
            % appropriate props
            obj.Type = 'IMAGE';
            obj.Filename = 'imported_image';        
            obj.Width       = size(img, 2);
            obj.Height      = size(img, 1);
            obj.AspectRatio = obj.Width / obj.Height;
            % detect RGB/grayscale
            if size(img, 3) == 1 || size(img, 3) == 3
                % grayscale or rgb
                obj.ImageData = img;
                obj.ImageAlpha = [];
            elseif size(img, 3) == 2
                % assume grayscale with alpha channel
                obj.ImageData = img;
                obj.ImageAlpha = img(:, :, 2);
            elseif size(img, 3) == 4
                % assume rgb with alpha
                obj.ImageData = img;
                obj.ImageAlpha = img(:, :, 4);
            else
                error('Unexpected number of colour/alpha channels (%d).',...
                    size(img, 3))
            end
            obj.SetClosed
            % send a log event to the presenter
            logData = teLogEventData('source', 'stim',...
                'topic', 'stim', 'data', 'Imported image');
            notify(obj, 'AddLog', logData)    
            
        end
        
        function SetStopped(obj)
            if ~obj.Playing
                error('Cannot stop a stimulus that is not playing.')
            end
            switch obj.Type
                case {'MOVIE', 'SOUND'}
                case 'IMAGE'
                    error('Cannot stop an image.')
                case 'SHORTSOUND'
            end
            obj.prState = 'PREPARED';  % may need some error checking here
        end

        function SetPlaying(obj)
            % check loaded/prepared (n.b. this will be done by the
            % presenter, not the user)
            if ~obj.Loaded
                error('Stimulus must be loaded and prepared before it is played.')
            elseif ~obj.Prepared
                error('Stimulus must be prepared before it is played.')
            end
            % play
            switch obj.Type
                case {'MOVIE', 'SOUND'}
                    % start PTB playing 
                case 'IMAGE'
                    error('Cannot play an image.')
                case 'SHORTSOUND'
                    % start PTB playing
            end
            % update state
            obj.prState = 'PLAYING';  % may need some error checking here
        end

        function SetPrepared(obj, ptr_main, ptr_preview)
            if ~obj.Loaded
                error('Cannot prepare an unloaded stimulus.')
            end
            if nargin <= 2
                ptr_preview = [];
            end
            switch obj.Type
                case 'IMAGE'
                    obj.TexturePtr = ptr_main;
                    obj.PreviewTexturePtr = ptr_preview;
                    obj.prState = 'PREPARED';
                    obj.isPrepared = true;
                case 'MOVIE'
                    obj.TexturePtr = ptr_main;
                    obj.PreviewTexturePtr = ptr_preview;
                    obj.prState = 'PREPARED';
                    obj.isPrepared = true;
                case 'SOUND'
                    obj.SoundPtr = ptr_main;
                    obj.prState = 'PREPARED';
                    obj.isPrepared = true;                    
            end
        end
        
        function SetClosed(obj)
            if obj.Playing
                error('Cannot close a playing stimulus.')
            end
            switch obj.Type
                case 'IMAGE'
                    obj.TexturePtr = nan;
                    obj.prState = 'LOADED';
                    obj.isPrepared = false;
                case 'MOVIE'
                    obj.MoviePtr = nan;
                    obj.TexturePtr = nan;
%                     obj.CurrentTime = nan;
                    obj.prState = 'LOADED';
                    obj.isPrepared = false;
                case 'SOUND'
                    obj.SoundPtr = nan;
%                     obj.CurrentTime = nan;
                    obj.prState = 'LOADED';
                    obj.isPrepared = false;
                otherwise
                    warning('Not yet implemented.')
                    % todo implement for sounds
            end            
        end
        
%         function Close(obj)
%             % check state
%             if ~obj.Loaded 
%                 warning('Cannot close an unloaded stimulus.')
%                 return
%             end
%             % stop
%             switch obj.Type
%                 case {'MOVIE', 'SOUND'}
%                     warning('Should close movie frame texture here!')
%                     Screen('CloseMovie', obj.MoviePtr);
%                 case 'IMAGE'
%                     Screen('Close', obj.TexturePtr);
%                 case 'SHORTSOUND'
%                     % TODO
%             end
%             % update state
%             obj.prState = 'LOADED';
%         end
            
        % get/set
        function val = get.Type(obj)
            if isempty(obj.prType)
                val = nan;
            else
                val = obj.prType;
            end
        end
        
        function set.Type(obj, val)
            obj.isMovie = false;
            obj.isImage = false;
            obj.isSound = false;
            obj.isShortSound = false;
            switch lower(val)
                case 'movie'
                    obj.isMovie = true;
                case 'image'
                    obj.isImage = true;
                case 'sound'
                    obj.isSound = true;
                case 'shortsound'
                    obj.isShortSound = true;
            end
            obj.prType = val;
        end
        
        function val = get.State(obj)
            val = obj.prState;
        end
        
        function val = get.CanDraw(obj)
            % check type
            val = false;
            switch obj.Type
                case 'IMAGE'
                    val = val && obj.Loaded;
                case 'MOVIE'
                    val = val && obj.Loaded;
                    % do we also need to check if playing?
            end
        end
        
        function set.PlaybackRate(obj, val)
            if ~isnumeric(val) || ~isscalar(val)
                error('PlaybackRate must be a numeric scalar.')
            end
            obj.PlaybackRate = val;
        end
        
        function set.Loop(obj, val)
            if ~islogical(val) || ~isscalar(val)
                error('Loop must be a logical scalar.')
            end
            obj.Loop = val;
        end
        
        function set.Volume(obj, val)
            if obj.Playing
                error('Cannot change volume when a stimulus is playing.')
            end
            if ~isnumeric(val) || val < 0 || val > 1 || ~isscalar(val)
                error('Volume must be between 0 and 1.')
            end
            if val ~= obj.prVolume
                obj.prVolume = val; 
                if obj.Prepared, obj.prState = 'LOADED'; end
            end
        end
        
        function val = get.Volume(obj)
            val = obj.prVolume;
        end
        
        function val = get.Loaded(obj)
            val = any(ismember(lower(obj.prState),...
                {'loaded', 'prepared', 'playing'}));
        end
        
        function val = get.Prepared(obj)
%             val = obj.isPrepared;
            val = any(ismember(lower(obj.prState),...
                {'prepared', 'playing'}));
        end
        
        function val = get.Playing(obj)
            val = strcmpi(obj.prState, 'playing');
        end
        
        function val = get.SoundMode(obj)
            if obj.isSound
                val = obj.prSoundMode;
            else
                val = nan;
            end
        end
        
        function set.SoundMode(obj, val)
            if ~ismember(val, {'nextflip', 'immediate'})
                error('SoundMode must be ''nextlip'' or ''immediate''.')
            else
                obj.prSoundMode = val;
            end
        end
        
        function set.CurrentTime(obj, val)
            % only sounds and movies have a current time
            if ~obj.isMovie && ~obj.isSound
                error('Can only set CurrentTime for movies or sounds.')
            end
            if ~isnumeric(val) || ~isscalar(val) || val < 0 ||...
                    val > obj.Duration + 1
                error('CurrentTime must be a positive numeric scalar, less than the duration of the stimulus.')
            end
            obj.prCurrentTime = val;
%             fprintf('Set stim [%s] time index to %d\n', obj.Filename, val);
        end
        
        function val = get.CurrentTime(obj)
            val = obj.prCurrentTime;
        end
        
        function val = get.Rect(obj)
            val = [0, 0, obj.Width, obj.Height];
        end
        
%         function set.prState(obj, val) 
%             obj.prState = val;
%             if isempty(obj.Name)
%                 name = obj.Filename;
%             else
%                 name = obj.Name;
%             end
%             teEcho('Stimulus %s state set to %s\n', obj.Name, val);
%         end
  
    end
    
    % backward compat methods for ECK
    methods (Hidden)
        
        function Play(obj, ~)
%             pres = teFindPresenter;
%             pres.PlayStim(obj)
        end
        
    end
    
end