function ops = teBatchSyncVideo(db)
% syncs all un-synced videos in a teAnalysisDatabase

    if nargin == 0 || isempty(db) || ~isa(db, 'teAnalysisClient')
        error('First argument must be a teAnalysisClient instance.')
    end
    
    if db.NumDatasets == 0
        warning('No datasets in database.')
    end
    
    ops = cell(db.NumDatasets, 1);
    for v = 1:db.NumDatasets
        
        ops{v}.operation = 'sync_video';
        ops{v}.success = false;
        ops{v}.outcome = 'unknown error';
        
        % get metadata
        md = db.Metadata(v);
        
%         % convert to logical struct for ease of field access
%         mdl = logicalstruct(md);
        
        % can dataset be processed?
%         if md.Checks.can_process
%             ops{v}.outcome = 'Dataset not ready for processing.';
%             continue
%         end
        
        % has dataset already been synced?
        if md.Checks.sync_video
            ops{v}.outcome = 'Video already synced.';
            continue
        end
        
%         % has a previous attempt failed?
%         if md.Checks.sync_video_failed
%             ops{v}.outcome = 'Video already synced and failed.';
%             continue
%         end
        
        % check video path
        path_video = db.GetPath('screenrecording', 'GUID', md.GUID);
        if isempty(path_video) || ~ischar(path_video) || ~exist(path_video, 'file')
            ops{v}.outcome = 'screenrecording path not found.';
            continue
        end
        
        % check PTB
        AssertOpenGL
        
        % sync
        try
            % clear PTB stuff in case of previous error
            Screen('CloseAll')
            sync = teSyncVideo(path_video);
        catch ERR
            ops{v}.outcome = sprintf('Error in teSyncVideo: %s', ERR.message);
            continue
        end
        
        % check sync
        numFound = length(sync.videoTime);
        if numFound == 0
            ops{v}.outcome = 'No sync markers found in video.';
            md.Checks.sync_video_failed = true;
            md.Checks.sync_video_outcome = 'No sync markers found in video.';
        end
        
        % check video GUIDs are consistent
        if ~all(cellfun(@(x) isequal(sync.GUID{1}, x), sync.GUID(2:end)))
            ops{v}.outcome = 'Video GUIDs were not consistent.';
            md.Checks.sync_video_failed = true;
            md.Checks.sync_video_outcome = 'Video GUIDs were  not consistent.';
        end
        
        % check GUID
        if ~all(cellfun(@(x) isequal(md.GUID, x), sync.GUID(2:end)))
            ops{v}.outcome = 'Video GUID did not match session GUID.';
            md.Checks.sync_video_failed = true;
            md.Checks.sync_video_outcome = 'No sync markers found in video.';
        end
        
        % update database metadata
        [suc, err] = db.UpdateMetadata(md);
        if ~suc
            ops{v}.outcome = sprintf('Failed to update metadata: %s', err);
        end
        
    end
    
end
        
        