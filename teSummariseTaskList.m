function smry = teSummariseTaskList(list)

    smry = list.Table(:, {'Task', 'NumSamples'});
    smry.NumSamples(isnan(smry.NumSamples)) = 1;

end