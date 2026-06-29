function [suc, oc] = teReplaceSequentialEvents(path_ses)
% teReplaceSequentialEvents
% Replace sequential/linked Enobio event markers (e.g., 10000,10001,...) in a
% Neuroelectrics .easy file with their original numeric event codes using the
% session log lookup table (source = teEventRelay_Enobio_linked).
%
% Workflow:
%   1) Load teSession from path_ses
%   2) Locate the raw Enobio .easy file via ses.ExternalData('enobio').Paths('enobio_easy')
%   3) Build lookup from teLogFilter(... 'teEventRelay_Enobio_linked')
%   4) Drop non-numeric lookup rows (e.g., eye tracking labels)
%   5) Replace per-sample markers in penultimate column of .easy matrix
%   6) Zip backup of original .easy file
%   7) Overwrite original .easy with updated version (atomic via temp file)
%
% Outputs:
%   suc : logical true/false
%   oc  : outcome string ('ok' on success; otherwise an error/outcome message)
%
% Notes:
%   - Only sequential codes present in the lookup table with numeric .data are replaced.
%   - Any sequential markers found in the .easy file but missing from the lookup table
%     are left unchanged (a warning is emitted).

    suc = false;
    oc  = 'unknown error';

    % ----------------------------
    % Basic input/dependency checks
    % ----------------------------
    if nargin < 1 || isempty(path_ses)
        fail('path_ses is missing or empty.'); return;
    end
    if ~(ischar(path_ses) || isstring(path_ses))
        fail('path_ses must be a char or string.'); return;
    end
    path_ses = char(path_ses);

    if ~exist(path_ses, 'dir')
        fail(sprintf('Session folder not found: %s', path_ses)); return;
    end
    if isempty(which('teSession'))
        fail('teSession not found on MATLAB path.'); return;
    end
    if isempty(which('teLogFilter'))
        fail('teLogFilter not found on MATLAB path.'); return;
    end

    % ----------------------------
    % Load session, locate .easy file
    % ----------------------------
    try
        ses = teSession(path_ses);
    catch ME
        fail(sprintf('Failed to load teSession from %s: %s', path_ses, ME.message)); return;
    end

    try
        ext = ses.ExternalData('enobio');
    catch
        fail('Session does not contain ExternalData(''enobio'').'); return;
    end

    try
        path_easy = ext.Paths('enobio_easy');
    catch
        fail('Could not locate enobio_easy path in ses.ExternalData(''enobio'').Paths.'); return;
    end
    path_easy = char(path_easy);

    if ~exist(path_easy, 'file')
        fail(sprintf('Enobio .easy file not found: %s', path_easy)); return;
    end

    % ----------------------------
    % Build lookup table from log
    % ----------------------------
    try
        tab_lookup = teLogFilter(ses.Log.LogArray, 'source', 'teEventRelay_Enobio_linked');
    catch ME
        fail(sprintf('Failed to filter log for linked event lookup: %s', ME.message)); return;
    end

    if isempty(tab_lookup) || height(tab_lookup) == 0
        fail('No linked events found in log (lookup table is empty).'); return;
    end
    if ~all(ismember({'data','linked_event_idx'}, tab_lookup.Properties.VariableNames))
        fail('Lookup table missing required columns: data and/or linked_event_idx.'); return;
    end

    % Keep only numeric scalar data entries (drop e.g. eye tracking strings)
    dataCol = tab_lookup.data;
    idxCol  = tab_lookup.linked_event_idx;

    numericMask = false(height(tab_lookup), 1);

    if isnumeric(dataCol)
        % Unusual, but handle: data column already numeric
        numericMask = isfinite(dataCol) & isfinite(idxCol);
        vals = double(dataCol(numericMask));
    else
        % Expected: cell array with either numeric scalars or strings
        try
            numericMask = cellfun(@(x) isnumeric(x) && isscalar(x) && isfinite(double(x)), dataCol) ...
                        & isfinite(idxCol);
        catch
            fail('Could not interpret lookup table .data column (unexpected type/shape).'); return;
        end
        vals = cellfun(@(x) double(x), dataCol(numericMask));
    end

    if ~any(numericMask)
        fail('Lookup table contains no numeric event codes after filtering (all were non-numeric).'); return;
    end

    keys = double(idxCol(numericMask));
    keys = keys(:);
    vals = double(vals(:));

    % De-duplicate keys (linked_event_idx) with conflict detection
    [ukeys, ia, ic] = unique(keys, 'stable');
    uvals = vals(ia);

    if numel(ukeys) < numel(keys)
        % detect conflicting duplicates
        conflicted = false;
        for k = 1:numel(ukeys)
            vv = vals(ic == k);
            if numel(unique(vv)) > 1
                conflicted = true;
                warning('teReplaceSequentialEvents:ConflictingLookup', ...
                    'Conflicting mappings for linked_event_idx=%g (multiple event codes). Using the first occurrence.', ukeys(k));
            end
        end
        if ~conflicted
            % no message needed
        end
    end

    % ----------------------------
    % Backup original .easy file (zip)
    % ----------------------------
    try
        backupZipPath = makeBackupZip(path_easy);
    catch ME
        fail(sprintf('Failed to create backup zip: %s', ME.message)); return;
    end

    % ----------------------------
    % Load .easy matrix and replace penultimate column markers
    % ----------------------------
    try
        eeg = load(path_easy);
    catch ME
        fail(sprintf('Failed to load .easy file as numeric matrix: %s', ME.message)); return;
    end

    if ~isnumeric(eeg) || isempty(eeg)
        fail('Loaded .easy data is empty or not numeric.'); return;
    end
    if size(eeg,2) < 2
        fail('Loaded .easy data has fewer than 2 columns; cannot identify penultimate marker column.'); return;
    end

    markerCol = size(eeg,2) - 1;
    markersBefore = eeg(:, markerCol);

    % Replace only markers that are exactly equal to a linked_event_idx key
    [tf, loc] = ismember(markersBefore, ukeys);
    nReplace = nnz(tf);

    if nReplace == 0
        warning('teReplaceSequentialEvents:NoMatches', ...
            'No markers in the .easy file matched the lookup table. File will still be rewritten after backup.');
    else
        markersAfter = markersBefore;
        markersAfter(tf) = uvals(loc(tf));
        eeg(:, markerCol) = markersAfter;
    end

    % Warn if there appear to be sequential markers that we couldn't map
    % (heuristic: anything >= 10000 that is not in ukeys)
    seqCand = unique(markersBefore(markersBefore >= 10000));
    if ~isempty(seqCand)
        unmapped = setdiff(seqCand, ukeys);
        if ~isempty(unmapped)
            warning('teReplaceSequentialEvents:UnmappedSequential', ...
                'Found %d sequential markers (>=10000) in .easy not present in lookup; left unchanged. Example: %g', ...
                numel(unmapped), unmapped(1));
        end
    end

    % ----------------------------
    % Write updated matrix back to same filename (via temp file)
    % ----------------------------
    tmpPath = [path_easy '.tmp'];

    try
        writeEasyNumericMatrix(tmpPath, eeg);
    catch ME
        if exist(tmpPath, 'file'); try, delete(tmpPath); end; end %#ok<TRYNC>
        fail(sprintf('Failed to write temp .easy file: %s', ME.message)); return;
    end

    try
        movefile(tmpPath, path_easy, 'f');
    catch ME
        if exist(tmpPath, 'file'); try, delete(tmpPath); end; end %#ok<TRYNC>
        fail(sprintf('Failed to overwrite original .easy file: %s', ME.message)); return;
    end

    % Success
    suc = true;
    oc  = 'ok';

    % Optional: small informational warning-free note (comment out if you prefer silence)
    % fprintf('teReplaceSequentialEvents: ok (replaced %d markers). Backup: %s\n', nReplace, backupZipPath);


    % ============================
    % Nested helper: fail and warn
    % ============================
    function fail(msg)
        suc = false;
        oc  = char(msg);
        warning('teReplaceSequentialEvents:Fail', '%s', oc);
    end
end


% ------------------------------------------------------------
% Helper: create a zip backup alongside the .easy file
% Returns full path to the created zip file.
% ------------------------------------------------------------
function zipPath = makeBackupZip(path_easy)
    [p, n, e] = fileparts(path_easy);

    % Base name: "<name><ext>.orig" (zip will append .zip)
    base = fullfile(p, sprintf('%s%s.orig', n, e));
    zipPath = [base '.zip'];

    % If exists, add timestamp suffix to avoid overwriting
    if exist(zipPath, 'file')
        ts = datestr(now, 'yyyymmddTHHMMSS');
        base = fullfile(p, sprintf('%s%s.orig_%s', n, e, ts));
        zipPath = [base '.zip'];
    end

    zip(base, path_easy);

    if ~exist(zipPath, 'file')
        error('Backup zip not created as expected: %s', zipPath);
    end
end


% ------------------------------------------------------------
% Helper: write numeric matrix as tab-delimited ASCII with good precision
% (so timestamps / large integers survive round-trip nicely).
% ------------------------------------------------------------
function writeEasyNumericMatrix(path_out, mat)
    if ~isnumeric(mat)
        error('Input mat must be numeric.');
    end

    nRows = size(mat, 1);
    nCols = size(mat, 2);

    fid = fopen(path_out, 'w');
    if fid < 0
        error('Could not open for writing: %s', path_out);
    end
    c = onCleanup(@() fclose(fid));

    % 15 significant digits is usually a good compromise for doubles in text
    fmt = [repmat('%.15g\t', 1, nCols-1), '%.15g\n'];

    chunk = 5000; % rows per write; tune if needed
    for r1 = 1:chunk:nRows
        r2 = min(r1 + chunk - 1, nRows);
        block = mat(r1:r2, :);
        fprintf(fid, fmt, block.');
    end
end