function tePlotTobiiCalib(sh)

    numPoints = size(sh, 1);
    figure('windowstyle', 'docked');
    for p = 1:numPoints
        
        scatter(sh.x(p), sh.y(p), 600, 'k');
        hold on
        
        scatter(sh.gaze{p}(:, 1), sh.gaze{p}(:, 2), [], 'b');
        scatter(sh.gaze{p}(:, 3), sh.gaze{p}(:, 4), [], 'g');
        
    end
    
    xlim([0, 1])
    ylim([0, 1])
    set(gca, 'ydir', 'reverse')

end