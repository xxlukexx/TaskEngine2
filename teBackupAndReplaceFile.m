function [suc, oc] = teBackupAndReplaceFile(var, varName, path_to_replace, zip_prefix)

    suc = false;
    oc  = 'unknown error';

    try
        % Break filename apart from path
        [pth, fil, ext] = fileparts(path_to_replace);

        % Zip up the existing file (store only the filename in the zip, not the full path)
        file_zip = fullfile(pth, sprintf('%s#%s.zip', fil, zip_prefix));
        if exist(path_to_replace, 'file') == 2
            oldDir = cd(pth);
            c = onCleanup(@() cd(oldDir));      % ensure we cd back even on error
            zip(file_zip, [fil ext]);
        else
            % If the file to be replaced doesn't exist yet, that's OK—no zip made
        end

        % Save 'var' into MAT-file under the variable name given by varName, no eval
        S = struct();
        S.(varName) = var;
        % -struct expands fields of S as variables in the MAT-file
        save(path_to_replace, '-struct', 'S');             % add '-v7.3' if needed for large data

        suc = true;
        oc  = '';

    catch ERR
        suc = false;
        oc  = ERR.message;
    end
end


% function [suc, oc] = teBackupAndReplaceFile(var, varName, path_to_replace, zip_prefix)
% 
%     suc = false;
%     oc = 'unknown error';
% 
%     try
%         
%         % break filename apart from path
%         [pth, fil] = fileparts(path_to_replace);
%         
%         % zip up the existing file
%         file_zip = fullfile(pth, sprintf('%s#%s.zip', fil, zip_prefix));
%         zip(file_zip, path_to_replace)
%         
%         % make a new var called varName, then save it
%         eval(sprintf('%s = var;', varName));
%         eval(sprintf('save(''%s'', ''%s'')', path_to_replace, varName));
% 
%     catch ERR
%         
%         suc = false;
%         oc = ERR.message;
%         return
%         
%     end
% 
%     suc = true;
%     oc = '';
% 
% end
% 
