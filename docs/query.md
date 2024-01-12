# Querying an Analysis Database

Queries are a way of filtering the data in a database, and only returning that which we are interested in. For example, we may wish to see all participants with raw EEG data at the `36 month` time point. 

### Variable/value pairs
Querying the database occurs using _variable/value pairs_. A variable can be a [metadata](metadata.md) field, or a [check](check.md). For example:

- **[Metadata](metadata.md):** Assume that we have a metadata field named `age`, which contains the age of the participant in months. The variable we would use to query would be `age` and the value would be `36`. 

- **[Checks](check.md):** Assume that we have a check named `raw_eeg_present`. The variable would be `raw_eeg_present` and the value would be `true`. 

### Type of results returned in a query
There are a number of types of data that can be returned form a query: 

#### GetGUID, GetMetadata
These methods always return one type of data (a [GUID](guid.md) or [metadata](metadata.md)). To get the GUID for a participant with an ID of `312`, do:

```matlab
guid = client.GetGUID('ID', '312');
```

To get the metadata for this ID, do:

```matlab
metadata = client.GetMetadata('ID', '312');
```

Note that when returning metadata, you can also optionally get the GUID as a second output argument:

```matlab
[metadata, guid] = client.GetMetadata('ID', '312');
```

#### GetField
This returns the contents of any database field (either a [metadata](metadata.md) field, or a [check](check.md)). Optionally it also returns the GUID as the second output argument. Unlike `GetGUID` and `GetMetadata`, you must speficy which field you want returned, using the following syntax:

```matlab
results = client.GetField(fieldname, variable, value)
```

Imagine we wish to get the ID field for a particular GUID:

```matlab
id = client.GetField('ID', 'GUID', '9e40d884-2510-472c-aa2e-c355b7edf5dc');
```

#### GetPath
Whilst you could query a [path](path.md) directly, using `GetField` and specifying the path name as the fieldname, this would return the [locater path](path.md) within the database, not an absolute path to the file system. By using the `GetPath` method, the database will build an absolute path to the data.

Imagine we wish to get the raw EEG data, saved in a MATLAB .mat file, for ID 312:

```matlab
[path_eeg, guid] = client.GetPath('ID', '312');
```

#### GetVariable
Imagine you wanted to get raw EEG data, saved in a MATLAB .mat file, for ID 312. You could call `GetPath` and then `load` the data into memory. Or, you could call `GetVariable`, which will find the path and load the data in one statement:

```matlab
[data, guid] = client.GetVariable('ID', '312');
```
Note that `GetVariable` will only load datatypes that MATLAB supports:

- MATLAB variables (.mat)
- Text files (.txt, .csv)
- Excel files (.xlsx)

For any other types of data, you must call `GetPath` and then deal with loading the data yourself. For example, you could get the path to an [EEGLab](https://sccn.ucsd.edu/eeglab/index.php) .set dataset, and then pass this path to EEGLab's `pop_loadset` function in your analysis code. 

#### GetTable
Returns a [table](table.md) of records from the database. The records can be queried using variable/value pairs. For example:

```matlab
tab = client.GetTable('ID', '312');
```

#### Returning more than on record from a query
If your query produces multiple results, they will be returned in a cell array. Imagine you wanted to get the IDs of all participants at the 36 month time point:

```matlab
[ids, guids] = client.GetField('ID', 'Age', '36');
```

The variables `ids` and `guids` would be cell arrays of string containing the results. 

#### Querying with more than one variable/value pair
Imagine you wanted to load the EEG data for all subjects at the 36 month time point who had raw EEG data:

```matlab
[data, guids] = client.GetVariable('raw_eeg', 'Age', '36', 'raw_eeg_present', true);
```

_Caution: the Analysis Database does not attempt to check how big the data you are quering is. That is to say, you could request all EEG data for an entire study. This would be slow, and you may run out of memory._

#### Holding a query whilst working with data
It is possible to instruct the Analysis Client to "hold" a query in place whilst you work. For example, if you are using the Client as a data source in an analysis, you may wish to only present a subset of the data to that analysis. In its default state, displaying the Analysis Client object in the MATLAB command window will list all data in the database:

```matlab
>> client

client = 

teAnalysisClient with properties:

HoldQuery: []
Status: 'connected'
User: 'luke'
Metadata: [550×1 teMetadata]
Verbose: 0
Debug: 0
Path_Database: '/Volumes/Projects/_adb/test4'
Path_Backup: []
Path_Data: '/Volumes/Projects/_adb/test4/data'
Path_Metadata: '/Volumes/Projects/_adb/test4/metadata.mat'
Path_Ingest: '/Volumes/Projects/_adb/test4/ingest'
Path_Update: '/Volumes/Projects/_adb/test4/update'
Name: []
NumDatasets: 550
LogArray: {550×1 cell}
Table: [550×11 table]
Log: {'Connected to file system at: /Volumes/Projects/_adb/test4↵'}
CONST_ReadTimeout: 10
CONST_LoadableFiletypes: {4×2 cell}
```

Note that the client reports 550 datasets, and that the size of the `Metadata`, `LogArray` and `Table` properties reflect this. Imagine we wanted to work only on those datasets from the LEAP study, with a `faceerp_avged` check reporting false to indicate that an average has not yet been constructed. 

Write hold queries as you would a normal query, except that they must be formatted in a cell array, with each element being one of a variable/value pair:

```matlab
>> client.HoldQuery = {'Study', 'LEAP', 'faceerp_avged', false};
>> client

client = 

teAnalysisClient with properties:

HoldQuery: {'Study'  'LEAP'  'faceerp_avged'  [0]}
Status: 'connected'
User: 'luke'
Metadata: [68×1 teMetadata]
Verbose: 0
Debug: 0
Path_Database: '/Volumes/Projects/_adb/test4'
Path_Backup: []
Path_Data: '/Volumes/Projects/_adb/test4/data'
Path_Metadata: '/Volumes/Projects/_adb/test4/metadata.mat'
Path_Ingest: '/Volumes/Projects/_adb/test4/ingest'
Path_Update: '/Volumes/Projects/_adb/test4/update'
Name: []
NumDatasets: 68
LogArray: {68×1 cell}
Table: [68×9 table]
Log: {'Connected to file system at: /Volumes/Projects/_adb/test4↵'}
CONST_ReadTimeout: 10
CONST_LoadableFiletypes: {4×2 cell}
```

Now the client reports only 68 datasets (those which match the hold query).



