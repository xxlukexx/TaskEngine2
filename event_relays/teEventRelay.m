classdef teEventRelay < handle
    
    methods
        
        function SendEvent(~, ~, ~)
            warning(...
               ['This is a generic event relay superclass. It does not ',...
                'send any events itself but should be used as a basis for ',...
                'writing your own event relays. Registering this relay with ',...
                'a tePresenter instance is allowed, but will NOT send any events!']);
        end
        
        % the following methods are empty placeholders. Sub classes based
        % on this class can choose whether or not to implement them. If not
        % implemeneted, then any method calls come here and do nothing. 
        function Flush(~)
        end
        
        function StartSession(~)
        end
        
        function EndSession(~)
        end
        
    end
    
end
            
            
        