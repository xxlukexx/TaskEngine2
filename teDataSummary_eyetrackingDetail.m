classdef teDataSummary_eyetrackingDetail < teDataSummary
    
    properties (Access = private)
        uiCalibPlot
        uiCalibQualityLeft
        uiCalibQualityRight
    end
    
    properties (Constant)
        COL_ET_LEFT             = [066, 133, 244]
        COL_ET_RIGHT            = [125, 179, 066]
        COL_ET_AVG              = [213, 008, 000]
    end
    
    methods
        
        function CreateUI(obj)
            
            ext = obj.Data.data;
            pos = obj.UICalculatePositions;
            
            if isempty(ext.Calibration)
                return
            end
            
        % calib plot
            
            % set up axes
            obj.uiCalibPlot = uiaxes(obj.uiParent,...
                'Position', pos.uiCalibPlot);
            obj.uiCalibPlot.XTick = [];
            obj.uiCalibPlot.YTick = [];
            obj.uiCalibPlot.XAxis.Visible = 'off';
            obj.uiCalibPlot.YAxis.Visible = 'off';
            
            % get calib data
            smry = ext.Calibration.Summary;
            gaze = ext.Calibration.Table...
                (:, {'LeftX', 'LeftY', 'RightX', 'RightY'});
            
            % plot points
            scatter(obj.uiCalibPlot, smry.PointX, smry.PointY, 200,...
                'MarkerFaceColor', [0.6, 0.6, 0.6], 'MarkerEdgeColor',...
                'none');
            hold(obj.uiCalibPlot, 'on')
            
            % plot gaze
            scatter(gaze.LeftX, gaze.LeftY, 20, obj.COL_ET_LEFT ./ 255,...
                'Parent', obj.uiCalibPlot,...
                'MarkerFaceColor', obj.COL_ET_LEFT ./ 255);
            scatter(gaze.RightX, gaze.RightY, 20, obj.COL_ET_RIGHT ./ 255,...
                'Parent', obj.uiCalibPlot,...
                'MarkerFaceColor', obj.COL_ET_RIGHT ./ 255);    
            
            % final settings
            ylim(obj.uiCalibPlot, [0, 1])
            xlim(obj.uiCalibPlot, [0, 1])
            obj.uiCalibPlot.YDir = 'reverse';
            
        % calib quality
        
            % set up axes
            obj.uiCalibQualityLeft = uiaxes(obj.uiParent,...
                'Position', pos.uiCalibQualityLeft);
            obj.uiCalibQualityRight = uiaxes(obj.uiParent,...
                'Position', pos.uiCalibQualityRight);   
            
            % get acc/prec for each eye
            ml = smry{:, {'LeftAccuracy_deg', 'LeftPrecision_deg'}};
            mr = smry{:, {'RightAccuracy_deg', 'RightPrecision_deg'}};
            
            % plot acc/prec
            bar(obj.uiCalibQualityLeft, ml)
            obj.uiCalibQualityLeft.XTickLabel = smry.Key;
            obj.uiCalibQualityLeft.TickLabelInterpreter = 'none';
            legend(obj.uiCalibQualityLeft, 'Acc', 'Prec', 'Location', 'best')
            bar(obj.uiCalibQualityRight, mr)
            obj.uiCalibQualityRight.XTickLabel = smry.Key;
            obj.uiCalibQualityRight.TickLabelInterpreter = 'none';
            legend(obj.uiCalibQualityRight, 'Acc', 'Prec', 'Location', 'best')
            
        end
        
        function UpdateUI(obj)
        end
        
    end
    
    methods (Hidden) 
                
        function pos = UICalculatePositions(obj)
            
            w = obj.uiParent.Position(3);
            h = obj.uiParent.Position(4);
            
            pos.uiCalibPlot = [0, h * (1 / 4), w, h * (3 / 4)];
            pos.uiCalibQualityLeft = [0, 0, w * 0.5, h * (1 / 4)];
            pos.uiCalibQualityRight = [w * 0.5, 0, w * 0.5, h * (1 / 4)];
            
        end
        
    end
     
end