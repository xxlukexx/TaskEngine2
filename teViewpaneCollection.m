classdef teViewpaneCollection < teCollection
% a subclass of teCollection, used to store teViewpane instances. The main 
% thing this class does is maintain a z-order variable to control how view
% panes are layered on top of each other. 

    properties %(Dependent, SetAccess = ?teViewport)
        ZOrder
    end
    
    methods
        
        function obj = teViewpaneCollection
        % teCollection supports an input arg specifying an object type
        % which restricts what can be added to the collection. Since this
        % is a collection for teViewpanes only, we override this first.
        
            obj = obj@teCollection('teViewpane');
            
        end
        
        function AddItem(obj, newItem, key, zPosition)
        % override the AddItem method to support a zPosition arg. By
        % default layers are stacked from bottom up, meaning that any new
        % zPositions increment from the max existing zPosition. If a lower
        % than max zPosition is specified, then any higher zPositions are
        % incremented, effectively slotting the new layer in between
        % existing layers. zPositions do now have to increase
        % monotonically, so a layer that should always be on top can be
        % assigned a high zOrder (up to realmax). 
        
            % check zPosition input arg
            if ~exist('zPosition', 'var') || isempty(zPosition)
                
                % no zPos passed, does the viewpane already have a zPos
                % set? If so use that, if not, add the new item to the top
                % of the zorder
                if ~isempty(newItem.ZOrder)
                    zPosition = newItem.ZOrder;
                else
                    zPosition = max(obj.ZOrder) + 1;
                end
                
            end
            
            if ~isnumeric(zPosition) || ~isScalar(zPosition) ||...
                    zPosition < 1
                error('ZPosition must be a positive numeric scalar.')
            end
            
            % check zPos is not already taken
            idx_exist = find(zPos == obj.zOrder, 1);
            if ~isempty(idx_exist)
                
                % zOrder is taken, increment higher zPositions and insert
                % new zPosition into the order
                above = obj.zOrder(idx_exist:end);
                obj.ZOrder(above) = obj.ZOrder(above) + 1;
                
            end
            
            % assign the ZPosiiton to the viewpane
            if exist('newItem', 'var') && isa(newItem, 'teViewpane')
                newItem.ZPosition = zPosition;
            else
                error('Must pass a teViewpane instance to this method.')
            end
            
            % fire superclass method to actually add the new item
            AddItem@teCollection(obj, newItem, key);
            
            % insert zPosition of new item into order
            obj.ZOrder(end + 1) = zPosition;
    
        end
        
        function val = get.ZOrder(obj)
        % build the zOrder by querying the individual ZPositions of each 
        % viewpane instance
        
            val = cellfun(@(x) x.ZPosition, obj.Items);
            
        end
        
        function set.ZOrder(obj, val)
        % update all viewpane zPositions based on the zOrder vector
        
            for i = 1:obj.Count
                obj.Items{i}.ZPosition = val(i);
            end
            
        end
        
        function varargout = subsref(obj, s, varargin)
            
            
            
        end
            
        
%         function obj = subsasgn(obj, varargin)
%             
%             obj = subsasgn@teCollection(varargin{:});
%             
%         end
        
    end
    
end