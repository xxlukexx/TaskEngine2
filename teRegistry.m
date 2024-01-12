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
    
end