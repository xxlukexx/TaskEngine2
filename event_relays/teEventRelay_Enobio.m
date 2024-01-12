classdef teEventRelay_Enobio < teEventRelay
            
    properties (SetAccess = private)
        LSL_Library
        LSL_Info
        LSL_Outlet
        LSL_UniqueSource = GetGUID
    end
    
    properties (Hidden)
        SentMarkers 
    end
            
    methods
        
        function obj = teEventRelay_Enobio
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
            if ~isnumeric(event) || isnan(event) || ~isscalar(event) ||...
                    ~isequal(event, round(event)) ||...
                    event < -intmax('int32') || event > intmax('int32') ||...
                    ~isa(event, 'double')
                warning('Enobio markers must be positive numeric integers between 1 and 2147483647 (but as double data type) - MARKER NOT SENT')
                return
            end
            % send event
            obj.LSL_Outlet.push_sample(event, when)
            % store in buffer
            obj.SentMarkers.Add([event, when]);
%             fprintf('gs now: %.4f | posix now: %.4f | when: %.4f\n',...
%                 GetSecs, teGetSecs, when)
        end
        
    end
    
end
            
            
        