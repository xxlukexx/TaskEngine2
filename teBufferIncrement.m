function [obj, changed] = teBufferIncrement(obj, propName, idxName)
    % get size and cursor pos of buffer
    curSize = size(obj.(propName), 1);
    curIdx = obj.(idxName);
    % if size is too small...
    changed = curIdx >= curSize;
    if changed
        % calculate new size
        curSize = curSize + obj.CONST_DEF_BUFFER_SIZE;
        % increase
        obj.(propName){curSize} = [];
    end
end