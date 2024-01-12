classdef teDataSummary_task < teDataSummary
    
    properties (Access = private)
        uiTable
    end
    
    methods
        
        function CreateUI(obj)
            
            % convert session metadata to table
            tab = obj.Data.trialLog;
            
            obj.uiTable = uitable(obj.uiParent,...
                'Data', tab,...
                'Position', obj.Position,...
                'RowName', [],...
                'FontName', 'Menlo',...
                'RowStriping', 'off');
            drawnow
            uitableAutoColumnHeaders(obj.uiTable, 1.1)
            drawnow
            
        end
        
        function UpdateUI(obj)
            obj.uiTable.Position = obj.Position;
        end
        
    end
     
end