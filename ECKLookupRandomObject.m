function val = ECKLookupRandomObject(col, name)
    if ~isa(col, 'tePresenter')
        error('This is a rewritten function that is part of TaskEngine2. If you weren''t expecting that, check the path.')
    end
    val = col.Stim.LookupRandom('key', name);
end
