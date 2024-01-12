classdef teBuffer < handle
    
    properties 
    end
    
    properties (Dependent, SetAccess = protected)
        Buffer
        NumCols
        NumRows
    end
    
    properties (Access = protected)
        prBuffer
        prIdx
    end
    
    properties (Constant)
        CONST_BUFFER_INC = 1e5;
    end
    
    methods
        
        function obj = teBuffer(numCols)
            
            if ~exist('numCols', 'var') || isempty(numCols)
                numCols = 1;
            end
            
            obj.prBuffer = nan(obj.CONST_BUFFER_INC, numCols);
            obj.prIdx = 0;
            
        end
        
        function Add(obj, val)
            
            if size(val, 2) ~= size(obj.prBuffer, 2)
                error('Can only store values with %d columns.', obj.NumCols)
            end
            numToAdd = size(val, 1);
            if obj.prIdx + numToAdd > size(obj.prBuffer, 1)
                obj.prBuffer = [obj.prBuffer; nan(obj.CONST_BUFFER_INC + numToAdd,...
                    size(obj.prBuffer, 2))];
                fprintf('Increased size to %d\n', size(obj.prBuffer, 1));
            end
            obj.prBuffer(obj.prIdx + 1:obj.prIdx + numToAdd, :) = val;
            obj.prIdx = obj.prIdx + numToAdd;
            
        end
         
        % get/set
        function val = get.Buffer(obj)
            if obj.prIdx == 0
                val = [];
            else
                val = obj.prBuffer(1:obj.prIdx, :);
            end
        end
        
        function val = get.NumRows(obj)
            val = obj.prIdx;
        end
        
        function val = get.NumCols(obj)
            val = size(obj.prBuffer, 2);
        end
        
    end
    
end