function vars = teLoadSerialisedMatFile(path_mat)

    vars = [];
    if ~exist(path_mat, 'file')
        error('File not found: %s', path_mat)
    end
    
    vars = load(path_mat);
    fnames = fieldnames(vars);
    for i = 1:length(fnames)
        tmp = vars.(fnames{i});
        if isa(tmp, 'uint8') && isvector(tmp)
            try
                deser = getArrayFromByteStream(tmp);
            catch ERR
                error('Could not deserialise variables.')
            end
            vars.(fnames{i}) = deser;
        end
    end
    
end
    
    