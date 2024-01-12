function metadata = teStimBaker(stimPath, type)

    metadata = struct;
    
    % get path to baked file
    bakedPath = [stimPath, '.baked.mat'];
    
    % try to load file
    success = false;
    if exist(bakedPath, 'file')
        try
            load(bakedPath);
            success = true;
        catch
        end
    end
    
    % determine type
    if ~exist('type', 'var') || isempty(type)
        if success && isfield(metadata, 'type')
            type = metadata.type;
        else
            type = teGetStimType(stimPath);
        end  
    end
    
    % set stim type
    metadata.type = type;
        
    % get file parts
    [~, metadata.File, metadata.Ext] = fileparts(stimPath);
    
    % if not found, return
    if ~exist(stimPath, 'file') || isempty(stimPath)
        metadata.missing = true;
        return
    else
        metadata.missing = false;
    end
    
    % get source file date/size
    d = dir(stimPath);
    
    % set date and time of source file in baked file
    metadata.datenum = d.datenum;
    metadata.bytes = d.bytes;
    
    % check file size/date matches
    if success
        hasCorrectFields = isfield(metadata, 'datenum') && isfield(metadata, 'bytes');
        changed = hasCorrectFields &&...
            (d.datenum ~= metadata.datenum || metadata.bytes ~= d.bytes);
        
        if strcmpi(type, 'IMAGE')
            changed = changed || ~isfield(metadata, 'image') ||...
                ~isfield(metadata.image, 'Data') || ~isfield(metadata.image, 'Map') ||...
                ~isfield(metadata.image, 'Alpha');
        end
    end
    
    % bake if necessary
    if ~success || changed
        
        % get info
        try
            switch type
                case 'MOVIE'
                    inf = mmfileinfo(stimPath);
                case 'IMAGE'
                    inf = imfinfo(stimPath);
                    [inf.image.Data, inf.image.Map, inf.image.Alpha] =...
                        imread(stimPath);
                case 'SOUND'
                    inf = audioinfo(stimPath);
                    [inf.sound.Data, inf.sound.fs] = audioread(stimPath);
            end
        catch ERR_INF
            metadata.missing = true;
            metadata.error =...
                sprintf('Could not load metadata - invalid format? %s',...
                stimPath);
        end
        
        % combine inf with metadata
        metadata = catstruct(metadata, inf);
        
        % save baked file
        save(bakedPath, 'metadata', '-v6');
        
    end

end

function [changed, newDate, newSize] = checkFile(filename, oldDate,...
    oldSize)

    % deal with instances in which no oldData and oldTime are passed - for
    % example when extracting date/size for the first time
    if ~exist('oldDate', 'var') || isempty(oldDate)
        oldDate = -1;
    end
    
    if ~exist('oldSize', 'var') || isempty(oldSize)
        oldSize = -1;
    end

    % get details
    d = dir(filename);
    newDate = d.datenum;
    newSize = d.bytes;
        
    % compare
    changed = newDate ~= oldDate || newSize ~= oldSize;

end

