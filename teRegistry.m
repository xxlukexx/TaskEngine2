classdef teRegistry < handle
    
    properties
        Paths teCollection
        Tasks teCollection
        Lists teListCollection
    end
    
    properties (Dependent, SetAccess = private)
        PathValidity
        AllPathsValid
    end
    
    methods
        
        % constructor
        function obj = teRegistry
            % init collections
            obj.Paths = teCollection('char');
            obj.Tasks = teCollection('teTask');
            obj.Tasks.ReturnKeyAsNameProp = true;
            obj.Lists = teListCollection;
        end
        
        function matches = VerifyAgainstPresenter(obj, pres)
            lists = isequal(obj.Lists, pres.Lists);
            tasks = isequal(obj.Tasks, pres.Tasks);
            paths = isequal(obj.Paths, pres.Paths);
            
            if ~lists
                teEcho('\t- Lists do not match.\n');
            end
            if ~tasks
                teEcho('\t- Tasks do not match.\n');
            end
            if ~paths
                teEcho('\t- Paths do not match.\n');
            end
            
            matches = lists && tasks && paths;
            
        end
        
        % get/set
        function val = get.PathValidity(obj)
            if isempty(obj.Paths)
                % if no paths defined, return empty
                val = [];
                return
            else
                keys = obj.Paths.Keys';
                paths = obj.Paths.Items';
                ex = cellfun(@(x) {exist(x, 'dir') ~= 0 ||...
                    exist(x, 'file') ~= 0}, paths);
                val = cell2table([keys, paths, ex], 'variablenames',...
                    {'Key', 'Path', 'Valid'});
            end 
        end
        
        function val = get.AllPathsValid(obj)
            tab = obj.PathValidity;
            val = all(tab.Valid);
        end
        
    end
    
    methods (Static)
        function obj = loadobj(s)
            % loadobj is called automatically when an object is loaded.
            % It accepts either a struct (from an older save) or an object instance.
            if isstruct(s)
                % Convert the struct to a teRegistry object.
                obj = teRegistry();
                obj.Paths         = s.Paths;
                obj.Tasks         = s.Tasks;
                obj.Lists         = s.Lists;
                obj.PathValidity  = s.PathValidity;
                obj.AllPathsValid = s.AllPathsValid;
            else
                obj = s;
            end
            
            % Display a summary of the registry contents.
            fprintf('\n== teRegistry Object Loaded ==\n');
            
            % Display Paths summary
            fprintf('\nPaths (%d entries):\n', obj.Paths.Count);
            % Iterate over the validity table to display each path.
            % (Assumes that obj.PathValidity is a table with variables: Key, Path, Valid)
            for i = 1:height(obj.PathValidity)
                % Retrieve the key, path, and validity status.
                key = obj.PathValidity.Key{i};      % assuming a cell array of strings
                pathStr = obj.PathValidity.Path{i};   % path string
                if obj.PathValidity.Valid(i)
                    status = 'valid';
                else
                    status = 'invalid';
                end
                fprintf('  %s: %s (%s)\n', key, pathStr, status);
            end
            
            % Display Tasks summary
            fprintf('\nTasks (%d entries):\n', obj.Tasks.Count);
            fprintf('Task Names:\n');
            for i = 1:obj.Tasks.Count
                fprintf('  %s\n', obj.Tasks.Keys{i});
            end
            
            % Display Lists summary
            fprintf('\nLists (%d entries):\n', obj.Lists.Count);
            fprintf('List Names:\n');
            for i = 1:obj.Lists.Count
                fprintf('  %s\n', obj.Lists.Keys{i});
            end
            
            fprintf('=================================\n');
        end
    end
    
end