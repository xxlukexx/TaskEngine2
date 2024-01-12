classdef teDBSession < teData
    
    properties
    end
    
    properties (SetAccess = ?teData)
        SessionStartTimeString
        SessionStartTime
    end
    
    properties (Dependent, SetAccess = private)
        Trials teTrial
    end
    
    methods
        
        function [obj, md] = teDBSession(client, varargin)
        % initialise instance with an input argument that is a path to a
        % session folder
        
            % call superclass constructor to init the general teData stuff
            obj = obj@teData;
            md = [];
        
        % handle input args
        
            % check that a valid tepAnalysisClient has been passed, and that
            % it is connected to a database
            if ~exist('client', 'var') || isempty(client) ||...
                    ~isa(client, 'tepAnalysisClient') ||...
                    ~strcmpi(client.Status, 'connected')
                error('First input argument must be a tepAnalysisClient that is connected to a valid database server.')
            end
            
%             % check GUID looks like a GUID
%             if ~exist('GUID', 'var') || isempty(GUID) || ~ischar(GUID) ||...
%                     length(GUID) ~= 36
%                 error('Second input argument must be a GUID that refers to a record in the datbase.')
%             end
        
        % attempt to read data from database
            
            try
                tracker = client.GetVariable('tracker', varargin{:});
                if isa(tracker, 'uint8')
                    try
                        tracker = getArrayFromByteStream(tracker);
                    catch ERR
                        error('Error attempting to deserialise tracker: %s',...
                            ERR.message)
                    end
                end
                md = client.GetMetadata(varargin{:});
            catch ERR
                error('Error reading from database: %s', ERR.message)
            end
            
            if isempty(tracker)
                error('Could not retrieve tracker for GUID: %s', md.GUID)
            end
            if isempty(md)
                error('Could not retrieve metadata for GUID: %s', md.GUID)
            end
            
        % store main fields from the teTracker into teData properties
            
            % call superclass to read tracker properties
            obj.ReadFromTracker(tracker);
    
        % attempt to discover external data from database paths
        
            ext = teDBDiscoverExternalData(client, md);
            
            % add to object
            obj.ExternalData = [obj.ExternalData, ext];

        end
      
    end
    
end