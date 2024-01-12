classdef teDynamicProps < dynamicprops
    
    properties (Hidden, SetAccess = protected)
        DynamicProps = {}
        DynamicPropOrder teCollection
%         DynamicPropTimestamps
        PropOrderCounter = 1
    end
    
    methods
        
        function obj = teDynamicProps
            obj.DynamicPropOrder = teCollection('double');
        end
        
        function obj = subsasgn(obj, s, varargin)
        % this functioniality allows to set a dynamic property by using dot
        % notation to reference its name.
        
            % check that we are using dot notation
            passToBuiltin = false;
            if strcmpi(s(1).type, '.')
                % get property name
                newProp = s(1).subs;
                % see if property exists
                if ischar(newProp) && ~any(strcmp(properties(obj), newProp))
                    
                    % if addressed in the form of newProp.field, then
                    % newProp should be a struct, and field should be a
                    % fieldname (whose value needs to be set). Detect and
                    % action this                    
                    if length(s) > 1 &&...
                            all(cellfun(@(x) strcmpi(x, '.'), {s.type}))
                        
                        % create struct
                        structProp = struct;
                        structProp = builtin('subsasgn',...
                            structProp, s(2:end), varargin{:});
                        
                        % add struct to object as property
                        obj.AddDynamicProp(newProp, structProp)
                        
                    else

                        % create new dyn prop 
                        obj.AddDynamicProp(newProp, varargin{1})
                        
                    end                      
                    
                else
                    % property already exists, so pass to builtin method
                    passToBuiltin = true;
                end
            else
                % not do notation, pass to builtin
                passToBuiltin = true;
            end
            
            % pass to builtin if required
            if passToBuiltin
                obj = builtin('subsasgn', obj, s, varargin{:});
            end
            
        end
        
        function AddDynamicProp(obj, newProp, val)
            % add it
            addprop(obj, newProp);
            % set it's value
            obj.(newProp) =val;
            % store in array for property access
            obj.DynamicProps{end + 1} = newProp;
            % store prop order for later sorting
            obj.DynamicPropOrder(newProp) = obj.PropOrderCounter;
            obj.PropOrderCounter = obj.PropOrderCounter + 1;
        end
        
    end
    
end