classdef teEventRelay_BrainVisionGhent < teEventRelay
    
    properties (SetAccess = private)
        EEGPort     
    end
    
    properties (Access = private)
        ptr
    end
    
    methods
        
        function obj = teEventRelay_BrainVisionGhent(port)
            
            try
                obj.ptr = IOPort('OpenSerialPort', port, 'BaudRate=9600');
                obj.EEGPort = port;
            catch ERR
                error('Error opening serial port: %s\n', ERR.message)
            end

        end
        
        function delete(obj)
            IOPort('Close', obj.ptr)
        end
        
        function when = SendEvent(obj, event, when, ~)
            
            if ~isnumeric(event) || ~isscalar(event) || event < 1 ||...
                    event > 255
                warning('EEG events must be positive numeric scalars <= 255. Event was not sent.')
                return
            end
            
            % format numeric event to AXXX format
            event_str = sprintf('A%03d', event);
            
            [~, when, err] = IOPort('Write', obj.ptr, event_str);
            if ~isempty(err)
                warning('Error when sending event to serial port: \n\n%s',...
                    err)
            end
            
        end
        
    end
    
end
            
            
        