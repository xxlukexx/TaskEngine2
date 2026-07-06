function registry = teRegistrySaveRecord(registry, record, keyFields)
%TEREGISTRYSAVERECORD Insert or update one dataset registry record.
%
% Missing fields in an existing record are treated as "not reached". Updating
% a record recursively merges structs and overwrites scalar/vector leaves.

    if nargin < 3 || isempty(keyFields)
        keyFields = {'dataset_key'};
    elseif ischar(keyFields) || isstring(keyFields)
        keyFields = cellstr(string(keyFields));
    end

    registry = teRegistryNormalise(registry);
    if ~isstruct(record) || ~isscalar(record)
        error('record must be a scalar struct.')
    end

    missing = keyFields(~isfield(record, keyFields));
    if ~isempty(missing)
        error('Record is missing registry key field: %s', missing{1})
    end

    idx = localFindRecord(registry, record, keyFields);
    if isempty(idx)
        registry{end + 1, 1} = record;
    else
        registry{idx} = localMergeStructs(registry{idx}, record);
    end

end

function idx = localFindRecord(registry, record, keyFields)
    match = false(numel(registry), 1);
    for r = 1:numel(registry)
        item = registry{r};
        ok = true;
        for k = 1:numel(keyFields)
            key = keyFields{k};
            if ~isfield(item, key)
                ok = false;
                break
            end
            ok = ok && isequal(string(item.(key)), string(record.(key)));
        end
        match(r) = ok;
    end
    idx = find(match, 1);
end

function out = localMergeStructs(base, patch)
    out = base;
    names = fieldnames(patch);
    for n = 1:numel(names)
        name = names{n};
        if isfield(out, name) && isstruct(out.(name)) && isscalar(out.(name)) && ...
                isstruct(patch.(name)) && isscalar(patch.(name))
            out.(name) = localMergeStructs(out.(name), patch.(name));
        else
            out.(name) = patch.(name);
        end
    end
end
