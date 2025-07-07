% This class expects to be passed one input argument, the path to a folder
% containing EEG data. It will determine the type and instantiate a new
% subclass for that type of EEG data, replacing itself. 
classdef teExternalData_EEG_brainproducts < teExternalData_EEG

%     properties 
%         Ext2Te = @(x) x
%         Te2Ext = @(x) x
%     end
    
    properties (SetAccess = protected)
%         NumChannels
%         NumSamples
%         SampleRate 
%         Duration 
%         Valid = false
%         T1 = nan
%         T2 = nan
%         Fieldtrip = []
%         Events = []
        Header = []
        File_vhdr
        File_eeg
        File_vmrk
        EEGSystem = 'brain_products';
%         NumEvents = nan
    end
    
    properties (SetAccess = protected)
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
            
            obj.File_vhdr = file_hdr;
            obj.File_eeg = file_eeg;
            obj.File_vmrk = file_mrk;
            
            % attempt to load hdr file
            obj.Header = obj.readHeader(file_hdr);
            
            % attempt to read data file
            obj.Fieldtrip = obj.readData(file_eeg);
            
            % attempt to read events
            obj.Events = obj.readEvents(file_mrk);
            
            obj.InstantiateSuccess = true;
            obj.InstantiateOutcome = '';         
            obj.Valid = true;
            
        end
        
        function [ft, events, t] = ToFieldtrip(obj)
            
            ft = obj.Fieldtrip;
            if isfield(ft, 'events')
                events = ft.events;
            else
                events = [];
            end
            t = [];
            
        end
       
    end
    
    methods (Access = private)
      
        function hdr = readHeader(obj, file_hdr)
            
            hdr = [];

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
        
        function ft = readData(obj, file_eeg)
            
            ft = [];
            
            % read the actual EEG data in the .eeg file, return duration
            % and number of samples
            cfg = [];
            cfg.dataset = file_eeg;
            ft = ft_preprocessing(cfg);
            
            % extract data
            obj.NumSamples = size(ft.trial{1}, 2);
            obj.Duration = ft.time{1}(end) - ft.time{1}(1);
            
            % extract first (T1) and last (T2) timestamps. In most cases
            % (e.g. brain vision), there is not absolute time, so this will
            % be [1, duration_in_secs]. In some cases (e.g. enobio loaded
            % using Luke's eegEnobio2Fieldtrip function) there will be an
            % abstime field holding (usually) posix timestamps. detect and
            % load these if possible. 
            if isfield(ft, 'abstime')
                error('todo -- extract absolute time')
            else
                obj.T1 = ft.time{1}(1);
                obj.T2 = ft.time{1}(end);
            end
            
        end
        
        function events = readEvents(~, file_mrk)
            
            events = ft_read_event(file_mrk);
            
        end
        
    end
    
    
    
end
