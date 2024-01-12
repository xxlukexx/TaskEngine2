function ops = teJoinEnobioFolder(path_enobio, ops)

    if ~exist('ops', 'var') || isempty(ops)
        ops = struct;
    end
    
    ops.teJoinEnobioFolder_suc = false;
    ops.teJoinEnobioFolder_oc = 'unknown error';
    
    % find all .easy files in the folder, we'll join them all
    d_easy = dir([path_enobio, filesep, '*.easy']);
    d_info = dir([path_enobio, filesep, '*.info']);
    numFiles = length(d_easy);
    if numFiles == 0
        ops.teJoinEnobioFolder_oc =...
            sprintf('no .easy files found in %s', path_enobio);
        return
    elseif numFiles == 1
        ops.teJoinEnobioFolder_oc =...
            sprintf('only one .easy file found in %s', path_enobio);
        return
    end
    teEcho('Found %d enobio files to join in %s\n', numFiles, path_enobio);
    
    % get full paths to all files that need joining
    filesToJoin = fullfile({d_easy.folder}, {d_easy.name});
    
    % join
    [ops.teJoinEnobioFolder_suc, ops.teJoinEnobioFolder_oc] =...
        eegEnobio_join(filesToJoin{:});
    if ~ops.teJoinEnobioFolder_suc, return, end
    
    % zip up pre-joined files and delete originals
    path_zip = fullfile(path_enobio, '_prejoin.zip');
    filesToZip = [...
        fullfile({d_easy.folder}, {d_easy.name}),...
        fullfile({d_info.folder}, {d_info.name}),...
        ];
    teEcho('Backing up pre-joined files to %s...\n', path_zip);    
    zip(path_zip, filesToZip)
    
    % check zip file, and if it's OK, delete originals
    if exist(path_zip, 'file')
        cellfun(@delete, filesToZip);
    else
        ops.teJoinEnobioFolder_oc =...
            'Could not verify backup zip file, originals not deleted';
        return
    end 
    
end
    
    
    

    