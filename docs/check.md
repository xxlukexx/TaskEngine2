# Checks

A check is a flag, a logical (true/false) value. It is connected to [session](session.md) data and [metadata](teMetadata.md) by a GUID. 

## Checks are useful for:

##### - Flagging the presence/absence of data
For example, we may wish to record whether a session has raw EEG data. A check called `raw_eeg_present` can record this information. 

##### - Flagging the completion of an analysis step
For example, EEG data must be preprocessed. A check called `eeg_preproc_complete` can record this information. 

## Checks return false if they are missing
If using a MATLAB `struct` datatype, a logical field can have three possible states, `true`, `false`, or `not present` (i.e. the struct does not contain a field with that name). This leads to tortuous code such as:

```matlab
	if isfield(checks, 'raw_eeg_present') && checks.raw_eeg_present
		% do something with the raw EEG data
	end
```

This quickly becomes tedious. Checks are structured using [logicalstructs](logicalstruct.md), which return `false` when a field is false, or if it does not exist. 

## Checks can be queried
We may often wish to see a list of all sessions that have missing EEG data. By [querying](query.md) on the `raw_eeg_present` check, we can achieve this. 
