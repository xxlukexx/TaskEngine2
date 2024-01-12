classdef teNetwork < handle
    
    properties 
        Verbose = true
    end
    
    properties (SetAccess = private)
        Log = {}
    end
    
    properties (Access = protected)
        prLastDataSent
        prLastDataSent_ser
    end
    
    properties (Constant)
        CONST_ReadTimeout = 10   % in seconds
    end
    
    methods
                           
        function NetSendCommand(obj, conn, cmd)
        % send a request to a connection and await acknolwedgement
            
            % first input arg is the command, others are data
            if ~exist('cmd', 'var') || isempty(cmd) || ~ischar(cmd)
                error('Must send a command as a char input argument.')
            end

            % send 
            pnet(conn, 'printf', sprintf('%s\n', cmd));
            
            % await READY
            if ~obj.netAwaitReady(conn)
                error('Server did not respond.')
            end
            
        end
        
        function [data, suc_receive] = NetReceiveVar(obj, conn)
        % wait for a variable to be sent from a connection and send an
        % acknowledgement

            % note this does not currently check for a valid size argument
            % - todo
            retries = 5;
            for r = 1:retries
                
                % get data
                [suc_receive, data] = obj.netReceiveData(conn);
                
                retry = ~suc_receive;

                try
                    data = getArrayFromByteStream(uint8(data));
                    retry = false;
                catch ERR_deser
                    retry = true;
                end
                
                if ~retry, break, end
                
            end
            
            if retry && exist('ERR_deser', 'var')
                error('Malformed response from server:\n\n%s',...
                    ERR_deser.message)
            end
            
        end
        
        function NetSendVar(obj, conn, data)
            
            % check whether data has changed - if it's the same data as
            % last time then we reuse this, rather than serialising again
            % (which is slow)
            if isequal(data, obj.prLastDataSent)
                data = obj.prLastDataSent_ser;
                
            else
                % store
                obj.prLastDataSent = data;
                
                % serialise variable
                data = getByteStreamFromArray(data);
                
                % store
                obj.prLastDataSent_ser = data;
                
            end            

            % get the size of the response
            sz = length(data);
            
            % hash data
            hash = CalcMD5(data);

        % send size

            pnet(conn, 'printf', sprintf('%d\n', sz))
            obj.netAwaitReady(conn);
            
        % send hash
            
            pnet(conn, 'printf', sprintf('%s\n', hash))
            obj.netAwaitReady(conn);

        % send data

            pnet(conn, 'write', data);
            obj.netAwaitReady(conn);
            
        end
        
        function NetError(~, conn, err)

            ack = '-1';

            % send ack and error message to client
            pnet(conn, 'printf', sprintf('%s\n', ack));
            pnet(conn, 'printf', sprintf('%s\n', err));
                            
        end
        
        function err = NetGET(obj, conn, data)
        % the GET command essentially call a class method
        % and returns the result
        
            err = true;

            % for GET, data cannot be empty. It has to be at
            % least one element long, that first element being
            % the property or method that is being queried
            if isempty(data)

                obj.NetError(conn,...
                    'Missing input argument for GET.');
                return

            end

            % check that the first arg is either a property or
            % a method
            if ~ismethod(obj, data{1}) && ~isprop(obj, data{1})

                obj.NetError(conn,...
                    sprintf('Unknown command %s.', data{1}))

                % move on to next connection (this
                % connection has nothing to offer now that
                % it has errored)
                return

            end

        % convert protocol commands to a string that can be
        % evaluated on the local class instance

            if length(data) == 1
            % if data is one word then we treat this as a
            % class method call on the server, from the
            % client. For example, if data is {'Metadata'}
            % then we simply call obj.Metadata (on this,
            % the server) and return the result to the
            % client. 

                str = sprintf('obj.%s', data{1});

            elseif length(data) > 1
            % if data is more than one word, we treat the
            % first word as the method call on the server,
            % and any subsequent words as input arguments
            % to that method

                % extract arguments
                args = data(2:end);
                
%                 % put any char arguments in quotes
%                 arg_char = cellfun(@(x) strcmp(x(1), '''') && strcmp(x(end), ''''), args);
%                 args(arg_char) = cellfun(@(x) sprintf('''%s''', x),...
%                     args(arg_char), 'uniform', false);
                
                % build expression
                str = sprintf('obj.%s(', data{1});
                str = [str, sprintf('%s,', args{:})];
                str(end) = ')';

            end

        % execute the command locally

            try
                
                % we don't know how many output arguments to send back. We
                % can use a hacky workaround to nargout for class methods,
                % but this doesn't work for properties (where nargout == 1
                % by definition). So figure out which situation we're in...
                
                if ~isprop(obj, data{1})
                    numOut = nargout(sprintf(...
                        'teAnalysisServer>teAnalysisServer.%s', data{1}));
                else
                    numOut = 1;
                end
                
                % if numOut > 1, then use this horrible hacky shit
                % workaround by construction the entire expression,
                % including variable length cell array (res) for results,
                % and execute the lot with evalc. Otherwise, evaluate just
                % the right hand side of the expression with eval and store
                % the results in a scalar
                if numOut > 1
                    res = cell(1, numOut);
                    cmd = 'res{1}';
                    for i = 2:numOut
                        cmd = [cmd, sprintf(', res{%d}', i)];
                    end
                    str = ['[', cmd, '] = ', str];
                    evalc(str);
                    
                else
                    res = eval(str);
                    
                end
                
            catch ERR_execute
                obj.NetError(conn,...
                    ERR_execute.message);
                return
            end

            obj.NetSendVar(conn, res);
            
            err = false;
                        
        end
        
        function AddLog(obj, varargin)
            fprintf('[%s] ', datestr(now, 'YYYYmmDD HH:MM:SS'));
            li = teEcho(sprintf(varargin{:}));
            obj.Log{end + 1} = li;
        end
        
    end
    
    methods (Access = protected)
               
        function AssertIPAddress(~, val)
            if ~ischar(val)
                error('Invalid IP address or hostname.')
            end
        end
        
        function [suc, data] = netReceiveData(~, conn)
            
            data = [];
            suc = false;
            
            % await size
            sz = str2double(pnet(conn, 'readline'));
            
            % send READY
            pnet(conn, 'printf', sprintf('READY\n'));
            
            % await hash
            hash_remote = pnet(conn, 'readline');
             
            % send READY
            pnet(conn, 'printf', sprintf('READY\n'));
            
            % await data
            data = pnet(conn, 'read', sz, 'uint8');
            
            % send READY
            pnet(conn, 'printf', sprintf('READY\n'));
            
            % check hash
            hash_local = CalcMD5(data);
            suc = isequal(hash_local, hash_remote);
            
        end
        
        function netSendReady(obj, conn)
        % send a READy command to the other end of the connection
        
            pnet(conn, 'printf', sprintf('READY\n'));
            
            if obj.Verbose
                cprintf('cyan', 'Sent READY\n');
            end
            
        end
            
        function suc = netAwaitReady(obj, conn)
        % awaits a READY command from the other end of the connection
        
            ready = pnet(conn, 'readline');
            suc = isequal(ready, 'READY');
            
            if obj.Verbose && suc
                cprintf('cyan', 'Received READY\n');
            end
            
            
        end
        
    end    
end