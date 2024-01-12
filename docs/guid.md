# Globally Unique Identifiers (GUIDs)

A [GUID](https://en.wikipedia.org/wiki/Universally_unique_identifier) is a unique (to all intents and purposes) string of numbers and text, such as `9e40d884-2510-472c-aa2e-c355b7edf5dc`. 

The purpose inside Task Engine is to identify a [session](session.md). A GUID is assigned to each session during data acquisition. 

In the [Analysis Database](teAnalysisDatabase.md) component, GUIDs are used to track sessions, and to connect data and metadata. If data not acquired with Task Engine is ingested into the database, it will be assigned a compatible GUID. 