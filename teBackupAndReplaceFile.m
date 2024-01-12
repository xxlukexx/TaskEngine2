function [suc, oc] = teBackupAndReplaceFile(var, varName, path_to_replace, zip_prefix)

    suc = false;
    oc = 'unknown error';

    try
        
        % break filename apart from path
        [pth, fil] = fileparts(path_to_replace);
        
        % zip up the existing file
        file_zip = fullfile(pth, sprintf('%s#%s.zip', fil, zip_prefix));
        zip(file_zip, path_to_replace)
        
        % make a new var called varName, then save it
        eval(sprintf('%s = var;', varName));
        eval(sprintf('save(''%s'', ''%s'')', path_to_replace, varName));

    catch ERR
        
        suc = false;
        oc = ERR.message;
        return
        
    end

    suc = true;
    oc = '';

end

