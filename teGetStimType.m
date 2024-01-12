function type = teGetStimType(stimPath)
    % get extension
    [~, ~, ext] = fileparts(stimPath);
    % determine type from extension
    switch upper(ext(2:end))
        case {'PNG', 'JPEG', 'JPG', 'GIF', 'TIF', 'TIFF'}
            type = 'IMAGE';
        case {'WAV', 'MP3'}
            type = 'SOUND';
        case {'AVI', 'MP4', 'MPEG4', 'MOV', 'MKV', 'M4V'}
            type = 'MOVIE';
        otherwise 
            error('Unrecognised file format.')
    end
end