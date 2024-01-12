clear all
pres = tePresenter;
pres.SetMonitorDiagonal(24, 9, 16, 'inches')
pres.MonitorNumber = max(Screen('Screens'));
pres.SkipSyncTests = true;
pres.OpenWindow
pres.EyeTracker = teEyeTracker_tobii;

%%

teEcho('Press %s to quit.\n', pres.KB_MOVEON);
pres.KeyFlush
pres.KeyUpdate
while ~pres.KeyPressed(pres.KB_MOVEON)
    pres.Refresh    Display;
end

%%