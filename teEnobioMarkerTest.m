classdef teEnobioMarkerTest < handle
    
    properties (SetAccess = private)
        NumberOfMarkersToSend = 100;
        Relay
        EnobioData
        Results
    end
    
    properties (Access = private)
        uiFig
        uiPlots
        uiTable
        uiAdvice
    end
       
    methods
        
        function [obj, suc] = teEnobioMarkerTest(relay, enobioData)
            suc = false;
            if ~exist('enobioData', 'var') || isempty(enobioData)
                try
                    obj.EnobioData = teEnobioData;
                catch ERR
                    errordlg(sprintf('Error whilst trying to contact NIC, error was:\n\n%s',...
                        ERR.message));
                    rethrow(ERR)
                end
            else
                obj.EnobioData = enobioData;
            end
            obj.Relay = relay;
            obj.UICreate;
            drawnow
            suc = obj.StartTest;
        end
        
        function delete(obj, varargin)
            delete(obj.Relay)
            delete(obj.EnobioData)
            if isgraphics(obj.uiFig)
                close(obj.uiFig)
            end
        end
        
        function allSuc = StartTest(obj, num)
            
        % setup
            
            obj.uiAdvice.String = 'Starting up...';
            
            if ~exist('num', 'var') || isempty(num)
                num = obj.NumberOfMarkersToSend;
            end
            
            WaitSecs(1);
            
        % prepare vars

            ts_out = nan(num, 1);
            ev_out = nan(num, 1);
            ts_in = nan(num, 1);
            ev_in = nan(num, 1);
            suc = false(num, 1);
            oc = cell(num, 1);
            obj.EnobioData.Refresh;
            
        % send markers
            
            for i = 1:num
                
%                 if mod(i, 20) == 0
                    obj.uiAdvice.String = sprintf('Marker %d of %d...',...
                        i, num);
%                     obj.Plot(ts_in, ts_out)
                    drawnow
%                 end

                ts_out(i) = obj.Relay.SendEvent(i);
                ev_out(i) = i;
                WaitSecs(0.1);

            end
            
        % receive markers and parse results
        
            [tmp_ev, tmp_ts] = obj.EnobioData.Refresh;     
            noReplies = false;
            
            if all(isempty(tmp_ev)) || all(isempty(tmp_ts))
                
                oc = repmat({'no reply received'}, num, 1);
                noReplies = true;
                
            else

                numRet = length(tmp_ev);
                for i = 1:numRet
                    
                    suc(tmp_ev(i)) = true;
                    oc{tmp_ev(i)} = 'success';
                    ev_in(tmp_ev(i)) = tmp_ev(i);
                    ts_in(tmp_ev(i)) = tmp_ts(i);
                    
                end
                
            end           
            
            results = table;
            results.Success = suc;
            results.Outcome = oc;
            results.Index = (1:num)';
            results.MarkerSent = ev_out;
            results.MarkerReceived = ev_in;
            results.TimestampSent = ts_out;
            results.TimestampReceieved = ts_in;
            results.TimeDeltaMs = (ts_out - ts_in) * 1000;
            obj.uiTable.Data = table2cell(results);
            obj.uiTable.ColumnName = results.Properties.VariableNames;
            
            % classify results
            allSuc = false;
            if all(suc)
                
                % check deltas
                if max(results.TimeDeltaMs) < 2
                    str = 'Marker test passed. Please proceed with testing.';
                else
                    str = 'All markers received but time delta exceeded 2ms. Please report, then proceed with testing.';
                end
                allSuc = true;
                
            elseif noReplies
                str = 'No replies were received from NIC. Please restart NIC and Matlab, then run the marker test again.';
                allSuc = false;
                
            elseif any(suc) && ~all(suc)
                str = 'Some replied not received from NIC. Please restart NIC and Matlab, then run the marker test again.';
                allSuc = false;
                
            end
            obj.uiAdvice.String = str;
            
            obj.Plot(ts_in, ts_out)

        end
        
        function Plot(obj, ts_in, ts_out)
            
            subplot(1, 2, 1, 'parent', obj.uiPlots)
            scatter(ts_out, ts_in)
            xlabel('Timestamp sent to NIC')
            ylabel('Timestamp received from NIC')

            subplot(1, 2, 2, 'parent', obj.uiPlots)
            bar((ts_in - ts_out) * 1000)
            xlabel('Marker')
            ylabel('Time difference (ms, sent - rec)')
            
        end
        
        function UICreate(obj)
            
            pos = obj.UIGetPositions;
            pos.uiFig = [.25, .25, .50, .50];
            
            obj.uiFig = figure('units', 'normalized',...
                'name', 'Enobio Marker Test',...
                'position', pos.uiFig,...
                'menubar', 'none');
            
            obj.uiPlots = uipanel('units', 'normalized',...
                'parent', obj.uiFig,...
                'position', pos.uiPlots);
            
            obj.uiTable = uitable('units', 'normalized',...
                'parent', obj.uiFig,...
                'position', pos.uiTable);            
            
            obj.uiAdvice = uicontrol('units', 'normalized',...
                'style', 'text',...
                'string', 'Waiting to start testing...',...
                'fontsize', 24,...
                'parent', obj.uiFig,...
                'position', pos.uiAdvice);                 
            
        end
        
        function pos = UIGetPositions(~)
            
            pos.uiPlots = [0, 1 / 3, 1, 1 / 3];
            pos.uiTable = [0, 1 / 1.5, 1, 1 / 3];
            pos.uiAdvice = [0, 0, 1, 1 / 3];
            
        end
        
    end
    
end