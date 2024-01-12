function c = teLogArray2Cell(logArray)
% c = TELOGARRAY2CELL(logArray) returns a cell array c containing one row
% for each log item in logArray. c has four columns, one for each of the
% general variables in a log item (Date, Timestamp, Source, Topic).
% logArray is a cell array of teLogItems. 
% 
% This is mostly useful for filtering the general variables, without the
% expense of extracting and combining the data variables. 

    c = cellfun(@(x) {x.Date, x.Timestamp, x.Source, x.Topic},...
        logArray, 'uniform', false);
    c = vertcat(c{:});
    
end