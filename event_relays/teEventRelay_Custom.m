classdef teEventRelay_Custom < teEventRelay
    
    properties 
        % place any properties (e.g. port address, IP address etc.) here
    end
    
    methods
        
        function obj = teEventRelay_Custom()
            % this method gets called when the event relay is set up (e.g.
            % it is created or registered with a tePresenter instance). Use
            % this to perform any initialisation (e.g. connecting to an EEG
            % amp server on a particular IP address). 
            %
            % Note that the name of this function (currently
            % teEventRelay_Custom) must match the name of the class in line
            % 1. 
        end
        
        function when = SendEvent(~, event, when)
            % this method gets called whenever an event is sent. 'event' is
            % the event itself, and 'when' is the optional timestamp. Use
            % this to actually relay the event to the target. 
            %
            % Note that 'event' can be any data type. This does not mean
            % your event handler has to support any event type (e.g. a
            % serial port cannot send anything other than 0-255 numeric),
            % but is is the responsiblity of this event relay to handle
            % these other data types. That can be in the form of throwing
            % an error (and stopping execution), showing a warning (but
            % continuing to execute), or simply ignoring it silently. 
            %
            % This method returns a 'when' argument. If a 'when' input
            % argument was passed then this is the value that will be
            % returned. If it was not passed, then the çurrent time of the
            % system clock will be returned.
            success = teGetSecs; 
        end
        
    end
    
end
            
            
        