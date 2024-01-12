classdef teEventRelay_Netstation < teEventRelay

    properties (SetAccess = private)
        HostIP
        AmpIP
        Port = 55513
    end

    methods
        
        function obj = teEventRelay_Netstation(ip_host, port_host, ip_amp)
        % Initialises the class instance and connects to a Netstation host
        % computer using the 'ip' and 'port' arguments. IP address is
        % required, but port is optional (if not supplied port will default
        % to 55513). 
        
            % check IP address has been supplied and is valid
            if ~exist('ip_host', 'var') || isempty(ip_host) || ~ischar(ip_host)
                error('IP address must be supplied as a string.')
            else
                obj.HostIP = ip_host;
                obj.AmpIP = ip_amp;
            end
            
            % if port has been supplied, then check it is a numeric scalar,
            % and if correct, store in object property. Otherwise do
            % nothing, as the default is already set in the properties
            % block
            if exist('port', 'var')
               
                % check format
                if isempty(port_host) || ~isnumeric(port_host) || ~isscalar(port_host)
                    error('Port is optional but if supplied must be a numeric scalar.')
                end
                
                % store in property
                obj.Port = port_host;
                
            end
            
        % attempt to connect to Nestation. To make things easier if
        % Netstation is not open at this point, do 50 tries, to give the
        % tester time to open it if they have forgotten to do s
        
            teEcho('Trying to connect to Netstation on %s:%d...\n');
        
            % set default number of tries, and wait between tries
            numTries = 50; 
            tryWait = 5;
            curTry = 1;
            
            % Netstation commands return a status flag, which is zero if
            % successfully executed. Init this var now
            status = nan;
            
            % start searching. Keep trying until max retries is reached
            while curTry < numTries && status ~= 0
                
                % try to connect
                try
                    [status, err] = NetStation('Connect', obj.HostIP, obj.Port);
                catch ERR
                    % handle any weird errors gracefully here. If specific
                    % errors keep occurring then we'll add code here to
                    % track them and advise on troubleshooting
                    error('Psychtoolbox Netstation code threw an error:\n\n%s',...
                        ERR.message)
                end         

                % validate search results. If no eye tracker found,
                % increment the counter and keep trying until max number of
                % tries
                if status ~= 0
                    teEcho('\tConnection failed, try %d of %d...\n',...
                        curTry, numTries);
                    % wait for x seconds between retries
                    WaitSecs(tryWait);
                end
                curTry = curTry + 1;
                
            end
            
            % did we connect successfully?
            if status == 0
                obj.Sync
                
            else
                error('Error during connection:\n\n\t%s', err)
            end
                
        end
        
        function Disconnect(~)
        
            [status, err] = NetStation('Disconnect');
            
            if status ~= 0
                error('Error during Disconnect:\n\n\t%s', err)
            end
            
        end
        
        function Sync(obj)
        % sync clocks between this computer and the Netstation  host
        % computer
        
            [status, err] = NetStation('GetNTPSynchronize', obj.AmpIP);
            
            if status ~= 0 
                error('Error during sync:\n\n\t%s', err)
            end
            
        end
        
        function StartSession(~)
        % send a message to Netstation to start the recording
        
            [status, err] = NetStation('StartRecording');
            
            if status ~= 0
                error('Error during StartSession:\n\n\t%s', err)
            end
            
        end
        
        function EndSession(~)
        % send a message to Netstation to stop the recording
        
            [status, err] = NetStation('StopRecording');
            
            if status ~= 0
                error('Error during EndSession:\n\n\t%s', err)
            end
            
        end       
        
        function when = SendEvent(obj, event, when, ~)

        % check input args
        
            % check (at least) an event has been passed. Events must be
            % strings of length <= 4
            if nargin == 1
                error('Must pass an ''event'' argument.')
            end
            
            % if no when argument is passed, use current time
            if nargin == 2
                when = GetSecs;
            elseif nargin >= 2
                % if a when argument was passed, assume it is in posix
                % format, and convert back to GetSecs (since this is what
                % LSL is expecting)
                when = teGetSecs(when, 'reverse');
            end
            
        % check event data type
        
            % if event is numeric, conver to string
            if isnumeric(event)
                event = num2str(event);
            end
            
            % event must be a string with length <= 4
            if ~ischar(event) || length(event) > 4 || isempty(event)
                error('event must be a string of length <= 4.')
            end
            
        % send event
        
            [status, err] = NetStation('Event', event, when);
            
            if status ~= 0
                error('Error during SendEvent:\n\n\t%s', err)
            end
            
        end  
        
%         function Flush(obj)
%         % this usually gets called when the tePresenter flushes buffers.
%         % Here we do a time sync to make sure timing is still good
%             
%             obj.Sync
%             
%         end
        
    end

end