classdef teConnectToDatabaseUI < teDataSummary
    
    properties 
        Client tepAnalysisClient
    end
    
    properties (Access = private)
        prIP = '127.0.0.1';
        prPort = '3000';
        % ui
        uiPanel
        uiLblIP
        uiTxtIP
        uiLblPort
        uiTxtPort
        uiBtnConnect
        uiLblStatus
    end
    
    methods
        
        function obj = teConnectToDatabaseUI(client, parent)
            obj = obj@teDataSummary(parent);
            obj.Client = client;
        end
        
%         function delete(obj)
%             obj.Client.DisconnectFromServer
%         end
        
        function CreateUI(obj)
            
            pos = obj.UICalculatePositions;
            
            obj.uiLblIP = uilabel(obj.uiParent, 'Position', pos.uiLblIP,...
                'Text', 'IP Address');
            obj.uiTxtIP = uitextarea(obj.uiParent, 'Position', pos.uiTxtIP,...
                'Value', obj.prIP);
            obj.uiLblPort = uilabel(obj.uiParent, 'Position', pos.uiLblPort,...
                'Text', 'Port');
            obj.uiTxtPort = uitextarea(obj.uiParent, 'Position', pos.uiTxtPort,...
                'Value', obj.prPort);
            obj.uiLblStatus = uilabel(obj.uiParent, 'Position', pos.uiLblStatus,...
                'Text', 'Not connected', 'FontColor', 'r');            
            obj.uiBtnConnect = uibutton(obj.uiParent, 'Position', pos.uiBtnConnect,...
                'Text', 'Connect', 'ButtonPushedFcn', @obj.UIBtnConnect_Click);
            
        end
        
        function UpdateUI(obj)
            
            obj.uiTxtIP.Value = obj.prIP;
            obj.uiTxtPort.Value = obj.prPort;
            
        end
        
        function UIBtnConnect_Click(obj, ~, ~)
            
            try
                obj.Client.ConnectToServer(obj.prIP, str2double(obj.prPort))
            catch ERR
                errordlg(sprintf('Error connecting to database:\n\n\t%s',...
                    ERR.message))
                return
            end
            
            obj.uiLblStatus.Text = obj.Client.Status;
            
        end
        
    end
    
    methods (Hidden)
        
        function pos = UICalculatePositions(obj)
            
            pos = struct;
            obj.uiParent.Units = 'pixels';
            
            h_ctrl = 30;
            w = obj.uiParent.Position(3);
            h = obj.uiParent.Position(4);
            
            pos.uiLblIP         = [0, h - (1 * h_ctrl), w * .3, h_ctrl];
            pos.uiTxtIP         = [w * .3, h - (1 * h_ctrl), w * .7, h_ctrl];
            pos.uiLblPort       = [0, h - (2 * h_ctrl), w * .3, h_ctrl];
            pos.uiTxtPort       = [w * .3, h - (2 * h_ctrl), w * .7, h_ctrl];
            pos.uiLblStatus     = [0, h - (3 * h_ctrl), w * .7, h_ctrl];
            pos.uiBtnConnect    = [w * .7, h - (3 * h_ctrl), w * .3, h_ctrl];
            
        end
        
    end
    
end