
classdef teEventRelay_Echo < teEventRelay
    
    properties (Access = private)
        prMode = 1  % pretty, 2 is fast
    end
    
    methods
        
        function obj = teEventRelay_Echo(varargin)
            % parse input args
            if ismember('fast', varargin)
                obj.prMode = 2; % fast printing (fprintf)
            else
                obj.prMode = 1; % pretty printing (cprintf)
            end
        end
        
        function when = SendEvent(obj, event, when, task)
            % check data type. This relay can handle any type of data, but
            % will display numeric or char data more neatly in the command
            % window - any other types will be passed to disp
            if nargin == 1
                error('Must pass an ''event'' argument.')
            end
            if isnumeric(event)
                type = 1;
            elseif ischar(event)
                type = 2;
            else
                type = 3;
            end
            % if no when argument is passed, use current time
            if nargin == 2
                when = teGetSecs;
            end
            switch obj.prMode
                case 1      % pretty
                    teEchoEvent(event, when, task)
                    
                case 2      % fast
                    % echo timestamp
                    fprintf('\n[%.4f]', when);
                    % echo task
                    if ~isempty(task)
                        fprintf(' [%s]', task);
                    end
                    % depending upon type, echo to command window
                    switch type
                        case 1
                            % numeric
                            fprintf('%d\n', event);
                        case 2
                            % char
                            fprintf('%s\n', event);
                        case 3
                            % not-neat
                            fprintf('data event:\n');
                            disp(event)
                    end
                    
            end
                
        end
        
    end
    
end
            
            
        