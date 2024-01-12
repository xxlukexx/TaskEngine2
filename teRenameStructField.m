function sr = teRenameStructField(s, old, new)

    fnames = fieldnames(s);
    data = struct2cell(s);
    
    fnames_sr = strrep(fnames, old, new);
    sr = cell2struct(data, fnames_sr, 1);
    if isa(s, 'hstruct')
        sr = hstruct(sr);
    end

end