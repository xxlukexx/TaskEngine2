function tab = tePreprocessSounds(path_in, path_out, path_sox)

    CONST_SUPPORTED_STIM_FORMATS = {'WAV', 'MP3'};
        
    % check input path exists
    if ~exist(path_in, 'dir')
        error('Path %d not found.', path_in);
    end
    % if no output path given, overwrite (i.e. use unput path)
    overwrite = ~exist('path_out', 'var') || isempty(path_out);

    if ~exist('path_sox', 'var') || isempty(path_sox)
        path_sox = '/usr/local/bin/sox';
    end
    
    % get all files
    files = recdir(path_in);
    res = cell(length(files), 1);
    for f = 1:length(files)
        teEcho('File %d of %d [%s]\n', f, length(files), files{f});
        % get file extension
        [file_path, file_name, file_ext] = fileparts(files{f});
        % compare to suppoerted formats
        if ismember(upper(file_ext(2:end)), upper(CONST_SUPPORTED_STIM_FORMATS))
            % make filenames
            if overwrite
                file_out = [tempdir, file_name, file_ext];
            else
                file_out = fullfile(path_out, [file_name, file_ext]);
            end
            cmd = sprintf('"%s" --clobber --norm=-23 "%s" -r 48000 -c 2 -b 24 "%s"',...
                path_sox, files{f}, file_out);
            [success, msg] = system(cmd);
            if success == 0
                movefile(file_out, files{f});
                res{f} = file_out;
            else
                res{f} = msg;
            end
        else
            res{f} = 'Skipped: unsupported format';
        end
    end
    
    tab = cell2table([files, res], 'variablenames', {'File', 'Action'});
    if nargout == 0, disp(tab), end
    
end
        
    
