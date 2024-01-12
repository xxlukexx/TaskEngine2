classdef teData < teDynamicProps
    
    properties
        GUID char
        Valid = false
        Paths teCollection
        Log teLog
        RegisteredEvents teEventCollection
        ExternalData teCollection
        Metadata teMetadata
    end
    
    properties (SetAccess = protected)
        DynamicValues
    end
    
    properties (Access = protected)
        prTracker
    end

    methods
        
        function obj = teData
        
            % paths
            obj.Paths = teCollection('char');
            
            % registered events collection
            obj.RegisteredEvents = teEventCollection;
            
            % external data collection
            obj.ExternalData = teCollection;
            obj.ExternalData.EnforceClass = 'teExternalData';
            obj.ExternalData.ChildProps = {'Paths'};
            
            % init standard te2 registered events. This may be replaced by
            % a subclass (i.e. teSession will overwrite these with the
            % values from the tracker)
            teInitStandardRegisteredEvents(obj.RegisteredEvents);

        end        
        
        function ReadFromTracker(obj, tracker)
        % this is a superclass function to read info from a teTracker 
        % instance and put the correct fields into class properties. It is
        % agnostic to the source of the tracker (filesystem/database),
        % hence it's location here as a superclass method
        
            obj.prTracker = tracker;
            
            % store GUID
            obj.GUID = tracker.GUID;
            
            % store log
            obj.Log = teLog(tracker.Log);    
            
            % session start time
            obj.SessionStartTime = tracker.SessionStartTime;
            obj.SessionStartTimeString = tracker.SessionStartTimeString;
            
        % take dynamic props from tracker and apply them to this class.
        % Dynamic properties are used to store fields that can vary between
        % batteries, e.g. ID, age, site etc.
        
            % get list of dynamic props (variables names) in the tracker
            varNames = tracker.prVariables(:, 1);
            
            % loop through variables and add a dynamic property to this
            % teData instance, then copy the value from the tracker into
            % the instance
            for v = 1:length(varNames)
                % add dynamic prop
                addprop(obj, varNames{v});
                obj.(varNames{v}) = tracker.(varNames{v});
                obj.DynamicProps{end + 1} = varNames{v};
                obj.DynamicValues{end + 1} = tracker.(varNames{v});
            end            
            
        % copy registered events from tracker to teData
        
            % if not reg events in the tracker, use the standard task
            % engine ones
            if ~isempty(tracker.RegisteredEvents)
                obj.RegisteredEvents = tracker.RegisteredEvents;
            end       
            
        % copy paths from tracker to teData
        
%             path_session = teFindFile(
            
        end
       
    end
    
end