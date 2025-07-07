classdef teEventRelay_BrainVisionHWB < teEventRelay
    % this handles the Brain Products system in the IoPPN Henry Wellcome
    % Building third-floor lab, using a blackbox USB to TLL adaptor
    
    properties (SetAccess = private)
        EEGPort     
    end
    
    properties (Access = private)
        ptr_port
        offline_mode = false;
    end
    
    methods
        
        function obj = teEventRelay_BrainVisionHWB(port)
            
            if isequal(port, '-offlinemode')
                obj.offline_mode = true;
                teEcho('[teEventRelay_BrainVisionHWB]: running in OFFLINE MODE -- event markers will NOT be sent!\n');
                return
            end
            
            try
                obj.ptr_port = IOPort('OpenSerialPort', port, 'BaudRate=9600');
                obj.EEGPort = port;
            catch ERR
                error('Error opening serial port: %s\n', ERR.message)
            end

        end
        
        function delete(obj)
            if ~obj.offline_mode
                IOPort('Close', obj.ptr_port)
            end
        end
        
        function when = SendEvent(obj, event, when, ~)
            
            if ~isnumeric(event) || ~isscalar(event) || event < 1 ||...
                    event > 255
                warning('EEG events must be positive numeric scalars <= 255. Event was not sent.')
                return
            end
            
            if ~obj.offline_mode
                
                warning('todo: figure out event code for HWB lab')
                
            else
                
                teEcho('[teEventRelay_BrainVisionHWB]: event %d running in OFFLINE MODE -- event markers will NOT be sent!\n',...
                    event);
                
            end
            
%             % format numeric event to AXXX format
%             event_str = sprintf('A%03d', event);
%             
%             [~, when, err] = IOPort('Write', obj.ptr_port, event_str);
%             if ~isempty(err)
%                 warning('Error when sending event to serial port: \n\n%s',...
%                     err)
%             end
            
        end
        
    end
    
end
            
            
        