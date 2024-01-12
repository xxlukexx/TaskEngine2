classdef teCollection < dynamicprops
    
    properties
        ReturnKeyAsNameProp = false;
        StoreItemsAsDynamicProperties = false;
    end
    
    properties (Dependent, SetAccess = protected)
        Keys
        Items
        Count
    end
    
    properties (SetAccess = private)
        EnforceClass
    end
    
    properties (Dependent)
        ChildProps
    end
    
    properties (Access = private)
        prItems
        prKeys 
        prKeyHashes
        prQueryResults
        prChildProps
        prChildPropsH
        prDynamicPropsH
    end
    
    events
        ItemAdded
%         ItemUpdated
        ItemRemoved
        ItemsCleared
        ItemChanged
    end
    
    methods
        
        % constructor
        function obj = teCollection(classType)
            % enforce class from input arg (if present)
            if exist('classType', 'var')
                obj.EnforceClass = classType;
            end
            % init dynamic props handle array
            obj.prDynamicPropsH = {};
        end
        
        % item management
        function AddItem(obj, newItem, key)
%             % check for uninitialised object, and init
%             if isempty(obj)
%                 obj = teCollection;
%             end
            % if enforcing classes, check newitem to ensure it is of the
            % right class
            if ~isempty(obj.EnforceClass)
                if ~isa(newItem, obj.EnforceClass)
                    error('This collection may only contain %s classes.',...
                        obj.EnforceClass)
                end
            end
            % find pos for new item in collection
            if isempty(obj.prItems)
                itemPos = 1;
            else
                itemPos = length(obj.prItems) + 1;
            end
            % make key if necessary
            keyNeeded = ~exist('key', 'var') || isempty(key);  
            if keyNeeded, key = num2str(itemPos); end
            % check key is unique
            if ~isempty(obj.LookupIndex(key))
                error('Keys must be unique.')
            end
            % if ReturnKeyAsNameProp flag is set, check that the item has a
            % name prop that can be set
            if obj.ReturnKeyAsNameProp && ~isprop(newItem, 'Name')
                error('ReturnKeyAsNameProp is true, but the item being added does not have a ''Name'' property.')
            end
            % store
            obj.prItems{itemPos} = newItem;
            obj.prKeys{itemPos} = key;
            obj.prKeyHashes(itemPos) = sum(uint8(key(:)));
            obj.UpdateChildProps
            eventData = teEvent(key);
            % if requested, store the item as a dynamic property
            if obj.StoreItemsAsDynamicProperties
                obj.StoreDynamicProp(key)
            end
            notify(obj, 'ItemAdded', eventData);
            notify(obj, 'ItemChanged', eventData);
        end
        
        function obj = Clear(obj)
            eventData = teEvent(obj.prKeys);
            notify(obj, 'ItemsCleared')            
            obj.prItems = [];
            obj.prKeys = [];
            obj.UpdateChildProps
            notify(obj, 'ItemChanged', eventData);
            % todo - remove all dynamic props
        end
        
        function RemoveItem(obj, key)
            idx = obj.LookupIndex(key);
            if ~isempty(idx)
                eventData = teEvent(key);
                notify(obj, 'ItemRemoved', eventData);    
                notify(obj, 'ItemChanged', eventData);                       
                obj.prItems(idx) = [];
                obj.prKeys(idx) = [];         
            else
                error('Item key not found.')
            end
            obj.UpdateChildProps
            if obj.StoreItemsAsDynamicProperties
                obj.RemoveDynamicProp(key);
            end
        end
        
        function RemoveItemIfPresent(obj, key)
            try
                obj.RemoveItem(key);
            end
        end
        
        function SortByIndex(obj, idx)
        % takes a numeric index vector and sorts both the Keys and Items 
        
            if any(idx) < 1 || any(idx) > obj.Count
                error('All elements of the sorting index must be >0 and <%d',...
                    obj.Count)
            end
            
            obj.prKeys = obj.prKeys(idx);
            obj.prItems = obj.prItems(idx);
            
        end
        
        % lookup
        function idx = LookupIndex(obj, stim)
            % return the numeric index of a stimulus. Can be passed a
            % stimulus name (key) or an object
            if isempty(obj)
                idx = [];
                return
            elseif ischar(stim)
                idx = find(obj.lookupLogicalIndex(stim));
%                 key = stim;
%                 idx = find(strcmp(obj.prKeys, key)); 
                return
            elseif isobject(stim) 
                idx = find(cellfun(@(x) isequal(x, stim), obj.prItems));
            elseif isnumeric(stim)
                idx = find(cellfun(@(x) isequal(x, stim), obj.prKeys));
            end
        end
                
        function varargout = Lookup(obj, key)
            if ~char(key)
                error('Keys must be char.')
            end
            % if collection is empty, return empty
            if isempty(obj)
                varargout = {[]};
                return
            end
            idx = obj.lookupLogicalIndex(key);
            if sum(idx) == 1
                % return just one item
                val = obj.prItems{idx};
                if obj.ReturnKeyAsNameProp
                    val.Name = obj.prKeys{idx};
                end
                varargout = {val};
            elseif sum(idx) > 1
                % return multiple, in a cell array
                val = obj.prItems(idx);
                if obj.ReturnKeyAsNameProp
                    for i = 1:length(val)
                        val{i}.Name = obj.prKeys{idx};
                    end
                end
                varargout = {val};
            else 
                varargout = {[]};
            end
        end
        
        function val = LookupRandom(obj, varargin)
            % with no input args, returns a random item
            if nargin == 1
                val = obj.prItems{randi(obj.Count)};
                return
            end
            % with pairs on inputs, can specify the field to search, and
            % the wildcard patttern sought
            if mod(nargin - 1, 2) ~= 0
                error('Must use pairs of searchfield / sought arguments.')
            end
            % process and validate pairs
            fieldIdx = 1:2:length(varargin);
            soughtIdx = 2:2:length(varargin);
            numPairs = length(fieldIdx);
            match = false(numPairs, obj.Count);
            for p = 1:numPairs
                % get pairs
                f           = varargin{fieldIdx(p)};
                s           = varargin{soughtIdx(p)};
                pairType    = zeros(size(f));   % 1 key, 2 prop
                % check search field - must be either 'key', or a class
                % property with a size equal to the items array
                if strcmpi(f, 'key')
                    f = 'Keys';
                else
                    valid = isprop(obj, f) &&...
                        isequal(size(obj.Items), size(obj.(f)));
                    if ~valid, error('Invalid search field %s.', f), end
                    pairType = 2;
                end
                % filter
                data = obj.(f);
                pattern = regexptranslate('wildcard', s);
                match(p, :) =...
                    cellfun(@(x) ~isempty(regexp(x, pattern, 'ONCE')), data);
                % if no matches found, return empty
                if ~any(match)
                    val = [];
                    return
                end
            end
            % lookup
            found = find(all(match, 1));
            idx = randi(length(found));
            val = obj.prItems{found(idx)};
            if obj.ReturnKeyAsNameProp
                val.Name = obj.prKeys{found(idx)};
            end
        end
        
        % utils
        function UpdateChildProps(obj)
            % if char, put into one-element cell array
            if ischar(obj.prChildProps)
                tmp = {obj.prChildProps}; 
            else
                tmp = obj.prChildProps; 
            end
            numChildProps = length(tmp);
            % remove previous child props
            if ~isempty(obj.prChildPropsH)
                cellfun(@(x) delete(x), obj.prChildPropsH)
            end
            % loop through child props
            for cp = 1:numChildProps
                childVal = cell(1, obj.Count);
                % loop through items
                for i = 1:length(obj.prItems)
                    % attempt to access child property for this item
                    try
                        childVal{i} = obj.prItems{i}.(tmp{cp});
                    catch ERR
                        childVal{i} = nan;
                    end
                end
                obj.prChildPropsH{end + 1} = obj.addprop(tmp{cp});
                obj.(tmp{cp}) = childVal;
            end
        end
                
        % overloaded functions
        function n = numArgumentsFromSubscript(obj,~,~)
            n = numel(obj);
        end
        
        function varargout = subsref(obj, s)
            passToBuiltIn = false;
            switch s(1).type
                case '()'
                    % key search
                    arg = s(1).subs{:};
                    if isnumeric(arg)
                        % return by numeric index
                        item = obj.Items{arg};
                    else
                        % key search
                        item = obj.Lookup(s(1).subs{:});
                    end
                    if length(s) == 1
                        varargout = {item};
                    elseif length(s) > 1
                        s(1) = [];
                        try
                            varargout = {builtin('subsref', item, s)};
                        catch ERR
                            if strcmpi(ERR.message, 'Too many output arguments.')
                                builtin('subsref', item, s)
                                varargout = {item};
                            else
                                rethrow(ERR)
                            end
                        end
                    end
                case '.'
                    % short-circuit common properties to prevent peformance
                    % hit due to calling builtin
                    if strcmp(s(1).subs, 'Count')
                        % return count
                        varargout = {obj.Count};
                    elseif length(s) == 1 && strcmp(s(1).subs, 'Keys')
                        varargout = {obj.Keys};
                    elseif strcmp(s(1).subs, 'Items') && length(s) == 2 &&...
                            strcmpi(s(2).type, '()')
                        % Items property was queried directly, with a
                        % numeric index rather than a key
                        varargout = obj.prItems(s(2).subs{1});
                    else
                        passToBuiltIn = true;
                    end
                otherwise  
                    passToBuiltIn = true;
            end
            if passToBuiltIn
                if nargout == 0
                    builtin('subsref', obj, s)
                else
                    varargout{1:nargout} = builtin('subsref', obj, s);
                end
            end
        end
        
        function obj = subsasgn(obj, s, varargin)
            if isempty(s) 
                error('Must specify a key to assign the new item to.')
            end
            switch s(1).type
                case '()'
                    if length(s) == 1
                        % assign by key - determine new data is being added
                        % or existing data updated
                        key = s.subs{1};
                        idx = obj.LookupIndex(key);
                        if isempty(idx)
                            % add new
                            obj.AddItem(varargin{1}, s(1).subs{:})
                        else
                            % update existing
                            obj.prItems{idx} = varargin{1};
                        end
                    else
                        % look up object, then assign to the object
                        key = s(1).subs{:};
                        if isnumeric(key)
                            % return by numeric index
                            item = obj.Items{key};
                        else
                            % key search
                            item = obj.Lookup(s(1).subs{:});
                        end
                        item_s = s(2:end);
                        [~] = builtin('subsasgn', item, item_s, varargin{:});
%                         eventData = teEvent(key, varargin{:});
%                         notify(obj, 'ItemUpdated', eventData);
                    end
                case '.'
                    if obj.StoreItemsAsDynamicProperties &&...
                            isprop(obj, s(1).subs)
                        obj.SetDynamicProp(s(1).subs, varargin{1})
                    else
                        obj = builtin('subsasgn', obj, s, varargin{:});
                    end
                otherwise
                    obj = builtin('subsasgn', obj, s, varargin{:});
            end
        end
        
        function val = size(obj)
            val = obj.Count;
        end
        
        function val = isempty(obj)
            val = builtin('isempty', obj) || isempty(obj.Items);
        end
        
        function val = horzcat(obj, varargin)
            val = vertcat(obj, varargin);
        end
        
        function obj = vertcat(obj, varargin)
            toCat = varargin{1};
            num = length(toCat);
            if ~iscell(toCat), toCat = {toCat}; end
            % check for empty input args
            if isempty(toCat)
                error('To-be-concatenated list is empty.')
            end
            % check all elements are the same class
            if ~all(cellfun(@(x) isa(x, 'teCollection'),...
                    [{obj}, toCat]))
                error('All elements must be of the same class.')
            end
            % check that enforce class is either blank, or equal, for all
            % objects
            enforceClass = cellfun(@(x) x.EnforceClass, [{obj}, toCat],...
                'uniform', false);
            if ~all(cellfun(@isempty, enforceClass)) &&...
                    ~all(isequal(enforceClass{:}))
                error('Mismatching EnforceClass properties.')
            end
            % cat
            for c = 1:num
                for i = 1:toCat{c}.Count
                    obj.AddItem(toCat{c}.Items{i}, toCat{c}.Keys{i});
                end
            end
        end
        
        % set/get
        function val = get.Count(obj)
            val = length(obj.Items); 
        end
        
        function val = get.Keys(obj)
            val = obj.prKeys;
        end
        
        function val = get.Items(obj)
            val = obj.prItems;
        end
        
        function set.Items(obj, val)
            obj.prItems = val;
        end
                
        function set.ChildProps(obj, val)
            % check input format (child props must be char or cellstr)
            if ~ischar(val) && ~iscellstr(val)
                error('Child properties must be specified as char or cellstr.')
            end
%             if iscell(val) 
%                 val = val{:};
%             end
            obj.prChildProps = val;
            obj.UpdateChildProps    
        end
        
        function val = get.ChildProps(obj)
            val = obj.prChildProps;
        end
        
        function val = GetDynamicProp(obj, key)
            val = obj.Lookup(key);
        end
        
        function val = SetDynamicProp(obj, key, val)
            item = obj.Lookup(key);
            item = val;
        end
        
    end
    
    methods (Hidden)
        
        function StoreDynamicProp(obj, key)
            % check that key does not match an existing property name
            props = properties(obj);
            if ismember(key, props)
                error('Invalid key - %d is already a property name and cannot be used.',...
                    key)
            end
            % get item idx
            idx_item = obj.LookupIndex(key);
            % add property
            obj.prDynamicPropsH{idx_item} = addprop(obj, key);
            obj.prDynamicPropsH{idx_item}.SetMethod = @(obj)SetDyanmicProp(obj, key, val);
            obj.prDynamicPropsH{idx_item}.GetMethod = @(obj, val)GetDynamicProp(obj, key);
        end
        
        function RemoveDynamicProp(obj, key)
            % get item idx
            idx_item = obj.LookupIndex(key);
            % delete handle
            delete(obj.prDynamicPropsH(idx_item));
        end
        
        function idx = lookupLogicalIndex(obj, key)
            % can search with wildcards, but this is not the default
            if ~instr(key, '*')
                idx = strcmp(obj.prKeys, key);
            else
                % search with regexp
                mask = regexptranslate('wildcard', key);
                res = regexp(obj.prKeys, mask);
                idx = cellfun(@(x) ~isempty(x) && x == 1, res);
            end
        end
       
        
    end
    
end

