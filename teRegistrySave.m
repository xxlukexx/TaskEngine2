function teRegistrySave(jsonPath, registry)
%TEREGISTRYSAVE Save a Task Engine dataset registry to JSON.
%
% The registry must be a cell vector of scalar structs. Values should be
% JSON-portable scalars/vectors or nested scalar/vector structs. Larger data
% objects should be represented by filename/path references.

    if nargin ~= 2
        error('Usage: teRegistrySave(jsonPath, registry)')
    end

    registry = teRegistryNormalise(registry);
    teRegistryValidate(registry);

    parent = fileparts(jsonPath);
    if ~isempty(parent) && ~isfolder(parent)
        mkdir(parent);
    end

    if isempty(registry)
        jsonText = "[]";
    else
        jsonText = string(jsonencode(registry, PrettyPrint = true));
    end

    fid = fopen(jsonPath, 'w');
    if fid == -1
        error('Could not open registry JSON for writing: %s', jsonPath)
    end
    cleaner = onCleanup(@() fclose(fid));
    fwrite(fid, jsonText, 'char');
    fwrite(fid, newline, 'char');

end
