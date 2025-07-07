function [names, tabVarNames, sig, sig_u, sig_i, sig_s, logArray] =...
    teLogGetVariableNames(logArray, varargin)

    % defaults in case of failure
    names = [];
    tabVarNames = [];
    sig = [];
    sig_u = [];
    sig_i = [];
    sig_s = [];

    % get names of all  vars
    names = cellfun(@fieldnames, logArray, 'uniform', false);
    
    % make signature of each unique combination of data fields
    makeSignatures
    
    % filter by variable name (if requested)
    if ~isempty(varargin)
        % indices to remove
        remIdx = false(size(names));
        % get wanted vars and vars
        wantedVars = varargin(1:2:end);
        vars = names(sig_i);
        % loop vars
        for v = 1:length(vars)
            % flag matrix
            wanted = false(1, length(wantedVars));
            for wv = 1:length(wantedVars)
                % if this wanted var in this vars?
                wanted(wv) = any(ismember(wantedVars{wv}, vars{v}));
            end
            % remove unwanted from main names array
            if ~all(wanted)
                remIdx(sig_s == v) = true;
            end
        end
        % if no results, give up
        if all(remIdx)
            logArray = [];
            return
        end
        
        % remake signatures
        if any(remIdx)
            names(remIdx) = [];
            logArray(remIdx) = [];
            makeSignatures
        end
    end
        
    % a chunk is a collection of log items with the same var names. We
    % have identified chunks in sig_s, and sig_i indexes the first
    % occurrence of each chunk. To determine the final order of var
    % names when all log items have been put in to a table, we sort by
    % the number of var names in each chunk. For each chunk, we
    % conserve the ordering of var names. We move through chunks from
    % biggest to smallest. 
    
        % get var names for each chunk
        chVarNames = arrayfun(@(x) names{x}', sig_i, 'uniform', false);
        
        % get number of var names in each chunk 
        chVarLen = cellfun(@length, chVarNames);
        
        % sort chunks by number of var names, descending
        [chVarLen, so] = sort(chVarLen, 'descend');
        chVarNames = chVarNames(so);
        
        % place all var names next to each other in a vector. There will be
        % many repeats
        tabVarNames = horzcat(chVarNames{:});

        % remove repeats
        [~, tvn_i, tvn_s] = unique(tabVarNames);
        tabVarNames = tabVarNames(tvn_i);
        
    
    function makeSignatures
        sig = cellfun(@(x) horzcat(x{:}), names, 'uniform', false);
        [sig_u, sig_i, sig_s] = unique(sig);
    end
    
end