function [suc, oc, res, tab, smry] = teCalculateExpectedTrialsFromList(listCol, rootListName)

    suc = false;
    oc = 'unknown error';
        
    % parse list
    
%         listCol = ses.Tracker.Lists;
    
        [suc_parse, oc_parse, res] = recParseList(listCol, rootListName);
        if ~suc_parse
            oc = oc_parse;
            return
        end
        
    % summarise results
    tab = teLogExtract(res);
    smry = tabulate(tab.Task);
    smry = smry(:, 1:2);   

    suc = true;
    oc = '';

end

function [suc, oc] = checkListValidity(list)

    suc = false;
    oc = 'unknown error';

    % data type
    if ~isa(list, 'teList')
        oc = sprintf('specified element (%s) was not a teList object', rootListName');
        return
    end

    tab = list.Table;
    if isempty(tab)
        oc = 'passed list contained an empty Table property';
        return
    end

    % required variables
    if ~all(ismember({'Enabled', 'Type', 'Target', 'Task', 'NumSamples'}, tab.Properties.VariableNames))
        oc = 'passed list must contain the following variables: Enabled, Type, Target, Task, NumSamples';
        return
    end
    
    suc = true;
    oc = '';

end

function [suc, oc, res] = recParseList(listCol, curListName, startSample, numSamples)

    debug = false;

    suc = false;
    oc = 'unknown error';
        
    if ~exist('res', 'var') || isempty(res)
        res = {};
    end    
    
    if ~exist('startSample', 'var') || isempty(startSample)
        startSample = 1;
    end
    if ~exist('numSamples', 'var') || isempty(numSamples)
        % empty NumSamples will use list default in teList.SampleFromList
        numSamples = [];
    end
    
    % check format of list
    
        % listCol must be a collection of teList objects
        if ~isa(listCol, 'teListCollection')
            oc = 'passed variable was not a teCollection object of lists';
            return
        end
        
        % all elements of the collection must be teLists
        if ~all(cellfun(@(x) strcmpi(class(x), 'teList'), listCol.Items))
            oc = 'passed variable was a teCollection but not all elements were lists';
            return
        end
        
        % rootListName must be char
        if ~ischar(curListName)
            oc = 'rootListName must be a string (char)';
            return
        end
        
        % look for root list in collection
        list = listCol(curListName);
    
        [suc_list, oc_list] = checkListValidity(list);
        if ~suc_list
            oc = oc_list;
            return
        end
        
        [suc_listVal, oc_listVal] = checkListValidity(list);
        if ~suc_listVal
            oc = sprintf('failed during %s: %s', oc_listVal, curListName);
            return
        end
        
    % parse
    
%         tab = list.SampleTable;    
        [~, tab] = list.SampleFromList(startSample, numSamples);
        
        % remove list rows that aren't enabled (since these won't have been
        % executed, so won't be in the data)
        tab = tab(tab.Enabled, :);
        
        numRows = size(tab, 1);
        localRes = res;
        for r = 1:numRows
            
            if debug, fprintf('debug: row %d of list %s\n', r, list.Name); end
            
            switch lower(tab.Type{r})
                
                case 'trial'
                    
                    if debug, fprintf('debug: trial: %s | %s \n', tab.Task{r}, tab.Target{r}); end
                    
                    logItem = table2struct(tab(r, :));
                    
                    % get number of samples planned to be executed for this
                    % row. If NaN, assume 1. 
                    if isnan(logItem.NumSamples)
                        logItem.NumSamples = 1;
                    end                    
                    
                    localRes = [localRes; logItem];
                                
                case 'nestedlist'
                    
                    if debug, fprintf('debug: nested list: %s | %s \n', tab.Task{r}, tab.Target{r}); end
                    
                    [suc_rec, oc_rec, recRes] =...
                        recParseList(listCol, tab.Target{r}, tab.StartSample(r), tab.NumSamples(r));
                    if ~suc_rec
                        oc = sprintf('failed during %s: %s', oc_rec, curListName);
                        return
                    end
                    
                    % flatten results
                    localRes = [localRes; recRes];
                    
%                     s1 = r - 1;
%                     if s1 < 1, s1 = 1; end
%                     s2 = r + 1; 
%                     if s2 > numRows, s2 = numRows; end
%                     if r == 1
%                         localRes = [recRes; localRes(s2:end)];
%                     else
%                         localRes = vertcat(localRes(1:s1), recRes{:}, localRes(s2:end));
%                     end
                    
            end
            
        end
            
        res = localRes;
        
        % mark each log item as being 'scheduled'
        for i = 1:length(res)
            res{i}.calc_type = 'scheduled';
        end
    
    suc = true;
    oc = '';

end