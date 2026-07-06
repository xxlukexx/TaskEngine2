function [tab, registry, files] = teRegistryQueryFolder(rootPath, varargin)
%TEREGISTRYQUERYFOLDER Concatenate registry JSON files and query with teLogFilter.
%
% Usage:
%   tab = teRegistryQueryFolder(rootPath)
%   tab = teRegistryQueryFolder(rootPath, 'status', 'ok')
%   [tab, registry, files] = teRegistryQueryFolder(...)
%
% Registry files are discovered recursively using *registry*.json.

    if nargin < 1 || isempty(rootPath)
        rootPath = pwd;
    end

    files = dir(fullfile(rootPath, '**', '*registry*.json'));
    registry = {};
    filePaths = strings(numel(files), 1);

    for f = 1:numel(files)
        filePaths(f) = string(fullfile(files(f).folder, files(f).name));
        thisRegistry = teRegistryLoad(filePaths(f));
        registry = [registry; thisRegistry]; %#ok<AGROW>
    end

    files = filePaths;
    if isempty(varargin)
        tab = teLogExtract(registry);
    else
        tab = teLogFilter(registry, varargin{:});
    end

end
