function tests = test_teTrial
%TEST_TETRIAL Constructor compatibility and fast-path behavior.

    tests = functiontests(localfunctions);
end

function testLegacyConstructorExtractsMetadata(testCase)

    lg = localLog;
    trial = teTrial(lg, [], []);

    verifyEqual(testCase, trial.Onset, 10)
    verifyEqual(testCase, trial.Offset, 12)
    verifyEqual(testCase, trial.Duration, 2)
    verifyEqual(testCase, trial.Task, 'example_task')
    verifyEqual(testCase, trial.TrialGUID, 'guid-001')
    verifyEqual(testCase, trial.Date, datetime(2026, 1, 2))
    verifySameHandle(testCase, trial.Log, lg)
end

function testFastConstructorUsesExplicitBoundsOnly(testCase)

    lg = localLog;
    trial = teTrial(lg, 10.25, 11.75, true);

    verifyEqual(testCase, trial.Onset, 10.25)
    verifyEqual(testCase, trial.Offset, 11.75)
    verifyEqual(testCase, trial.Duration, 1.5)
    verifyEmpty(testCase, trial.Date)
    verifyEmpty(testCase, trial.Task)
    verifyEmpty(testCase, trial.TrialGUID)
    verifySameHandle(testCase, trial.Log, lg)
end

function lg = localLog

    date = datetime(2026, 1, 2);
    rows = cell(3, 1);
    for i = 1:3
        rows{i} = struct( ...
            'timestamp', 9 + i, ...
            'date', date, ...
            'topic', 'trial_log_data', ...
            'task', 'example_task', ...
            'trialguid', 'guid-001');
    end
    lg = teLog(rows);
end

function verifySameHandle(testCase, actual, expected)

    verifyTrue(testCase, actual == expected)
end
