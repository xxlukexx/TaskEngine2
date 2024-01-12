classdef teEventRelay_Log < teEventRelay
    
    properties (SetAccess = private)
        TargetPresenter tePresenter
    end
    
    properties (Access = private)
        prDeferredLog
        prDeferredLogIdx
        prDeferredLogFlushed
    end
    
    properties (Constant)
        CONST_DEF_BUFFER_SIZE = 1e5;
    end
    
    methods
        
        function obj = teEventRelay_Log(pres)
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
            % set up deferred log storage
            obj.prDeferredLog = cell(obj.CONST_DEF_BUFFER_SIZE, 1);
            obj.prDeferredLogIdx = 1;
            obj.prDeferredLogFlushed = false(obj.CONST_DEF_BUFFER_SIZE, 1);
        end
        
        function when = SendEvent(obj, event, when, task)
%             ptic
%             profile on
            % check (at least) an event has been passed. Note there is no
            % type checking of the event argument - the log can accept any
            % data type, so we won't limit this 
            if nargin == 1
                error('Must pass an ''event'' argument.')
            end
            % if no when argument is passed, use current time
            if nargin == 2
                when = teGetSecs;
            end
            % if no task argument is passed, use empty
            if nargin == 3
                task = [];
            end
            % if event is a cell array, then nest it within a cell array (a
            % value cell array) to prevent Matlab from erroneously making a
            % struct array of the contents
            if iscell(event), event = {event}; end
            % make struct of log entry
            li = struct(...
                'timestamp', when,...
                'topic', 'event',...
                'data', event,...
                'source', 'teEventRelay_Log',...
                'task', task,...
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
%             deferred = obj.prDeferredLog(1:obj.prDeferredLogIdx - 1);
%             path_deferred = fullfile(obj.TargetPresenter.Tracker.Path_Session,...
%                 'teEventRelay_Log.deferred.mat');
%             save(path_deferred, 'deferred')
            
%             % print timing if too high
%             pt = ptoc;
%             if pt > .010, fprintf('Log: %.3f', pt); end
%             profile off
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
            
            
        