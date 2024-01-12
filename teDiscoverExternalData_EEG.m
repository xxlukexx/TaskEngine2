function obj = teDiscoverExternalData_EEG(path_in)

    % get all files in the folder
    d = dir(path_in);
    files = struct2table(d);
    idx_crap = ismember(files.name, {'.', '..'});
    files(idx_crap, :) = [];

    % split into path, file, extension
    [files.path, files.filename, files.ext] =...
        cellfun(@(x) fileparts(x), files.name, 'UniformOutput', false);

    % define EEG types against file types
    types = {...
        'enobio',               'teExternalData_Enobio',                    {'.easy', '.info'}                 ;...
        'brainproducts',        'teExternalData_EEG_brainproducts',         {'.eeg', '.vhdr', '.vmrk'}          ;...
            };
    numTypes = size(types, 1);

    % compare extensions in folder against EEG types define above
    for t = 1:numTypes

        if all(ismember(types{t, 3}, files.ext))

            try
                className = types{t, 2};
                obj = feval(className, path_in);
            catch ERR
                obj = teExternalData;
                obj.InstantiateOutcome = ERR.message;           
            end
            break

        end

    end













end