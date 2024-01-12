classdef teDataSummary_struct < teDataSummary
    
    properties (Access = private)
        uiTable
    end
    
    methods
        
        function CreateUI(obj)

            % break apart metadata fieldnames and values
            s = obj.Data.s;
            vals = struct2cell(s);
            vars = fieldnames(s);
            
            % make table of [vars, vals]
            tab = cell2table([vars, vals]);

            obj.uiTable = uitable(obj.uiParent,...
                'Data', tab,...
                'ColumnName', [],...
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