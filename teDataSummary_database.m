classdef teDataSummary_database < teDataSummary
    
    properties (Access = private)
        uiTable
    end
    
    methods
        
        function CreateUI(obj)
            
            % convert session metadata to table
            client = obj.Data.client;
            
            obj.uiTable = uitable(obj.uiParent,...
                'Data', client.Table,...
                'Position', obj.Position,...
                'FontName', 'Menlo',...
                'RowStriping', 'off');
            drawnow
            
        end
        
        function UpdateUI(obj)
            obj.uiTable.Position = obj.Position;
        end
        
    end
     
end