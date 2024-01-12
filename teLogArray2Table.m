function t = teLogArray2Table(logArray)

    c = teLogArray2Cell(logArray);
    t = cell2table(c, 'variablenames',...
        {'Date', 'Timestamp', 'Source', 'Topic'});
    
end