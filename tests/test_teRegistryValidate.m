function tests = test_teRegistryValidate
%TEST_TEREGISTRYVALIDATE Portable registry value validation.

    tests = functiontests(localfunctions);
end

function testAllowsEmptyStructValues(testCase)

    record = struct;
    record.dataset_id = 'example';
    record.tasks = struct;
    record.failures = struct([]);

    verifyWarningFree(testCase, @() teRegistryValidate({record}))
end

function testRejectsMatrixLeaves(testCase)

    record = struct('dataset_id', 'example', 'bad', ones(2));

    verifyError(testCase, @() teRegistryValidate({record}), '')
end
