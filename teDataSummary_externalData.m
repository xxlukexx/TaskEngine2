classdef teDataSummary_externalData < teDataSummary
    
    properties (Access = private)
        uiTable
    end
    
    methods
        
        function CreateUI(obj)
            
            % convert external data metadata to table
            ext = obj.Data.data;
            
            % get row names from external data properties
            rowNames = properties(ext);
            unwanted = {'Paths', 'CONST_FileTypes'};
            idx_unwanted = ismember(rowNames, unwanted);
            rowNames(idx_unwanted) = [];
            
            % get vals
            vals = cellfun(@(x) ext.(x), rowNames, 'UniformOutput', false);
            
            % make table
            tab = cell2table(vals, 'RowNames', rowNames);
            
            obj.uiTable = uitable(obj.uiParent,...
                'Data', tab,...
                'Position', obj.Position,...
                'ColumnName', []);
            
        end
        
        function UpdateUI(obj)
            obj.uiTable.Position = obj.Position;
        end
        
    end
     
end