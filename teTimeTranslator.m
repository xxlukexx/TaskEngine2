classdef teTimeTranslator < handle
    
    properties
        TimeFormats 
        TeTime 
        FirstTeTimestamp = []
    end
    
    methods
        
        function obj = teTimeTranslator(optFirstTeTimestamp)
            
            obj.TimeFormats = teCollection;
            
            if exist('optFirstTeTimestamp', 'var') && ~isempty(optFirstTeTimestamp)
                obj.FirstTeTimestamp = optFirstTeTimestamp;
            end
            
        end
        
        function out = Te2Ext(obj, val, name)
            
            s = obj.TimeFormats(name);
            if isempty(s)
                error('Time format %s not found.', name)
            end
            
            out = s.te2ext(val);
            
        end
        
        function out = Ext2Te(obj, val, name)
            
            s = obj.TimeFormats(name);
            if isempty(s)
                error('Time format %s not found.', name)
            end
            
            out = s.ext2te(val);
            
        end
        
        function out = Te2Abs(obj, val)
            
            if isempty(obj.FirstTeTimestamp)
                out = [];
            else
                out = val - obj.FirstTeTimestamp;
            end
            
        end
        
        function out = Abs2Te2(obj, val)
            
            if isempty(obj.FirstTeTimestamp)
                out = [];
            else
                out = val + obj.FirstTeTimestamp;
            end
            
        end
        
        function out = te2AbsFormatted(obj, val)
            
            if isempty(obj.FirstTeTimestamp)
                out = [];
            else
                out = val - obj.FirstTeTimestamp;
                out = datestr(out / 86400, 'HH:MM:SS.fff');
            end
            
        end
        
        function out = te2Formatted(~, val)
            
            out = char(datetime(val, 'ConvertFrom', 'posixtime'));
     
        end
        
        function AddTimeFormat(obj, varargin)
            
            % two ways to add time formats, 1) with three input args which
            % correspond to name, ext2te and te2ext; 2) with a
            % teExternalData (or subclass) object 
            %
            %   name - the name to refer to this time format when doing
            %   conversion in future. 
            %
            %   te2ext - a function handle to convert from Task Engine
            %   timestamps to external timestamps
            %
            %   ext2te - a function handle to convert from external
            %   timestamps to Task Engine timestamps
            
            if nargin == 4
                
                name = varargin{1};
                ext2te = varargin{2};
                te2ext = varargin{3}; 
                
            elseif nargin == 2
                
                if isa(varargin{1}, 'teExternalData')
                    
                    name = sr.Type;
                    ext2te = sr.Ext2Te;
                    te2ext = sr.Te2Ext;
                    
                end
                
            end
            
            s = struct;
            s.ext2te = ext2te; 
            s.te2ext = te2ext;
            obj.TimeFormats(name) = s;     
                
        end
        
    end
    
end