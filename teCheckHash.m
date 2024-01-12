function result = teCheckHash(file)

    % read existing hash by appending .md5 to filename
    if ~exist(file, 'file'), result = []; return, end
    path_old = sprintf('%s.md5', file);
    fid = fopen(path_old);
    hash_old = fread(fid);
    hash_old = char(hash_old');
    fclose(fid);
    
    % calculate hash based on current data on disk
    hash_new = CalcMD5(file, 'File');
    
    % compare
    result = isequal(hash_old, hash_new);
    
end
    
    