function [eb_filt, found] = etFilterEvents2(eb, mask)
% eb_filt = ETFILTEREVENTS2(eb, mask) filters event buffer eb using mask,
% and returns the filtered events in eb_filt.
%
% [eb_filter, idx] = ETFILTEREVENTS2(eb, mask) optionally returns idx, the
% indices of filtered events in the original event buffer.
%
% mask can be any format that an event buffer data chunk can take. This may
% be a char for simple labels, or a cell array for data labels. The
% contents of the cell array are not limited to chars, but the array itself
% must be a row vector. 
%
% Wildcards can be used in any cells of mask that contain a char. 
%
% If a char mask is supplied, and the data chunk of an event is a cell
% array, the mask will be sought in all cells. 
%
% if a cell mask is supplied, label events will not be searched, and only
% cell events of the same size as mask will be compared.

    % check input args
    if ~exist('eb', 'var') || isempty(eb) || ~iscell(eb) ||...
            size(eb, 2) ~= 3
        error('Missing or invalid format eventbuffer.')
    end
    
    if ~exist('mask', 'var') || isempty(mask)
        error('Missing mask value.')
    elseif ~ischar(mask) && ~iscell(mask)
        error('mask value must be char or cell array.')
    elseif iscell(mask) && (~isvector(mask) || size(mask, 1) > size(mask, 2))
        error('mask value must be a cell array in row vector shape.')
    end
    
    % determine mask type
    if ischar(mask)
        if ~instr(mask, '*')
            % straight match - no wildcard
            maskType = 1;
            % no regexp needed
            maskRegExp = [];
        else
            % wildcard
            maskType = 2;
            % prepare regexp expression
            maskRegExp = regexptranslate('wildcard', mask);
        end
    elseif iscell(mask)
        maskType = 3;
        % no regexp needed
        maskRegExp = [];
    end
 
    switch maskType
        case {1, 2}
            % convert to text
            eb_char = cellfun(@cell2char, eb(:, 3), 'uniform', false);
            % search
            if maskType == 1
                % straight search
                found = strcmpi(eb_char, mask);
            elseif maskType == 2
                res = regexp(eb_char, maskRegExp);
                found = cellfun(@(x) ~isempty(x) && x == 1, res);
            end
        case 3
            found = cellfun(@(x) isequal(x, mask{:}), eb(:, 3));
    end
    
    % return val
    eb_filt = eb(found, :);
    if nargout == 2, idx = find(found); end
    
end
        
        
        
        