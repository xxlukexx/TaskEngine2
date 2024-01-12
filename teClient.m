classdef teClient < teNetwork
    
    properties (SetAccess = private)
        Status = 'not connected'
        User 
    end
    
    properties (Access = private)
        prConn
        prConnectedToServer = false
    end
    
    methods
        
        function obj = teClient
            
            % check for pnet 
            if isempty(which('pnet'))
                error('This class requires the ''pnet'' library.')
            end
            
            % get username (different ways for different OS)
            if ismac || islinux
                obj.User = getenv('USER');
            elseif ispc
                obj.User = getenv('username');
            else
                obj.User = 'unknown';
            end
            
        end
        
        function delete(obj)
            obj.DisconnectFromServer
        end
        
        function ConnectToServer(obj, ip_server, port_server)
        % connects to a teAnalysisServer instance over TCP/IP
        
            % attempt connection
            teEcho('Connecting to remote server on %s:%d...\n', ip_server,...
                port_server);
            res = pnet('tcpconnect', ip_server, port_server);
            
            % process result
            if res == -1
                error('Could not connect to server.')
            else
                
                % store connection handle, update status
                obj.prConn = res;
                obj.Status = 'connected';
                obj.prConnectedToServer = true;
                teEcho('Connected to server %s on port %d.\n', ip_server,...
                    port_server);
                
                % send username 
                obj.NetSendCommand(sprintf('USER %s\n', obj.User));
                
                % set read timeout to 10s
                pnet(obj.prConn, 'setreadtimeout', obj.CONST_ReadTimeout)
                
            end
            
        end
        
        function DisconnectFromServer(obj)
            if obj.prConnectedToServer
                pnet(obj.prConn, 'close');
                teEcho('Disconnected from server.\n');
            end
            obj.prConnectedToServer = false;
        end
        
        function NetSendCommand(obj, cmd)
        % send a request to a connection and await acknolwedgement
            
            % first input arg is the command, others are data
            if ~exist('cmd', 'var') || isempty(cmd) || ~ischar(cmd)
                error('Must send a command as a char input argument.')
            end

            % send 
            pnet(obj.prConn, 'printf', sprintf('%s\n', cmd));
            
            % await READY
            if ~obj.netAwaitReady(obj.prConn)
                error('Server did not respond.')
            end
            
        end
                
    end
    
    methods (Access = private)
        
        function res = netExecuteQueryFromPairs(obj, cmd, varargin)
            
            for i = 1:length(varargin)
                if ischar(varargin{i})
                    cmd = [cmd, sprintf(' ''%s''', varargin{i})];
                elseif isnumeric(varargin{i}) || islogical(varargin{i})
                    cmd = [cmd, sprintf(' %d', varargin{i})];
                else
                    error('Unsupported value format.')
                end
            end
            obj.NetSendCommand(obj.prConn, cmd);
            res = obj.NetReceiveVar(obj.prConn);

        end
        
    end
        
end