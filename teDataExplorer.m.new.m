classdef teDataExplorer < handle
    
    properties
        Tree
        Panel
%         Nodes@teCollection
    end
    
    properties (Access = private)
        uiFig
    end
    
    events
        SingleNodeSelected
        MultipleNodesSelected
    end
    
    methods
        
        function obj = teDataExplorer(path_root)
            
            % if not root path supplied, use pwd
            if ~exist('path_root', 'var') || ~exist(path_root, 'dir')
                pathSupplied = false;
            else
                pathSupplied = true;
            end
            
            % create figure
            obj.uiFig = uifigure(...
                'SizeChangedFcn', @obj.UIResize,...
                'Visible', 'off',...
                'AutoResizeChildren', 'off');
            
%             % create nodes collection
%             obj.Nodes = teCollection('teDataNode');
            
            % create UI elements
            pos = obj.UIGetPositions;
            
            obj.Tree = uitree(obj.uiFig,...
                'Position', pos.Tree,...
                'SelectionChangedFcn', @obj.NodeSelected,...
                'Multiselect',  'on');
            
            obj.Panel = uipanel(obj.uiFig, 'Position', pos.Panel);
            
            % if a path was supplied, create a filesystem node
            if pathSupplied
                teDataNode_fileSystem(obj, path_root);
            end
            
            obj.uiFig.Visible = 'on';
            
        end
        
        function delete(obj)
            delete(obj.uiFig)
        end
        
        function NodeSelected(obj, ~, event)
            
            numSel = length(event.SelectedNodes);
            if numSel == 1
                notify(obj, 'SingleNodeSelected')
            elseif numSel > 1
                notify(obj, 'MultipleNodesSelected')
            end
            
        end
        
%         function SelectionChanged(obj, src, ~)
%         % fired by a selection change on the data tree. We process the
%         % NodeData property to determine what to do about it.
%         
%             obj.ClearSummary
%             
%             w = obj.uiPnlData.Position(3);
%             h = obj.uiPnlData.Position(4);
%         
%             dat = src.SelectedItem.NodeData;
%             switch dat.type
%                 case 'folder'
%                 case 'session'
%                     teDataSummary_session(obj.uiPnlData, dat, [0, 0, w, h]);
%                 case 'tasks'
%                     teDataSummary_tasks(obj.uiPnlData, dat, [0, 0, w, h]);
%                 case 'task'
%                     teDataSummary_task(obj.uiPnlData, dat, [0, 0, w, h]);
%                 case 'events'
%                     teDataSummary_events(obj.uiPnlData, dat,  [0, 0, w, h]);
%                 case 'external_data'
%                     teDataSummary_externalData(obj.uiPnlData, dat,  [0, 0, w, h]);
%                 case 'eyetracking_detail'
%                     teDataSummary_eyetrackingDetail(obj.uiPnlData, dat,  [0, 0, w, h]);
%             end
%             
%         end
        
%         function JoinableSelectionMade(obj, src, ~)
%             
%             obj.ClearSummary
%             
%             w = obj.uiPnlData.Position(3);
%             h = obj.uiPnlData.Position(4);
%             
%             nodes = src.SelectedItem;
%             
%             
%             
%         end
        
%         function ClearSummary(obj)
%             
%             % delete any existing summaries
%             delete(obj.uiPnlData.Children)
%             
%         end
        
        % UI
        function UIResize(obj, ~, ~)
            
            pos = obj.UIGetPositions;
            
            if ~isempty(obj.Tree)
                obj.Tree.Position = pos.Tree;
            end
            
            obj.Panel.Position = pos.Panel;
            
        end
        
        function pos = UIGetPositions(obj)
            
            w = obj.uiFig.Position(3);
            h = obj.uiFig.InnerPosition(4);
            
            pos.Tree = [0, 0, w * .3, h];
            pos.Panel = [w * .3, 0, w * .7, h];
            
        end
        
    end
    
end