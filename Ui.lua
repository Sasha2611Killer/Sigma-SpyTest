local Ui = {
    DefaultEditorContent = [=[--[[
    Sigma Spy, written by depso
    Hooks rewritten and many more fixes!

    Discord: https://discord.gg/bkUkm2vSbv
]]]=],
    LogLimit = 100,
    SeasonLabels = { 
        January = "⛄ %s ⛄", 
        February = "🌨️ %s 🏂", 
        March = "🌹 %s🌺 ", 
        April = "🐣 %s ✝️", 
        May = "🐝 %s 🌞", 
        June = "🌲 %s 🥕", 
        July = "🌊 %s 🌅", 
        August = "☀️ %s 🌞", 
        September = "🍁 %s 🍁", 
        October = "🎃 %s 🎃", 
        November = "🍂 %s 🍂", 
        December = "🎄 %s 🎁"
    },
    Scales = {
        ["Mobile"] = UDim2.fromOffset(480, 280),
        ["Desktop"] = UDim2.fromOffset(600, 400),
    },
    BaseConfig = {
        Theme = "DarkTheme",
        NoScroll = true,
    },
    OptionTypes = {
        boolean = "Checkbox",
    },
    DisplayRemoteInfo = {
        "MetaMethod",
        "Method",
        "Remote",
        "CallingScript",
        "IsActor",
        "Id"
    },

    Window = nil,
    RandomSeed = Random.new(tick()),
    Logs = setmetatable({}, {__mode = "k"}),
    LogQueue = setmetatable({}, {__mode = "v"}),
} 

type table = {
    [any]: any
}

type Log = {
    Remote: Instance,
    Method: string,
    Args: table,
    IsReceive: boolean?,
    MetaMethod: string?,
    OrignalFunc: ((...any) -> ...any)?,
    CallingScript: Instance?,
    CallingFunction: ((...any) -> ...any)?,
    ClassData: table?,
    ReturnValues: table?,
    RemoteData: table?,
    Id: string,
    Selectable: table,
    HeaderData: table,
    ValueSwaps: table,
    Timestamp: number,
    IsExploit: boolean
}

--// Compatibility
local SetClipboard = setclipboard or toclipboard or set_clipboard

--// Libraries
local ReGui = nil

--// Modules
local Flags
local Generation
local Process
local Hook 
local Config
local Communication
local Files

local ActiveData = nil
local RemotesCount = 0

local TextFont = Font.fromEnum(Enum.Font.Code)
local FontSuccess = false
local CommChannel

function Ui:Init(Data)
    if not Data then
        warn("Ui:Init called with nil Data")
        return
    end
    
    local Modules = Data.Modules
    if not Modules then
        warn("Ui:Init: Modules not found in Data")
        return
    end

    --// Modules
    Flags = Modules.Flags
    Generation = Modules.Generation
    Process = Modules.Process
    Hook = Modules.Hook
    Config = Modules.Config
    Communication = Modules.Communication
    Files = Modules.Files

    --// Check essential modules
    if not Process then error("Process module not loaded") end
    if not Hook then error("Hook module not loaded") end
    if not Config then error("Config module not loaded") end

    --// Load ReGui with fallback
    local repoUrl = "https://raw.githubusercontent.com/Sasha2611Killer/Sigma-SpyTest/main"
    if Data.Configuration and Data.Configuration.RepoUrl then
        repoUrl = Data.Configuration.RepoUrl
    end
    
    print("Loading ReGui from:", repoUrl)
    
    --// Try multiple sources for ReGui
    local reGuiSources = {
        repoUrl .. "/Regui.lua",
    }
    
    for _, source in ipairs(reGuiSources) do
        local success, result = pcall(function()
            local code = game:HttpGet(source, true)
            return loadstring(code, "ReGui")()
        end)
        
        if success then
            ReGui = result
            print("ReGui loaded successfully from:", source)
            break
        else
            warn("Failed to load ReGui from", source, ":", result)
        end
    end
    
    if not ReGui then
        error("Could not load ReGui from any source")
    end
    
    --// Initialize font
    self:LoadFont()
    self:LoadReGui()
    self:CheckScale()
    
    print("Ui initialized successfully")
end

function Ui:SetCommChannel(NewCommChannel: BindableEvent)
    CommChannel = NewCommChannel
end

function Ui:CheckScale()
    if not ReGui then return end
    
    local BaseConfig = self.BaseConfig
    local Scales = self.Scales

    local IsMobile = ReGui:IsMobileDevice()
    local Device = IsMobile and "Mobile" or "Desktop"

    BaseConfig.Size = Scales[Device]
end

function Ui:SetClipboard(Content: string)
    if SetClipboard then
        SetClipboard(Content)
    end
end

function Ui:TurnSeasonal(Text: string): string
    local SeasonLabels = self.SeasonLabels
    local Month = os.date("%B")
    local Base = SeasonLabels[Month]

    return Base:format(Text)
end

function Ui:LoadFont()
    if not Files or not self.FontJsonFile then return end

    local AssetId = Files:LoadCustomasset(self.FontJsonFile)
    if not AssetId then return end

    local NewFont = Font.new(AssetId)
    TextFont = NewFont
    FontSuccess = true
end

function Ui:SetFontFile(FontFile: string)
    self.FontJsonFile = FontFile
end

function Ui:FontWasSuccessful()
    if FontSuccess then return end

    self:ShowModal({
        "Font not loaded, using default font",
    })
end

function Ui:LoadReGui()
    if not ReGui then return end
    
    if Config and Config.ThemeConfig then
        Config.ThemeConfig.TextFont = TextFont
        ReGui:DefineTheme("DarkTheme", Config.ThemeConfig)
    end
end

type CreateButtons = {
    Base: table?,
    Buttons: table,
    NoTable: boolean?
}
function Ui:CreateButtons(Parent, Data: CreateButtons)
    if not ReGui then return end
    
    local Base = Data.Base or {}
    local Buttons = Data.Buttons
    local NoTable = Data.NoTable

    if not NoTable then
        Parent = Parent:Table({MaxColumns = 3}):NextRow()
    end

    for _, Button in next, Buttons do
        local Container = Parent
        if not NoTable then
            Container = Parent:NextColumn()
        end

        ReGui:CheckConfig(Button, Base)
        Container:Button(Button)
    end
end

function Ui:CreateWindow(WindowConfig)
    if not ReGui then return nil end
    
    local BaseConfig = self.BaseConfig
    local Config = Process:DeepCloneTable(BaseConfig)
    Process:Merge(Config, WindowConfig)

    local Window = ReGui:Window(Config)

    if not FontSuccess then 
        Window:SetTheme("DarkTheme")
    end
    
    return Window
end

type AskConfig = {
    Title: string,
    Content: table,
    Options: table
}
function Ui:AskUser(Config: AskConfig): string
    local Window = self.Window
    if not Window then return "No" end

    local Answered = false

    local ModalWindow = Window:PopupModal({Title = Config.Title})
    ModalWindow:Label({
        Text = table.concat(Config.Content, "\n"),
        TextWrapped = true
    })
    ModalWindow:Separator()

    local Row = ModalWindow:Row({Expanded = true})
    for _, Answer in next, Config.Options do
        Row:Button({
            Text = Answer,
            Callback = function()
                Answered = Answer
                ModalWindow:ClosePopup()
            end,
        })
    end

    repeat task.wait() until Answered
    return Answered
end

function Ui:CreateMainWindow()
    local Window = self:CreateWindow()
    if not Window then
        error("Failed to create main window")
    end
    
    self.Window = Window

    self:FontWasSuccessful()
    self:AuraCounterService()

    if Flags and Flags.SetFlagCallback then
        Flags:SetFlagCallback("UiVisible", function(self, Visible)
            Window:SetVisible(Visible)
        end)
    end

    return Window
end

function Ui:ShowModal(Lines: table)
    local Window = self.Window
    if not Window then return end
    
    local Message = table.concat(Lines, "\n")

    local ModalWindow = Window:PopupModal({Title = "Sigma Spy"})
    ModalWindow:Label({
        Text = Message,
        RichText = true,
        TextWrapped = true
    })
    ModalWindow:Button({
        Text = "Okay",
        Callback = function()
            ModalWindow:ClosePopup()
        end,
    })
end

function Ui:ShowUnsupportedExecutor(Name: string)
    Ui:ShowModal({
        "Sigma Spy not supported on: " .. Name,
    })
end

function Ui:ShowUnsupported(FuncName: string)
    Ui:ShowModal({
        "Missing function: " .. FuncName,
    })
end

function Ui:CreateOptionsForDict(Parent, Dict: table, Callback)
    local Options = {}

    for Key, Value in next, Dict do
        Options[Key] = {
            Value = Value,
            Label = Key,
            Callback = function(_, Value)
                Dict[Key] = Value
                if Callback then Callback() end
            end
        }
    end

    self:CreateElements(Parent, Options)
end

function Ui:CheckKeybindLayout(Container, KeyCode: Enum.KeyCode, Callback)
    if not KeyCode then return Container end

    Container = Container:Row({
        HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween
    })

    Container:Keybind({
        Label = "",
        Value = KeyCode,
        LayoutOrder = 2,
        IgnoreGameProcessed = false,
        Callback = function()
            if Flags:GetFlagValue("KeybindsEnabled") then
                Callback()
            end
        end,
    })

    return Container
end

function Ui:CreateElements(Parent, Options)
    if not ReGui then return end
    
    local OptionTypes = self.OptionTypes
    local Table = Parent:Table({MaxColumns = 3}):NextRow()

    for Name, Data in Options do
        local Value = Data.Value
        local Type = typeof(Value)

        ReGui:CheckConfig(Data, {
            Class = OptionTypes[Type],
            Label = Name,
        })
        
        local Class = Data.Class
        if not Class then continue end

        local Container = Table:NextColumn()
        local Checkbox = nil

        local Keybind = Data.Keybind
        Container = self:CheckKeybindLayout(Container, Keybind, function()
            if Checkbox then Checkbox:Toggle() end
        end)
        
        if Container[Class] then
            Checkbox = Container[Class](Container, Data)
        end
    end
end

function Ui:DisplayAura()
    local Window = self.Window
    if not Window then return end
    
    local Rand = self.RandomSeed

    local AURA = Rand:NextInteger(1, 9999999)
    local AURADELAY = Rand:NextInteger(1, 5)

    local Title = "Sigma Spy | AURA: " .. AURA
    local Seasonal = self:TurnSeasonal(Title)
    Window:SetTitle(Seasonal)

    task.wait(AURADELAY)
end

function Ui:AuraCounterService()
    task.spawn(function()
        while true do
            self:DisplayAura()
            task.wait(5)
        end
    end)
end

function Ui:CreateWindowContent(Window)
    if not ReGui then return end
    
    local Layout = Window:List({
        UiPadding = 2,
        HorizontalFlex = Enum.UIFlexAlignment.Fill,
        VerticalFlex = Enum.UIFlexAlignment.Fill,
        FillDirection = Enum.FillDirection.Vertical,
        Fill = true
    })

    self.RemotesList = Layout:Canvas({
        Scroll = true,
        UiPadding = 5,
        AutomaticSize = Enum.AutomaticSize.None,
        FlexMode = Enum.UIFlexMode.None,
        Size = UDim2.new(0, 130, 1, 0)
    })

    local InfoSelector = Layout:TabSelector({
        NoAnimation = true,
        Size = UDim2.new(1, -130, 0.4, 0),
    })

    self.InfoSelector = InfoSelector
    self.CanvasLayout = Layout

    self:MakeEditorTab(InfoSelector)
    self:MakeOptionsTab(InfoSelector)
    
    if Config and Config.Debug then
        self:ConsoleTab(InfoSelector)
    end
end

function Ui:ConsoleTab(InfoSelector)
    local Tab = InfoSelector:CreateTab({Name = "Console"})

    local Console
    local ButtonsRow = Tab:Row()

    ButtonsRow:Button({
        Text = "Clear",
        Callback = function()
            if Console then Console:Clear() end
        end
    })
    ButtonsRow:Button({
        Text = "Copy",
        Callback = function()
            if Console then toclipboard(Console:GetValue()) end
        end
    })
    ButtonsRow:Expand()

    Console = Tab:Console({
        Text = "-- Sigma Spy Console",
        ReadOnly = true,
        Border = false,
        Fill = true,
        Enabled = true,
        AutoScroll = true,
        RichText = true,
        MaxLines = 50
    })

    self.Console = Console
end

function Ui:ConsoleLog(...)
    local Console = self.Console
    if not Console then return end

    local text = table.concat({...}, " ")
    Console:AppendText(text .. "\n")
end

function Ui:MakeOptionsTab(InfoSelector)
    local Tab = InfoSelector:CreateTab({Name = "Options"})

    Tab:Separator({Text="Logs"})
    self:CreateButtons(Tab, {
        Base = {
            Size = UDim2.new(1, 0, 0, 20),
            AutomaticSize = Enum.AutomaticSize.Y,
        },
        Buttons = {
            {
                Text = "Clear logs",
                Callback = function()
                    local Tab = ActiveData and ActiveData.Tab or nil
                    if Tab then InfoSelector:RemoveTab(Tab) end
                    ActiveData = nil
                    self:ClearLogs()
                end,
            },
            {
                Text = "Join Discord",
                Callback = function()
                    self:SetClipboard("https://discord.gg/s9ngmUDWgb")
                end,
            },
            {
                Text = "Copy Github",
                Callback = function()
                    self:SetClipboard("https://github.com/depthso/Sigma-Spy")
                end,
            },
        }
    })

    if Flags then
        Tab:Separator({Text="Settings"})
        self:CreateElements(Tab, Flags:GetFlags())
    end
end

function Ui:AddDetailsSection(OptionsTab)
    OptionsTab:Separator({Text="Information"})
    OptionsTab:BulletText({
        Rows = {
            "Sigma spy - Remote event logger",
            "For debugging and analyzing game networking",
            "Use responsibly!"
        }
    })
end

local function MakeActiveDataCallback(Name: string)
    return function(...)
        if not ActiveData then return end
        return ActiveData[Name](ActiveData, ...)
    end
end

function Ui:MakeEditorTab(InfoSelector)
    local Default = self.DefaultEditorContent
    local SyntaxColors = Config and Config.SyntaxColors or {}

    local EditorTab = InfoSelector:CreateTab({Name = "Editor"})

    local CodeEditor = EditorTab:CodeEditor({
        Fill = true,
        Editable = true,
        FontSize = 13,
        Colors = SyntaxColors,
        FontFace = TextFont,
        Text = Default
    })

    local ButtonsRow = EditorTab:Row()
    self:CreateButtons(ButtonsRow, {
        NoTable = true,
        Buttons = {
            {
                Text = "Copy",
                Callback = function()
                    local Script = CodeEditor:GetText()
                    self:SetClipboard(Script)
                end
            },
            {
                Text = "Run",
                Callback = function()
                    local Script = CodeEditor:GetText()
                    local Func, Error = loadstring(Script, "SigmaSpy-USERSCRIPT")
                    if not Func then
                        self:ShowModal({"Error:", Error})
                        return
                    end
                    Func()
                end
            },
        }
    })
    
    self.CodeEditor = CodeEditor
end

function Ui:ShouldFocus(Tab): boolean
    local InfoSelector = self.InfoSelector
    local ActiveTab = InfoSelector.ActiveTab

    if not ActiveTab then return true end
    return InfoSelector:CompareTabs(ActiveTab, Tab)
end

function Ui:MakeEditorPopoutWindow(Content: string, WindowConfig: table)
    local Window = self:CreateWindow(WindowConfig)
    if not Window then return nil, nil end
    
    local Buttons = WindowConfig.Buttons or {}
    local Colors = Config and Config.SyntaxColors or {}

    local CodeEditor = Window:CodeEditor({
        Text = Content,
        Editable = true,
        Fill = true,
        FontSize = 13,
        Colors = Colors,
        FontFace = TextFont
    })

    table.insert(Buttons, {
        Text = "Copy",
        Callback = function()
            local Script = CodeEditor:GetText()
            self:SetClipboard(Script)
        end
    })

    local ButtonsRow = Window:Row()
    self:CreateButtons(ButtonsRow, {
        NoTable = true,
        Buttons = Buttons
    })

    Window:Center()
    return CodeEditor, Window
end

function Ui:EditFile(FilePath: string, InFolder: boolean, OnSaveFunc: ((table, string) -> nil)?)
    local Folder = Files and Files.FolderName or "Sigma Spy"
    local CodeEditor, Window

    if InFolder then
        FilePath = Folder .. "/" .. FilePath
    end

    local Content
    if readfile then
        local success, result = pcall(readfile, FilePath)
        if success then
            Content = result:gsub("\r\n", "\n")
        else
            Content = "-- File not found or cannot be read"
        end
    else
        Content = "-- File system not available"
    end
    
    local Buttons = {
        {
            Text = "Save",
            Callback = function()
                if not writefile then
                    self:ShowModal({"File system not available"})
                    return
                end
                
                local Script = CodeEditor:GetText()
                local Success, Error = loadstring(Script, "SigmaSpy-Editor")

                if not Success then
                    self:ShowModal({"Error saving file:", Error})
                    return
                end
                
                writefile(FilePath, Script)

                if OnSaveFunc then
                    OnSaveFunc(Window, Script)
                end
            end
        }
    }

    CodeEditor, Window = self:MakeEditorPopoutWindow(Content, {
        Title = "Editing: " .. FilePath,
        Buttons = Buttons
    })
end

type MenuOptions = {
    [string]: (GuiButton, ...any) -> nil
}
function Ui:MakeButtonMenu(Button: Instance, Unpack: table, Options: MenuOptions)
    local Window = self.Window
    if not Window then return end
    
    local Popup = Window:PopupCanvas({
        RelativeTo = Button,
        MaxSizeX = 500,
    })

    for Name, Func in Options do
         Popup:Selectable({
            Text = Name,
            Callback = function()
                Func(Process:Unpack(Unpack))
            end,
        })
    end
end

function Ui:RemovePreviousTab(Title: string): boolean
    if not ActiveData then return false end

    local InfoSelector = self.InfoSelector
    local PreviousTab = ActiveData.Tab
    local PreviousSelectable = ActiveData.Selectable

    local TabFocused = self:ShouldFocus(PreviousTab)
    InfoSelector:RemoveTab(PreviousTab)
    PreviousSelectable:SetSelected(false)

    return TabFocused
end

function Ui:MakeTableHeaders(Table, Rows: table)
    local HeaderRow = Table:HeaderRow()
    for _, Catagory in Rows do
        local Column = HeaderRow:NextColumn()
        Column:Label({Text=Catagory})
    end
end

function Ui:Decompile(Editor: table, Script: Script)
    Editor:SetText("--Decompiling...")

    local Decompiled, IsError = Process:Decompile(Script)

    if not IsError then
        Decompiled = "-- Decompiled with Sigma Spy\n" .. Decompiled
    end

    Editor:SetText(Decompiled)
end

type DisplayTableConfig = {
    Rows: table,
    Flags: table?,
    ToDisplay: table,
    Table: table
}
function Ui:DisplayTable(Parent, Config: DisplayTableConfig): table
    local Rows = Config.Rows
    local Flags = Config.Flags or {}
    local DataTable = Config.Table
    local ToDisplay = Config.ToDisplay

    Flags.MaxColumns = #Rows

    local Table = Parent:Table(Flags)
    self:MakeTableHeaders(Table, Rows)

    for RowIndex, Name in ToDisplay do
        local Row = Table:Row()
        
        for Count, Catagory in Rows do
            local Column = Row:NextColumn()
            
            local Value = Catagory == "Name" and Name or DataTable[Name]
            if not Value then continue end

            local String = self:FilterName(tostring(Value), 150)
            Column:Label({Text=String})
        end
    end

    return Table
end

function Ui:SetFocusedRemote(Data)
    if not Data then return end
    
    local Remote = Data.Remote
    local Method = Data.Method
    local Script = Data.CallingScript
    local ClassData = Data.ClassData
    local HeaderData = Data.HeaderData
    local Args = Data.Args
    local Id = Data.Id

    if not Remote or not Method then return end

    local RemoteName = self:FilterName(tostring(Remote), 50)
    local InfoSelector = self.InfoSelector
    if not InfoSelector then return end

    local TabFocused = self:RemovePreviousTab()
    local Tab = InfoSelector:CreateTab({
        Name = "Remote: " .. RemoteName,
        Focused = TabFocused
    })

    ActiveData = Data
    Data.Tab = Tab
    if Data.Selectable then
        Data.Selectable:SetSelected(true)
    end

    --// Simple options for the remote
    Tab:Separator({Text="Remote Options"})
    
    local Row = Tab:Row()
    Row:Button({
        Text = "Copy Remote Path",
        Callback = function()
            self:SetClipboard(tostring(Remote:GetFullName()))
        end
    })
    
    Row:Button({
        Text = "Copy Script Path",
        Callback = function()
            if Script then
                self:SetClipboard(tostring(Script:GetFullName()))
            end
        end
    })

    --// Display basic info
    local infoTable = {
        Method = Method,
        Remote = tostring(Remote),
        CallingScript = Script and tostring(Script) or "None",
        Id = Id
    }
    
    self:DisplayTable(Tab, {
        Rows = {"Name", "Value"},
        Table = infoTable,
        ToDisplay = {"Method", "Remote", "CallingScript", "Id"},
        Flags = {
            Border = true,
            RowBackground = true,
            MaxColumns = 2
        }
    })
    
    --// Display arguments
    if Args and #Args > 0 then
        Tab:Separator({Text="Arguments"})
        local argsText = ""
        for i, arg in ipairs(Args) do
            argsText = argsText .. string.format("Arg[%d]: %s\n", i, tostring(arg))
        end
        Tab:Label({Text = argsText, TextWrapped = true})
    end
end

function Ui:ViewConnections(RemoteName: string, Signal: RBXScriptConnection)
    local Window = self:CreateWindow({
        Title = "Connections for: " .. RemoteName,
        Size = UDim2.fromOffset(450, 250)
    })
    
    if not Window then return end
    
    Window:Label({Text = "Connection viewer not fully implemented", TextWrapped = true})
    Window:Center()
end

function Ui:GetRemoteHeader(Data: Log)
    local LogLimit = self.LogLimit
    local Logs = self.Logs
    local RemotesList = self.RemotesList

    local Id = Data.Id
    local Remote = Data.Remote
    local RemoteName = self:FilterName(tostring(Remote), 30)

    local Existing = Logs[Id]
    if Existing then return Existing end

    local HeaderData = {    
        LogCount = 0,
        Data = Data,
        Entries = {}
    }

    RemotesCount += 1

    if RemotesList then
        HeaderData.TreeNode = RemotesList:TreeNode({
            LayoutOrder = -1 * RemotesCount,
            Title = RemoteName
        })
    end

    function HeaderData:CheckLimit()
        local Entries = self.Entries
        if #Entries < LogLimit then return end
            
        local Log = table.remove(Entries, 1)
        if Log.Selectable then
            Log.Selectable:Remove()
        end
    end

    function HeaderData:LogAdded(Data)
        self.LogCount += 1
        self:CheckLimit()
        table.insert(self.Entries, Data)
        return self
    end

    function HeaderData:Remove()
        if self.TreeNode then
            self.TreeNode:Remove()
        end
        Logs[Id] = nil
    end

    Logs[Id] = HeaderData
    return HeaderData
end

function Ui:ClearLogs()
    local Logs = self.Logs
    local RemotesList = self.RemotesList

    RemotesCount = 0
    if RemotesList then
        RemotesList:ClearChildElements()
    end

    table.clear(Logs)
end

function Ui:QueueLog(Data)
    if not Process then return end
    
    local LogQueue = self.LogQueue
    Process:Merge(Data, {
        Args = Process:DeepCloneTable(Data.Args),
    })

    if Data.ReturnValues then
        Data.ReturnValues = Process:DeepCloneTable(Data.ReturnValues)
    end
    
    table.insert(LogQueue, Data)
end

function Ui:ProcessLogQueue()
    local Queue = self.LogQueue
    if #Queue <= 0 then return end

    for Index, Data in ipairs(Queue) do
        self:CreateLog(Data)
    end
    
    table.clear(Queue)
end

function Ui:BeginLogService()
    task.spawn(function()
        while true do
            self:ProcessLogQueue()
            task.wait(0.1)
        end
    end)
end

function Ui:FilterName(Name: string, CharacterLimit: number?): string
    local limit = CharacterLimit or 20
    local Trimmed = string.sub(tostring(Name), 1, limit)
    local Filtered = Trimmed:gsub("[\n\r]", "")
    
    -- Simple printable filter
    Filtered = Filtered:gsub("[^%w%s%p]", "")
    
    return Filtered
end

function Ui:CreateLog(Data: Log)
    if not Data or not Data.Remote then return end
    
    local Remote = Data.Remote
    local Method = Data.Method
    local Id = Data.Id

    if not Method then return end

    local RemoteData = Process:GetRemoteData(Id)
    if RemoteData and RemoteData.Excluded then return end

    local Text = self:FilterName(tostring(Remote), 30) .. " | " .. Method
    local Header = self:GetRemoteHeader(Data)
    
    if not self.RemotesList then return end
    
    local Selectable = self.RemotesList:Selectable({
        Text = Text,
        LayoutOrder = -1 * Header.LogCount,
        TextXAlignment = Enum.TextXAlignment.Left,
        Callback = function()
            self:SetFocusedRemote(Data)
        end,
    })

    Data.HeaderData = Header
    Data.Selectable = Selectable
    Header:LogAdded(Data)
end

return Ui
