function val = teAssertColourType(val)
    % if char, attempt to convert to num - this supports background
    % colours encoded as strings, e.g. '128, 128, 128' or
    % '[128, 128, 128]'
    if ischar(val), val = str2num(val); end
    if...
            ~isnumeric(val) ||...           
            ~isvector(val) ||...
            length(val) ~= 3 ||...
            any(val) > 255 ||...
            any(val) < 0 ||...
            ~isequal(val, uint8(val))   % no decimal places
        error('Colour values must be three-element col vectors, 0-255, with no decimal places.')
    end
end