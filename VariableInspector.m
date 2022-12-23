classdef VariableInspector < handle
    properties(Access=public)
        ModelName
    end

    properties(Access=private)
        AppData

        UIFigure
        RootGridLayout

        ModelInfoPanel
        ModelInfoPanelGridLayout
        ModelNameLabel
        UpdateButton

        VariablesPanel
        VariablesPanelGridLayout
        VariablesTable

        UsersPanel
        UsersGridLayout
        UsersTable
        HighlightButton
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = VariableInspector(model)

            if ~bdIsLoaded(model)
                ME = MException('simulink:model_not_loaded',sprintf('Block Diagram ''%s'' is not loaded.', model));
                ME.throw();
            end
            app.ModelName = model;

            % Initialize AppData
            app.AppData.VariableInfo = [];
            app.AppData.HiglitedBlock = [];

            % Create UIFigure and components
            createComponents(app)
        end

        % Code that executes before app deletion
        function delete(app)
            % Remove any highlighting
            if ~isempty(app.AppData.HiglitedBlock)
                hilite_system(app.AppData.HiglitedBlock,'none');
            end

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end

    methods (Access = private)
        % Close request function: UIFigure
        function UIFigureCloseRequest(app)
            selection = uiconfirm(app.UIFigure,'Close App?','Confirm Close','Icon','warning');
            switch selection
                case 'OK'
                    delete(app);
                case 'Cancel'
                    return
            end
        end

        function createComponents(app)
            % Create Figure
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Name = 'Variable Inspector';
            app.UIFigure.Position = [100 100 640 480];
            app.UIFigure.CloseRequestFcn = @(src,data)app.UIFigureCloseRequest;

            % Create GridLayout
            app.RootGridLayout = uigridlayout(app.UIFigure);
            app.RootGridLayout.ColumnWidth = {'1x'};
            app.RootGridLayout.RowHeight = {90, '1x','1x'};
            app.configureRootGridLayout();

            % Update the list of variables
            app.updateVariableData();

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end

        function configureRootGridLayout(app)
            % Create ModelInfoPanel and position it in the grid layout
            app.ModelInfoPanel = uipanel(app.RootGridLayout);
            app.ModelInfoPanel.Layout.Row = 1;

            % Create TunableVariablesPanel and position it in the grid layout
            app.VariablesPanel = uipanel(app.RootGridLayout);
            app.VariablesPanel.Layout.Row = 2;

            % Create VariableInfoPanel and position it in the grid layout
            app.UsersPanel = uipanel(app.RootGridLayout);
            app.UsersPanel.Layout.Row = 3;

            % Configure individual elements
            app.configureModelInfoPanel();
            app.configureTunableVariablesPanel();
            app.configureUsersPanel();
        end

        function configureModelInfoPanel(app)
            % Set title
            app.ModelInfoPanel.Title = 'Model Info';

            % Add grid layout
            app.ModelInfoPanelGridLayout = uigridlayout(app.ModelInfoPanel,[1,2]);
            app.ModelInfoPanelGridLayout.ColumnWidth = {'1x', 100};
            app.ModelInfoPanelGridLayout.RowHeight = {40};

            % Add label
            app.ModelNameLabel = uilabel(app.ModelInfoPanelGridLayout);
            app.ModelNameLabel.Layout.Column = 1;
            app.ModelNameLabel.Text = sprintf("Model: %s",app.ModelName);

            % Add push button
            app.UpdateButton = uibutton(app.ModelInfoPanelGridLayout);
            app.UpdateButton.Layout.Column = 2;
            app.UpdateButton.Text = 'Update';
            app.UpdateButton.ButtonPushedFcn = @(button,button_pushed_data)app.updateVariableData();
        end

        function configureTunableVariablesPanel(app)
            app.VariablesPanel.Title = 'Variables';

            % Create TunableVariablesGridLayout
            app.VariablesPanelGridLayout = uigridlayout(app.VariablesPanel);
            app.VariablesPanelGridLayout.ColumnWidth = {'1x'};
            app.VariablesPanelGridLayout.RowHeight = {'1x'};

            % Create VariablesTable
            app.VariablesTable = uitable(app.VariablesPanelGridLayout);
            app.VariablesTable.ColumnName = {'Name'; 'Source'; 'SourceType'};
            app.VariablesTable.RowName = {};
            app.VariablesTable.SelectionType = 'row';
            app.VariablesTable.Multiselect = false;
            app.VariablesTable.Layout.Row = 1;
            app.VariablesTable.Layout.Column = 1;
            app.VariablesTable.SelectionChangedFcn = @(table,event)app.updateUsersTable();
        end

        function configureUsersPanel(app)
            app.UsersPanel.Title = 'Variable Info';

            % Create UsersGridLayout
            app.UsersGridLayout = uigridlayout(app.UsersPanel);
            app.UsersGridLayout.ColumnWidth = {'1x', 100};
            app.UsersGridLayout.RowHeight = {'1x', 40, '1x'};

            % Create UsersTable
            app.UsersTable = uitable(app.UsersGridLayout);
            app.UsersTable.ColumnName = {'Block Paths'};
            app.UsersTable.RowName = {};
            app.UsersTable.SelectionType = 'row';
            app.UsersTable.Multiselect = false;
            app.UsersTable.Layout.Row = [1 3];
            app.UsersTable.Layout.Column = 1;
            app.UsersTable.SelectionChangedFcn = @(table,event)app.updateHighlightButton();

            % Add push button
            app.HighlightButton = uibutton(app.UsersGridLayout);
            app.HighlightButton.Layout.Column = 2;
            app.HighlightButton.Layout.Row = 2;
            app.HighlightButton.Text = 'Find in Model';
            app.HighlightButton.ButtonPushedFcn = @(button,event)app.highlightBlock();
            app.HighlightButton.Enable = false;
        end

        function updateVariableData(app)
            app.AppData.VariableInfo = Simulink.findVars(app.ModelName);
            table_data = cell(numel(app.AppData.VariableInfo),2);
            for i = 1:numel(app.AppData.VariableInfo)
                table_data{i,1} = app.AppData.VariableInfo(i).Name;
                table_data{i,2} = app.AppData.VariableInfo(i).Source;
                table_data{i,3} = app.AppData.VariableInfo(i).SourceType;
            end
            app.VariablesTable.Data = table_data;
        end

        function updateUsersTable(app)
            app.UsersTable.Data = app.AppData.VariableInfo(app.VariablesTable.Selection).Users;
        end

        function updateHighlightButton(app)
            if ~isempty(app.UsersTable.Selection)
                app.HighlightButton.Enable = true;
            else
                app.HighlightButton.Enable = false;
            end
        end

        function highlightBlock(app)
            if ~isempty(app.AppData.HiglitedBlock)
                hilite_system(app.AppData.HiglitedBlock,'none');
            end
            app.AppData.HiglitedBlock = app.UsersTable.Data{app.UsersTable.Selection};
            hilite_system(app.AppData.HiglitedBlock,'find');
        end
    end

end