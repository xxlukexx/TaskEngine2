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
    
%     % add numeric index to each name, for later sorting
%     nameIdx = cell(size(names));
%     for n = 1:length(names)
%         nameIdx{n} = 1:length(names{n});
%     end
    
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
        
%         tmp = cell(sum(chVarLen), 1);
%         s1 = 1;
%         s2 = chVarLen(1);
%         tmp(s1:s2) = chVarNames{1};
%         for v = 2:length(chVarNames)
%             idx_rem = ismember(chVarNames{v}, tmp(1:s2));
%             chVarNames{v}(idx_rem) = [];
%             s1 = s2 + 1;
%             s2 = s2 + length(chVarNames{v});
%         end
%         
%         % for each chunk, make a vector indicating a sort order to restore
%         % the current order once the values have been alphabetised
%         [chVarNames_c, ~, chVarNames_s] = cellfun(@unique, chVarNames, 'uniform', false);
        
        % place all var names next to each other in a vector. There will be
        % many repeats
        tabVarNames = horzcat(chVarNames{:});

        % remove repeats
        [~, tvn_i, tvn_s] = unique(tabVarNames);
        tabVarNames = tabVarNames(tvn_i);
        
        
% %         [
%         
% 
%         % get number of unique names for each log item
%         lens = cellfun(@length, chVarNames);
%         
%         % find the longest set of unique names
%         idx_longest = lens == max(lens);
%         uOrder = chVarNames{idx_longest};
%         
% %         % get sort order of longest unique names
% %         [~, so] = sort(uOrder);
%         
%         % get unique names across entire log array
%         [ch_u, ch_i, ch_s] = unique(horzcat(chVarNames{:}));
% 
%         tmp = cell(size(chVarNames));
%         maxPos = max(lens) + 1;
%         for un = 1:length(chVarNames)
%             idx = find(strcmpi(chVarNames{un}, uOrder));
%             if isempty(idx)
%                 idx = maxPos;
%                 maxPos = maxPos +  1;
%             end
%             tmp{idx} = chVarNames{un};
%         end
%         idx_empty = cellfun(@isempty, tmp);
% %         tmp(idx_empty) = [];
%         chVarNames = tmp;
%         
%         % generic vars are always first in the order
%         genVars = {'date', 'timestamp', 'source', 'topic'};
%         if any(ismember(genVars, chVarNames))
%             genVarIdx = cellfun(@(x) find(strcmpi(x, chVarNames)), genVars);
%             chVarNames = [chVarNames(genVarIdx), setdiff(chVarNames, genVars)];
%         end
    
    function makeSignatures
        sig = cellfun(@(x) horzcat(x{:}), names, 'uniform', false);
        [sig_u, sig_i, sig_s] = unique(sig);
    end
    
end