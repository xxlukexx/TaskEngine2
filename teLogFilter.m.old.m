function [tab, idx] = teLogFilter(logArray, varargin)

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
    
    [fnames, fnames_u, ~, ~, sig_i, sig_s, logArray] =...
        teLogGetVariableNames(logArray, varargin{:});   
    
    % attempt to execute each function
    idx = true(size(logArray, 1), 1);
    for v = 1:length(vars)
        idx = idx & cellfun(@(x) fcns{v}(x.(vars{v})), logArray);
    end
    tab = teLogExtract(logArray(idx));
    % if no results, quit
    if isempty(tab), return, end
    % remove empties
    tvars = tab.Properties.VariableNames;
    empty = false(length(tvars), 1);
    for tv = 1:length(tvars)
        contents = tab.(tvars{tv});
        if iscell(contents(1))
            empty(tv) = all(cellfun(@isempty, contents));
        else
            empty(tv) = all(arrayfun(@isempty, contents));
        end
    end
    tab(:, empty) = [];
    
end