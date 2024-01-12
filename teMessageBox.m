function resp = teMessageBox(msg, varargin)

    resp = [];

    parser = inputParser;
    parser.addParameter('title', []);
    parser.addParameter('image', []);
    parser.addParameter('buttons', []);
    parser.parse(varargin{:});
    
    % title
    title = parser.Results.title;
    if ~isempty(title)
        if ~ischar(title)
            error('Must specifiy ''title'' parameter as a string.')
        end
    else
        title = 'Message box';
    end

    % if image is non-empty, if it is a string, treat it as a filename.
    % Otherwise assume it is an image we can display. 
    img = parser.Results.image;
    if ~isempty(img)
        if ischar(img)
            % filename
            file_image = img;
            if exist(file_image, 'file')
                try
                    img = imread(file_image);
                catch ERR
                    error('Error loading image:\n\n%s', ERR.message)
                end
            else
                error('File not found: %s', file_image);
            end
        end
    end
    
    % message can be empty if an image is supplied
    if isempty(title) && isempty(img)
        error('Must specify a title unless an image is specified with the ''image'' parameter.')
    end
    
    % Default button is 'OK', but can specify a cellstr. Each element will
    % spawn a button, and if that button is clicked the response variable
    % resp will be the name of that button
    buttons = parser.Results.buttons;
    if ~isempty(buttons)
        if ~iscellstr(buttons)
            error('Must specify ''buttons'' parameter as cell array of strings. Each element is a button name.')
        end
    else
        buttons = {'OK'};
    end
    
    if ~isempty(img)
        
        % get image width/height and calculate aspect ratio
        iw = size(img, 2);
        ih = size(img, 1);
        ar_i = iw / ih;

        % get screen width/height
        screenSize = get(0, 'ScreenSize');
        sw = screenSize(3);
        sh = screenSize(4);

        % if image is bigger than screen, resize it
        if iw > (sw * .9)
            iw = round(sw * .9);
            ih = round(iw / ar_i);
            img = imresize(img, [ih, iw]);
        end
        if ih > (sh * .9)
            ih = round(sh * .9);
            iw = round(ih * ar_i);
            img = imresize(img, [ih, iw]);
        end
        
        fh = ih * 1.1;
        fw = iw * 1.1;
        
    else
        
        fh = 500;
        fw = 800;
        
    end
    
    % centre figure rect
    rect = teCentreRect([0, 0, fw, fh], [0, 0, sw, sh]);
    rect(3) = rect(3) - rect(1);
    rect(4) = rect(4) - rect(2);
    
    % make figure
    fig = figure('name', title, 'MenuBar', 'none', 'WindowStyle', 'modal',...
        'units', 'pixels', 'Position', rect);
    
    % display image
    if ~isempty(img)
        ax = axes('Parent', fig, 'Units', 'normalized', 'Position', [0, .1, 1, .9]);
        imshow(img, 'parent', ax)
    end
    
    % display buttons
    fig.Units = 'Normalized';
    bw = 0.1;
    bh = 0.08;
    by = 0;
    numButtons = length(buttons);
    totButtonW = bw * numButtons;
    bx = (1 - totButtonW) / 2;
    for i = 1:length(buttons)
        rect = [bx, by, bw, bh];
        bx = bx + bw;
        uicontrol('style', 'pushbutton', 'parent', fig, 'String',...
            buttons{i}, 'units', 'normalized', 'position', rect,...
            'Callback', @teMessageBox_BtnClick)
    end
    
    while isempty(resp)
        pause(0.010)
    end
    
    function teMessageBox_BtnClick(src, ~)
        resp = src.String;
        close(fig)
    end

end