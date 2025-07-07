function msg = teEcho(varargin)
    % teEcho prints messages with colored segments based on simple rules.
    if nargin == 1
        msg = sprintf(varargin{1});
    else
        msg = sprintf(varargin{1}, varargin{2:end});
    end

    % Format text into segments with associated styles
    segments = format_text(msg);

    % Display each segment in its color
    for k = 1:numel(segments)
        cprintf(segments(k).style, '%s', segments(k).text);
    end
    cprintf('Text', '\n');  % ensure newline at end
end

function segments = format_text(msg)
    % Define consistent styles
    prefixStyle = '*Blue';     % bold blue for leading tags
    midStyle    = 'Text';      % default black for main content
    suffixStyle = '*Green';    % bold green for trailing info
    numberStyle = 'Yellow';    % yellow for numeric values

    segments = struct('text', {}, 'style', {});

    %% 1. Extract leading [tag]:
    prefixPattern = '^\[[^\]]+\]:';
    prefixToken = regexp(msg, prefixPattern, 'match', 'once');
    if ~isempty(prefixToken)
        segments(end+1) = struct('text', prefixToken, 'style', prefixStyle);
        msg = strtrim(msg(length(prefixToken)+1:end));
    end

    %% 2. Check for trailing [bracketed] override:
    brSuffixPattern = '\[[^\]]+\]$';
    brSuffixToken = regexp(msg, brSuffixPattern, 'match', 'once');
    if ~isempty(brSuffixToken)
        mainText = strtrim(msg(1:end-length(brSuffixToken)));
        % Add main text (with a space) and bracketed suffix
        segments(end+1) = struct('text', [mainText ' '], 'style', midStyle);
        segments(end+1) = struct('text', brSuffixToken,    'style', suffixStyle);
        return;
    end

    %% 3. Check for colon-delimited suffix:
    colonIdx = find(msg == ':', 1, 'last');
    if ~isempty(colonIdx) && colonIdx < numel(msg)
        mainText   = msg(1:colonIdx);
        suffixText = msg(colonIdx+1:end);
        segments(end+1) = struct('text', mainText,   'style', midStyle);
        segments(end+1) = struct('text', suffixText, 'style', suffixStyle);
    else
        % No special suffix: all as main content
        segments(end+1) = struct('text', msg, 'style', midStyle);
    end

    %% 4. Highlight numeric values within main-text segments
    newSegs = segments; segments = struct('text', {}, 'style', {});
    for i = 1:numel(newSegs)
        seg = newSegs(i);
        if strcmp(seg.style, midStyle)
            parts = regexp(seg.text, '(\d+(?:\.\d+)?)', 'split');
            nums  = regexp(seg.text, '(\d+(?:\.\d+)?)', 'match');
            for j = 1:numel(parts)
                if ~isempty(parts{j})
                    segments(end+1) = struct('text', parts{j}, 'style', midStyle);
                end
                if j <= numel(nums)
                    segments(end+1) = struct('text', nums{j}, 'style', numberStyle);
                end
            end
        else
            segments(end+1) = seg;
        end
    end
end


% function msg = teEcho(varargin)
% 
%     if nargin == 1
%         msg = sprintf(varargin{1});
%     elseif nargin > 1
%         msg = sprintf(varargin{1}, varargin{2:end});
%     end
%     
%     cprintf('Strings', msg)
%     
% end