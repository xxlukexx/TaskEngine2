#  Getting started with an Analysis Database

This guide assumes that an [Analysis Server](teAnalysisServer) has already been set up, and you want to connect to it. 

#### Prerequisites
- You will need to know the _IP address_ (or _hostname_) and _port_ of the server. In this case, we will assume that the server and client are running on the same machine so will use the [loopback](https://www.lifewire.com/network-computer-special-ip-address-818385) address of `127.0.0.1` and the default port `3000`. 
- You need network access to the _IP address_. You can check this by `pinging` that IP address (using the _command window_ in Windows, or the _terminal_ in macOS or Linux). If you do not get replies, then there is a problem.
- You need to be able to access the _port_. So long as you are on the same network as the server, this should just work. If it does not, and you can ping the server, then there is almost certainly a firewall on the server blocking the port. You should either edit the firewall to open the port, or choose a port you can conect to. 
- You need access to the file system. Usually this will be a network share (a location on a server). You'll get an error if you don't have access, and the error will tell you the share it is trying to access. 

#### Step 1 - Create an instance of the `teAnalysisClient` class

```matlab
>> client = teAnalysisClient

client = 

teAnalysisClient with properties:

Status: 'not connected'
User: 'luke'
Metadata: []
Verbose: 0
Path_Database: []
Path_Backup: []
Path_Data: []
Path_Metadata: []
Path_Ingest: []
Path_Update: []
Name: []
NumDatasets: 0
LogArray: {0×1 cell}
Log: {}
CONST_ReadTimeout: 5
CONST_LoadableFiletypes: {4×2 cell}
```

You have created a blank client - as indicated by the `Status` property, which is `not connected`. You cannot do anything with this client until you...

#### Step 2 - Connect to the server

```matlab
>> client.ConnectToServer('127.0.0.1', 3000)
Connecting to remote server on 127.0.0.1:3000...
Connected to server 127.0.0.1 on port 3000.
[20190115 22:07:56] Connected to file system at: /Volumes/Projects/_adb/test4
```

If all goes, well, you'll see the message above confirming you have connected. If you get an error, take a look at the _prerequisites_ section above. 

#### Step 3 - Check the state of the database
The easiest way to get information about the database itself is to display the `client` variable in the command window:

```matlab
>> client

client = 

teAnalysisClient with properties:

Status: 'connected'
User: 'luke'
Metadata: [550×1 teMetadata]
Verbose: 0
Path_Database: '/Volumes/Projects/_adb/test4'
Path_Backup: []
Path_Data: '/Volumes/Projects/_adb/test4/data'
Path_Metadata: '/Volumes/Projects/_adb/test4/metadata.mat'
Path_Ingest: '/Volumes/Projects/_adb/test4/ingest'
Path_Update: '/Volumes/Projects/_adb/test4/update'
Name: []
NumDatasets: 550
LogArray: {550×1 cell}
Log: {'Connected to file system at: /Volumes/Projects/_adb/test4↵'}
CONST_ReadTimeout: 5
CONST_LoadableFiletypes: {4×2 cell}
```

_Note: displaying the `client` variable causes **all** metadata to be pulled from the server, so can be slow. For really big databases, you may want to avoid doing this at all_. 

A few things to note:

- The `Status` property is now `connected`
- The `NumDatasets` property shows how many total datasets are on the server (in this case, 550)
- The various `Path_xxx` properties show the absolute paths to the file system. This is where any data you upload to the database gets saved, and where any data you pull from the database is copied from. 
- The `Metadata` property is an array of all [metadata](metadata.md) in the database. If you want to just pull everything, and not bother with [querying](query.md) then you can go ahead and use this. Unless you are dealing with a small database and want to process everything, this is not recommended. 

#### Step 4 - Query some data
You'll find full details of the ways in which you can query the database [here](query.md). This is just one example. 

Get a list of IDs and GUIDs which have cleaned EEG data:

```matlab
>> [ids, guids] = client.GetField('ID', 'faceerp_cleaned', true)

ids =

484×1 cell array

{'114414660031'}
{'115677420583'}
{'118194667229'}
{'118910793563'}
{'118980777980'}
...

guids =

484×1 cell array

{'9a98503f-c089-4261-b9e9-a952b4a623e4'}
{'bae6cb87-3fb7-4a35-82cc-ebb929473cbb'}
{'03f5a0e3-015c-4cf0-be34-807d4c667b61'}
{'41977873-e003-4fc9-b3be-39b273cb97d8'}
{'0d16eee3-95ba-40f0-a022-194cf366fe48'}
...
```

#### Step 5 - Loop through a list of data, load each dataset, and process
Now we know that there are 484 datasets with EEG data that has been cleaned, we can process them. 

```matlab
% loop through all ids
for i = 1:length(ids)

[data, guid] = client.GetVariable('faceerp_clean', 'ID', ids{i});

% do some processing

end
```

