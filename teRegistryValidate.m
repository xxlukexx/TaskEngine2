function teRegistryValidate(registry)
%TEREGISTRYVALIDATE Check registry entries are portable JSON-sized values.
%
% Registry leaves may be scalar/vector numeric, logical, char, string, or
% cell arrays containing those values. Structs may be scalar or vectors. Tables,
% MATLAB objects, and non-vector arrays should be written to a separate file
% and referenced by filename/path instead.

    registry = teRegistryNormalise(registry);
    for r = 1:numel(registry)
        localValidateValue(registry{r}, sprintf('registry{%d}', r));
    end

end

function localValidateValue(value, path)
    if isstruct(value)
        if ~(isscalar(value) || isvector(value))
            error('Registry value at %s is a non-vector struct array. Store it by file reference.', path)
        end
        for i = 1:numel(value)
            names = fieldnames(value(i));
            for n = 1:numel(names)
                name = names{n};
                localValidateValue(value(i).(name), sprintf('%s.%s', path, name));
            end
        end
    elseif isnumeric(value) || islogical(value) || isstring(value) || ischar(value)
        if ~(isscalar(value) || isvector(value) || isempty(value))
            error('Registry value at %s is a non-vector array. Store it by file reference.', path)
        end
    elseif iscell(value)
        if ~(isscalar(value) || isvector(value) || isempty(value))
            error('Registry value at %s is a non-vector cell array. Store it by file reference.', path)
        end
        for i = 1:numel(value)
            localValidateValue(value{i}, sprintf('%s{%d}', path, i));
        end
    else
        error('Registry value at %s has unsupported class %s. Store it by file reference.', path, class(value))
    end
end
