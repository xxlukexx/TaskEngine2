function md = teReadMetadataFromSessionFolder(path_session, tracker, ext)

    md = [];
    path_md = fullfile(path_session, 'metadata');
    if exist(path_md, 'dir')
        file_md = teFindFile(path_md, '*.metadata.mat', '-latest');
        if ~isempty(file_md)
            tmp = load(file_md);
            if ~isempty(tmp.metadata.Hash)
                % hash the tracker and external data and compare to
                % the hash in the metadata file. If they match, load
                % the metadata. If they don't warn and continue
                % without the metadata (will have to run tepInspect
                % again to generate new metadata). 
                hash_disk = lm_hashClass(tracker, ext);
                if isequal(hash_disk, tmp.metadata.Hash)
                    md = tmp.metadata;
                else
                    warning('Metadata on disk did not match, and was not loaded (run tepInspect to create and save updated metadata): %s',...
                        file_md)
                end
            end
        end
    end
    
end