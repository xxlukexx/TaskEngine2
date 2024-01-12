function teEchoLogArray(la, idx_highlight)

    maxHeight = 21;

    t = cellfun(@(x) x.timestamp, la);
    delta = diff(t);
    delta(end + 1, 1) = 1;
    dur = t(end) - t(1);
    num = length(la);
    
    dur_lines = ceil((delta / dur) * maxHeight);
    
    if ~exist('idx_highlight', 'var') || isempty(idx_highlight)
        idx_highlight = false(size(la));
    end

    for i = 1:num
        
        % convert struct to string
        fnames = fieldnames(la{i});
        vals = struct2cell(la{i});
        
        % remove obligatory fields
        fields_oblig = {'date', 'timestamp', 'topic', 'source', 'data', 'task'};
        idx_oblig = ismember(fnames, fields_oblig);
        fnames_opt = fnames(~idx_oblig);
        vals_opt = vals(~idx_oblig);        
        
        % format obligatory
        col_timestamp   = [0.5, 0.5, 1.0];
%         col_date        = [0.0, 0.0, 0.6];
        col_topic       = [0.8, 0.4, 0.0];
        col_src         = [0.8, 0.8, 0.0];
        col_data        = [0.4, 0.8, 0.4];
        col_task        = [0.8, 0.2, 0.5];
        
        % format optional
        str = '';
        for f = 1:length(fnames_opt)
            switch class(vals_opt{f})
                case 'double'
                    val_str = num2str(vals_opt{f});
                case 'char'
                    val_str = vals_opt{f};
                otherwise
                    val_str = class(vals_opt{f});
            end
            str = sprintf('%s | %s = [%s]', str, fnames_opt{f}, val_str);
        end
        
        % remove unwanted newline chars
        str = strrep(str, '\n', '');
        
        % display
        if delta(i) > 0
            col_elap = 'green';
        else
            col_elap = '*red';
        end
        if isfield(la{i}, 'elapsed')
            elap = la{i}.elapsed;
        else
            elap = la{i}.timestamp - la{1}.timestamp;
        end
        cprintf(col_timestamp, '[%.2f', elap);
        cprintf(col_elap, ' (+%.3f) ', delta(i)) 
        cprintf(col_timestamp, ']');
            
%         if delta(i) > 0
%             cprintf(col_timestamp, '[%s (+%.3f)]', la{i}.timestamp, delta(i)) 
%         else
%             cprintf(col_timestamp, '[%s', la{i}.timestamp);
%             cprintf('*red', '(+%.3f)', delta(i)) 
%             cprintf(col_timestamp, ']');
%         end
        
        cprintf(col_src, '[%s]', la{i}.source);        
        cprintf(col_topic, '[%s]', la{i}.topic);
        
        if isfield(la{i}, 'data')
            if iscell(la{i}.data)
                val = cell2char(la{i}.data);
            elseif isnumeric(la{i}.data)
                val = num2str(la{i}.data);
            elseif ischar(la{i}.data)
                val = la{i}.data;
            else
                val = '<DATA>';
            end
            cprintf(col_data, '[data:%s]', val);
        end
        
        if isfield(la{i}, 'task')
            cprintf(col_task, '[%s]', la{i}.task);
        end        
        
        if idx_highlight(i)
            cprintf('*red', '--> %s <---\n', str(3:end));
        else
            cprintf('text', '%s\n', str(3:end));
        end
        
        % gap
        if dur_lines(i) > 5
            numNewLines = 5;
        else 
            numNewLines = dur_lines(i);
        end
        
        for l = 1:numNewLines
            fprintf('\n');
        end
        
        if dur_lines(i) > 5
            fprintf('\t...+%.3fs\n\n', delta(i));
        end
        
        if mod(i, maxHeight) == 0
            fprintf('\n\nPress any key to move to the next page...\n')
            pause
        end

    end









end