classdef teDataSummary_tepInspect < teDataSummary
    
    properties (Access = private)
        uiTable
        uiSmry
    end
    
    methods
        
        function CreateUI(obj)
            
            % convert session metadata to table
            md = obj.Data.md;
            
            % break apart metadata fieldnames and values
            s = struct(md);
            vals = struct2cell(s);
            vars = fieldnames(s);
            
            % make table of [vars, vals]
            tab = cell2table([vars, vals]);
            
            pos = obj.UIGetPositions;
            obj.uiTable = uitable(obj.uiParent,...
                'Data', tab,...
                'ColumnName', [],...
                'Position', pos.uiTable,...
                'FontName', 'Menlo',...
                'RowStriping', 'off');
            obj.uiSmry = axes('Parent', obj.uiParent,...
                'units', 'pixels',...
                'Position', pos.uiSmry);
            obj.UpdateUI
            drawnow
            
        end
        
        function UpdateUI(obj)
            if isempty(obj.uiTable)
                % UI is not yet drawn/initialised
                return
            end
            pos = obj.UIGetPositions;
            obj.uiTable.Position = pos.uiTable;
            obj.uiSmry.Position = pos.uiSmry;
            tepPlotDataTimes(obj.Data.md, obj.uiSmry);
        end
        
        function pos = UIGetPositions(obj)
            w = obj.Position(3);
            h = obj.Position(4);
            pos.uiTable = [0, h / 2, w, h / 2];
            pos.uiSmry = [0, 0, w, h / 2];
        end
        
    end
     
end