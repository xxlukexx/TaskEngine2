function samp = teTimeToSample(buffer, timestamp, tol)

    % default tolerance is 0 (i.e. exact)
    if ~exist('tol', 'var') || isempty(tol)
        tol = 0;
    end

    samp = find(abs(buffer(:, 1) - timestamp) <= tol, 1, 'first');

end