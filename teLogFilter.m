function [tab, idx, la] = teLogFilter(logArray, varargin)

    if isempty(logArray)
        tab = [];
        idx = [];
        return
    end
    
    numPairs = length(varargin);
    
    % if no var/fcn pairs are supplied then we simply return the whole
    % table
    if numPairs == 0
        tab = teLogExtract(logArray);
        idx = ones(size(tab, 1), 1);
        return
    end
    
    % check that input args can be paired
    if mod(numPairs, 2) ~= 0
        error('Input arguments must be pairs of ''variable''/''function''.')
    end
    
    % extact pairs
    vars = varargin(1:2:end);
    fcns = varargin(2:2:end);
    
    % second argument of each pair can be a function handle or a char. If
    % char, it is assumed to be a text filter, so build a function for it
    char_fcn = cellfun(@ischar, fcns);
    num_fcn = cellfun(@isnumeric, fcns) | cellfun(@islogical, fcns);
    if any(char_fcn)
        fcns(char_fcn) = cellfun(@(x) sprintf('@(x) strcmpi(x, ''%s'')', x),...
            fcns(char_fcn), 'uniform', false);
        fcns(char_fcn) = cellfun(@str2func, fcns(char_fcn), 'uniform', false);
    end    
    if any(num_fcn)
        fcns(num_fcn) = cellfun(@(x) sprintf('@(x) isequal(x, %d)', x),...
            fcns(num_fcn), 'uniform', false);

        fcns(num_fcn) = cellfun(@str2func, fcns(num_fcn), 'uniform', false);
        
    end
    
    % check that pairs are of the right data type
    if ~all(cellfun(@ischar, vars))
        error('First argument of each pair must be ''variable'' as char.')
    end
    if ~all(cellfun(@(x) isa(x, 'function_handle'), fcns))
        error('Second argument of each pair must be ''function'' as function handle.')
    end
    
    if iscell(logArray)
    
        [fnames, fnames_u, ~, ~, sig_i, sig_s, logArray] =...
            teLogGetVariableNames(logArray, varargin{:});   
        
        % if logArray is empty, it is because no vars were found in the
        % log. 
        if isempty(logArray)
            fprintf(2, 'The requested variables:\n\n')
            fprintf(2, '\t%s\n', vars{:})
            error('Variables not found in the log.')
        end

        % attempt to execute each function
        idx = true(size(logArray, 1), 1);
        for v = 1:length(vars)
            % 20230726 - added any() to fcns below to catch log fields that
            % are cell arrays. These return a vector of true/false,
            % corresponding to whether fcn was true for each element. This
            % isn't the purpose of this function so I changed it to any. 
            idx = idx & cellfun(@(x) any(fcns{v}(x.(vars{v}))), logArray);
        end
        
        % first filter the log array using the idx from the previous step.
        % Then extract all log items. This is faster than extracting all
        % log items, then filtering. However it messes up the LogIdx table
        % variable, which references the original index of the log item. We
        % therefore update the table's LogIdx variable via the index used
        % to filter the table
        tab = teLogExtract(logArray(idx));
        
        % make a temp log index vector, ensure it is a col vector
        logIdx_tmp = find(idx);
        if ~isvector(logIdx_tmp)
            error('Log index returned a non-vector -- debug!')
        end
        
        % if a row vector, transpose to col vector
        if size(logIdx_tmp, 1) == 1 
            logIdx_tmp = logIdx_tmp';
        end
        
        tab.logIdx = logIdx_tmp;
        
    elseif istable(logArray)
        
        tab = logArray;
        
        % if no table variables match search variables then return empty
        if ~any(ismember(vars, tab.Properties.VariableNames))
            tab = [];
            idx = [];        
            return
        end        

        % attempt to execute each function
        idx = false(size(tab, 1), 1);
        for v = 1:length(vars)
%             idx = feval(fcns{v}, tab.(vars{v}))
            res = dbsparsefun(fcns{v}, tab.(vars{v}));
            if v == 1
                idx(res) = true;
            else
                idx = idx & res;
            end
        end
        tab = tab(idx, :);
        
    end
    
    
    % if no results, quit
    if isempty(tab), return, end
    % remove empties
    tvars = tab.Properties.VariableNames;
    empty = false(length(tvars), 1);
    for tv = 1:length(tvars)
        % get the contents (rows of values) for this variable
        contents = tab.(tvars{tv});
        % in case of matrix nested inside cell array (e.g. rows of RGB
        % colours), unpack to a vector to avoid an error when testing for
        % empty below
        contents = contents(:);
        % test for empty
        if iscell(contents(1))
            empty(tv) = all(cellfun(@isempty, contents));
        else
            empty(tv) = all(arrayfun(@isempty, contents));
        end
    end
    tab(:, empty) = [];
    
    if nargout == 3
        la = structArray2cellArrayOfStructs(table2struct(tab));
        if isscalar(la) 
            la = la{1};
        end
    end
    
end