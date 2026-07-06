function registry = teRegistryNormalise(data)
%TEREGISTRYNORMALISE Convert decoded JSON registry data to a cell log array.

    if isempty(data)
        registry = {};
        return
    end

    if iscell(data)
        registry = data(:);
    elseif isstruct(data)
        registry = num2cell(data(:));
    else
        error('Registry data must be a JSON object array / MATLAB struct array / cell array.')
    end

    if ~all(cellfun(@(x) isstruct(x) && isscalar(x), registry))
        error('Registry entries must be scalar structs.')
    end

end
