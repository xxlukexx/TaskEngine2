% This class expects to be passed one input argument, the path to a folder
% containing EEG data. It will determine the type and instantiate a new
% subclass for that type of EEG data, replacing itself. 
classdef teExternalData_EEG_brainproducts < teExternalData

    properties 
        Ext2Te = @(x) x
        Te2Ext = @(x) x
    end
    
    properties (SetAccess = private)
        NumChannels
        NumSamples
        SampleRate
        Duration      
        Valid = false
    end
    
    properties (SetAccess = private)
        Type = 'EEG'        
    end
    
    methods
        
        function obj = teExternalData_EEG_brainproducts(path_in)    
            
            % note that this function is called by teExternalData_EEG, so
            % we do not call the superclass constructor as this would lead
            % to an infinite loop
            
            % default to failure 
            obj.InstantiateSuccess = false;
            obj.InstantiateOutcome = 'unknown error';
            
            % look for .eeg, .vhdr and .vmrk files
            file_eeg = teFindFile(path_in, '*.eeg');
            file_hdr = teFindFile(path_in, '*.vhdr');
            file_mrk = teFindFile(path_in, '*.vmrk');
            
            % check that the right number of each files (one) is present
            if isempty(file_eeg) 
                obj.InstantiateOutcome = 'missing .eeg file';
                return
            end
            if isempty(file_hdr) 
                obj.InstantiateOutcome = 'missing .vhdr file';
                return
            end
            if isempty(file_mrk) 
                obj.InstantiateOutcome = 'missing .vmrk file';
                return
            end
            
            if iscell(file_eeg) && length(file_eeg) > 1
                obj.InstantiateOutcome = 'multiple .eeg files';
                return
            end
            if iscell(file_hdr) && length(file_hdr) > 1
                obj.InstantiateOutcome = 'multiple .vhdr files';
                return
            end
            if iscell(file_mrk) && length(file_mrk) > 1
                obj.InstantiateOutcome = 'multiple .vmrk files';
                return
            end            
            
            % attempt to load hdr file
            obj.readHeader(file_hdr);
            

            
        end
       
    end
    
    methods (Access = private)
      
        function readHeader(obj, file_hdr)

            % read each line of the header text file to an element of the
            % cell array
            fid = fopen(file_hdr, 'r');
            hdr = textscan(fid,'%s', 'Delimiter', '\n');
            fclose(fid);            
            hdr = hdr{1};
            
            % find the sampling rate
            obj.SampleRate = obj.searchHeaderForEntry(hdr, 'SamplingInterval');
            obj.NumChannels = obj.searchHeaderForEntry(hdr, 'NumberOfChannels');
            
        end
        
        function val = searchHeaderForEntry(~, hdr, entry)

            val = nan;

            % Loop through each line  
            for i = 1:length(hdr)   
                if contains(hdr{i}, entry)
                    parts = strsplit(hdr{i}, '=');
                    val = parts{end};
                    break
                end
            end
            
        end
        
        
    end
    
    
    
end
