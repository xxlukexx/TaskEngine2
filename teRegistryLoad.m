function registry = teRegistryLoad(jsonPath)
%TEREGISTRYLOAD Load a JSON dataset registry as a Task Engine log array.
%
% The registry is stored on disk as a JSON array of objects. In MATLAB it is
% returned as a cell column vector of scalar structs so teLogExtract and
% teLogFilter can tabulate/query it directly. Missing files return an empty
% registry.

    if nargin ~= 1
        error('Usage: registry = teRegistryLoad(jsonPath)')
    end

    if ~isfile(jsonPath)
        registry = {};
        return
    end

    txt = strtrim(fileread(jsonPath));
    if isempty(txt)
        registry = {};
        return
    end

    data = jsondecode(txt);
    registry = teRegistryNormalise(data);

end
