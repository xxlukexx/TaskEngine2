function tePlotLogArray(la)

    figure
    
    la = teSortLog(la);
    
    % find temporal extent of log items in the passed array
    t_posix = cellfun(@(x) x.timestamp, la);
    numItems = length(la);
    
    % convert posix timestamps to dates/times, and pure seconds
    t_dt = datetime(t_posix, 'ConvertFrom', 'posixtime');
    t_secs = t_posix - t_posix(1);
    
    % calculate temporal gap between items. This will determine the height
    % of each rectangle. The last height is the mode of all the others. 
    dur = diff(t_secs);
    dur(end + 1) = mode(dur);
    
    % prepare to colour by topic
    topic = cellfun(@(x) x.topic, la, 'UniformOutput', false);
    [topic_u, topic_i, topic_s] = unique(topic, 'stable');
    numUniqueTopics = length(topic_u);
    cols = lines(numUniqueTopics);
    
    % make axis
    clf
    ax = axes;
    ylim([t_secs(1), t_secs(end)]);
    set(ax, 'ydir', 'reverse')

    for i = 1:numItems
        
        pos = [0, t_secs(i), 1, dur(i)];
        rectangle(...
            'Position', pos,...
            'FaceColor', cols(topic_s(i), :));
        
            summaryText = sprintf('%s, %s, %s, %s',...
            la{i}.date, la{i}.timestamp, la{i}.topic, la{i}.source);

            otherFields = '';
            fieldNames = setdiff( fieldnames(la{i}), {'date','timestamp','topic','source'});

            for j=1:numel(fieldNames)
                val = la{i}.(fieldNames{j});
                switch class(val)
                    case 'char'
                        val_str = val;
                    case 'double'
                        val_str = num2str(val);
                    otherwise
                        val_str = class(val);
                end
                        
                otherFields = sprintf('%s\n%s: %s', otherFields, fieldNames{j}, val_str);
            end
            
            allStr = sprintf('%s\n%s', summaryText, otherFields);

            text('Position',pos(1:2),'String',allStr,...
            'HorizontalAlignment','left', 'VerticalAlignment', 'top')

%             text('Position',[0 pos(4)-0.1*dur(i)],'String',otherFields,...
%             'HorizontalAlignment','left', 'VerticalAlignment', 'top')      



        
        
        
        
    end












end