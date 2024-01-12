function [suc, oc, hash] = teImportExternalDataInteractive(...
    path_session, dataType, fileList, filterSpec)
% import external data by interacting with the user via the command window.
% First the user is asked whether they wish to import a particular data
% type. If the accept then they are asked for the location of the file.
% Results are logged to the presenter. 
%
% Multiple files can be requested for one data type. For example, if a raw
% EEG dataset is comprised of a header and a data file, they will both be
% of the 'eeg' data type. In this case, fileList will be {'header', 'data'}
%
% - path_session        The session path to import data TO
%
% - dataType            Char describing the external data type
%
% - fileList            Cell array of strings describing each individual
%                       file that is expected
%
% - filterSpec          optional uigetfile filterSpec (e.g. '*.jpg'). Must
%                       be of the same length as fileList

% check input args

    % session folder
    if ~teIsSession(path_session)
        error('Not a valid session folder: %s', path_session)
    end
    
    % data type
    if ~ischar(dataType)
        error('''dataType'' must be char.')
    end
    
    % file list
    if ischar(fileList)
        % put into cell array
        fileList = {fileList};
    end
    if ~iscellstr(fileList)
        error('''fileList'' must be a cell array of strings.')
    end
    numFiles = length(fileList);
    
    % filterSpec
    if ~exist('filterSpec', 'var') || isempty(filterSpec)
        filterSpec = '*.*';
    end
    if ischar(filterSpec)
        % put into cell array
        filterSpec = {filterSpec};
    end
    if ~iscellstr(filterSpec)
        error('''filterSpec'' must be a char or cell array of string.')
    end
    if length(filterSpec) ~= length(fileList)
        error('''filterSpec'' must be the same length as ''fileList''.')
    end

    % get presenter
    pres = teFindPresenter;
    if isempty(pres)
        warning('No tePresenter found in the global workspace - results will not be logged.')
    end
    
    % loop through files
    toImport = {};
    for f = 1:numFiles
        
        % prompt
        teEcho('\n[%d of %d] %s: %s...\n', f, numFiles,...
            upper(dataType), fileList{f});
        % get response
        resp = enforceinput('Do you wish to import the file now? If not, session will be marked as incomplete (y/n) > ',...
            {'y', 'n'});
        % check response
        if isequal(resp, 'y')
            % get file path
            happy = false;
            while ~happy
                [file, pth] = uigetfile(filterSpec{f});
                happy = ~isequal(pth, 0);
            end
            % store details
            toImport{end + 1}    = fullfile(pth, file);
        else
            pres.AddLog(...
                'source',       'braintools_eeg_main',...
                'topic',        'external_data_import',...
                'type',         'enobio_easy',...
                'success',      false,...
                'outcome',      'user_declined');
        end
        
    end
    
    % do importing
    [suc, oc, hash] = teImportExternalData(path_session, dataType,...
        toImport{:});
    % log outcome
    pres.AddLog(...
        'source',       'braintools_eeg_main',...
        'topic',        'external_data_import',...
        'type',         dataType,...
        'success',      suc,...
        'outcome',      oc);
    % echo
    if suc
        teEcho('Successfully imported %s external data.\n', dataType);
    else
        teEcho('Failed to import %s external data: %s\n', dataType, oc);
    end

end
