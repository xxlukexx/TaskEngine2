function [suc, oc, tab_smry, tab_res, tab_sched, tab_pres] =...
    teMatchExpectedTrialsToPresented(tracker, logArray, rootListName)

    suc = false;
    oc = 'unknown error';
    res = [];

    [suc_calc, oc_calc, res_calc, tab_sched, smry_sched] =...
        teCalculateExpectedTrialsFromList(tracker.Lists, rootListName);
    numCalc = length(res_calc);
    
    tab_pres = teLogFilter(logArray,...
        'topic', 'trial_change', 'data', 'trial_onset');

    idx_sched = 1;
    idx_pres = 1;
    tab_res = table;
    tab_res.task = cell(numCalc, 1);
    tab_res.idx_sched = nan(numCalc, 1);
    tab_res.idx_pres = nan(numCalc, 1);
    tab_res.matched = false(numCalc, 1);
    stop = false;
    while ~stop
        
        task_sched = res_calc{idx_sched}.Task;
        task_pres = tab_pres.source{idx_pres};
        
        tab_res.task{idx_sched} = task_sched;
        tab_res.idx_sched(idx_sched) = idx_sched;
        tab_res.idx_pres(idx_sched) = idx_pres;
        
        if strcmpi(task_sched, task_pres)
            tab_res.matched(idx_sched) = true;
            idx_sched = idx_sched + 1;
            idx_pres = idx_pres + 1;
        else
            idx_pres = idx_pres + 1;
        end
        
        if idx_pres > length(res_calc) || idx_sched > size(tab_pres, 1)
            stop = true;
        end
        
    end
    
    % summary
    tab_all = tab_sched(:, {'Task', 'calc_type'});
    tab_pres_smry = tab_pres(:, {'source'});
    tab_pres_smry.Properties.VariableNames{'source'} = 'Task';
    tab_pres_smry.calc_type = repmat({'presented'}, size(tab_pres_smry, 1), 1);
    tab_all = [tab_all; tab_pres_smry];
    tab_all.val = ones(size(tab_all, 1), 1);
    [task_u, ~, task_s] = unique(tab_all.Task);
    [type_u, ~, type_s] = unique(tab_all.calc_type);
   
    m = accumarray([task_s, type_s], tab_all.val, [], @sum);
    tab_smry = array2table(m, 'RowNames', task_u, 'VariableNames', type_u);
    tab_smry.missing = tab_smry.scheduled - tab_smry.presented;

    suc = true;
    oc = '';

end