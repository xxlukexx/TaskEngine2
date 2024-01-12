function varargout = teReadyForTrial(varargin)
        
    % check that a presenter was passed
    if nargin < 1
        problem = 'presenter';
    end
    % check for valid presenter, and window open
    if nargin >= 1
        pres = varargin{1};
        if ~isa(pres, 'tePresenter')
            problem = 'presenter';
        elseif ~pres.WindowOpen
            problem = 'nowindow';
        end
    end
    % get variables
    if nargin > 1
        vars = structFieldsToLowercase(varargin{2});
    else
        vars = [];
    end
    % get task
    if nargin > 2
        task = varargin{3};
    else
        task = [];
    end

    % determine trial type
    switch lower(vars.type)
        case 'eck'
            % make ECK vars
            if ~isempty(vars)
                ECKVars = struct2cell(vars)';
                ECKVarNames = fieldnames(vars)';
            end
            % build output args
            varargout = {pres, vars, ECKVars, ECKVarNames};
            
        case 'trial'
            % build output args
            varargout = {pres, vars, task};
            
        otherwise
            error('teReadyForTrial can only accept list items of type ''trial'' or ''ECK''.')
            
    end
    
    % look for the presenter's CurrentVariables property. If called by
    % tePresenter.ExecuteList this will contain the variables defined in
    % the list. 
            
    problem = 'none';
    switch problem
        case 'none'
            % make presenter ready
            pres.KeyFlush;
            % todo - update keyboard, eye tracker, screen? think this is
            % handled by tePresenter.ExecuteList / FlushBuffer?
            return
            
        case 'presenter'
            error('No presenter object was found. Call trial functions with a tePresenter instance as an input argument')
            
        case 'nowindow'
            error('Presenter window must be open before a trial can start.')
            
        otherwise
            error('Unknown error - problem was %s', problem)
            
    end
    
end