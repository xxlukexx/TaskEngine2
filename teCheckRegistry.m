function teCheckRegistry(reg)

    teTitle('Check Registry\n\n');
    
    if isa(reg, 'teRegistry')
        teEcho('Registry format is correct.\n\n');
    else
        teEcho('Registry format is not correct (should be ''teRegistry'', was ''%s'')\n', class(reg));
        return
    end
    
    % validate paths
    pathFound = cellfun(@(x) exist(x, 'dir') == 7, reg.Paths.Items);
    teEcho('Paths: ');
    teEcho('%d of %d paths were found.\n', sum(pathFound), length(pathFound));
    if any(~pathFound)
        teEcho('Paths not found were:\n');
        for i = 1:length(pathFound)
            if ~pathFound(i)
                teEcho('\t-%s [%s]', reg.Paths.Keys{i}, reg.Paths.Items{i});
            end
        end
        teEcho('\nYou can continue with a missing path, but it might cause errors if you attempt to use that path\nin any subsequent code.\n');
    end

    % validate task trial functions
    tfFound = cellfun(@(x) exist(x.TrialFunction, 'file') == 2, reg.Tasks.Items);
    teEcho('\n\nTask trial functions: ');
    teEcho('%d of %d trial functions were found.\n', sum(tfFound), length(tfFound));
    if any(~tfFound)
        teEcho('Trial functions not found were:\n');
        for i = 1:length(tfFound)
            if ~tfFound(i)
                teEcho('\t-%s [%s]\n', reg.Tasks.Keys{i}, reg.Tasks.Items{i}.TrialFunction);
            end
        end
        teEcho('\nAny attempt to use these tasks will result in an error.\n');
    end
    
    % summary
    if all(pathFound) && all(tfFound)
        teEcho('\nRegistry format, all paths and all trial functions were correct.\n');
    end


end