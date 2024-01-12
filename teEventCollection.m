classdef teEventCollection < teCollection
    
    properties (Dependent, SetAccess = private)
        Summary
    end
    
    methods
        
        % constructor 
        function obj = teEventCollection
        % override the teCollection constructor with this method. Event
        % collections are hard coded to only accept struct elements. So
        % call the superclass (teCollection) constructor, enforcing classes
        % to structs
        
            obj = obj@teCollection('struct');
        end
        
        function AddItem(obj, newItem, key)
        % override the superclass (teCollection) method to ensure that
        % there is a task field in the item (which is a struct) being added
        
            % add task field if not present
            if ~isfield(newItem, 'task')
                newItem.task = [];
            end
            
            % pass to superclass method
            AddItem@teCollection(obj, newItem, key)
        end
        
        % get / set
        function val = get.Summary(obj)
        % produce a tabular summary of all events. Event labels are row
        % labels, each event type is a column label, and values are the
        % individual event codes
        
            % if no event, return empty
            if isempty(obj)
                val = [];
                return
            end
            
%             % switch off stupid Malab warning about creating empty
%             % variables when adding rows to a table
%             warning('off', 'MATLAB:table:RowsAddedExistingVars');
            
            % check all items are struct. They should be, since this
            % subclass forces all elements to struct in the constructor,
            % but better to check here than risk errors if this assumption
            % is violated
            if ~all(cellfun(@isstruct, obj.Items))
                error('All elements of a teEventCollection must be struct.')
            end
            
            % extract all values from the registered events
            val = teLogExtract(obj.Items);
            
            % append key (event label) to left of table
            val.Label = obj.Keys';
            val = movevars(val, 'Label', 'before', 'eeg');
            
%             % get fieldnames for all items
%             fnames = cellfun(@fieldnames, obj.Items, 'uniform', false);
%             
%             % loop through events...
%             val = table;
%             tic
%             for e = 1:100%obj.Count
%                 
%                 % get label and events
%                 label = obj.Keys{e};
%                 ev = obj.Items{e};
%                 
%                 % get values names (fieldnames)
%                 vals = fieldnames(ev);
%                 numVals = length(vals);
%                 
%                 % store label in table
%                 val.Label{e} = label;
%                 
%                 % loop through each event value...
%                 for v = 1:numVals
%                     val.(vals{v}){e} = ev.(vals{v});
%                 end
%             
%             end
%             toc
%             % switch warning back on
%             warning('on', 'MATLAB:table:RowsAddedExistingVars');
        
        end
        
    end
    
end
    
    