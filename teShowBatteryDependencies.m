function teShowBatteryDependencies(path_battery)

    % find all registry files
    d = dir([path_battery, filesep, '*.reg.mat']);
    numFiles = length(d);
    
    for f = 1:numFiles
        
        tmp = load(fullfile(d(f).folder, d(f).name));
        if ~isa(tmp.reg, 'teRegistry')
            continue
        end
        
        fprintf('Battery: %s\n\n\tTasks:\n', d(f).name);
        cellfun(@(x) fprintf('\t\t%s\n', x), tmp.reg.Tasks.Keys,...
            'UniformOutput', false);
        
        fprintf('\tPaths:\n', d(f).name);
        cellfun(@(x) fprintf('\t\t%s\n', x), tmp.reg.Paths.Keys,...
            'UniformOutput', false);
        
        fprintf('\tLists:\n', d(f).name);
        cellfun(@(x) fprintf('\t\t%s\n', x), tmp.reg.Lists.Keys,...
            'UniformOutput', false);                
        
    end

end