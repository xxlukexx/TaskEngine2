classdef teTask < handle

    properties 
        TrialEndAction = 'continue'
        FlushBuffersOnTrialEnd = true
        ClearAOIsOnTrialEnd = true
    end
    
    properties (SetAccess = private)
        Path
        Functions
    end
    
    properties (Access = private)
        prTrialFunctionIdx
    end
    
    properties (Dependent, SetAccess = private)
        TrialFunction
    end
    
    properties (SetAccess = private)
        Version
        VersionString
    end
    
    properties (SetAccess = {?tePresenter, ?teCollection})
        Name
        TrialNo = 0
        NextTaskWillChange = false
    end
    
    methods
        
        function obj = teTask(path, trialFun)
            % check args
%             if ~exist('name', 'var')
%                 error('Must provide a task name.')
%             else
%                 obj.Name = name;
%             end
            if ~exist('path', 'var')
                error('Must provide a path to the task folder.')
            else
                obj.Path = path;
            end
            % check path
            if ~exist(path, 'dir')
                error('Path does not exist.')
            end
            % discover functions
            obj.DiscoverTaskFunctions
            % attempt to load version information
            verFunIdx = find(instr(obj.Functions, '_ver'), 1);
            if ~isempty(verFunIdx)
                verFun = obj.Functions{verFunIdx};
                % if a trial function was passed as an input argument, make
                % a copy in case it is overwritten from the _ver file
                if exist('trialFun', 'var')
                    oldTrialFun = trialFun;
                    trialFunExists = true;
                else
                    trialFunExists = false;
                end
                % load from _ver
                [obj.Version, obj.VersionString, trialFun] = feval(verFun);
                % warn if overwriting
                if trialFunExists
                    warning('Overwrote trial function from _ver file (%s) with that from input argument (%s) ',...
                        trialFun, oldTrialFun)
                end
            end
            % set trial function (optional). This can be set by passing a
            % value when the teTask instance if created, or loaded from a
            % _ver file. Trial functions loaded from _ver files overwrite
            % those supplied as input arguments to the constructor. The
            % trial function can be one of the functions in the folder, or
            % a .m file on the Matlab path
            if exist('trialFun', 'var')
                
                trialFunIsOnPath = exist(trialFun, 'file') == 2;
                trialFunIsInCollection = ismember(trialFun, obj.Functions);
                
                % if the trial function exists on the path, but is not one
                % of the functions defined for this task, then make it one
                if trialFunIsOnPath && ~trialFunIsInCollection
                    obj.Functions{end + 1} = trialFun;
                end
                
                % now set the task's trial function by looking up it's
                % index in the Functions collection. If it's not in there,
                % throw an error
                if ismember(trialFun, obj.Functions)
                    obj.prTrialFunctionIdx = find(strcmpi(obj.Functions,...
                        trialFun));
                else
                    error('Trial function (%s) was not found in task folder.',...
                        trialFun)
                end
                
            end            
        end
        
        function DiscoverTaskFunctions(obj)
            % check path
            if isempty(obj.Path)
                error('Path is empty.')
            elseif ~exist(obj.Path, 'dir')
                error('Path does not exist.')
            end
            % get files
            d = dir([obj.Path, filesep, '*.m']);
            if isempty(d) 
                error('No trial functions found.')
            end
            obj.Functions = {d.name};
            % add to path
            onPath = cellfun(@(x) exist(x, 'file') == 2,...
                obj.Functions);
            addpath(obj.Path)
            if any(onPath)
                onPathWhich = cellfun(@which, obj.Functions, 'uniform',...
                    false);
                onPathSummary =...
                    cellfun(@(x, y) sprintf('%s: %s\n', x, y),...
                    obj.Functions(onPath), onPathWhich(onPath),...
                    'uniform', false);
               teEcho(...
                   ['Some of the functions in the task folder are '         ,...
                    'already in the Matlab path.\nBe careful not to have '  ,...
                    'duplicates! According to Matlab, these are the\n'     ,...
                    'versions that will be used:\n\n']);
                teEcho('%s', onPathSummary{:});
                teEcho('\nIf you are reinstalling/updating, this message is safe to ignore.\n');
                teEcho('\n\n');
            end
            % strip off .m suffix
            obj.Functions = cellfun(@(x) x(1:end - 2), obj.Functions,...
                'uniform', false);
        end
        
        % set/get
        function val = get.TrialFunction(obj)
            if isempty(obj.prTrialFunctionIdx)
                val = [];
            else
                val = obj.Functions{obj.prTrialFunctionIdx};
            end
        end
        
        function set.TrialEndAction(obj, val)
            validValues = {'continue', 'repeat', 'resampleFromList'};
            if ~ismember(lower(val), lower(validValues))
                validValuesStr = sprintf('\t%s\n', validValues{:});
                error('Valid values for TrialEndAction are:\n%s',...
                    validValuesStr)
            else
                obj.TrialEndAction = val;
            end
        end
        
        function set.FlushBuffersOnTrialEnd(obj, val)
            if ~islogical(val) || ~isscalar(val)
                error('FlushBuffersOnTrialEnd must be a logical scalar.')
            else
                obj.FlushBuffersOnTrialEnd = val;
            end
        end
        
    end

end