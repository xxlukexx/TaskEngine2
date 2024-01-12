classdef teDataSummary < handle
       
    properties (SetAccess = private)
        Data
    end
    
    properties (Dependent)
        Position 
    end
    
    properties (Access = protected)
        prPosition = [0, 0, 300, 800]
        % ui elements
        uiParent
    end
    
    properties (Constant)
        CONST_CONTROL_HEIGHT = 35;
    end
    
    methods
        
        function obj = teDataSummary(h, data, position)
            
            % if no handle to a parent supplied, make a figure
            if ~exist('h', 'var') || isempty(h)
                obj.uiParent = uifigure(...
                    'Visible', 'off',...
                    'ToolBar', 'none',...
                    'MenuBar', 'none',...
                    'Name', 'Task Engine Data Summary',...
                    'SizeChangedFcn', @obj.UIFigSizeChanged);
            else
                obj.uiParent = h;
            end
            
            if exist('data', 'var')
                obj.Data = data;
            end
            
            if exist('position', 'var') && assertPosition(position)
                obj.Position = position;
            else
                obj.Position = [0, 0, obj.uiParent.InnerPosition(3),...
                    obj.uiParent.InnerPosition(4)];
            end
            
            obj.UIFigSizeChanged;
            obj.CreateUI;
            
        end
        
        function CreateUI(obj)
        end
                
        function UpdateUI(obj)
        end
        
        function UIFigSizeChanged(obj)
            obj.Position = [0, 0, obj.uiParent.InnerPosition(3),...
                obj.uiParent.InnerPosition(4)];
        end
        
        % get / set        
        function val = get.Position(obj)
            val = obj.prPosition;
        end
        
        function set.Position(obj, val)
            if ~assertPosition(val)
                error('Position must be a positive numeric vector in the form of [x, y, w, h].')
            end
            obj.prPosition = val;
            obj.UpdateUI;
        end
             
    end
    
    methods (Hidden)
        
        function Error(~, varargin)
            
            % todo make this error dialog
            error(varargin)
            
        end
        
        function pos = UICalculatePositions(obj)
            pos = [];
        end
        
    end
    
end