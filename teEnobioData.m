classdef teEnobioData < handle
            
    properties (SetAccess = private)
        LSL_Library
        LSL_Info
        LSL_Inlet_markers
        Valid = false
        Chunks
        Timestamps
    end
            
    methods
        
        function obj = teEnobioData
            % attempt to load the lsl library
            if ~exist('lsl_loadlib', 'file')
                error('Lab streaming layer (specifically lsl_loadlib.m) not found in the Matlab path.')
            else
                obj.LSL_Library = lsl_loadlib;
            end
            % find stream
            obj.LSL_Info = lsl_resolve_byprop(obj.LSL_Library, 'type', 'Markers');
            if isempty(obj.LSL_Info)
                error('Could not subscribe to NIC events -- is NIC running?')
            end
            % subscribe
            obj.LSL_Inlet_markers = lsl_inlet(obj.LSL_Info{1});
            obj.Valid = true;
            obj.Refresh
        end
        
%         function delete(obj)
%             try
%                 lsl_destroy_inlet(obj.LSL_Library, obj.LSL_Inlet_markers);
%             end
%             try
%                 lsl_destroy_streaminfo(obj.LSL_Library, obj.LSL_Info{1});
%             end
%         end
        
        function [tmp_chunk, tmp_timestamp] = Refresh(obj)
            if ~obj.Valid
                warning('Object is not in a valid state and cannot receive markers from NIC.')
                return
            end
            [tmp_chunk, tmp_timestamp] = obj.LSL_Inlet_markers.pull_chunk();
            obj.Chunks = [obj.Chunks; tmp_chunk'];
            obj.Timestamps = [obj.Timestamps; tmp_timestamp'];
        end
        
    end
    
end
            
            
        