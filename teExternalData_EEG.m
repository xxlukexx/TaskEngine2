% This class expects to be passed one input argument, the path to a folder
% containing EEG data. It will determine the type and instantiate a new
% subclass for that type of EEG data, replacing itself. 
classdef teExternalData_EEG < teExternalData

    properties 
        Ext2Te = @(x) x
        Te2Ext = @(x) x
    end
    
    properties (SetAccess = protected)
        Fieldtrip
        Events
        NumChannels
        NumSamples
        SampleRate
        Duration      
        T1 = nan
        T2 = nan
        Valid = false
    end
    
    properties (Dependent, SetAccess = private)
        NumEvents
    end
    
%     properties (Abstract, SetAccess = protected)
%         Type       
%     end
    
    methods
        
        function val = get.NumEvents(obj)
            if isempty(obj.Events)
                val = 0;
            else
                val = length(obj.Events);
            end
        end
        
%         function obj = teExternalData_EEG(path_in)    
%             
%             % call superclass constructor to do common initiation
%             obj = obj@teExternalData;
%             
%             % default to failure 
%             obj.InstantiateSuccess = false;
%             obj.InstantiateOutcome = 'unknown error';
%             
%             % get all files in the folder
%             d = dir(path_in);
%             files = struct2table(d);
%             
%             % split into path, file, extension
%             [files.path, files.filename, files.ext] =...
%                 cellfun(@(x) fileparts(x), files.name, 'UniformOutput', false);
%             
%             % define EEG types against file types
%             types = {...
%                 'brainproducts',        'teExternalData_EEG_brainproducts',         {'.eeg', '.vhdr', '.vmrk'}          ;...
%                     };
%             numTypes = size(types, 1);
%                 
%             % compare extensions in folder against EEG types define above
%             for t = 1:numTypes
%                 
%                 if all(ismember(types{t, 3}, files.ext))
%                     
%                     try
%                         className = types{t, 2};
%                         obj = feval(className, path_in);
%                     catch ERR
%                         obj.InstantiateOutcome = ERR.message;           
%                     end
%                     break
%                     
%                 end
%                 
%             end
%             
%         end
%        
%     end
    
    end
    
end
