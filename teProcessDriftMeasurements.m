function teProcessDriftMeasurements(tab)

    % vars
    gridSize = [11, 11];

    % validity
    tab.LeftValid = ~isnan(tab.LeftGazeX);
    tab.RightValid = ~isnan(tab.RightGazeX);

    % calculate offsets
    tab.LeftOffsetX = tab.PointX - tab.LeftGazeX;
    tab.LeftOffsetY = tab.PointY - tab.LeftGazeY;
    tab.RightOffsetX = tab.PointX - tab.RightGazeX;
    tab.RightOffsetY = tab.PointY - tab.RightGazeY;

    % make grids coords
    xgs = 1 / (gridSize(1) - 1);
    xgy = 1 / (gridSize(2) - 1);
    [gx, gy] = meshgrid(0:xgs:1, 0:xgs:1);
    gx = reshape(gx, [], 1);
    gy = reshape(gy, [], 1);
    
    % find grid neighbours for each drift measurement, record the idx of
    % the neighbour in the [gx, gy] vector
    neigh = nan(size(tab, 1), 1);
    for i = 1:size(tab, 1)
        dist = sqrt(((gx - tab.PointX(i)) .^ 2) + ((gy - tab.PointY(i)) .^ 2));
        neigh(i) = find(dist == min(dist), 1);
    end
    tab.GridIdx = neigh;
         
    % aggregate by grid location
    [gu, gi, gs] = unique(neigh);
    offlx = accumarray(gs, tab.LeftOffsetX, [], @nanmean);
    offly = accumarray(gs, tab.LeftOffsetY, [], @nanmean);
    offrx = accumarray(gs, tab.RightOffsetX, [], @nanmean);
    offry = accumarray(gs, tab.RightOffsetY, [], @nanmean);
    
    % put aggregated offsets into grid structure
%     gofflx = gx;
%     goffly = gy;
%     goffrx = gx;
%     goffry = gy;
%     gofflx(gu) = gofflx(gu) + offlx;
%     goffly(gu) = goffly(gu) + offly;
%     goffrx(gu) = goffrx(gu) + offrx;
%     goffry(gu) = goffry(gu) + offry;
    gofflx = nan(size(gx));
    goffly = nan(size(gx));
    goffrx = nan(size(gx));
    goffry = nan(size(gx));
    gofflx(gu) = offlx;
    goffly(gu) = offly;
    goffrx(gu) = offrx;
    goffry(gu) = offry;

%     figure
    clf
    scatter(gx, gy, 200, 'k', 'MarkerEdgeColor', 'none', 'MarkerFaceColor', [.8, .8, .8])
    hold on
    quiver(gx, gy, gofflx, goffly)
    quiver(gx, gy, goffrx, goffry)
    set(gca, 'ydir', 'reverse')
    legend('Point', 'Left eye', 'Right eye')

end