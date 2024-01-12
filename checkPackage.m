function [res, errmsg] = checkPackage(pkg, throwError)

    if ~exist('throwError') || isempty(throwError)
        throwError = true;
    end
    
    res = false;
    errmsg = 'Unknown error';
    
    switch pkg
        case 'ECKAnalyse'
            res = ~isempty(which('ECKData'));
        case 'lm_tools'
            res = ~isempty(which('ECKData'));
        otherwise
            error('Unrecognised package')
    end
    
    if ~res
        % try to add to path
    end
    
end
    