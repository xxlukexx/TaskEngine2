classdef teLayers < handle
    
    properties (Access = private)
        prNames
        prValues
        prData = {}
    end
    
    properties (Dependent, SetAccess = private)
        Count
        Items
        Names
    end
    
    methods
        
        function obj = teLayers
        end
        
        function n = numArgumentsFromSubscript(obj,~,~)
            n = numel(obj);
        end
        
        function obj = subsasgn(obj, s, varargin)
            
            if length(s) == 1
                % a fully-formed struct is being assigned
                name = s(1).subs{1};
                data = varargin{1};
                idx = strcmpi(obj.prNames, name);
                if ~any(idx)
                    idx = length(obj.prNames) + 1;
                    obj.prNames{idx} = name;
                end
                if ~isfield(data, 'schematicChoice')
                    data.schematicChoice = [];
                end
                try
                    obj.prData(idx, :) = {...
                        data.ptr,...
                        data.w,...
                        data.h,...
                        data.drawOnWindow,...
                        data.drawOnPreview,...
                        data.z,...
                        data.posPreset,...
                        data.schematicChoice,...
                        };
                catch ERR
                    if contains(ERR.message, 'Reference to non-existent field')
                        error('Unrecognised data format.')
                    else
                        rethrow(ERR)
                    end
                end
            elseif length(s) == 2
                % first element of s is the name of the layer. Second element
                % is the field. Varargin contains the data
                name = s(1).subs{1};
                fld = s(2).subs;
                data = varargin{1};

                idx = strcmpi(obj.prNames, name);
                if ~any(idx)
                    idx = length(obj.prNames) + 1;
                    obj.prNames{idx} = name;
                end                
                idx_fld = obj.lookupFieldIndex(fld);     
                obj.prData{idx, idx_fld} = data;
            else
                error('Unexpected input when assigning a value to a layer.')
            end
            
        end
        
        function varargout = subsref(obj, s)
            
            if length(s) == 1
                if ~iscell(s(1).subs)
                    if nargout == 0
                        builtin('subsref', obj, s)
                        return
                    else
                        varargout{1:nargout} = builtin('subsref', obj, s);
                        return
                    end
                end
                % return entire layer struct (e.g. user asked for
                % layers('layerName')
                name = s(1).subs{1};
                idx = strcmpi(obj.prNames, name);
                if ~any(idx)
                    error('No layer named %s exists.', name);
                else
                    varargout = {obj.prData(idx, :)};
                end
            elseif length(s) == 2
                % return one filed (e.g, user asked for
                % layers('layerName').ptr)
                name = s(1).subs{1};
                fld = s(2).subs;       
                idx = strcmpi(obj.prNames, name);
                if ~any(idx)
                    error('No layer named %s exists.', name);
                end
                idx_fld = obj.lookupFieldIndex(fld);
                varargout = obj.prData(idx, idx_fld);
            else
                error('Unexpected query of layer contents.')
            end
            
        end
        
        function val = get.Count(obj)
            if isempty(obj.prData)
                val = 0;
            else
                val = length(obj.prNames);
            end
        end
        
        function val = get.Items(obj)
            if isempty(obj.prData)
                val = [];
            else
                val = obj.prData;
            end
        end
        
        function val = get.Names(obj)
            if isempty(obj.prData)
                val = [];
            else
                val = obj.prNames;
            end
        end
        
        function idx_fld = lookupFieldIndex(obj, fld)
            switch fld
                case 'ptr'
                    idx_fld = 1;
                case 'w'
                    idx_fld = 2;
                case 'h'
                    idx_fld = 3;
                case 'drawOnWindow'
                    idx_fld = 4;
                case 'drawOnPreview'
                    idx_fld = 5;
                case 'z'
                    idx_fld = 6;
                case 'posPreset'
                    idx_fld = 7;
                case 'schematicChoice'
                    idx_fld = 8;
                otherwise
                    error('No field %s exists in layer %s.', name, fld)
            end
        end
        
    end
    
end