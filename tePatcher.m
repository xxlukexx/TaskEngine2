classdef tePatcher < handle
    
    properties 
        LastSnapshot 
    end
    
    properties (SetAccess = private)
        Path_Root
        Changes = table
    end
    
    properties (Access = private)
        prSnapshot
    end
    
    methods
        
        function obj = tePatcher(path_root)
            obj.Path_Root = path_root;
            obj.TakeSnapshot
        end
        
        function TakeSnapshot(obj)
            obj.prSnapshot = obj.hashFiles;
            obj.LastSnapshot = datestr(now, 30);
        end
        
        function RecordChanges(obj)
            tab_ss = obj.prSnapshot;
            tab_ch = obj.hashFiles;
            if isequal(tab_ss, tab_ch)
                obj.Changes = table;
            end
            tab = outerjoin(tab_ss, tab_ch, 'Keys', 'file');
            
            tab.changed = cellfun(@(x, y) ~strcmpi(x, y), tab.hash_orig,...
                tab.hash_new);
        end
        
    end
    
    methods (Hidden)
        
        function tab = hashFiles(obj)
            files = recdir(obj.Path_Root);
            numFiles = length(files);
            hashes = repmat({'not a file'}, numFiles, 1);
            parfor f = 1:numFiles
                if isfile(files{f})
                    hashes{f} = CalcMD5(files{f}, 'file');
                end
                fprintf('%s [%s]\n', files{f}, hashes{f});
            end
            tab = table(files, hashes, 'VariableNames',...
                {'file', 'hash_orig'});
        end
        
    end
    
end
            