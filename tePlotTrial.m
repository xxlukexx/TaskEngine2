function tePlotTrial(trial)

    if ~isprop(trial, 'EyeTracking') || isempty(trial.EyeTracking)
        error('No eye tracking data in this trial.')
    end
    
    % get x, y, t
    t = trial.EyeTracking(:, 1) - trial.Onset;
    xl = [t(1), t(end)];
    lx = trial.EyeTracking(:, 2);
    ly = trial.EyeTracking(:, 3);
    rx = trial.EyeTracking(:, 17);
    ry = trial.EyeTracking(:, 18);
    
    % get missing
    miss = ~trial.EyeTracking(:, 4);
    
    figure
    
    % x
    subplot(6, 1, 1:2)
    scatter(t, lx, 5)
    hold on
    scatter(t, rx, 5)
    xlabel('Trial time (s)')
    ylabel('Gaze on x axis')
    set(gca, 'ydir', 'reverse')
    ylim([0, 1])
    xlim(xl)
    
    % y
    subplot(6, 1, 3:4)
    scatter(t, ly, 5)
    hold on
    scatter(t, ry, 5)
    xlabel('Trial time (s)')
    ylabel('Gaze on y axis')
    set(gca, 'ydir', 'reverse')
    ylim([0, 1])
    xlim(xl)
    
    % missing
    subplot(5, 1, 5)
    bar(t, miss * .1, 1, 'FaceColor', [0.5, 0.0, 0.0])
    xlim(xl)
    
    % events
    numEvents = size(trial.Events, 1);
    et = trial.Events.timestamp - trial.Onset;
    cols = lines(numEvents);
    subplot(6, 1, 5:6)
    hold on
    tb = textBounds('ARSE', gca);
    ey = 1 - tb(4);
    for e = 1:numEvents
        
        subplot(6, 1, 1:2)
        line([et(e), et(e)], [0, 1], 'color', cols(e, :))
        
        subplot(6, 1, 3:4)
        line([et(e), et(e)], [0, 1], 'color', cols(e, :))
        
        subplot(6, 1, 5:6)
        line([et(e), et(e)], [0, 1], 'color', cols(e, :))
        tx = text(et(e), ey, trial.Events.data{e},...
            'Interpreter', 'none',...
            'BackgroundColor', 'w',...
            'EdgeColor', cols(e, :));
        ey = ey - tx.Extent(4);
        if ey - tx.Extent(4) < 0
            ey = 1 - tx.Extent(4);
        end
        xlim(xl)
        
    end
    
end