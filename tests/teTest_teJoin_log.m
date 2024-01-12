% make master log
num = 10;
la_master = cell(num, 1);
for i = 1:num
    la_master{i} = struct(...
        'timestamp', 999 + i,...
        'topic', 'test',...
        'source', 'master');
end

% before, no overlap
num = 5;
la_before_no = cell(num, 1);
for i = 1:num
    la_before_no{i} = struct(...
        'timestamp', i,...
        'topic', 'test',...
        'source', 'before_no_overlap');
end

% after, no overlap
num = 5;
la_after_no = cell(num, 1);
for i = 1:num
    la_after_no{i} = struct(...
        'timestamp', 1999 + i,...
        'topic', 'test',...
        'source', 'after_no_overlap');
end

% before, overlap
num = 5;
la_before_ol = cell(num, 1);
for i = 1:num
    la_before_ol{i} = struct(...
        'timestamp', 99 + i,...
        'topic', 'test',...
        'source', 'before_overlap');
end
la_before_ol = [la_before_ol; la_master(1:5)];

% after, overlap
num = 5;
la_after_ol = cell(num, 1);
for i = 1:num
    la_after_ol{i} = struct(...
        'timestamp', 1009 + i,...
        'topic', 'test',...
        'source', 'after_overlap');
end
la_after_ol = [la_master(end - 5:end); la_after_ol];

% middle, all overlap
la_middle_ol = la_master(3:8);



tr_master = teTracker;
tr_master.AppendLog(la_master);

tr_before_no = teTracker;
tr_before_no.AppendLog(la_before_no);

tr_after_no = teTracker;
tr_after_no.AppendLog(la_after_no);

tr_before_ol = teTracker;
tr_before_ol.AppendLog(la_before_ol);

tr_after_ol = teTracker;
tr_after_ol.AppendLog(la_after_ol);

tr_middle = teTracker;
tr_middle.AppendLog(la_middle_ol);

allTrackers = {tr_master, tr_before_no, tr_after_no, tr_before_ol, tr_after_ol, tr_middle};