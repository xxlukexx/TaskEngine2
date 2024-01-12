# teAnalysisDatabase

## Just get me started...
If you just want to get connected to a database and retrieve some data, go [here](teAnalysisDatabase_gettingstarted.md).

## Introduction

The Analysis Database is a component of Task Engine that stores raw data, and data that has been operated upon during processing and analysis. Its aims are:

##### - Identify an individual participant (potentially at multiple time points)
When a dataset is first entered into the database, it is assigned a [GUID](guid.md). Technically, a GUID identifies a [session](session.md) (a particular participant at a particular wave or time point). 

##### - Connect data with [metadata](teMetadata.md)
Metadata is vital for describing features of a dataset, such as the study from which it originated, the age of the participant, or the site from which it was collected. Metadata not only contains information about a dataset but also provides a way to [query](query.md) and filter the data in the database (e.g. show me all datasets collected from the `braintools` study where the age of the participant is `36 months`).

##### - Provide a clear way of flagging the outcome of analysis steps
[Checks](check.md) provide a way to store logical (true/false) information about an analysis. They can be used to indicate the presence or absence of data (e.g. is an EEG file present?), and to indicate which analysis steps have been applied (e.g. has the EEG data been preprocessed?). Like metadata, checks can be used to query and filter the database (e.g. show me all data from the `braintools` study that has been preprocessed). 

##### - Manage the location of data files
Multimodal studies produce a range of data files (e.g. EEG, eye tracking, screen recording). These are usually too large to be stored in a relational database. Typically they are stored in a folder structure, which presents its own problems. The Analysis Database has authority over where the data are stored on disk. The user doesn't know or care - they simply query the metadata and the database returns the data they need (or a path to it). 

##### - Backup data robustly against file system corruption
Data are usually stored on a file system and then (hopefully) backed up. The size of many datasets often precludes versioning of backups, so the entire dataset may be replicated each time it changes. Corruption in the file system will then be replicated to backups. The Analysis Database defines a _database path_ and a _backup path_. If the _backup path_ is set, then all data is replicated to this backup file system, but _from the source computer_ - meaning that any corruption on one file system (and its own backups) does not replicate to the database backup. 

## Technically...
From a technical perspective, the Analysis Database is a schema-free, client/server (for metadata and checks) database running over TCP/IP. Metadata is stored as an array of [teMetadata](teMetadata.md) instances, with dynamic properties. These can be intelligently and (relatively) quickly combined into something resembling a sparse table. The sparse table can be queried with variable/value pairs, at which point any empty fields are not returned. 
