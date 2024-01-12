classdef teListCollection < teCollection
    
    methods
        
        % constructor
        function obj = teListCollection(obj)
            obj = obj@teCollection('teList');
        end
        
        function AddItem(obj, item, key)
            % override superclass (teCollection) constructor, so that
            % setting the key of a new list sets the name of that list (so
            % that the two stay in sync)
            AddItem@teCollection(obj, item, key)
            item.Name = key;
%             % add listener for list name changes
%             addlistener(item, 'Name', 'PreSet', @obj.MatchKeyToListName)
        end
        
%         function MatchKeyToListName(obj, src, event, data)
%             
%         end
                
    end
    
end
    