classdef teTactors < handle
    
    properties (SetAccess = private)
        Port
        Connected
    end
    
    properties (Access = private)
        prConnected = false
        prPtr 
        prOfflineMode = false
    end
    
    properties (Constant)
        ESCAPECHAR = 27;
        MAX_CHANNELS = 2;
    end
    
    methods
        
        function obj = teTactors(port)
            
            if ~exist('port', 'var') || isempty(port)
                error('Must supply a port address to instantiate this class.')
            end
            
            obj.prOfflineMode = isequal(lower(port), '-offlinemode');
            
            obj.Port = port;
            obj.Connect;
            
        end
        
        function delete(obj)
            
            if obj.Connected
                obj.Disconnect
            end
            
        end
        
        function Connect(obj)
            
            if obj.Connected
                error('Already connected, call the .Disconnect method first.')
            end
            
            % handle offline mode
            if obj.prOfflineMode
                warning('Using teTactors in offline mode - no connection will be made.')
                obj.Connected = true;
                return
            end
            
            [ptr, err] = IOPort('OpenSerialPort', obj.Port,...
                'BaudRate=57600 DataBits=8 StopBits=1');
            if ~isempty(err)
                error('Error connecting to port %s:\n\n%s',...
                    obj.Port, err)
            else
                obj.prPtr = ptr;
                obj.Connected = true;
            end
            
        end
               
        function Disconnect(obj)
            
            if ~obj.Connected
                error('Not connected.')
            end
            
            % handle offline mode
            if obj.prOfflineMode
                obj.Connected = false;
                return
            end
            
            try
                IOPort('Close', obj.prPtr);
                obj.Connected = false;
            catch ERR
                error('Error closing port %s:\n\n', obj.Port, ERR.message)
            end
            
        end
        
        function Enable(obj, chan)
            
            if ~exist('chan', 'var')
                chan = [];
            end
            
            if obj.prOfflineMode
                teEcho('[offline mode] Tactor channel %d ON\n', chan);
            else
                obj.Communicate(chan, 'E');
            end

        end
            
        function Disable(obj, chan)
            
            if ~exist('chan', 'var')
                chan = [];
            end
            
            if obj.prOfflineMode
                teEcho('[offline mode] Tactor channel %d OFF\n', chan);
            else
                obj.Communicate(chan, 'D');
            end
            
        end
        
    end
    
    methods (Hidden)
        
        function Communicate(obj, chan, code)
        
            if ~exist('chan', 'var') || isempty(chan)
                chan = 1:obj.MAX_CHANNELS;
            end              
            
            numChansToEnable = length(chan);
            for c = 1:numChansToEnable
                
                switch code
                    case 'E'
                        teEcho('Tactor %d ON\n', chan(c));
                    case 'D'
                        teEcho('Tactor %d OFF\n', chan(c));
                end

                cmdStr = sprintf('T%d%s', chan(c), code);
                IOPort('Write', obj.prPtr, char(obj.ESCAPECHAR));
                IOPort('Write', obj.prPtr, cmdStr);
                
            end        
        
        
        end
        
    end
    
end