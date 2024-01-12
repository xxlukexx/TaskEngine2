classdef teEventRelay_biopac < teEventRelay
    
    properties (SetAccess = private)
        Port
    end
    
    properties (Access = private)
        prPtr
    end
    
    methods
        
        function obj = teEventRelay_biopac(port)
        % creates an instance of the event relay and connects to the serial 
        % port defined in 'port'
        
            if ~ischar(port)
                error('Biopac port must be a string.')
            end
            
            teEcho('Connecting to Biopac MP150 on port %s...\n', port);
            
            % try to connect
            [obj.prPtr, err] = IOPort('OpenSerialPort', port,...
                'BaudRate=115200');
            
            % check 
            if ~isempty(err)
                error('Error connecting to Biopac MP150:\n\n%s', err)
            end

            % set pulse time
            IOPort('Write', obj.prPtr, uint8(['mp' 50]));
            
            % store port
            obj.Port = port;
            
            teEcho('Successfully connected to Biopac MP150.\n');

        end  
        
        function delete(obj) 
            IOPort('Close', obj.prPtr);
        end
        
        function when = SendEvent(~, ~, ~, ~)
        % because biopac has a limited number of event markers (1-7 only),
        % we do not want to behave like a normal event relay and send all
        % event markers. So this method doesn't do anything - we instead
        % operate using the StartSession and TaskChanged methods
            when = teGetSecs;
        end
        
        function StartSession(obj)
        % send an event marker 1 when session starts
            obj.sendSessionStartEndEvent
        end
        
        function EndSession(obj)
        % send an event marker 1 when session ends
            obj.sendSessionStartEndEvent
        end          
        
        function TaskChanged(obj)
        % send an event marker 2 when task changes
            obj.sendEventMarker(2)
        end
        
    end
    
    methods (Hidden)
        
        function sendSessionStartEndEvent(obj)
            
            obj.sendEventMarker(1)
            
        end
        
        function sendEventMarker(obj, event)
            
            % check event format
            if ~isnumeric(event) || ~isscalar(event) || event < 1 ||...
                    event > 7
                error('Biopac events must be positive numeric scalars of 7 or less.')
            end
            
            % set duration of event to 20ms
            duration = 0.020;
            
            % send event
            IOPort('Write', obj.prPtr, uint8([109, 104, event, 255]));
            WaitSecs(duration);
            IOPort('Write', obj.prPtr, uint8([109, 104, 000, 255]));    
            
%             % add log
%             obj.AddLog(...
%                 'source',   'teEventRelay_biopac',...
%                 'topic',    'event',...
%                 'data',     event);    
            
        end
        
    end
    
end
            
            
        