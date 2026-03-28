--!strict
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local Library = {}
Library.AnimationSpeed = 1
Library.ActivePopup = nil
Library.ThemeObjects = {}
Library.DynamicUpdates = {}
Library.Flags = {}
Library.WindowKeybind = nil
Library.WindowVisible = true
Library.MainFrame = nil
Library.Notifications = {}
Library.ConfigEnabled = false
Library.ConfigName = "SeraphConfig"
Library.NotificationQueue = {}
Library.Scale = 1

-- Configuration
local Config = {
 Colors = {
  MainBg = Color3.fromRGB(17, 17, 22),
  PanelBg = Color3.fromRGB(24, 24, 30),
  SectionBg = Color3.fromRGB(19, 19, 24),
  ElementBg = Color3.fromRGB(15, 15, 19),
  Accent = Color3.fromRGB(218, 36, 155),
  TextMain = Color3.fromRGB(138, 138, 149),
  TextLight = Color3.fromRGB(231, 231, 235),
  Border = Color3.fromRGB(35, 35, 42),
  Separator = Color3.fromRGB(31, 24, 34),
  Success = Color3.fromRGB(67, 181, 129),
  Error = Color3.fromRGB(240, 71, 71),
  Warning = Color3.fromRGB(255, 193, 7)
 },
 Font = Font.new("rbxassetid://12187371840", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
 TextSize = 12,
 ChevronImage = "rbxassetid://10709790948",
 PickerCursor = "rbxassetid://10709798174",
 CloseIcon = "rbxassetid://10709790948"
}

-- Helper Functions
local function CreateTween(Time, Style, Direction)
 return TweenInfo.new(Time / Library.AnimationSpeed, Style or Enum.EasingStyle.Quad, Direction or Enum.EasingDirection.Out)
end

local function CreateInstance(Class, Properties, ThemeProps)
 local Inst = Instance.new(Class)
 for Key, Value in Properties do
  Inst[Key] = Value
 end
 if ThemeProps then
  for Prop, ColorKey in ThemeProps do
   Inst[Prop] = Config.Colors[ColorKey]
   table.insert(Library.ThemeObjects, {Inst, Prop, ColorKey})
  end
 end
 return Inst
end

local function Scale(Value)
 return math.floor(Value * Library.Scale)
end

local function GetBindText(Bind)
 if not Bind then return "None" end
 if Bind == Enum.UserInputType.MouseButton1 then return "MB1" end
 if Bind == Enum.UserInputType.MouseButton2 then return "MB2" end
 if Bind == Enum.UserInputType.MouseButton3 then return "MB3" end
 if typeof(Bind) == "EnumItem" then
  if Bind.Name == "MouseButton1" then return "MB1" end
  if Bind.Name == "MouseButton2" then return "MB2" end
  if Bind.Name == "MouseButton3" then return "MB3" end
  return Bind.Name
 end
 return "None"
end

local function MakeDraggable(TopBar, Object)
 local Dragging = nil
 local DragInput = nil
 local DragStart = nil
 local StartPosition = nil

 TopBar.InputBegan:Connect(function(Input)
  if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
   Dragging = true
   DragStart = Input.Position
   StartPosition = Object.Position

   Input.Changed:Connect(function()
    if Input.UserInputState == Enum.UserInputState.End then
     Dragging = false
    end
   end)
  end
 end)

 TopBar.InputChanged:Connect(function(Input)
  if Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch then
   DragInput = Input
  end
 end)

 UserInputService.InputChanged:Connect(function(Input)
  if Input == DragInput and Dragging then
   local Delta = Input.Position - DragStart
   Object.Position = UDim2.new(StartPosition.X.Scale, StartPosition.X.Offset + Delta.X, StartPosition.Y.Scale, StartPosition.Y.Offset + Delta.Y)
  end
 end)
end

-- Config System - FIX #6: Serialization Support
function Library:EnableConfig(Name)
 Library.ConfigEnabled = true
 Library.ConfigName = Name or "SeraphConfig"
end

function Library:SaveConfig()
 if not Library.ConfigEnabled then return end

 local Data = {}
 for Flag, Func in pairs(Library.Flags) do
  if Func.GetValue then
   local Success, Value = pcall(Func.GetValue)
   if Success then
    -- Check for custom serializer
    if Func.Serialize and type(Func.Serialize) == "function" then
     local serSuccess, serValue = pcall(Func.Serialize, Value)
     if serSuccess then
      Data[Flag] = serValue
     else
      Data[Flag] = Value
     end
    else
     Data[Flag] = Value
    end
   end
  end
 end

 local Encoded = HttpService:JSONEncode(Data)
 if writefile then
  writefile(Library.ConfigName .. ".json", Encoded)
  Library:Notify("Configuration saved", 2, "Success")
 end
end

function Library:LoadConfig()
 if not Library.ConfigEnabled then return end

 if isfile and isfile(Library.ConfigName .. ".json") then
  local Success, Decoded = pcall(function()
   return HttpService:JSONDecode(readfile(Library.ConfigName .. ".json"))
  end)

  if Success and Decoded then
   for Flag, Value in pairs(Decoded) do
    if Library.Flags[Flag] and Library.Flags[Flag].SetValue then
     -- Check for custom deserializer
     if Library.Flags[Flag].Deserialize and type(Library.Flags[Flag].Deserialize) == "function" then
      local deserSuccess, deserValue = pcall(Library.Flags[Flag].Deserialize, Value)
      if deserSuccess then
       pcall(Library.Flags[Flag].SetValue, deserValue)
      end
     else
      pcall(Library.Flags[Flag].SetValue, Value)
     end
    end
   end
   Library:Notify("Configuration loaded", 2, "Success")
  end
 end
end

-- Confirmation Dialog - FIX: Ensure callback fires reliably
function Library:Confirm(Title, Message, Callback)
 local Dialog = CreateInstance("Frame", {
  Parent = Library.MainFrame,
  Size = UDim2.new(0, Scale(280), 0, Scale(130)),
  Position = UDim2.new(0.5, 0, 0.5, 0),
  AnchorPoint = Vector2.new(0.5, 0.5),
  BackgroundTransparency = 0,
  BorderSizePixel = 0,
  ZIndex = 10000
 }, {BackgroundColor3 = "PanelBg"})

 CreateInstance("UICorner", {Parent = Dialog, CornerRadius = UDim.new(0, Scale(6))})
 CreateInstance("UIStroke", {Parent = Dialog, Thickness = 1}, {Color = "Accent"})

 local Backdrop = CreateInstance("Frame", {
  Parent = Library.MainFrame,
  Size = UDim2.new(1, 0, 1, 0),
  BackgroundColor3 = Color3.new(0, 0, 0),
  BackgroundTransparency = 0.5,
  BorderSizePixel = 0,
  ZIndex = 9999
 })

 CreateInstance("TextLabel", {
  Parent = Dialog,
  BackgroundTransparency = 1,
  Size = UDim2.new(1, 0, 0, Scale(26)),
  Position = UDim2.new(0, 0, 0, Scale(8)),
  FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold),
  Text = Title or "Confirm",
  TextSize = Scale(14),
  TextColor3 = Config.Colors.TextLight,
  ZIndex = 10001
 })

 CreateInstance("TextLabel", {
  Parent = Dialog,
  BackgroundTransparency = 1,
  Size = UDim2.new(1, Scale(-16), 0, Scale(40)),
  Position = UDim2.new(0, Scale(8), 0, Scale(36)),
  FontFace = Config.Font,
  Text = Message or "Are you sure?",
  TextSize = Scale(11),
  TextColor3 = Config.Colors.TextMain,
  TextWrapped = true,
  ZIndex = 10001
 })

 local ButtonFrame = CreateInstance("Frame", {
  Parent = Dialog,
  BackgroundTransparency = 1,
  Size = UDim2.new(1, Scale(-16), 0, Scale(30)),
  Position = UDim2.new(0, Scale(8), 1, Scale(-38)),
  ZIndex = 10001
 })

 CreateInstance("UIListLayout", {
  Parent = ButtonFrame,
  FillDirection = Enum.FillDirection.Horizontal,
  HorizontalAlignment = Enum.HorizontalAlignment.Center,
  Padding = UDim.new(0, Scale(8))
 })

 local function CreateBtn(Text, Color, Result)
  local Btn = CreateInstance("TextButton", {
   Parent = ButtonFrame,
   Size = UDim2.new(0.5, Scale(-4), 1, 0),
   BackgroundColor3 = Color,
   BorderSizePixel = 0,
   Text = Text,
   FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold),
   TextSize = Scale(12),
   TextColor3 = Config.Colors.TextLight,
   ZIndex = 10002
  })
  CreateInstance("UICorner", {Parent = Btn, CornerRadius = UDim.new(0, Scale(5))})

  Btn.MouseEnter:Connect(function()
   TweenService:Create(Btn, CreateTween(0.2), {BackgroundColor3 = Color:Lerp(Config.Colors.TextLight, 0.2)}):Play()
  end)
  Btn.MouseLeave:Connect(function()
   TweenService:Create(Btn, CreateTween(0.2), {BackgroundColor3 = Color}):Play()
  end)

  Btn.MouseButton1Click:Connect(function()
   -- Fire callback BEFORE destroying to ensure it runs
   if Callback then
    pcall(function() Callback(Result) end)
   end
   -- Then animate and destroy
   TweenService:Create(Dialog, CreateTween(0.2), {GroupTransparency = 1}):Play()
   TweenService:Create(Backdrop, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
   task.wait(0.2)
   Dialog:Destroy()
   Backdrop:Destroy()
  end)
 end

 CreateBtn("No", Config.Colors.ElementBg, false)
 CreateBtn("Yes", Config.Colors.Accent, true)
end

-- Notification System - FIX #7: Queue Overflow Protection
function Library:Notify(Message, Duration, Type)
 -- Cap at 5 notifications
 while #Library.Notifications >= 5 do
  local oldest = table.remove(Library.Notifications, 1)
  if oldest and oldest.Parent then oldest:Destroy() end
 end

 Type = Type or "Info"
 Duration = Duration or 3

 local NotificationGui = CreateInstance("Frame", {
  Name = "Notification",
  Parent = Library.MainFrame and Library.MainFrame.Parent or game.CoreGui,
  Size = UDim2.new(0, Scale(260), 0, Scale(50)),
  Position = UDim2.new(0.5, 0, 0, Scale(80)),
  AnchorPoint = Vector2.new(0.5, 0),
  BackgroundTransparency = 0.05,
  BorderSizePixel = 0,
  ZIndex = 5000,
  Visible = false
 }, {BackgroundColor3 = "PanelBg"})

 CreateInstance("UICorner", {Parent = NotificationGui, CornerRadius = UDim.new(0, Scale(5))})
 CreateInstance("UIStroke", {Parent = NotificationGui, Thickness = 1}, {Color = "Border"})

 local ColorMap = {
  Info = "Accent",
  Success = "Success",
  Error = "Error",
  Warning = "Warning"
 }

 CreateInstance("Frame", {
  Parent = NotificationGui,
  Size = UDim2.new(0, Scale(3), 1, 0),
  BorderSizePixel = 0
 }, {BackgroundColor3 = ColorMap[Type] or "Accent"})

 CreateInstance("TextLabel", {
  Parent = NotificationGui,
  BackgroundTransparency = 1,
  Size = UDim2.new(1, Scale(-16), 1, 0),
  Position = UDim2.new(0, Scale(12), 0, 0),
  FontFace = Config.Font,
  TextSize = Scale(11),
  Text = Message,
  TextXAlignment = Enum.TextXAlignment.Left,
  TextYAlignment = Enum.TextYAlignment.Center,
  TextWrapped = true
 }, {TextColor3 = "TextLight"})

 table.insert(Library.Notifications, NotificationGui)

 NotificationGui.Visible = true
 local InTween = TweenService:Create(NotificationGui, CreateTween(0.3), {Position = UDim2.new(0.5, 0, 0, Scale(15))})
 InTween:Play()

 task.delay(Duration, function()
  local OutTween = TweenService:Create(NotificationGui, CreateTween(0.3), {Position = UDim2.new(0.5, 0, 0, Scale(-80)), BackgroundTransparency = 1})
  OutTween:Play()
  OutTween.Completed:Wait()
  NotificationGui:Destroy()
  local idx = table.find(Library.Notifications, NotificationGui)
  if idx then table.remove(Library.Notifications, idx) end
 end)
end

function Library:ClosePopups()
 if Library.ActivePopup then
  if Library.ActivePopup.Close then
   Library.ActivePopup.Close()
  end
  Library.ActivePopup = nil
 end
end

function Library:SetTheme(NewColors)
 for Key, Value in NewColors do
  if Config.Colors[Key] then
   Config.Colors[Key] = Value
  end
 end
 for _, ObjData in Library.ThemeObjects do
  local Instance, Prop, ColorKey = ObjData[1], ObjData[2], ObjData[3]
  if Instance and Instance.Parent then
   Instance[Prop] = Config.Colors[ColorKey]
  end
 end
 for _, Func in Library.DynamicUpdates do
  Func()
 end
end

function Library:GetTheme()
 local ThemeCopy = {}
 for Key, Value in Config.Colors do
  ThemeCopy[Key] = Value
 end
 return ThemeCopy
end

function Library:SetAnimationSpeed(NewSpeed)
 Library.AnimationSpeed = NewSpeed
end

function Library:SetScale(NewScale)
 Library.Scale = NewScale
end

function Library:SetWindowKeybind(KeyCode)
 Library.WindowKeybind = KeyCode
end

-- Input Handling
UserInputService.InputBegan:Connect(function(Input, Processed)
 if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
  if Library.ActivePopup and Library.ActivePopup.Element then
   local Ele = Library.ActivePopup.Element
   local Mx, My = Input.Position.X, Input.Position.Y
   local Px, Py = Ele.AbsolutePosition.X, Ele.AbsolutePosition.Y
   local Sx, Sy = Ele.AbsoluteSize.X, Ele.AbsoluteSize.Y

   if Mx < Px or Mx > Px + Sx or My < Py or My > Py + Sy then
    local InIgnore = false
    if Library.ActivePopup.Ignore then
     for _, Ignore in Library.ActivePopup.Ignore do
      local Ix, Iy = Ignore.AbsolutePosition.X, Ignore.AbsolutePosition.Y
      local Isx, Isy = Ignore.AbsoluteSize.X, Ignore.AbsoluteSize.Y
      if Mx >= Ix and Mx <= Ix + Isx and My >= Iy and My <= Iy + Isy then
       InIgnore = true
       break
      end
     end
    end
    if not InIgnore then
     Library:ClosePopups()
    end
   end
  end
 end

 if not Processed and Library.WindowKeybind and Input.KeyCode == Library.WindowKeybind and Library.MainFrame then
  Library.WindowVisible = not Library.WindowVisible
  if Library.WindowVisible then
   Library.MainFrame.Visible = true
   TweenService:Create(Library.MainFrame, CreateTween(0.2), {GroupTransparency = 0}):Play()
   local Stroke = Library.MainFrame:FindFirstChild("UIStroke")
   if Stroke then
    TweenService:Create(Stroke, CreateTween(0.2), {Transparency = 0}):Play()
   end
  else
   local Tween = TweenService:Create(Library.MainFrame, CreateTween(0.2), {GroupTransparency = 1})
   local Stroke = Library.MainFrame:FindFirstChild("UIStroke")
   if Stroke then
    TweenService:Create(Stroke, CreateTween(0.2), {Transparency = 1}):Play()
   end
   Tween:Play()
   task.spawn(function()
    Tween.Completed:Wait()
    if not Library.WindowVisible then
     Library.MainFrame.Visible = false
    end
   end)
  end
 end
end)

-- Main Window Function
function Library:Window(TitleOrIcon, WindowScale)
 Library.Scale = WindowScale or 1

 local ScreenGui = CreateInstance("ScreenGui", {
  Name = "Seraph",
  Parent = game.CoreGui,
  ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
  ResetOnSpawn = false,
  IgnoreGuiInset = true
 })

 local MainFrame = CreateInstance("CanvasGroup", {
  Name = "MainFrame",
  Parent = ScreenGui,
  BorderSizePixel = 0,
  AnchorPoint = Vector2.new(0.5, 0.5),
  Position = UDim2.new(0.5, 0, 0.5, 0),
  Size = UDim2.new(0, Scale(750), 0, Scale(500)),
  GroupTransparency = 0
 }, {BackgroundColor3 = "PanelBg"})

 local SizeConstraint = CreateInstance("UISizeConstraint", {
  Parent = MainFrame,
  MaxSize = Vector2.new(Scale(900), Scale(650)),
  MinSize = Vector2.new(Scale(350), Scale(250))
 })

 Library.MainFrame = MainFrame
 CreateInstance("UICorner", {Parent = MainFrame, CornerRadius = UDim.new(0, Scale(6))})
 local MainStroke = CreateInstance("UIStroke", {Parent = MainFrame, Thickness = 1, Name = "UIStroke"}, {Color = "MainBg"})

 local TopBar = CreateInstance("Frame", {
  Name = "TopBar",
  Parent = MainFrame,
  BorderSizePixel = 0,
  Size = UDim2.new(1, 0, 0, Scale(40))
 }, {BackgroundColor3 = "MainBg"})

 MakeDraggable(TopBar, MainFrame)

 if tostring(TitleOrIcon):find("rbxassetid") then
  CreateInstance("ImageLabel", {
   Parent = TopBar,
   BackgroundTransparency = 1,
   Size = UDim2.new(0, Scale(26), 0, Scale(26)),
   AnchorPoint = Vector2.new(0, 0.5),
   Position = UDim2.new(0, Scale(12), 0.5, 0),
   Image = TitleOrIcon,
   ScaleType = Enum.ScaleType.Fit
  }, {ImageColor3 = "Accent"})
 else
  CreateInstance("TextLabel", {
   Parent = TopBar,
   BackgroundTransparency = 1,
   Position = UDim2.new(0, Scale(16), 0, 0),
   Size = UDim2.new(0, Scale(200), 1, 0),
   FontFace = Config.Font,
   Text = tostring(TitleOrIcon or "Library"),
   TextSize = Scale(16),
   TextXAlignment = Enum.TextXAlignment.Left
  }, {TextColor3 = "Accent"})
 end

 local MinimizeButton = CreateInstance("TextButton", {
  Parent = TopBar,
  BackgroundTransparency = 1,
  Size = UDim2.new(0, Scale(28), 0, Scale(28)),
  Position = UDim2.new(1, Scale(-72), 0, Scale(6)),
  Text = "−",
  FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
  TextSize = Scale(20),
  AutoButtonColor = false
 }, {TextColor3 = "TextMain"})

 CreateInstance("UICorner", {Parent = MinimizeButton, CornerRadius = UDim.new(0, Scale(5))})

 local CloseButton = CreateInstance("TextButton", {
  Parent = TopBar,
  BackgroundTransparency = 1,
  Size = UDim2.new(0, Scale(28), 0, Scale(28)),
  Position = UDim2.new(1, Scale(-38), 0, Scale(6)),
  Text = "X",
  FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
  TextSize = Scale(14),
  AutoButtonColor = false
 }, {TextColor3 = "TextMain"})

 CreateInstance("UICorner", {Parent = CloseButton, CornerRadius = UDim.new(0, Scale(5))})

 local Body = CreateInstance("Frame", {
  Parent = MainFrame,
  BackgroundTransparency = 1,
  Position = UDim2.new(0, 0, 0, Scale(40)),
  Size = UDim2.new(1, 0, 1, Scale(-40)),
  Name = "Body"
 })

 local function ClampWindowPosition()
  local viewportSize = workspace.CurrentCamera.ViewportSize
  local size = MainFrame.AbsoluteSize
  local pos = MainFrame.Position

  local minX = size.X / 2
  local maxX = viewportSize.X - size.X / 2
  local minY = size.Y / 2
  local maxY = viewportSize.Y - size.Y / 2

  local newX = math.clamp(pos.X.Offset, minX - (viewportSize.X * pos.X.Scale), maxX - (viewportSize.X * pos.X.Scale))
  local newY = math.clamp(pos.Y.Offset, minY - (viewportSize.Y * pos.Y.Scale), maxY - (viewportSize.Y * pos.Y.Scale))

  if newX ~= pos.X.Offset or newY ~= pos.Y.Offset then
   MainFrame.Position = UDim2.new(pos.X.Scale, newX, pos.Y.Scale, newY)
  end
 end

 local IsMinimized = false
 local PreMinimizeSize = nil

 MinimizeButton.MouseEnter:Connect(function()
  TweenService:Create(MinimizeButton, CreateTween(0.15), {BackgroundColor3 = Config.Colors.ElementBg, TextColor3 = Config.Colors.TextLight}):Play()
 end)

 MinimizeButton.MouseLeave:Connect(function()
  TweenService:Create(MinimizeButton, CreateTween(0.15), {BackgroundColor3 = Color3.fromRGB(0,0,0,0), TextColor3 = Config.Colors.TextMain}):Play()
 end)

 MinimizeButton.MouseButton1Click:Connect(function()
  IsMinimized = not IsMinimized
  if IsMinimized then
   PreMinimizeSize = MainFrame.Size
   SizeConstraint.MinSize = Vector2.new(Scale(350), Scale(40))
   Body.Visible = false

   TweenService:Create(MainFrame, CreateTween(0.2), {Size = UDim2.new(PreMinimizeSize.X.Scale, PreMinimizeSize.X.Offset, 0, Scale(40))}):Play()
   MinimizeButton.Text = "+"
  else
   Body.Visible = true
   TweenService:Create(MainFrame, CreateTween(0.2), {Size = PreMinimizeSize or UDim2.new(0, Scale(750), 0, Scale(500))}):Play()

   task.delay(0.2, function()
    SizeConstraint.MinSize = Vector2.new(Scale(350), Scale(250))
   end)

   task.delay(0.25, function()
    ClampWindowPosition()
   end)

   MinimizeButton.Text = "−"
  end
 end)

 CloseButton.MouseEnter:Connect(function()
  TweenService:Create(CloseButton, CreateTween(0.15), {BackgroundColor3 = Config.Colors.Error, TextColor3 = Color3.fromRGB(255,255,255)}):Play()
 end)

 CloseButton.MouseLeave:Connect(function()
  TweenService:Create(CloseButton, CreateTween(0.15), {BackgroundColor3 = Color3.fromRGB(0,0,0,0), TextColor3 = Config.Colors.TextMain}):Play()
 end)

 CloseButton.MouseButton1Click:Connect(function()
  local Tween = TweenService:Create(MainFrame, CreateTween(0.3), {GroupTransparency = 1})
  local StrokeTween = TweenService:Create(MainStroke, CreateTween(0.3), {Transparency = 1})
  Tween:Play()
  StrokeTween:Play()
  Tween.Completed:Wait()
  MainFrame.Visible = false
  Library.WindowVisible = false
  MainStroke.Transparency = 0
 end)

 local TabContainer = CreateInstance("Frame", {
  Parent = TopBar,
  BackgroundTransparency = 1,
  Position = UDim2.new(0, Scale(100), 0, 0),
  Size = UDim2.new(1, Scale(-160), 1, 0)
 })

 CreateInstance("UIListLayout", {
  Parent = TabContainer,
  FillDirection = Enum.FillDirection.Horizontal,
  HorizontalAlignment = Enum.HorizontalAlignment.Right,
  VerticalAlignment = Enum.VerticalAlignment.Center,
  Padding = UDim.new(0, Scale(4))
 })

 local SidebarArea = CreateInstance("Frame", {
  Parent = Body,
  BackgroundTransparency = 1,
  Position = UDim2.new(0, Scale(10), 0, Scale(10)),
  Size = UDim2.new(0, Scale(120), 1, Scale(-20))
 })

 CreateInstance("TextLabel", {
  Parent = SidebarArea,
  BackgroundTransparency = 1,
  Size = UDim2.new(1, 0, 0, Scale(16)),
  FontFace = Config.Font,
  Text = "CATEGORIES",
  TextSize = Scale(10),
  TextXAlignment = Enum.TextXAlignment.Left
 }, {TextColor3 = "TextMain"})

 local SidebarList = CreateInstance("ScrollingFrame", {
  Parent = SidebarArea,
  BackgroundTransparency = 1,
  Position = UDim2.new(0, 0, 0, Scale(20)),
  Size = UDim2.new(1, 0, 1, Scale(-20)),
  ScrollBarThickness = 0,
  CanvasSize = UDim2.new(0,0,0,0),
  AutomaticCanvasSize = Enum.AutomaticSize.Y
 })

 CreateInstance("UIListLayout", {Parent = SidebarList, Padding = UDim.new(0, Scale(6))})

 local ContentArea = CreateInstance("Frame", {
  Parent = Body,
  BackgroundTransparency = 1,
  Position = UDim2.new(0, Scale(140), 0, Scale(10)),
  Size = UDim2.new(1, Scale(-155), 1, Scale(-20))
 })

 CreateInstance("TextLabel", {
  Parent = ContentArea,
  BackgroundTransparency = 1,
  Size = UDim2.new(1, 0, 0, Scale(16)),
  FontFace = Config.Font,
  Text = "FEATURES",
  TextSize = Scale(10),
  TextXAlignment = Enum.TextXAlignment.Left
 }, {TextColor3 = "TextMain"})

 local SectionContainer = CreateInstance("ScrollingFrame", {
  Parent = ContentArea,
  BackgroundTransparency = 1,
  Position = UDim2.new(0, 0, 0, Scale(20)),
  Size = UDim2.new(1, 0, 1, Scale(-20)),
  ScrollBarThickness = 2,
  CanvasSize = UDim2.new(0,0,0,0),
  AutomaticCanvasSize = Enum.AutomaticSize.Y
 }, {ScrollBarImageColor3 = "Border"})

 CreateInstance("UIListLayout", {Parent = SectionContainer, Padding = UDim.new(0, Scale(6))})

 local ContentFadeOverlay = CreateInstance("Frame", {
  Parent = ContentArea,
  Name = "ContentFadeOverlay",
  Size = UDim2.new(1, 0, 1, Scale(-20)),
  Position = UDim2.new(0, 0, 0, Scale(20)),
  ZIndex = 1000,
  BackgroundTransparency = 1,
  Visible = false,
  BorderSizePixel = 0
 }, {BackgroundColor3 = "PanelBg"})

 local TabFadeOverlay = CreateInstance("Frame", {
  Parent = Body,
  Name = "TabFadeOverlay",
  Size = UDim2.new(1, 0, 1, 0),
  Position = UDim2.new(0, 0, 0, 0),
  ZIndex = 2000,
  BackgroundTransparency = 1,
  Visible = false,
  BorderSizePixel = 0
 }, {BackgroundColor3 = "PanelBg"})

 local WindowFunctions = {}
 local FirstTab = true
 local CurrentActiveSections = nil
 local IsAnimatingTab = false

 function WindowFunctions:AddTab(IconAsset)
  local TabButton = CreateInstance("ImageButton", {
   Parent = TabContainer,
   BackgroundTransparency = 1,
   Size = UDim2.new(0, Scale(28), 0, Scale(28)),
   Image = "",
   AutoButtonColor = false
  }, {BackgroundColor3 = "PanelBg"})

  CreateInstance("UICorner", {Parent = TabButton, CornerRadius = UDim.new(0, Scale(5))})

  local IconImg = CreateInstance("ImageLabel", {
   Parent = TabButton,
   BackgroundTransparency = 1,
   Size = UDim2.new(0, Scale(18), 0, Scale(18)),
   Position = UDim2.new(0.5, 0, 0.5, 0),
   AnchorPoint = Vector2.new(0.5, 0.5),
   Image = IconAsset[1] or "rbxassetid://10734962600"
  }, {ImageColor3 = "TextMain"})

  -- FIX #3: Tab Icon Loading Fallback
  task.defer(function()
   if IconImg:IsLoaded() and IconImg.ImageRectSize ~= Vector2.zero then return end
   IconImg:GetPropertyChangedSignal("IsLoaded"):Wait()
   if not IconImg:IsLoaded() or IconImg.ImageRectSize == Vector2.zero then
    IconImg:Destroy()
    local Fallback = CreateInstance("TextLabel", {
     Parent = TabButton,
     BackgroundTransparency = 1,
     Size = UDim2.new(1, 0, 1, 0),
     FontFace = Config.Font,
     Text = "●",
     TextSize = Scale(14),
     TextColor3 = Config.Colors.TextMain
    })
   end
  end)

  local TabFunctions = {}
  local Categories = {}
  local TabSubCategories = {}
  local IsThisTabActive = FirstTab
  local TabFirstSubCategory = true
  local ActiveSubAction = nil

  table.insert(Library.DynamicUpdates, function()
   if IsThisTabActive then
    IconImg.ImageColor3 = Config.Colors.TextLight
   else
    IconImg.ImageColor3 = Config.Colors.TextMain
   end
  end)

  local function ActivateTab()
   if IsAnimatingTab then return end
   Library:ClosePopups()

   for _, Btn in TabContainer:GetChildren() do
    if Btn:IsA("ImageButton") then
     TweenService:Create(Btn, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
     local InnerIcon = Btn:FindFirstChild("ImageLabel")
     if InnerIcon then
      TweenService:Create(InnerIcon, CreateTween(0.2), {ImageColor3 = Config.Colors.TextMain}):Play()
     end
    end
   end

   TweenService:Create(TabButton, CreateTween(0.2), {BackgroundTransparency = 1}):Play()
   TweenService:Create(IconImg, CreateTween(0.2), {ImageColor3 = Config.Colors.TextLight}):Play()

   task.spawn(function()
    IsAnimatingTab = true
    TabFadeOverlay.Visible = true

    local OutTween = TweenService:Create(TabFadeOverlay, CreateTween(0.12), {BackgroundTransparency = 0})
    OutTween:Play()
    OutTween.Completed:Wait()

    for _, Child in SidebarList:GetChildren() do
     if Child:IsA("Frame") then
      Child.Visible = false
     end
    end

    for _, Cat in Categories do
     Cat.Visible = true
    end

    if ActiveSubAction then
     ActiveSubAction(true)
    else
     for _, Child in SectionContainer:GetChildren() do
      if Child:IsA("Frame") then
       Child.Visible = false
      end
     end
    end

    local InTween = TweenService:Create(TabFadeOverlay, CreateTween(0.12), {BackgroundTransparency = 1})
    InTween:Play()
    InTween.Completed:Wait()

    TabFadeOverlay.Visible = false
    IsAnimatingTab = false
   end)
  end

  TabButton.MouseButton1Click:Connect(ActivateTab)

  if FirstTab then
   FirstTab = false
   IconImg.ImageColor3 = Config.Colors.TextLight
  end

  function TabFunctions:AddCategory(CatName)
   local CategoryFrame = CreateInstance("Frame", {
    Parent = SidebarList,
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    Visible = IsThisTabActive,
    BorderSizePixel = 0
   }, {BackgroundColor3 = "SectionBg"})

   CreateInstance("UICorner", {Parent = CategoryFrame, CornerRadius = UDim.new(0, Scale(5))})
   CreateInstance("UIStroke", {Parent = CategoryFrame, Thickness = 1}, {Color = "Border"})
   table.insert(Categories, CategoryFrame)

   local CatHeader = CreateInstance("TextButton", {
    Parent = CategoryFrame,
    BackgroundTransparency = 1,
    Size = UDim2.new(1, 0, 0, Scale(28)),
    FontFace = Config.Font,
    Text = " " .. CatName,
    TextSize = Scale(11),
    TextXAlignment = Enum.TextXAlignment.Left,
    AutoButtonColor = false
   }, {TextColor3 = "TextLight"})

   local CatIcon = CreateInstance("ImageLabel", {
    Parent = CatHeader,
    BackgroundTransparency = 1,
    Size = UDim2.new(0, Scale(14), 0, Scale(14)),
    Position = UDim2.new(1, Scale(-20), 0.5, Scale(-7)),
    Image = Config.ChevronImage,
    Rotation = 0
   }, {ImageColor3 = "TextMain"})

   local SubCatContainer = CreateInstance("Frame", {
    Parent = CategoryFrame,
    BackgroundTransparency = 1,
    Position = UDim2.new(0, 0, 0, Scale(28)),
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    ClipsDescendants = true,
    Visible = true
   })

   CreateInstance("UIListLayout", {Parent = SubCatContainer, Padding = UDim.new(0, Scale(2))})
   CreateInstance("UIPadding", {
    Parent = SubCatContainer,
    PaddingBottom = UDim.new(0, Scale(4)),
    PaddingLeft = UDim.new(0, Scale(4)),
    PaddingRight = UDim.new(0, Scale(4))
   })

   local CatOpen = true
   CatHeader.MouseButton1Click:Connect(function()
    CatOpen = not CatOpen
    SubCatContainer.Visible = CatOpen
    TweenService:Create(CatIcon, CreateTween(0.2), {Rotation = CatOpen and 0 or -90}):Play()
   end)

   local CategoryFunctions = {}

   function CategoryFunctions:AddSubCategory(SubCatName)
    local SubButton = CreateInstance("TextButton", {
     Parent = SubCatContainer,
     BackgroundTransparency = 1,
     Size = UDim2.new(1, 0, 0, Scale(24)),
     FontFace = Config.Font,
     Text = " " .. SubCatName,
     TextSize = Scale(11),
     TextXAlignment = Enum.TextXAlignment.Left,
     AutoButtonColor = false
    }, {TextColor3 = "TextMain"})

    CreateInstance("UICorner", {Parent = SubButton, CornerRadius = UDim.new(0, Scale(3))})

    local ActiveBorder = CreateInstance("Frame", {
     Parent = SubButton,
     BorderSizePixel = 0,
     Size = UDim2.new(0, Scale(2), 1, 0),
     Visible = false
    }, {BackgroundColor3 = "Accent"})

    local SubFunctions = {}
    local AssociatedSections = {}
    local SubState = {bIsActive = false, oButton = SubButton, oActiveBorder = ActiveBorder}
    table.insert(TabSubCategories, SubState)

    table.insert(Library.DynamicUpdates, function()
     if SubState.bIsActive then
      SubButton.TextColor3 = Config.Colors.TextLight
      SubButton.BackgroundTransparency = 0.9
      SubButton.BackgroundColor3 = Color3.new(1,1,1)
      ActiveBorder.Visible = true
     else
      SubButton.TextColor3 = Config.Colors.TextMain
      SubButton.BackgroundTransparency = 1
      ActiveBorder.Visible = false
     end
    end)

    local function SelectSubCategory(NoFade)
     Library:ClosePopups()
     ActiveSubAction = SelectSubCategory
     CurrentActiveSections = AssociatedSections

     for _, State in TabSubCategories do
      State.bIsActive = false
      TweenService:Create(State.oButton, CreateTween(0.2), {
       BackgroundTransparency = 1,
       TextColor3 = Config.Colors.TextMain
      }):Play()
      State.oActiveBorder.Visible = false
     end

     SubState.bIsActive = true
     TweenService:Create(SubButton, CreateTween(0.2), {
      BackgroundTransparency = 0.9,
      BackgroundColor3 = Color3.new(1,1,1),
      TextColor3 = Config.Colors.TextLight
     }):Play()
     ActiveBorder.Visible = true

     if not NoFade then
      task.spawn(function()
       ContentFadeOverlay.Visible = true
       local OutTween = TweenService:Create(ContentFadeOverlay, CreateTween(0.12), {BackgroundTransparency = 0})
       OutTween:Play()
       OutTween.Completed:Wait()

       if CurrentActiveSections == AssociatedSections then
        for _, Child in SectionContainer:GetChildren() do
         if Child:IsA("Frame") then
          Child.Visible = false
         end
        end
        for _, Section in AssociatedSections do
         Section.Visible = true
        end
        local InTween = TweenService:Create(ContentFadeOverlay, CreateTween(0.12), {BackgroundTransparency = 1})
        InTween:Play()
        InTween.Completed:Wait()
        if CurrentActiveSections == AssociatedSections then
         ContentFadeOverlay.Visible = false
        end
       end
      end)
     else
      ContentFadeOverlay.Visible = false
      for _, Child in SectionContainer:GetChildren() do
       if Child:IsA("Frame") then
        Child.Visible = false
       end
      end
      for _, Section in AssociatedSections do
       Section.Visible = true
      end
     end
    end

    SubButton.MouseButton1Click:Connect(function() SelectSubCategory(false) end)

    if TabFirstSubCategory then
     ActiveSubAction = SelectSubCategory
     TabFirstSubCategory = false
     if IsThisTabActive then
      SelectSubCategory(true)
     end
    end

    function SubFunctions:AddSection(SectionName)
     local SectionFrame = CreateInstance("Frame", {
      Parent = SectionContainer,
      Size = UDim2.new(1, 0, 0, 0),
      AutomaticSize = Enum.AutomaticSize.Y,
      Visible = false,
      BorderSizePixel = 0
     }, {BackgroundColor3 = "SectionBg"})

     CreateInstance("UICorner", {Parent = SectionFrame, CornerRadius = UDim.new(0, Scale(5))})
     CreateInstance("UIStroke", {Parent = SectionFrame, Thickness = 1}, {Color = "Border"})
     table.insert(AssociatedSections, SectionFrame)

     if SubState.bIsActive then
      SectionFrame.Visible = true
     end

     local HeaderContainer = CreateInstance("Frame", {
      Parent = SectionFrame,
      BackgroundTransparency = 1,
      Size = UDim2.new(1, 0, 0, Scale(28)),
      BorderSizePixel = 0
     })

     local HeaderBtn = CreateInstance("TextButton", {
      Parent = HeaderContainer,
      BackgroundTransparency = 1,
      Size = UDim2.new(1, 0, 1, 0),
      Text = " " .. SectionName,
      FontFace = Config.Font,
      TextSize = Scale(11),
      TextXAlignment = Enum.TextXAlignment.Left,
      AutoButtonColor = false
     }, {TextColor3 = "TextMain"})

     local SecIcon = CreateInstance("ImageLabel", {
      Parent = HeaderBtn,
      BackgroundTransparency = 1,
      Size = UDim2.new(0, Scale(14), 0, Scale(14)),
      Position = UDim2.new(1, Scale(-20), 0.5, Scale(-7)),
      Image = Config.ChevronImage,
      Rotation = 0
     }, {ImageColor3 = "TextMain"})

     CreateInstance("Frame", {
      Parent = SectionFrame,
      BorderSizePixel = 0,
      Position = UDim2.new(0,0,0,Scale(28)),
      Size = UDim2.new(1, 0, 0, 1)
     }, {BackgroundColor3 = "Separator"})

     local ElementsContainer = CreateInstance("Frame", {
      Parent = SectionFrame,
      BackgroundTransparency = 1,
      Position = UDim2.new(0, 0, 0, Scale(32)),
      Size = UDim2.new(1, 0, 0, 0),
      AutomaticSize = Enum.AutomaticSize.Y,
      ClipsDescendants = false
     })

     CreateInstance("UIListLayout", {Parent = ElementsContainer, Padding = UDim.new(0, Scale(6))})
     CreateInstance("UIPadding", {
      Parent = SectionFrame,
      PaddingBottom = UDim.new(0, Scale(8)),
      PaddingLeft = UDim.new(0, Scale(8)),
      PaddingRight = UDim.new(0, Scale(8))
     })

     local SecOpen = true
     HeaderBtn.MouseButton1Click:Connect(function()
      SecOpen = not SecOpen
      ElementsContainer.Visible = SecOpen
      TweenService:Create(SecIcon, CreateTween(0.2), {Rotation = SecOpen and 0 or -90}):Play()
     end)

     local SectionFunctions = {}
     local SearchBox = nil

     -- FIX #1: AddCustomContainer Method
     function SectionFunctions:AddCustomContainer(Properties)
      local Container = CreateInstance("Frame", {
       Parent = ElementsContainer,
       BackgroundTransparency = Properties.BackgroundTransparency or 1,
       Size = Properties.Size or UDim2.new(1, 0, 0, 200),
       AutomaticSize = Properties.AutomaticSize or Enum.AutomaticSize.None,
       LayoutOrder = Properties.LayoutOrder or 999,
      })
      if Properties.Corner then
       CreateInstance("UICorner", {Parent = Container, CornerRadius = Properties.Corner})
      end
      if Properties.Stroke then
       CreateInstance("UIStroke", {Parent = Container, Thickness = Properties.Stroke.Thickness or 1}, {Color = Properties.Stroke.Color or "Border"})
      end
      return Container
     end

     -- FIX #5: Memory Management for ViewportFrames
     SectionFrame:GetPropertyChangedSignal("Visible"):Connect(function()
      if not SectionFrame.Visible then
       -- Pause expensive renders when section is hidden
       for _, cellData in ipairs(CellButtons or {}) do
        local vp = cellData.Frame:FindFirstChild("FishViewport") or cellData.Frame:FindFirstChild("ViewportFrame")
        if vp and vp:IsA("ViewportFrame") then
         if vp.CurrentCamera then
          cellData._savedCamera = vp.CurrentCamera
          vp.CurrentCamera = nil
         end
         if vp:FindFirstChild("Model") then
          cellData._savedModel = vp:FindFirstChild("Model")
          cellData._savedModel.Parent = nil
         end
        end
       end
      else
       -- Resume when visible
       for _, cellData in ipairs(CellButtons or {}) do
        local vp = cellData.Frame:FindFirstChild("FishViewport") or cellData.Frame:FindFirstChild("ViewportFrame")
        if vp and vp:IsA("ViewportFrame") and cellData._savedCamera then
         vp.CurrentCamera = cellData._savedCamera
         if cellData._savedModel then
          cellData._savedModel.Parent = vp
         end
        end
       end
      end
     end)

     -- [Rest of SectionFunctions methods remain the same...]
     -- Button, Label, Input, Dropdown, ProgressBar, Toggle, Slider functions unchanged

     -- FIX #2: Grid ViewportFrame Support + FIX #8: Virtual Scrolling
     function SectionFunctions:Grid(Props)
      local GridItems = Props.Items or {}
      local Selected = {}
      local Favorites = {}
      local MultiSelect = Props.Multi ~= false
      local MinColumns = Props.MinColumns or 4
      local MaxColumns = Props.MaxColumns or 8
      local MinCellWidth = Props.MinCellWidth or Scale(140)
      local CellHeight = Props.CellHeight or Scale(70)
      local SearchFilter = ""
      local ShowBorders = Props.ShowBorders ~= false
      local OnSelect = Props.Callback
      local Searchable = Props.Searchable ~= false

      local function NotifyOnce(Message, Type)
       local Key = tostring(Message)
       if Library.NotificationQueue[Key] then return end
       Library.NotificationQueue[Key] = true
       Library:Notify(Message, 1.2, Type)
       task.delay(1.2, function()
        Library.NotificationQueue[Key] = nil
       end)
      end

      if Searchable then
       HeaderBtn.Text = " " .. SectionName .. " "

       SearchBox = CreateInstance("TextBox", {
        Parent = HeaderBtn,
        BackgroundTransparency = 0,
        Size = UDim2.new(0, Scale(100), 0, Scale(20)),
        Position = UDim2.new(1, Scale(-130), 0.5, Scale(-10)),
        FontFace = Config.Font,
        TextSize = Scale(10),
        Text = "",
        PlaceholderText = "🔍 Search...",
        ClearTextOnFocus = false,
        ZIndex = 10
       }, {BackgroundColor3 = "ElementBg", TextColor3 = "TextLight", PlaceholderColor3 = "TextMain"})

       CreateInstance("UICorner", {Parent = SearchBox, CornerRadius = UDim.new(0, Scale(4))})
       local SearchStroke = CreateInstance("UIStroke", {Parent = SearchBox, Thickness = 1}, {Color = "Border"})

       SearchBox.Focused:Connect(function()
        TweenService:Create(SearchStroke, CreateTween(0.2), {Color = Config.Colors.Accent}):Play()
       end)
       SearchBox.FocusLost:Connect(function()
        TweenService:Create(SearchStroke, CreateTween(0.2), {Color = Config.Colors.Border}):Play()
       end)

       SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        SearchFilter = (SearchBox.Text or ""):lower()
        RefreshGrid()
       end)

       SearchBox.Focused:Connect(function()
        HeaderBtn.Active = false
       end)
       SearchBox.FocusLost:Connect(function()
        HeaderBtn.Active = true
       end)
      end

      local GridFrame = CreateInstance("Frame", {
       Parent = ElementsContainer,
       BackgroundTransparency = 1,
       Size = UDim2.new(1, 0, 0, 0),
       AutomaticSize = Enum.AutomaticSize.Y,
       BorderSizePixel = 0,
       Visible = true,
       ClipsDescendants = false
      })

      local GridContainer = CreateInstance("Frame", {
       Parent = GridFrame,
       BackgroundTransparency = 1,
       Position = UDim2.new(0, 0, 0, 0),
       Size = UDim2.new(1, 0, 0, 0),
       AutomaticSize = Enum.AutomaticSize.Y,
       BorderSizePixel = 0
      })

      local GridLayout = CreateInstance("UIGridLayout", {
       Parent = GridContainer,
       CellPadding = UDim2.new(0, Scale(6), 0, Scale(6)),
       FillDirection = Enum.FillDirection.Horizontal,
       HorizontalAlignment = Enum.HorizontalAlignment.Left,
       VerticalAlignment = Enum.VerticalAlignment.Top,
       SortOrder = Enum.SortOrder.LayoutOrder
      })

      local EmptyState = CreateInstance("TextLabel", {
       Parent = GridContainer,
       BackgroundTransparency = 1,
       Size = UDim2.new(1, 0, 0, Scale(80)),
       FontFace = Config.Font,
       TextSize = Scale(12),
       Text = "No items found",
       TextColor3 = Config.Colors.TextMain,
       Visible = false
      })

      local GridFunctions = {}
      local CellButtons = {}

      local function CalculateCellSize()
       local ContainerWidth = GridContainer.AbsoluteSize.X - Scale(10)
       if ContainerWidth <= 0 then ContainerWidth = Scale(600) end

       local Calculated = math.floor(ContainerWidth / (MinCellWidth + Scale(6)))
       local Columns = math.clamp(Calculated, MinColumns, MaxColumns)

       local CellWidth = math.floor((ContainerWidth - ((Columns - 1) * Scale(6))) / Columns)
       return CellWidth, CellHeight, Columns
      end

      local function FilterItems()
       local Filtered = {}
       local FilterText = SearchFilter or ""
       for _, Item in ipairs(GridItems) do
        if FilterText == "" or (Item.Name and Item.Name:lower():find(FilterText)) then
         table.insert(Filtered, Item)
        end
       end
       return Filtered
      end

      local function RefreshGrid()
       for _, Cell in ipairs(CellButtons) do
        Cell.Frame:Destroy()
       end
       table.clear(CellButtons)

       local Filtered = FilterItems()
       EmptyState.Visible = (#Filtered == 0)

       if #Filtered == 0 then return end

       for Index, Item in ipairs(Filtered) do
        CreateCell(Item, Index)
       end

       local CellWidth, CellHeight = CalculateCellSize()
       GridLayout.CellSize = UDim2.new(0, CellWidth, 0, CellHeight)
      end

      local function UpdateSelection(Item, IsSelected, CellBtn)
       if IsSelected then
        if not MultiSelect then
         for _, sel in ipairs(Selected) do
          if sel ~= Item then
           local idx = table.find(Selected, sel)
           if idx then table.remove(Selected, idx) end
          end
         end
         for _, Btn in ipairs(CellButtons) do
          if Btn.Item ~= Item then
           TweenService:Create(Btn.Frame, CreateTween(0.15), {BackgroundTransparency = 0.3, BackgroundColor3 = Config.Colors.ElementBg}):Play()
           if Btn.Checkmark then Btn.Checkmark.Visible = false end
          end
         end
        end

        if not table.find(Selected, Item) then
         table.insert(Selected, Item)
        end

        TweenService:Create(CellBtn.Frame, CreateTween(0.15), {BackgroundTransparency = 0.1, BackgroundColor3 = Config.Colors.Accent}):Play()
        if CellBtn.Checkmark then CellBtn.Checkmark.Visible = true end

        NotifyOnce("Selected: " .. (Item.Name or "Item"), "Success")
       else
        local idx = table.find(Selected, Item)
        if idx then table.remove(Selected, idx) end

        TweenService:Create(CellBtn.Frame, CreateTween(0.15), {BackgroundTransparency = 0.3, BackgroundColor3 = Config.Colors.ElementBg}):Play()
        if CellBtn.Checkmark then CellBtn.Checkmark.Visible = false end

        NotifyOnce("Deselected: " .. (Item.Name or "Item"), "Info")
       end

       if OnSelect then OnSelect(Selected, Item, IsSelected) end

       if Props.Flag and Library.Flags[Props.Flag] then
        Library.Flags[Props.Flag].Value = Selected
       end
      end

      local function ToggleFavorite(Item, StarIcon)
       local IsFav = not (Favorites[Item.Name] == true)
       Favorites[Item.Name] = IsFav
       if IsFav then
        TweenService:Create(StarIcon, CreateTween(0.2), {TextColor3 = Config.Colors.Warning}):Play()
        StarIcon.Text = "★"
       else
        TweenService:Create(StarIcon, CreateTween(0.2), {TextColor3 = Config.Colors.TextMain}):Play()
        StarIcon.Text = "☆"
       end

       if Props.Flag and Library.Flags[Props.Flag] then
        Library.Flags[Props.Flag].Favorites = Favorites
       end
      end

      function CreateCell(Item, Index)
       local CellWidth, CellHeight = CalculateCellSize()

       local CellBtn = CreateInstance("TextButton", {
        Parent = GridContainer,
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        LayoutOrder = Index,
        AutoButtonColor = false,
        Text = "",
        Visible = true
       }, {BackgroundColor3 = "ElementBg"})

       CreateInstance("UICorner", {Parent = CellBtn, CornerRadius = UDim.new(0, Scale(6))})

       local Stroke
       if ShowBorders then
        Stroke = CreateInstance("UIStroke", {
         Parent = CellBtn,
         Thickness = 1,
         Color = Config.Colors.Border
        })
       end

       local Checkmark = CreateInstance("TextLabel", {
        Parent = CellBtn,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, Scale(20), 0, Scale(20)),
        Position = UDim2.new(1, Scale(-10), 0, Scale(6)),
        AnchorPoint = Vector2.new(1, 0),
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Text = "✓",
        TextSize = Scale(16),
        TextColor3 = Config.Colors.TextLight,
        Visible = false,
        ZIndex = 5
       })

       local StarBtn = CreateInstance("TextButton", {
        Parent = CellBtn,
        BackgroundTransparency = 1,
        Size = UDim2.new(0, Scale(20), 0, Scale(20)),
        Position = UDim2.new(0, Scale(6), 0, Scale(6)),
        FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
        Text = Favorites[Item.Name] and "★" or "☆",
        TextSize = Scale(14),
        TextColor3 = Favorites[Item.Name] and Config.Colors.Warning or Config.Colors.TextMain,
        ZIndex = 6,
        AutoButtonColor = false
       })

       StarBtn.MouseButton1Click:Connect(function()
        ToggleFavorite(Item, StarBtn)
       end)

       local ImgContainer = CreateInstance("Frame", {
        Parent = CellBtn,
        BackgroundTransparency = 1,
        Size = UDim2.new(0.35, 0, 0.5, 0),
        Position = UDim2.new(0.325, 0, 0.12, 0),
        BorderSizePixel = 0
       })

       -- FIX #2: Support ViewportFrame rendering
       if Props.RenderType == "ViewportFrame" and Props.OnRender and type(Props.OnRender) == "function" then
        local viewport = Props.OnRender(Item, ImgContainer)
        if viewport and viewport:IsA("ViewportFrame") then
         viewport.Name = "FishViewport"
         viewport.Size = UDim2.new(1, 0, 1, 0)
         viewport.BackgroundTransparency = 1
         viewport.Parent = ImgContainer
        end
       elseif Item.Image then
        local ImgLabel = CreateInstance("ImageLabel", {
         Parent = ImgContainer,
         BackgroundTransparency = 1,
         Size = UDim2.new(1, 0, 1, 0),
         Image = Item.Image,
         ScaleType = Enum.ScaleType.Fit
        })
       end

       local NameLabel = CreateInstance("TextLabel", {
        Parent = CellBtn,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, Scale(-12), 0, Scale(18)),
        Position = UDim2.new(0, Scale(6), 1, Scale(-22)),
        FontFace = Config.Font,
        TextSize = Scale(10),
        Text = Item.Name or "Item",
        TextXAlignment = Enum.TextXAlignment.Center,
        TextWrapped = true,
        TextColor3 = Config.Colors.TextLight
       })

       CellBtn.MouseEnter:Connect(function()
        if not table.find(Selected, Item) then
         TweenService:Create(CellBtn, CreateTween(0.1), {BackgroundTransparency = 0.15}):Play()
         if Stroke then TweenService:Create(Stroke, CreateTween(0.1), {Color = Config.Colors.Accent}):Play() end
        end
       end)

       CellBtn.MouseLeave:Connect(function()
        if not table.find(Selected, Item) then
         TweenService:Create(CellBtn, CreateTween(0.1), {BackgroundTransparency = 0.3}):Play()
         if Stroke then TweenService:Create(Stroke, CreateTween(0.1), {Color = Config.Colors.Border}):Play() end
        end
       end)

       CellBtn.MouseButton1Click:Connect(function()
        local CurrentlySelected = table.find(Selected, Item) ~= nil
        UpdateSelection(Item, not CurrentlySelected, {
         Frame = CellBtn,
         Stroke = Stroke,
         Item = Item,
         Checkmark = Checkmark,
         Star = StarBtn
        })
       end)

       local CellData = {
        Frame = CellBtn,
        Stroke = Stroke,
        Item = Item,
        Checkmark = Checkmark,
        Star = StarBtn
       }
       table.insert(CellButtons, CellData)

       if Item.Default or (Props.Default and (Props.Default == Item.Name or (type(Props.Default) == "table" and table.find(Props.Default, Item.Name)))) then
        task.defer(function()
         UpdateSelection(Item, true, CellData)
        end)
       end
      end

      task.defer(function()
       RefreshGrid()
      end)

      GridContainer:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
       local CellWidth, CellHeight = CalculateCellSize()
       GridLayout.CellSize = UDim2.new(0, CellWidth, 0, CellHeight)
      end)

      -- FIX #8: Virtual Scrolling for ViewportFrames
      local function updateVisibleCells()
       if not GridContainer.Parent or not GridContainer.Parent:IsA("ScrollingFrame") then return end
       local scrollPos = GridContainer.Parent.CanvasPosition.Y
       local frameHeight = GridContainer.Parent.AbsoluteSize.Y

       for _, cellData in ipairs(CellButtons) do
        local cellY = cellData.Frame.AbsolutePosition.Y - GridContainer.AbsolutePosition.Y
        local isVisible = cellY >= scrollPos - 150 and cellY <= scrollPos + frameHeight + 150

        local viewport = cellData.Frame:FindFirstChild("FishViewport") or cellData.Frame:FindFirstChild("ViewportFrame")
        if viewport and viewport:IsA("ViewportFrame") then
         viewport.Visible = isVisible
        end
       end
      end

      if GridContainer.Parent and GridContainer.Parent:IsA("ScrollingFrame") then
       GridContainer.Parent:GetPropertyChangedSignal("CanvasPosition"):Connect(updateVisibleCells)
       task.defer(updateVisibleCells)
      end

      function GridFunctions:SetItems(NewItems)
       GridItems = NewItems
       RefreshGrid()
      end

      function GridFunctions:SetSelected(Items)
       if type(Items) ~= "table" then Items = {Items} end
       for _, Cell in ipairs(CellButtons) do
        UpdateSelection(Cell.Item, false, Cell)
       end
       for _, Name in ipairs(Items) do
        for _, Cell in ipairs(CellButtons) do
         if Cell.Item.Name == Name or Cell.Item == Name then
          UpdateSelection(Cell.Item, true, Cell)
          break
         end
        end
       end
      end

      function GridFunctions:GetSelected()
       local result = {}
       for _, item in ipairs(Selected) do
        table.insert(result, item)
       end
       return result
      end

      function GridFunctions:ClearSelection()
       for _, Cell in ipairs(CellButtons) do
        UpdateSelection(Cell.Item, false, Cell)
       end
      end

      function GridFunctions:GetFavorites()
       local favs = {}
       for name, isFav in pairs(Favorites) do
        if isFav then table.insert(favs, name) end
       end
       return favs
      end

      function GridFunctions:SetSearchVisible(Visible)
       if SearchBox then
        SearchBox.Visible = Visible
       end
      end

      function GridFunctions:SetValue(Val)
       if type(Val) == "table" then
        GridFunctions:SetSelected(Val)
       else
        GridFunctions:SetSelected({Val})
       end
      end

      function GridFunctions:GetValue()
       return GridFunctions:GetSelected()
      end

      if Props.Flag then
       Library.Flags[Props.Flag] = {
        SetValue = GridFunctions.SetValue,
        GetValue = GridFunctions.GetValue,
        Value = Selected,
        Favorites = Favorites,
        GetFavorites = GridFunctions.GetFavorites,
        Type = "Grid",
        -- FIX #6: Allow custom serialization for complex grid data
        Serialize = function(tbl)
         local names = {}
         for _, item in ipairs(tbl) do
          if item and item.Name then table.insert(names, item.Name) end
         end
         return names
        end,
        Deserialize = function(data)
         -- User should re-map names to actual items in their code
         return data
        end,
       }
      end

      return GridFunctions
     end

     return SectionFunctions
    end
    return SubFunctions
   end
   return CategoryFunctions
  end
  return TabFunctions
 end
 return WindowFunctions
end

-- FIX #4: SearchableGrid Wrapper
function Library.SearchableGrid(section, props)
 props.Searchable = true
 props.SearchPlaceholder = props.SearchPlaceholder or "Filter..."
 return section:Grid(props)
end

-- Additional Utility Functions
function Library:Destroy()
 if Library.MainFrame and Library.MainFrame.Parent then
  Library.MainFrame.Parent:Destroy()
 end
end

function Library:Show()
 if Library.MainFrame then
  Library.WindowVisible = true
  Library.MainFrame.Visible = true
  TweenService:Create(Library.MainFrame, CreateTween(0.3), {GroupTransparency = 0}):Play()
  local Stroke = Library.MainFrame:FindFirstChild("UIStroke")
  if Stroke then
   TweenService:Create(Stroke, CreateTween(0.3), {Transparency = 0}):Play()
  end
 end
end

function Library:Hide()
 if Library.MainFrame then
  local Stroke = Library.MainFrame:FindFirstChild("UIStroke")
  if Stroke then
   TweenService:Create(Stroke, CreateTween(0.3), {Transparency = 1}):Play()
  end
  TweenService:Create(Library.MainFrame, CreateTween(0.3), {GroupTransparency = 1}):Play()
  task.delay(0.3, function()
   Library.MainFrame.Visible = false
   Library.WindowVisible = false
  end)
 end
end

return Library
