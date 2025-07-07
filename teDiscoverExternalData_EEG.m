function [obj, ft] = teDiscoverExternalData_EEG(path_in)
    % teDiscoverExternalData_EEG  Detect and load EEG data from a folder
    %
    %   OBJ = teDiscoverExternalData_EEG(PATH_IN) examines all files in the
    %   directory PATH_IN, determines which supported EEG data format is
    %   present, and returns an object of the corresponding handler class.
    %   If loading fails, returns a default teExternalData object with the
    %   error message in InstantiateOutcome.
    
    obj = [];
   ft = [];

    % List all entries in the input folder
    d = dir(path_in);
    files = struct2table(d);
    
    % Remove the '.' and '..' entries
    idx_crap = ismember(files.name, {'.', '..'});
    files(idx_crap, :) = [];

    % Split each filename into its path, name, and extension
    %    - files.path     : the folder part (always empty here since dir only returns names)
    %    - files.filename : the base filename without extension
    %    - files.ext      : the file extension (including the dot), e.g. '.eeg'
    [files.path, files.filename, files.ext] = ...
        cellfun(@(x) fileparts(x), files.name, 'UniformOutput', false);

    % Define supported EEG systems:
    %    types is an N×3 cell array where each row is:
    %      { system_tag, handler_class_name, required_extensions }
    types = {...
    %   data type               handler class                               extensions                      rank    
        'enobio',               'teExternalData_Enobio',                    {'.easy', '.info'}              2    ; ...
        'brainproducts',        'teExternalData_EEG_brainproducts',         {'.eeg', '.vhdr', '.vmrk'}      2    ; ...
        'fieldtrip',            'teExternalData_Fieldtrip',                 {'.mat'}                        3    ; ...
    };
    types = cell2table(types, 'VariableNames', {'type', 'class_name', 'extensions', 'rank'});
    numTypes = size(types, 1);
    
    % find all types present in this data
    idx_types_present = false(numTypes, 1);
    for t = 1:numTypes
        idx_types_present(t) = all(ismember(types.extensions{t}, files.ext));
    end
    num_types_present = sum(idx_types_present);
    
    % if more than on type, try to decide on rank
    if num_types_present > 1
        types = sortrows(types(idx_types_present, :), 'rank');
        types = types(1, :);
    else
        types = types(idx_types_present, :);
    end
    
    % if not events found, return an empty class
    if num_types_present == 0
        return
    end
    
    types = table2struct(types);

    % If every required extension for this type is found in files.ext
    if all( ismember(types.extensions, files.ext) )

        try

            % Instantiate the corresponding handler class
            className = types.class_name;
            obj = feval(className, path_in);

        catch ERR
            % On error, fall back to a generic object and store message
            obj = [];
            obj.InstantiateOutcome = ERR.message;
        end

    end

end
