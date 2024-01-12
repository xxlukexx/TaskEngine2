classdef teDataSummary_session < teDataSummary
    
    properties (Access = private)
        uiTable
%         uiSmry
    end
    
    methods
        
        function CreateUI(obj)
            
            % convert session metadata to table
            data = obj.Data.data;
            
            % get row names from teSession properties
            rowNames = [...
                'GUID',...
                data.DynamicProps,...
                ];
            
            % get vals
            vals = cellfun(@(x) data.(x), rowNames, 'UniformOutput', false);
            
            % make table
            tab = cell2table(vals', 'RowNames', rowNames);
            
            pos = obj.UIGetPositions;
            
            obj.uiTable = uitable(obj.uiParent,...
                'Data', tab,...
                'Position', pos.uiTable,...
                'ColumnName', []);
%             obj.uiSmry = axes('Parent', obj.uiParent,...
%                 'Position', pos.uiSmry);
            
        end
        
        function UpdateUI(obj)
            pos = obj.UIGetPositions;
            obj.uiTable.Position = pos.uiTable;
        end
        
        function val = UIGetPositions(obj)
            w = obj.Position(3);
            h = obj.Position(4);
            val.uiTable = [0, 0, w, h];
%             val.uiSmry = [0, 0, w, h / 2];
        end
        
    end
     
end