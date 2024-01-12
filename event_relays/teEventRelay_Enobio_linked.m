classdef teEventRelay_Enobio_linked < teEventRelay
            
    properties (SetAccess = private)
        LSL_Library
        LSL_Info
        LSL_Outlet
        LSL_UniqueSource = GetGUID
        LinkedEventIdx
        TargetPresenter
        prDeferredLog
        prDeferredLogIdx
        prDeferredLogFlushed        
    end
    
    properties (Hidden)
        SentMarkers 
    end
        
    properties (Constant)
        CONST_DEF_BUFFER_SIZE = 1e5;
    end
            
    methods
        
        function obj = teEventRelay_Enobio_linked(pres)
            
            % set the target presenter (which contains the log to send
            % events to) from the pres input argument
            if ~isa(pres, 'tePresenter')
                error('''pres'' must be a tePresenter instance.')
            end
            % check that the presenter has the required method to add a log
            % entry. There's no way this should fail, but good practice to
            % check anyway
            if ~ismethod(pres, 'AddLog')
                error('pres argument does not have the required ''AddLog'' method.')
            end
            obj.TargetPresenter = pres;         
            
            % attempt to load the lsl library
            if ~exist('lsl_loadlib', 'file')
                error('Lab streaming layer (specifically lsl_loadlib.m) not found in the Matlab path.')
            else
                obj.LSL_Library = lsl_loadlib;
            end
            % setup stream info
            obj.LSL_Info = lsl_streaminfo(obj.LSL_Library, 'TaskEngineEvents',...
                'Markers', 1, 0, 'cf_int32', obj.LSL_UniqueSource);
            % create outlet
            obj.LSL_Outlet = lsl_outlet(obj.LSL_Info);
            % create buffer to store markers
            obj.SentMarkers = teBuffer(2);
            
            % set up deferred log storage
            obj.prDeferredLog = cell(obj.CONST_DEF_BUFFER_SIZE, 1);
            obj.prDeferredLogIdx = 1;
            obj.prDeferredLogFlushed = false(obj.CONST_DEF_BUFFER_SIZE, 1);            
            
            % init linked event idx
            obj.LinkedEventIdx = 10000;
            
        end
        
        function delete
            
        end
        
        function [when, when_ret] = SendEvent(obj, event, when, ~)
            % check (at least) an event has been passed. Note there is no
            % type checking of the event argument
            if nargin == 1
                error('Must pass an ''event'' argument.')
            end
            % if no when argument is passed, use current time
            if nargin == 2
                when = GetSecs;
                when_ret = teGetSecs;
            elseif nargin >= 2
                % if a when argument was passed, assume it is in posix
                % format, and convert back to GetSecs (since this is what
                % LSL is expecting)
                when = teGetSecs(when, 'reverse');
            end
            % check event data type
            if ischar(event)
                event = num2str(event);
            end
%             if ~isnumeric(event) || isnan(event) || ~isscalar(event) ||...
%                     ~isequal(event, round(event)) ||...
%                     event < -intmax('int32') || event > intmax('int32') ||...
%                     ~isa(event, 'double')
%                 warning('Enobio markers must be positive numeric integers between 1 and 2147483647 (but as double data type) - MARKER NOT SENT')
%                 return
%             end
            
            % capture event and save to log, then send index linking log
            % event to NIC
            
                % make struct of log entry
                li = struct(...
                    'timestamp', when,...
                    'topic', 'linked_event',...
                    'data', event,...
                    'linked_event_idx', obj.LinkedEventIdx,...
                    'source', 'teEventRelay_Enobio_linked',...
                    'trialguid', obj.TargetPresenter.CurrentTrialGUID);
                % add to deferred log buffer
                obj.prDeferredLog{obj.prDeferredLogIdx} = li;
                obj.prDeferredLogIdx = obj.prDeferredLogIdx + 1;
                if obj.prDeferredLogIdx >= length(obj.prDeferredLog)
                    curSize = length(obj.prDeferredLog);
                    newSize = curSize + obj.CONST_DEF_BUFFER_SIZE;
                    obj.prDeferredLog(newSize) = {};
                    obj.prDeferredLogFlushed(curSize + 1:newSize) = false;
                end            

                % send to NIC
                obj.LSL_Outlet.push_sample(obj.LinkedEventIdx, when);
                
                % echo to command window
                if isnumeric(event)
                    event_str = num2str(event);
                else
                    event_str = event;
                end
                if ischar(event_str)
                    fprintf('teEventRelay_Enobio_linked: Sent %d to NIC [%s]\n',...
                        obj.LinkedEventIdx, event_str);
                end
                
                % increment index
                obj.LinkedEventIdx = obj.LinkedEventIdx + 1;
                if obj.LinkedEventIdx > 2147483647
                    error('Can only send a maximum of 2147483647 events.')
                end

            % store in buffer
%             obj.SentMarkers.Add([event, when]);
%             fprintf('gs now: %.4f | posix now: %.4f | when: %.4f\n',...
%                 GetSecs, teGetSecs, when)
        end
        
        function Flush(obj)
            for l = 1:obj.prDeferredLogIdx - 1
                if ~obj.prDeferredLogFlushed(l)
                    obj.TargetPresenter.AddLog(obj.prDeferredLog{l});
                    obj.prDeferredLogFlushed(l) = true;
                end
            end
        end        
        
    end
    
end
            
            
        