function teRecSyncVideos(path_in)

    allFiles = recdir(path_in);
    [~, ~, ext] = cellfun(@fileparts, allFiles, 'uniform', false);
    idx_isVideo = cellfun(@(x) ismember(x, {'.mov', '.avi', '.mp4', '.m4v'}), ext);
    allFiles = allFiles(idx_isVideo);
    teSyncVideo(allFiles);

end