classdef teEventRelay_BrainVisionNijmegen < teEventRelay
    
    properties (SetAccess = private)
        EEGPort     
    end
    
    properties (Access = private)
        ptr
    end
    
    methods
        
        function obj = teEventRelay_BrainVisionNijmegen(port)
            
            try
                obj.ptr = IOPort('OpenSerialPort', port, 'BaudRate=115200');
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
            
            [~, when, err] = IOPort('Write', obj.ptr, uint8(event));
            if ~isempty(err)
                warning('Error when sending event to serial port: \n\n%s',...
                    err)
            end
            
        end
        
    end
    
end
            
            
        