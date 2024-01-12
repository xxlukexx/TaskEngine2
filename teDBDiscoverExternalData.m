function ext = teDBDiscoverExternalData(client, md)

    if ~exist('client', 'var') || isempty(client) ||...
            ~isa(client, 'tepAnalysisClient') ||...
            ~strcmpi(client.Status, 'connected')
        error('First input argument must be a tepAnalysisClient instance, connected to a database sever.')
    end

    if ~exist('md', 'var') || ~isa(md, 'teMetadata')
        error('Second input argument must be a teMetadata instance.')
    end
    
    ext = teCollection('teExternalData');

    % eye tracking
    
        pth = client.GetPath('eyetracking', 'GUID', md.GUID);
        if ~isempty(pth)
            ext('eyetracking') = teExternalData_EyeTracking(pth);
        end
        
    % enobio
    
        pth_easy = client.GetPath('enobio_easy', 'GUID', md.GUID);
        pth_info = client.GetPath('enobio_info', 'GUID', md.GUID);
        if ~isempty(pth_easy) && ~isempty(pth_info)
            ext('enobio') = teExternalData_Enobio(pth_easy, pth_info);
        end
        
    % fieldtrip
    
        pth_ft = client.GetPath('fieldtrip', 'GUID', md.GUID);
        if ~isempty(pth_ft) 
            ext('fieldtrip') = teExternalData_Fieldtrip(pth_ft);
        end        
        
end