function [suc, oc, hash] = teImportExternalData(path_session, type, varargin)
% import externally recorded data into a Task Engine 2 data session.
% Supported data types are detailed below, but can include EEG, NIRS,
% Biopac or video recordings. 

    hash = {};
    suc = false;
    oc = 'unknown error';

% check validity of input arguments, and files

    % check session file can be found
    if ~teIsSession(path_session)
        suc = false;
        oc = sprintf('The folder [%s] is not a valid Task Engine 2 session.',...
            path_session);
        return
    end

    % valid data types
    validTypes = {'enobio', 'screenrecording'};
    if ~ismember(type, validTypes)
        suc = false;
        oc = sprintf('''%s'' is not a valid type. Valid types are: %s.',...
            type, cell2char(validTypes));
        return
    end
    
    % at least one file
    if isempty(varargin)
        suc = false;
        oc = 'No files specified';
        return
    end
    
    % define expected files for each type. These can be operated on by a
    % logical AND or a logival OR. For example, enobio files must have both
    % a .easy AND a .info file, whereas video files can be .avi or .mp4
    % etc. 
    switch type
        case 'enobio'
            expectedFiles = {'.easy', '.info'};
            expectedOperator = @all;
        case 'screenrecording'
            expectedFiles = {'.mp4', '.mov', '.m4v', '.avi', '.flv', 'mkv'};
            expectedOperator = @any;
    end
    
    % check that external files exist
    if ~all(cellfun(@(x) exist(x, 'file'), varargin))
        suc = false;
        oc = sprintf('One or more external files do not exist.');
        return
    end
    
    % check validity of external files
    [~, xtrFile, xtrExt] = cellfun(@fileparts, varargin,...
        'uniform', false);
    if ~expectedOperator(ismember(xtrExt, expectedFiles))
        suc = false;
        warning('Not all expected external files were specified. For ''type'' %s, expected files are:\n',...
            type)
        warning('\t- %s\n', expectedFiles{:})
        oc = 'Not all expected external files were specified.';
        return
    end
    
% hash original files
    hash = cellfun(@(x) CalcMD5(x, 'File'), varargin, 'uniform', false);

% copy to session folder

    % make type folder
    path_type = fullfile(path_session, type);
    [mkdir_suc, mkdir_err] = mkdir(path_type);
    if ~mkdir_suc
        suc = false;
        oc = sprintf('Error making type folder. Error was: %s', mkdir_err);
        return
    end
    
    % copy 
    file_dest = cellfun(@(file, ext)...
        fullfile(path_type, sprintf('%s%s', file, ext)), xtrFile, xtrExt,...
        'uniform', false);
    [copy_suc, copy_err] = cellfun(@(src, dest) copyfile(src, dest),...
        varargin, file_dest, 'uniform', false);
    % check for copy errors
    copyFailed = find(~cell2mat(copy_suc), 1);
    if ~isempty(copyFailed)
        suc = false;
        oc = copy_err{copyFailed};
        return
    end
    
    % check hash
    try
        newHash = cellfun(@(x) CalcMD5(x, 'File'), file_dest, 'uniform', false);
    catch hash_err
        suc = false;
        oc = sprintf('Destination hashing failed, error was: %s', hash_err.message);
        return
    end
    hashFailed = ~all(arrayfun(@(x, y) isequal(x, y), hash, newHash));
    if hashFailed
        suc = false;
        oc = 'At least one destination file failed during hashing';
        return
    end
    
    % save hash
    file_hash = cellfun(@(x) sprintf('%s.md5', x), file_dest,...
        'uniform', false);
    fid = cellfun(@(x) fopen(x, 'w'), file_hash);
    cellfun(@(id, hsh) fprintf(id, '%s', hsh), num2cell(fid), hash);
    arrayfun(@fclose, fid);
    
    suc = true;
    oc = '';
    
end