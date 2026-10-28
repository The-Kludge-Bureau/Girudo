local ADDON, ns = ...

-- ===========================================================================
-- 1. Early definitions (must exist before any tab OnClick can fire)
-- ===========================================================================
ns.pages = {}
ns.activePage = 0

function ns.ShowPage(index)
  if ns.activePage == index then
    return
  end
  ns.activePage = index
  for i, page in ipairs(ns.pages) do
    if i == index then
      page:Show()
    else
      page:Hide()
    end
  end
  if _G.GirudoFrame and _G.GirudoFrame.selectedTab ~= index then
    PanelTemplates_SetTab(_G.GirudoFrame, index)
  end
  if ns.Girudo and ns.Girudo.UpdateHeader then
    ns.Girudo:UpdateHeader()
  end
  -- NEW: refresh the log when its tab is opened.
  if index == 1 and ns.Girudo then
    if ns.Girudo.ScanGuildLog then
      ns.Girudo:ScanGuildLog()
    end
    if ns.Girudo.RefreshGuildLog then
      ns.Girudo:RefreshGuildLog()
    end
  end
end

-- ===========================================================================
-- 2. Addon object & saved variables
-- ===========================================================================
local Girudo = CreateFrame("Frame", "GirudoEventFrame")
ns.Girudo = Girudo
_G.Girudo = Girudo

GirudoDB = GirudoDB or {}
GirudoDB.lastSeenOnline = GirudoDB.lastSeenOnline or {}
GirudoDB.position = GirudoDB.position

local stored = GirudoDB.showOffline
GirudoDB.showOffline = (stored == true) or (stored == 1)

GirudoDB.logEntries = GirudoDB.logEntries or {}
GirudoDB.playerCache = GirudoDB.playerCache or {}
-- Rank structure derived from the current roster. Used to compute the
-- "old rank" for promote / demote events without having to have cached
-- that specific player's previous rank.
Girudo.rankByIndex = {}
Girudo.indexByRank = {}

-- ===========================================================================
-- 3. Constants
-- ===========================================================================
local FRAME_WIDTH = 980
local FRAME_HEIGHT = 566
local ROW_HEIGHT = 14
local NUM_ROWS = 28
local SCROLLBAR_PAD = 25
local ICON_SIZE = 12
local LOG_FILTER_WIDTH = 170
local LOG_FILTER_GAP = 10
local LOG_FILTER_RIGHT_MARGIN = 5
local LOG_RIGHT_OFFSET = SCROLLBAR_PAD + LOG_FILTER_WIDTH + LOG_FILTER_GAP

local TAB_NAMES = { "Log", "GB Log", "Roster", "Alts", "Macros", "Ranks", "Settings" }

local COLUMNS = {
  { key = "level", label = "Lvl", width = 32, align = "CENTER" },
  { key = "class", label = "Cls", width = 40, align = "CENTER" },
  { key = "name", label = "Name", width = 105, align = "LEFT" },
  { key = "zone", label = "Location", width = 127, align = "LEFT" },
  { key = "lastOnline", label = "Last Online", width = 85, align = "LEFT" },
  { key = "joinDate", label = "Join Date", width = 78, align = "LEFT" },
  { key = "rank", label = "Rank", width = 85, align = "LEFT" },
  { key = "note", label = "Note", width = 189, align = "LEFT" },
  { key = "officerNote", label = "Officer Note", width = 189, align = "LEFT" },
}

local CLASS_ICON_TEX = "Interface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes"

-- ===========================================================================
-- 4. Main frame
-- ===========================================================================
local frame = CreateFrame("Frame", "GirudoFrame", UIParent)
frame:SetWidth(FRAME_WIDTH)
frame:SetHeight(FRAME_HEIGHT)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:SetClampedToScreen(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local point, _, relPoint, x, y = self:GetPoint()
  GirudoDB.position = { point = point, relPoint = relPoint, x = x, y = y }
end)
frame:SetFrameStrata("DIALOG")
frame:SetToplevel(true)
frame:SetBackdrop({
  bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile = true,
  tileSize = 32,
  edgeSize = 32,
  insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
frame:SetBackdropColor(0, 0, 0, 0.9)
frame:Hide()

if GirudoDB.position then
  frame:ClearAllPoints()
  frame:SetPoint(
    GirudoDB.position.point,
    UIParent,
    GirudoDB.position.relPoint,
    GirudoDB.position.x,
    GirudoDB.position.y
  )
end

local title = frame:CreateFontString("GirudoFrameTitle", "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", frame, "TOP", 0, -16)
title:SetText("Girudo")

local close = CreateFrame("Button", "GirudoFrameCloseButton", frame, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
close:SetScript("OnClick", function()
  ToggleFriendsFrame(3)
end)

-- Top-right header stats (visible only on the Roster tab)
local onlineCount = frame:CreateFontString("GirudoFrameOnlineCount", "OVERLAY", "GameFontHighlightSmall")
onlineCount:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -18)
onlineCount:SetJustifyH("RIGHT")
onlineCount:Hide()

local displayedCount = frame:CreateFontString("GirudoFrameDisplayedCount", "OVERLAY", "GameFontNormalSmall")
displayedCount:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -33)
displayedCount:SetJustifyH("RIGHT")
displayedCount:Hide()

-- ===========================================================================
-- 5. Pages
-- ===========================================================================
local pageArea = CreateFrame("Frame", "GirudoPageArea", frame)
pageArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -70)
pageArea:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 40)

for i = 1, #TAB_NAMES do
  local page = CreateFrame("Frame", "GirudoFramePage" .. i, pageArea)
  page:SetAllPoints(pageArea)
  page:Hide()
  ns.pages[i] = page
end

-- ===========================================================================
-- 6. Tabs
-- ===========================================================================
local tabs = {}
for i, name in ipairs(TAB_NAMES) do
  local tab = CreateFrame("Button", "GirudoFrameTab" .. i, frame, "TabButtonTemplate")
  tab:SetID(i)
  tab:SetText(name)
  tab:SetWidth(80)
  PanelTemplates_TabResize(tab, 0)
  if i == 1 then
    tab:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -40)
  else
    tab:SetPoint("LEFT", tabs[i - 1], "RIGHT", 4, 0)
  end
  tab:SetScript("OnClick", function()
    ns.ShowPage(i)
  end)
  tabs[i] = tab
end
PanelTemplates_SetNumTabs(frame, #TAB_NAMES)

-- ===========================================================================
-- 7. Roster page
-- ===========================================================================
local rosterPage = ns.pages[3]

local showOfflineCheck = CreateFrame("CheckButton", "GirudoRosterShowOfflineCheck", rosterPage, "UICheckButtonTemplate")
showOfflineCheck:SetSize(24, 24)
showOfflineCheck:SetPoint("TOPLEFT", rosterPage, "TOPLEFT", 0, 0)
showOfflineCheck:SetChecked(GirudoDB.showOffline)
showOfflineCheck:SetScript("OnClick", function(self)
  local checked = self:GetChecked()
  -- GetChecked() returns true/false on stock 3.3.5a but 1/nil on some
  -- templates and private-server builds. Treat both as "checked".
  GirudoDB.showOffline = (checked == true) or (checked == 1)
  Girudo:UpdateRosterDisplay()
end)

local showOfflineLabel =
  showOfflineCheck:CreateFontString("GirudoRosterShowOfflineLabel", "OVERLAY", "GameFontNormalSmall")
showOfflineLabel:SetPoint("LEFT", showOfflineCheck, "RIGHT", 2, 0)
showOfflineLabel:SetText("Show Offline")

-- Search boxes (filter the roster list)
local function CreateGirudoSearchBox(name, parent, x, placeholderText)
  local eb = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
  eb:SetSize(160, 20)
  eb:SetPoint("LEFT", parent, "TOPLEFT", x, -12)
  eb:SetAutoFocus(false)
  eb:SetMaxLetters(30)
  eb:SetTextInsets(4, 4, 0, 0)

  local ph = eb:CreateFontString(name .. "Placeholder", "OVERLAY", "GameFontDisableSmall")
  ph:SetPoint("LEFT", eb, "LEFT", 6, 0)
  ph:SetText(placeholderText)
  ph:SetJustifyH("LEFT")
  eb.placeholder = ph

  eb:SetScript("OnEditFocusGained", function(self)
    self.placeholder:Hide()
  end)
  eb:SetScript("OnEditFocusLost", function(self)
    if self:GetText() == "" then
      self.placeholder:Show()
    end
  end)
  eb:SetScript("OnTextChanged", function(self)
    if self:GetText() == "" and not self:HasFocus() then
      self.placeholder:Show()
    else
      self.placeholder:Hide()
    end
    -- Jump to the top so the user always sees fresh results.
    local scrollBar = _G["GirudoRosterScrollScrollBar"]
    if scrollBar then
      scrollBar:SetValue(0)
    end
    Girudo:UpdateRosterDisplay()
  end)
  eb:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  eb:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)

  return eb
end

local playerSearchBox = CreateGirudoSearchBox("GirudoRosterPlayerSearch", rosterPage, 115, "Player Search")
local noteSearchBox = CreateGirudoSearchBox("GirudoRosterNoteSearch", rosterPage, 290, "Note Search")
local allSearchBox = CreateGirudoSearchBox("GirudoRosterAllSearch", rosterPage, 465, "Search All")

-- Tab / Shift+Tab cycling across the three search boxes.
-- In 3.3.5a, EditBox does not have OnShiftTabPressed; OnTabPressed fires for
-- both Tab and Shift+Tab, and IsShiftKeyDown() tells them apart.
local searchBoxes = { playerSearchBox, noteSearchBox, allSearchBox }

local function FocusSearchBox(index)
  local eb = searchBoxes[index]
  if not eb then
    return
  end
  eb:SetFocus()
  eb:HighlightText()
end

for i = 1, #searchBoxes do
  local eb = searchBoxes[i]
  eb:SetScript("OnTabPressed", function()
    if IsShiftKeyDown() then
      FocusSearchBox(i == 1 and #searchBoxes or i - 1)
    else
      FocusSearchBox(i == #searchBoxes and 1 or i + 1)
    end
  end)
end

local header = CreateFrame("Frame", "GirudoRosterHeader", rosterPage)
header:SetPoint("TOPLEFT", rosterPage, "TOPLEFT", 0, -26)
header:SetPoint("TOPRIGHT", rosterPage, "TOPRIGHT", -SCROLLBAR_PAD, -26)
header:SetHeight(24)
header:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
header:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

local headerButtons = {}
local xOffset = 0
for _, col in ipairs(COLUMNS) do
  local capKey = col.key:sub(1, 1):upper() .. col.key:sub(2)
  local btnName = "GirudoRosterHeader" .. capKey
  local btn = CreateFrame("Button", btnName, header)
  btn:SetWidth(col.width)
  btn:SetHeight(24)
  btn:SetPoint("LEFT", header, "LEFT", xOffset, 0)
  btn:SetNormalFontObject("GameFontNormalSmall")
  btn:SetHighlightFontObject("GameFontHighlightSmall")
  btn:SetText(col.label)
  btn.colKey = col.key
  btn:SetScript("OnClick", function()
    Girudo:SetSort(col.key)
  end)

  local arrow = btn:CreateFontString(btnName .. "Arrow", "OVERLAY", "GameFontHighlightSmall")
  arrow:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
  arrow:SetText("")
  btn.arrow = arrow

  headerButtons[col.key] = btn
  xOffset = xOffset + col.width
end

-- Bordered container matching the header's visual style, behind the rows.
local listContainer = CreateFrame("Frame", "GirudoRosterList", rosterPage)
listContainer:SetPoint("TOPLEFT", rosterPage, "TOPLEFT", 0, -52)
listContainer:SetPoint("BOTTOMRIGHT", rosterPage, "BOTTOMRIGHT", -SCROLLBAR_PAD, 0)
listContainer:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
listContainer:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

local scrollFrame = CreateFrame("ScrollFrame", "GirudoRosterScroll", rosterPage, "FauxScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", rosterPage, "TOPLEFT", 0, -56)
scrollFrame:SetPoint("BOTTOMRIGHT", rosterPage, "BOTTOMRIGHT", -SCROLLBAR_PAD, 0)
scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
  FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
    Girudo:UpdateRosterDisplay()
  end)
end)

local rows = {}
for i = 1, NUM_ROWS do
  local row = CreateFrame("Frame", "GirudoRosterRow" .. i, rosterPage)
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", rosterPage, "TOPLEFT", 0, -56 - (i - 1) * ROW_HEIGHT)
  row:SetPoint("TOPRIGHT", rosterPage, "TOPRIGHT", -SCROLLBAR_PAD, -56 - (i - 1) * ROW_HEIGHT)

  if i % 2 == 1 then
    row:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    row:SetBackdropColor(0.2, 0.2, 0.2, 0.25)
  end

  local cells = {}
  local x = 0
  for j, col in ipairs(COLUMNS) do
    local capKey = col.key:sub(1, 1):upper() .. col.key:sub(2)
    local cellName = "GirudoRosterRow" .. i .. capKey
    if col.key == "class" then
      local tex = row:CreateTexture(cellName, "OVERLAY")
      tex:SetSize(ICON_SIZE, ICON_SIZE)
      tex:SetPoint("LEFT", row, "LEFT", x + (col.width - ICON_SIZE) / 2, 0)
      cells[j] = tex
    else
      local fs = row:CreateFontString(cellName, "OVERLAY", "GameFontHighlightSmall")
      fs:SetWidth(col.width)
      fs:SetHeight(ROW_HEIGHT)
      fs:SetPoint("LEFT", row, "LEFT", x, 0)
      fs:SetJustifyH(col.align)
      cells[j] = fs
    end
    x = x + col.width
  end
  row.cells = cells

  -- Invisible click overlay. Sits above all cell content so a click anywhere
  -- in the row triggers the member popup, while the underlying fontstrings,
  -- class icons, and row backdrop continue to render normally.
  local rowButton = CreateFrame("Button", "GirudoRosterRow" .. i .. "Button", row)
  rowButton:SetAllPoints(row)
  rowButton:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  rowButton:SetScript("OnClick", function(self)
    local parent = self:GetParent()
    if parent.entry and parent.entry.name then
      Girudo:OpenMemberPopup(parent.entry.name)
    end
  end)
  row.button = rowButton

  rows[i] = row
end

local statusBar = CreateFrame("Frame", "GirudoStatusBar", frame)
statusBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
statusBar:SetHeight(20)

local warningText = statusBar:CreateFontString("GirudoStatusBarText", "OVERLAY", "GameFontNormal")
warningText:SetPoint("TOPLEFT", statusBar, "TOPLEFT", 0, 0)
warningText:SetPoint("BOTTOMRIGHT", statusBar, "BOTTOMRIGHT", -90, 0)
warningText:SetJustifyH("CENTER")
warningText:SetTextColor(1, 0.2, 0.2)
warningText:Hide()

local clearLogButton = CreateFrame("Button", "GirudoClearLogButton", statusBar, "UIPanelButtonTemplate")
clearLogButton:SetSize(80, 20)
clearLogButton:SetPoint("RIGHT", statusBar, "RIGHT", 0, 0)
clearLogButton:SetText("Clear Log")
clearLogButton:Hide()
clearLogButton:SetScript("OnClick", function()
  GirudoDB.logEntries = {}
  Girudo:UpdateLogDisplay()
end)

-- ===========================================================================
-- 7b. Log page (tab 1)
-- ===========================================================================
local logPage = ns.pages[1]

-- Search / filter box
local logSearchBox = CreateFrame("EditBox", "GirudoLogSearchBox", logPage, "InputBoxTemplate")
logSearchBox:SetSize(300, 20)
logSearchBox:SetPoint("TOPLEFT", logPage, "TOPLEFT", 8, 0)
logSearchBox:SetAutoFocus(false)
logSearchBox:SetMaxLetters(60)
logSearchBox:SetTextInsets(4, 4, 0, 0)

local logSearchPlaceholder =
  logSearchBox:CreateFontString("GirudoLogSearchBoxPlaceholder", "OVERLAY", "GameFontDisableSmall")
logSearchPlaceholder:SetPoint("LEFT", logSearchBox, "LEFT", 6, 0)
logSearchPlaceholder:SetText("Search log entries...")
logSearchBox.placeholder = logSearchPlaceholder

logSearchBox:SetScript("OnEditFocusGained", function(self)
  self.placeholder:Hide()
end)
logSearchBox:SetScript("OnEditFocusLost", function(self)
  if self:GetText() == "" then
    self.placeholder:Show()
  end
end)
logSearchBox:SetScript("OnTextChanged", function(self)
  if self:GetText() == "" and not self:HasFocus() then
    self.placeholder:Show()
  else
    self.placeholder:Hide()
  end
  local sb = _G["GirudoLogScrollScrollBar"]
  if sb then
    sb:SetValue(0)
  end
  Girudo:UpdateLogDisplay()
end)
logSearchBox:SetScript("OnEscapePressed", function(self)
  self:ClearFocus()
end)
logSearchBox:SetScript("OnEnterPressed", function(self)
  self:ClearFocus()
end)

-- Header
local logHeader = CreateFrame("Frame", "GirudoLogHeader", logPage)
logHeader:SetPoint("TOPLEFT", logPage, "TOPLEFT", 0, -26)
logHeader:SetPoint("TOPRIGHT", logPage, "TOPRIGHT", -LOG_RIGHT_OFFSET, -26)
logHeader:SetHeight(24)
logHeader:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
logHeader:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

local LOG_COLUMNS = {
  { key = "date", label = "Date", width = 140, align = "LEFT" },
  { key = "action", label = "Action", width = 110, align = "LEFT" },
  { key = "details", label = "Details", width = 495, align = "LEFT" },
}

local logHeaderButtons = {}
local logX = 0
for _, col in ipairs(LOG_COLUMNS) do
  local cap = col.key:sub(1, 1):upper() .. col.key:sub(2)
  local btn = CreateFrame("Button", "GirudoLogHeader" .. cap, logHeader)
  btn:SetWidth(col.width)
  btn:SetHeight(24)
  local textOffset = (logX == 0) and 4 or 0
  btn:SetPoint("LEFT", logHeader, "LEFT", logX + textOffset, 0)
  btn:SetNormalFontObject("GameFontNormalSmall")
  btn:SetHighlightFontObject("GameFontHighlightSmall")
  btn:SetText(col.label)
  btn.colKey = col.key
  btn:SetScript("OnClick", function()
    Girudo:SetLogSort(col.key)
  end)

  local arrow = btn:CreateFontString("GirudoLogHeader" .. cap .. "Arrow", "OVERLAY", "GameFontHighlightSmall")
  arrow:SetPoint("RIGHT", btn, "RIGHT", -2, 0)
  arrow:SetText("")
  btn.arrow = arrow

  logHeaderButtons[col.key] = btn
  logX = logX + col.width
end

-- Bordered container behind the rows
local logListContainer = CreateFrame("Frame", "GirudoLogList", logPage)
logListContainer:SetPoint("TOPLEFT", logPage, "TOPLEFT", 0, -52)
logListContainer:SetPoint("BOTTOMRIGHT", logPage, "BOTTOMRIGHT", -LOG_RIGHT_OFFSET, 0)
logListContainer:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
logListContainer:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

-- Scroll frame
local logScrollFrame = CreateFrame("ScrollFrame", "GirudoLogScroll", logPage, "FauxScrollFrameTemplate")
logScrollFrame:SetPoint("TOPLEFT", logPage, "TOPLEFT", 0, -56)
logScrollFrame:SetPoint("BOTTOMRIGHT", logPage, "BOTTOMRIGHT", -LOG_RIGHT_OFFSET, 0)
logScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
  FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, function()
    Girudo:UpdateLogDisplay()
  end)
end)

-- Rows
local logRows = {}
for i = 1, NUM_ROWS do
  local row = CreateFrame("Frame", "GirudoLogRow" .. i, logPage)
  row:SetHeight(ROW_HEIGHT)
  row:SetPoint("TOPLEFT", logPage, "TOPLEFT", 0, -56 - (i - 1) * ROW_HEIGHT)
  row:SetPoint("TOPRIGHT", logPage, "TOPRIGHT", -LOG_RIGHT_OFFSET, -56 - (i - 1) * ROW_HEIGHT)

  if i % 2 == 1 then
    row:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
    row:SetBackdropColor(0.2, 0.2, 0.2, 0.25)
  end

  local cells = {}
  local x = 0
  for j, col in ipairs(LOG_COLUMNS) do
    local cap = col.key:sub(1, 1):upper() .. col.key:sub(2)
    local fs = row:CreateFontString("GirudoLogRow" .. i .. cap, "OVERLAY", "GameFontHighlightSmall")
    fs:SetWidth(col.width)
    fs:SetHeight(ROW_HEIGHT)
    local textOffset = (x == 0) and 4 or 0
    fs:SetPoint("LEFT", row, "LEFT", x + textOffset, 0)
    fs:SetJustifyH(col.align)
    cells[j] = fs
    x = x + col.width
  end
  row.cells = cells
  logRows[i] = row
end

-- ===========================================================================
-- 8. Data, parsing, sorting
-- ===========================================================================
Girudo.rosterData = {}
Girudo.sortKey = "rank"
Girudo.sortAscending = false

local function ParseJoinDate(officerNote)
  if not officerNote then
    return nil, 0
  end
  local d, m, y = officerNote:match("(%d%d)%.(%d%d)%.(%d%d)")
  if d and m and y then
    local day, month, yr = tonumber(d), tonumber(m), tonumber(y)
    local fullYear = 2000 + yr
    return string.format("%02d.%02d.%02d", day, month, yr), fullYear * 10000 + month * 100 + day
  end
  return nil, 0
end

local function FormatOfflineTime(apiY, apiM, apiD, apiH, lastSeen)
  local apiTotalHours = (apiY or 0) * 365 * 24 + (apiM or 0) * 30 * 24 + (apiD or 0) * 24 + (apiH or 0)

  if apiTotalHours >= 1 then
    local parts = {}
    if apiY and apiY > 0 then
      table.insert(parts, apiY .. "y")
    end
    if apiM and apiM > 0 then
      table.insert(parts, apiM .. "mo")
    end
    if apiD and apiD > 0 then
      table.insert(parts, apiD .. "d")
    end
    if apiH and apiH > 0 then
      table.insert(parts, apiH .. "h")
    end
    return table.concat(parts, " "), apiTotalHours
  end

  if lastSeen then
    local diff = time() - lastSeen
    local minutes = math.floor(diff / 60)
    if minutes < 1 then
      return "Just now", math.max(diff / 3600, 0.01)
    elseif minutes < 60 then
      return minutes .. "m", diff / 3600
    end
  end
  return "< 1h", 0.5
end

local function ColorForOfflineHours(hours)
  if hours < 24 then
    return 0.4, 1, 0.4
  elseif hours < 168 then
    return 1, 1, 1
  elseif hours < 672 then
    return 1, 1, 0.5
  elseif hours < 2160 then
    return 1, 0.6, 0
  elseif hours < 4320 then
    return 1, 0.4, 0.4
  else
    return 0.7, 0, 0
  end
end

local sortFunctions = {
  level = function(a, b)
    return a.level < b.level
  end,
  name = function(a, b)
    return a.name < b.name
  end,
  class = function(a, b)
    return a.class < b.class
  end,
  zone = function(a, b)
    return a.zone < b.zone
  end,
  lastOnline = function(a, b)
    return a.lastOnlineValue < b.lastOnlineValue
  end,
  joinDate = function(a, b)
    return a.joinDateValue < b.joinDateValue
  end,
  rank = function(a, b)
    return a.rankValue < b.rankValue
  end,
  note = function(a, b)
    return a.note < b.note
  end,
  officerNote = function(a, b)
    return a.officerNote < b.officerNote
  end,
}

local SORT_VALUE_KEY = {
  lastOnline = "lastOnlineValue",
  joinDate = "joinDateValue",
  rank = "rankValue",
}

function Girudo:SortRoster()
  local key = self.sortKey
  local asc = self.sortAscending
  local fn = sortFunctions[key]
  local valueKey = SORT_VALUE_KEY[key] or key

  table.sort(self.rosterData, function(a, b)
    local av, bv = a[valueKey], b[valueKey]
    if av == bv then
      return a.name < b.name
    end
    local result
    if fn then
      result = fn(a, b)
    else
      result = a.name < b.name
    end
    if not asc then
      result = not result
    end
    return result
  end)
end

function Girudo:SetSort(key)
  if self.sortKey == key then
    self.sortAscending = not self.sortAscending
  else
    self.sortKey = key
    self.sortAscending = (key ~= "rank")
  end
  self:SortRoster()
  self:UpdateRosterDisplay()
end

function Girudo:UpdateSortArrows()
  for key, btn in pairs(headerButtons) do
    if key == self.sortKey then
      btn.arrow:SetText(self.sortAscending and "↑" or "↓")
    else
      btn.arrow:SetText("")
    end
  end
end

function Girudo:GetDisplayData()
  -- Strict boolean: defends against a SavedVariables value that ended up
  -- as 1, "true", or anything else truthy but not literally true.
  local showOffline = (GirudoDB.showOffline == true) or (GirudoDB.showOffline == 1)

  local playerTerm = playerSearchBox:GetText():lower()
  local noteTerm = noteSearchBox:GetText():lower()
  local allTerm = allSearchBox:GetText():lower()

  local function matches(haystack, needle)
    if needle == "" then
      return true
    end
    if not haystack then
      return false
    end
    return haystack:lower():find(needle, 1, true) ~= nil
  end

  local filtered = {}
  for _, e in ipairs(self.rosterData) do
    local passes = true

    -- Show Offline filter (explicit online-state check)
    local isOnline = (e.online == 1) or (e.online == true)
    if not showOffline and not isOnline then
      passes = false
    end

    -- Player Search: name only
    if passes and playerTerm ~= "" then
      if not matches(e.name, playerTerm) then
        passes = false
      end
    end

    -- Note Search: note OR officer note
    if passes and noteTerm ~= "" then
      if not (matches(e.note, noteTerm) or matches(e.officerNote, noteTerm)) then
        passes = false
      end
    end

    -- Search All: every text field
    if passes and allTerm ~= "" then
      if
        not (
          matches(e.name, allTerm)
          or matches(e.note, allTerm)
          or matches(e.officerNote, allTerm)
          or matches(e.zone, allTerm)
          or matches(e.rank, allTerm)
          or matches(e.class, allTerm)
        )
      then
        passes = false
      end
    end

    if passes then
      table.insert(filtered, e)
    end
  end
  return filtered
end

-- ===========================================================================
-- 8b. Header (title, online count, displayed count)
-- ===========================================================================
-- Returns true iff the default pane's Show Offline Members is enabled.
-- Handles all flag representations the client has been observed to use:
-- true / false / 1 / 0 / nil.
local function DefaultPaneShowsOffline()
  local flag = GetGuildRosterShowOffline()
  return (flag == true) or (flag == 1)
end

function Girudo:UpdateWarning()
  if not IsInGuild() then
    warningText:Hide()
    return
  end
  if DefaultPaneShowsOffline() then
    warningText:Hide()
  else
    warningText:SetText(
      "|cffff3333Show Offline Members must be enabled in the default guild window for Girudo to function correctly.|r"
    )
    warningText:Show()
  end
end

function Girudo:UpdateHeader()
  local YELLOW = "|cffffd100" -- same yellow as GameFontNormalLarge
  local WHITE = "|cffffffff"
  local RESET = "|r"

  local guildName = GetGuildInfo("player")
  local realmName = GetRealmName()
  if guildName and realmName and guildName ~= "" then
    title:SetText(YELLOW .. "Girudo" .. RESET .. " | " .. WHITE .. guildName .. " (" .. realmName .. ")" .. RESET)
  elseif guildName and guildName ~= "" then
    title:SetText(YELLOW .. "Girudo" .. RESET .. " | " .. WHITE .. guildName .. RESET)
  else
    title:SetText(YELLOW .. "Girudo" .. RESET)
  end

  if ns.activePage == 3 then
    local online, total = 0, 0
    for _, e in ipairs(self.rosterData) do
      total = total + 1
      if e.online == 1 then
        online = online + 1
      end
    end
    onlineCount:SetText(online .. " / " .. total .. " Online")
    onlineCount:Show()

    local displayed = #self:GetDisplayData()
    displayedCount:SetText(string.format("%d displayed member%s", displayed, displayed == 1 and "" or "s"))
    displayedCount:Show()
  else
    onlineCount:Hide()
    displayedCount:Hide()
  end

  if ns.activePage == 1 then
    clearLogButton:Show()
  else
    clearLogButton:Hide()
  end
end

-- ===========================================================================
-- 8c. Row rendering
-- ===========================================================================
function Girudo:UpdateRosterDisplay()
  local data = self:GetDisplayData()
  local numEntries = #data

  FauxScrollFrame_Update(scrollFrame, numEntries, NUM_ROWS, ROW_HEIGHT)
  local offset = FauxScrollFrame_GetOffset(scrollFrame)

  for i = 1, NUM_ROWS do
    local index = offset + i
    local row = rows[i]
    if index <= numEntries then
      local e = data[index]
      local classColor = e.classFileName and RAID_CLASS_COLORS[e.classFileName]

      row.cells[1]:SetText(e.level)
      row.cells[1]:SetTextColor(1, 1, 1)

      if e.classFileName and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[e.classFileName] then
        row.cells[2]:SetTexture(CLASS_ICON_TEX)
        row.cells[2]:SetTexCoord(unpack(CLASS_ICON_TCOORDS[e.classFileName]))
        row.cells[2]:Show()
      else
        row.cells[2]:Hide()
      end

      row.cells[3]:SetText(e.name)
      if classColor then
        row.cells[3]:SetTextColor(classColor.r, classColor.g, classColor.b)
      else
        row.cells[3]:SetTextColor(1, 1, 1)
      end

      row.cells[4]:SetText(e.zone or "")
      row.cells[4]:SetTextColor(1, 1, 1)

      row.cells[5]:SetText(e.lastOnlineText)
      if e.online == 1 then
        row.cells[5]:SetTextColor(0, 1, 0)
      else
        local r, g, b = ColorForOfflineHours(e.lastOnlineValue)
        row.cells[5]:SetTextColor(r, g, b)
      end

      row.cells[6]:SetText(e.joinDate or "—")
      row.cells[6]:SetTextColor(1, 1, 1)

      row.cells[7]:SetText(e.rank or "")
      row.cells[7]:SetTextColor(1, 1, 1)

      row.cells[8]:SetText(e.note or "")
      row.cells[8]:SetTextColor(1, 1, 1)

      row.cells[9]:SetText(e.officerNote or "")
      row.cells[9]:SetTextColor(1, 1, 1)

      row.entry = e
      row:Show()
    else
      row.entry = nil
      row:Hide()
    end
  end

  self:UpdateSortArrows()
  self:UpdateWarning()
  self:UpdateHeader()
  if self.RefreshMemberPopup then
    self:RefreshMemberPopup()
  end
end

-- ===========================================================================
-- 8d. Member popup
-- ===========================================================================
local PADDING = 14
local POPUP_WIDTH = 320
local CONTENT_WIDTH = POPUP_WIDTH - PADDING * 2 -- 292

local popup = CreateFrame("Frame", "GirudoMemberPopup", UIParent)
popup:SetWidth(POPUP_WIDTH)
popup:SetHeight(385)
popup:SetPoint("CENTER")
popup:SetMovable(true)
popup:SetClampedToScreen(true)
popup:EnableMouse(true)
popup:RegisterForDrag("LeftButton")
popup:SetScript("OnDragStart", popup.StartMoving)
popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
popup:SetFrameStrata("FULLSCREEN_DIALOG")
popup:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
popup:SetBackdropColor(0, 0, 0, 0.9)
popup:Hide()
tinsert(UISpecialFrames, "GirudoMemberPopup")

local popupClose = CreateFrame("Button", "GirudoMemberPopupCloseButton", popup, "UIPanelCloseButton")
popupClose:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -4, -4)

local popupName = popup:CreateFontString("GirudoMemberPopupName", "OVERLAY", "GameFontNormalLarge")
popupName:SetPoint("TOPLEFT", popup, "TOPLEFT", PADDING, -PADDING)
popupName:SetWidth(CONTENT_WIDTH)
popupName:SetJustifyH("LEFT")

local popupLevelClass = popup:CreateFontString("GirudoMemberPopupLevelClass", "OVERLAY", "GameFontHighlightSmall")
popupLevelClass:SetPoint("TOPLEFT", popupName, "BOTTOMLEFT", 0, -4)
popupLevelClass:SetWidth(CONTENT_WIDTH)
popupLevelClass:SetJustifyH("LEFT")

local popupRank = popup:CreateFontString("GirudoMemberPopupRank", "OVERLAY", "GameFontHighlightSmall")
popupRank:SetPoint("TOPLEFT", popupLevelClass, "BOTTOMLEFT", 0, -2)
popupRank:SetWidth(CONTENT_WIDTH)
popupRank:SetJustifyH("LEFT")

local popupZone = popup:CreateFontString("GirudoMemberPopupZone", "OVERLAY", "GameFontHighlightSmall")
popupZone:SetPoint("TOPLEFT", popupRank, "BOTTOMLEFT", 0, -2)
popupZone:SetWidth(CONTENT_WIDTH)
popupZone:SetJustifyH("LEFT")

local popupJoined = popup:CreateFontString("GirudoMemberPopupJoined", "OVERLAY", "GameFontHighlightSmall")
popupJoined:SetPoint("TOPLEFT", popupZone, "BOTTOMLEFT", 0, -2)
popupJoined:SetWidth(CONTENT_WIDTH)
popupJoined:SetJustifyH("LEFT")

local popupLastSeen = popup:CreateFontString("GirudoMemberPopupLastSeen", "OVERLAY", "GameFontHighlightSmall")
popupLastSeen:SetPoint("TOPLEFT", popupJoined, "BOTTOMLEFT", 0, -2)
popupLastSeen:SetWidth(CONTENT_WIDTH)
popupLastSeen:SetJustifyH("LEFT")

local popupPublicNoteLabel =
  popup:CreateFontString("GirudoMemberPopupPublicNoteLabel", "OVERLAY", "GameFontNormalSmall")
popupPublicNoteLabel:SetPoint("TOPLEFT", popupLastSeen, "BOTTOMLEFT", 0, -10)
popupPublicNoteLabel:SetText("Public Note")

local popupPublicNoteEdit = CreateFrame("EditBox", "GirudoMemberPopupPublicNoteEdit", popup, "InputBoxTemplate")
popupPublicNoteEdit:SetSize(CONTENT_WIDTH, 20)
popupPublicNoteEdit:SetPoint("TOPLEFT", popupPublicNoteLabel, "BOTTOMLEFT", 0, -4)
popupPublicNoteEdit:SetAutoFocus(false)
popupPublicNoteEdit:SetMaxLetters(255)
popupPublicNoteEdit:SetTextInsets(4, 4, 0, 0)

local popupOfficerNoteLabel =
  popup:CreateFontString("GirudoMemberPopupOfficerNoteLabel", "OVERLAY", "GameFontNormalSmall")
popupOfficerNoteLabel:SetPoint("TOPLEFT", popupPublicNoteEdit, "BOTTOMLEFT", 0, -8)
popupOfficerNoteLabel:SetText("Officer Note")

local popupOfficerNoteEdit = CreateFrame("EditBox", "GirudoMemberPopupOfficerNoteEdit", popup, "InputBoxTemplate")
popupOfficerNoteEdit:SetSize(CONTENT_WIDTH, 20)
popupOfficerNoteEdit:SetPoint("TOPLEFT", popupOfficerNoteLabel, "BOTTOMLEFT", 0, -4)
popupOfficerNoteEdit:SetAutoFocus(false)
popupOfficerNoteEdit:SetMaxLetters(255)
popupOfficerNoteEdit:SetTextInsets(4, 4, 0, 0)

local popupPromoteBtn = CreateFrame("Button", "GirudoMemberPopupPromote", popup, "UIPanelButtonTemplate")
popupPromoteBtn:SetSize(92, 22)
popupPromoteBtn:SetPoint("TOPLEFT", popupOfficerNoteEdit, "BOTTOMLEFT", 0, -10)
popupPromoteBtn:SetText("Promote")

local popupDemoteBtn = CreateFrame("Button", "GirudoMemberPopupDemote", popup, "UIPanelButtonTemplate")
popupDemoteBtn:SetSize(92, 22)
popupDemoteBtn:SetPoint("LEFT", popupPromoteBtn, "RIGHT", 8, 0)
popupDemoteBtn:SetText("Demote")

local popupWhisperBtn = CreateFrame("Button", "GirudoMemberPopupWhisper", popup, "UIPanelButtonTemplate")
popupWhisperBtn:SetSize(92, 22)
popupWhisperBtn:SetPoint("TOPLEFT", popupPromoteBtn, "BOTTOMLEFT", 0, -6)
popupWhisperBtn:SetText("Whisper")

local popupInviteBtn = CreateFrame("Button", "GirudoMemberPopupInvite", popup, "UIPanelButtonTemplate")
popupInviteBtn:SetSize(92, 22)
popupInviteBtn:SetPoint("LEFT", popupWhisperBtn, "RIGHT", 8, 0)
popupInviteBtn:SetText("Invite")

local popupKickBtn = CreateFrame("Button", "GirudoMemberPopupKick", popup, "UIPanelButtonTemplate")
popupKickBtn:SetSize(92, 22)
popupKickBtn:SetPoint("LEFT", popupInviteBtn, "RIGHT", 8, 0)
popupKickBtn:SetText("Kick")

local popupSeparator = popup:CreateTexture("GirudoMemberPopupSeparator", "ARTWORK")
popupSeparator:SetHeight(1)
popupSeparator:SetTexture(0.5, 0.5, 0.5, 0.5)
popupSeparator:SetPoint("TOPLEFT", popupWhisperBtn, "BOTTOMLEFT", 0, -10)
popupSeparator:SetPoint("TOPRIGHT", popupWhisperBtn, "BOTTOMRIGHT", 0, -10)

local popupAltsLabel = popup:CreateFontString("GirudoMemberPopupAltsLabel", "OVERLAY", "GameFontNormalSmall")
popupAltsLabel:SetPoint("TOPLEFT", popupSeparator, "BOTTOMLEFT", 0, -8)
popupAltsLabel:SetText("Alts")

local popupAltsContainer = CreateFrame("Frame", "GirudoMemberPopupAltsContainer", popup)
popupAltsContainer:SetPoint("TOPLEFT", popupAltsLabel, "BOTTOMLEFT", 0, -4)
popupAltsContainer:SetSize(CONTENT_WIDTH, 60)

local popupAltsPlaceholder =
  popupAltsContainer:CreateFontString("GirudoMemberPopupAltsPlaceholder", "OVERLAY", "GameFontDisableSmall")
popupAltsPlaceholder:SetPoint("TOPLEFT", popupAltsContainer, "TOPLEFT", 0, 0)
popupAltsPlaceholder:SetText("No alts configured.")

local function FindRosterIndex(name)
  local n = GetNumGuildMembers(true)
  for i = 1, n do
    local mName = GetGuildRosterInfo(i)
    if mName == name then
      return i
    end
  end
  return nil
end

local function FormatLastSeenAgo(entry)
  if entry.online == 1 then
    return "Online"
  end
  local hours = entry.lastOnlineValue
  if not hours or hours < 0 then
    hours = 0
  end

  if hours < 1 / 60 then
    return "just now"
  elseif hours < 1 then
    local m = math.floor(hours * 60 + 0.5)
    if m < 1 then
      m = 1
    end
    return m .. (m == 1 and " minute ago" or " minutes ago")
  elseif hours < 24 then
    local h = math.floor(hours)
    return h .. (h == 1 and " hour ago" or " hours ago")
  elseif hours < 168 then
    local d = math.floor(hours / 24)
    return d .. (d == 1 and " day ago" or " days ago")
  elseif hours < 720 then
    local w = math.floor(hours / 168)
    return w .. (w == 1 and " week ago" or " weeks ago")
  elseif hours < 8760 then
    local mo = math.floor(hours / 730)
    if mo < 1 then
      mo = 1
    end
    return mo .. (mo == 1 and " month ago" or " months ago")
  else
    local y = math.floor(hours / 8760)
    return y .. (y == 1 and " year ago" or " years ago")
  end
end

function Girudo:RefreshMemberPopup()
  if not popup:IsShown() then
    return
  end
  if not popup.currentName then
    return
  end

  local entry
  for _, e in ipairs(self.rosterData) do
    if e.name == popup.currentName then
      entry = e
      break
    end
  end

  if not entry then
    popup:Hide()
    return
  end

  local classColor = entry.classFileName and RAID_CLASS_COLORS[entry.classFileName]

  local YELLOW = "|cffffd100"
  local RESET = "|r"

  popupName:SetText(entry.name)
  if classColor then
    popupName:SetTextColor(classColor.r, classColor.g, classColor.b)
  else
    popupName:SetTextColor(1, 1, 1)
  end

  -- Level line: yellow "Level:" label, white level number, class-colored name.
  local classDisplay = entry.class or "?"
  if classColor then
    classDisplay =
      string.format("|cff%02x%02x%02x%s|r", classColor.r * 255, classColor.g * 255, classColor.b * 255, classDisplay)
  end
  popupLevelClass:SetText(YELLOW .. "Level:" .. RESET .. " " .. tostring(entry.level or "?") .. " " .. classDisplay)
  popupLevelClass:SetTextColor(1, 1, 1)

  popupRank:SetText(YELLOW .. "Rank:" .. RESET .. " " .. (entry.rank or "?"))
  popupRank:SetTextColor(1, 1, 1)

  popupZone:SetText(YELLOW .. "Zone:" .. RESET .. " " .. (entry.zone or ""))
  popupZone:SetTextColor(1, 1, 1)

  if entry.joinDate and entry.joinDate ~= "—" and entry.joinDate ~= "" then
    popupJoined:SetText(YELLOW .. "Joined:" .. RESET .. " " .. (entry.joinDate or "-"))
  else
    popupJoined:SetText("")
  end
  popupJoined:SetTextColor(1, 1, 1)

  -- Last Seen: yellow label, colored time portion.
  local lastSeenText = FormatLastSeenAgo(entry)
  local r, g, b
  if entry.online == 1 then
    r, g, b = 0, 1, 0
  else
    r, g, b = ColorForOfflineHours(entry.lastOnlineValue)
  end
  popupLastSeen:SetText(
    string.format("%sLast Seen:%s |cff%02x%02x%02x%s|r", YELLOW, RESET, r * 255, g * 255, b * 255, lastSeenText)
  )
  popupLastSeen:SetTextColor(1, 1, 1)

  if not popupPublicNoteEdit:HasFocus() then
    popupPublicNoteEdit:SetText(entry.note or "")
  end
  if not popupOfficerNoteEdit:HasFocus() then
    popupOfficerNoteEdit:SetText(entry.officerNote or "")
  end

  local canPromote, canDemote = true, true
  if CanPromote then
    local ok, result = pcall(CanPromote, entry.name)
    if ok and result == false then
      canPromote = false
    end
  end
  if CanDemote then
    local ok, result = pcall(CanDemote, entry.name)
    if ok and result == false then
      canDemote = false
    end
  end
  popupPromoteBtn:SetEnabled(canPromote)
  popupDemoteBtn:SetEnabled(canDemote)
end

function Girudo:OpenMemberPopup(name)
  if not name then
    return
  end
  popup.currentName = name

  popup:ClearAllPoints()
  popup:SetPoint("TOPLEFT", GirudoFrame, "TOPRIGHT", 8, 0)

  self:RefreshMemberPopup()
  popup:Show()
end

popupPublicNoteEdit:SetScript("OnEnterPressed", function(self)
  self:ClearFocus()
end)
popupPublicNoteEdit:SetScript("OnEscapePressed", function(self)
  self:ClearFocus()
end)
-- The InputBoxTemplate's default OnEditFocusGained calls HighlightText(),
-- which selects the entire string. Removing that handler restores the
-- built-in click-to-place-cursor behaviour without selecting all.
popupPublicNoteEdit:SetScript("OnEditFocusGained", function() end)
popupOfficerNoteEdit:SetScript("OnEditFocusGained", function() end)
popupPublicNoteEdit:SetScript("OnEditFocusLost", function(self)
  if not popup.currentName then
    return
  end
  local cache = GirudoDB.playerCache[popup.currentName]
  local original = (cache and cache.publicNote) or ""
  if self:GetText() == original then
    return
  end
  local index = FindRosterIndex(popup.currentName)
  if not index then
    return
  end
  if GuildRosterSetPublicNote then
    GuildRosterSetPublicNote(index, self:GetText())
  end
end)

popupOfficerNoteEdit:SetScript("OnEnterPressed", function(self)
  self:ClearFocus()
end)
popupOfficerNoteEdit:SetScript("OnEscapePressed", function(self)
  self:ClearFocus()
end)
popupOfficerNoteEdit:SetScript("OnEditFocusLost", function(self)
  if not popup.currentName then
    return
  end
  local cache = GirudoDB.playerCache[popup.currentName]
  local original = (cache and cache.officerNote) or ""
  if self:GetText() == original then
    return
  end
  local index = FindRosterIndex(popup.currentName)
  if not index then
    return
  end
  if GuildRosterSetOfficerNote then
    GuildRosterSetOfficerNote(index, self:GetText())
  end
end)

popupPromoteBtn:SetScript("OnClick", function()
  if not popup.currentName then
    return
  end
  if PromoteByName then
    PromoteByName(popup.currentName)
  end
end)

popupDemoteBtn:SetScript("OnClick", function()
  if not popup.currentName then
    return
  end
  if DemoteByName then
    DemoteByName(popup.currentName)
  end
end)

popupWhisperBtn:SetScript("OnClick", function()
  if not popup.currentName then
    return
  end
  ChatFrame_OpenChat("/w " .. popup.currentName .. " ")
  popup:Hide()
end)

popupInviteBtn:SetScript("OnClick", function()
  if not popup.currentName then
    return
  end
  if InviteUnit then
    InviteUnit(popup.currentName)
  end
end)

popupKickBtn:SetScript("OnClick", function()
  if not popup.currentName then
    return
  end
  if GuildUninvite then
    GuildUninvite(popup.currentName)
  end
  popup:Hide()
end)

function Girudo:ScanRoster()
  if not IsInGuild() then
    self.rosterData = {}
    self:UpdateRosterDisplay()
    return
  end

  self:UpdateWarning()

  local numMembers = GetNumGuildMembers(true)
  local newData = {}

  for i = 1, numMembers do
    local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName =
      GetGuildRosterInfo(i)
    if name then
      local lastOnlineText, lastOnlineValue
      if online == 1 then
        lastOnlineText = "Online"
        lastOnlineValue = -1
        GirudoDB.lastSeenOnline[name] = time()
      else
        local y, mo, d, h = GetGuildRosterLastOnline(i)
        lastOnlineText, lastOnlineValue =
          FormatOfflineTime(y or 0, mo or 0, d or 0, h or 0, GirudoDB.lastSeenOnline[name])
      end

      local joinText, joinValue = ParseJoinDate(officernote)

      table.insert(newData, {
        name = name,
        rank = rank or "",
        rankIndex = rankIndex or 0,
        rankValue = -(rankIndex or 0),
        level = level or 0,
        class = class or "",
        classFileName = classFileName,
        zone = zone or "",
        note = note or "",
        officerNote = officernote or "",
        online = online,
        lastOnlineValue = lastOnlineValue,
        lastOnlineText = lastOnlineText,
        joinDate = joinText or "—",
        joinDateValue = joinValue,
      })
    end
  end

  self.rosterData = newData

  GirudoDB.playerCache = GirudoDB.playerCache or {}
  Girudo.rankByIndex = {}
  Girudo.indexByRank = {}
  for _, e in ipairs(newData) do
    GirudoDB.playerCache[e.name] = {
      level = e.level,
      rank = e.rank,
      rankIndex = e.rankIndex,
      class = e.class,
      classFileName = e.classFileName,
      publicNote = e.note,
      officerNote = e.officerNote,
    }
    if e.rank and e.rank ~= "" then
      Girudo.rankByIndex[e.rankIndex] = e.rank
      Girudo.indexByRank[e.rank] = e.rankIndex
    end
  end

  self:SortRoster()
  self:UpdateRosterDisplay()
end

function Girudo:UpdateRoster()
  if not IsInGuild() then
    self.rosterData = {}
    self:UpdateRosterDisplay()
    return
  end
  GuildRoster()
end

-- ===========================================================================
-- 8e. Guild log: persistence, scanning, sorting, rendering
-- ===========================================================================

-- WotLK 3.3.5a event types returned by GetGuildEventInfo (0-based).
local EVENT_INVITE = 0
local EVENT_JOIN = 1
local EVENT_QUIT = 2
local EVENT_PROMOTE = 3
local EVENT_DEMOTE = 4
local EVENT_UNINVITE = 5
local EVENT_SIGN_ON = 6
local EVENT_SIGN_OFF = 7
local EVENT_MOTD = 8
local EVENT_PUBLIC_NOTE = 100
local EVENT_OFFICER_NOTE = 101

local ACTION_COLORS = {
  [EVENT_INVITE] = { 0.35, 0.70, 1.00 }, -- light blue
  [EVENT_JOIN] = { 0.40, 1.00, 0.40 }, -- green
  [EVENT_QUIT] = { 1.00, 0.40, 0.40 }, -- red
  [EVENT_PROMOTE] = { 0.50, 1.00, 0.50 }, -- light green
  [EVENT_DEMOTE] = { 1.00, 0.60, 0.30 }, -- orange
  [EVENT_UNINVITE] = { 1.00, 0.20, 0.20 }, -- dark red
  [EVENT_SIGN_ON] = { 0.80, 0.80, 0.80 }, -- gray
  [EVENT_SIGN_OFF] = { 0.50, 0.50, 0.50 }, -- darker gray
  [EVENT_MOTD] = { 1.00, 1.00, 0.50 }, -- yellow
  [EVENT_PUBLIC_NOTE] = { 0.70, 0.80, 1.00 }, -- pale blue
  [EVENT_OFFICER_NOTE] = { 0.90, 0.70, 1.00 }, -- pale purple
}

-- Filter state. Every action is visible by default.
Girudo.logFilter = Girudo.logFilter or {}
do
  local all = {
    EVENT_INVITE,
    EVENT_JOIN,
    EVENT_QUIT,
    EVENT_PROMOTE,
    EVENT_DEMOTE,
    EVENT_UNINVITE,
    EVENT_MOTD,
    EVENT_PUBLIC_NOTE,
    EVENT_OFFICER_NOTE,
  }
  for _, t in ipairs(all) do
    if Girudo.logFilter[t] == nil then
      Girudo.logFilter[t] = true
    end
  end
end

-- Filter box on the right of the Log page.
local logFilterBox = CreateFrame("Frame", "GirudoLogFilterBox", logPage)
logFilterBox:SetPoint("TOPRIGHT", logPage, "TOPRIGHT", -LOG_FILTER_RIGHT_MARGIN, -26)
logFilterBox:SetPoint("BOTTOMRIGHT", logPage, "BOTTOMRIGHT", -LOG_FILTER_RIGHT_MARGIN, 0)
logFilterBox:SetWidth(LOG_FILTER_WIDTH)
logFilterBox:SetBackdrop({
  bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile = true,
  tileSize = 16,
  edgeSize = 16,
  insets = { left = 4, right = 4, top = 4, bottom = 4 },
})
logFilterBox:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

local logFilterTitle = logFilterBox:CreateFontString("GirudoLogFilterTitle", "OVERLAY", "GameFontNormalSmall")
logFilterTitle:SetPoint("TOPLEFT", logFilterBox, "TOPLEFT", 8, -8)
logFilterTitle:SetText("Show Actions")

local logFilterCheckboxes = {}
local LOG_FILTER_ACTIONS = {
  { type = EVENT_INVITE, label = "Invited" },
  { type = EVENT_JOIN, label = "Joined" },
  { type = EVENT_QUIT, label = "Left" },
  { type = EVENT_PROMOTE, label = "Promoted" },
  { type = EVENT_DEMOTE, label = "Demoted" },
  { type = EVENT_UNINVITE, label = "Kicked" },
  { type = EVENT_MOTD, label = "MOTD Changed" },
  { type = EVENT_PUBLIC_NOTE, label = "Public Note" },
  { type = EVENT_OFFICER_NOTE, label = "Officer Note" },
}

local filterY = -28
for _, action in ipairs(LOG_FILTER_ACTIONS) do
  local cbName = "GirudoLogFilter" .. action.label:gsub("%s+", "")
  local cb = CreateFrame("CheckButton", cbName, logFilterBox, "UICheckButtonTemplate")
  cb:SetSize(20, 20)
  cb:SetPoint("TOPLEFT", logFilterBox, "TOPLEFT", 6, filterY)
  cb:SetChecked(Girudo.logFilter[action.type] and true or false)
  cb.eventType = action.type

  local lbl = cb:CreateFontString(cbName .. "Label", "OVERLAY", "GameFontHighlightSmall")
  lbl:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  lbl:SetText(action.label)

  cb:SetScript("OnClick", function(self)
    local checked = self:GetChecked()
    Girudo.logFilter[self.eventType] = (checked == true) or (checked == 1)
    Girudo:UpdateLogDisplay()
  end)

  logFilterCheckboxes[action.type] = cb
  filterY = filterY - 22
end

local logFilterAllButton = CreateFrame("Button", "GirudoLogFilterAllButton", logFilterBox, "UIPanelButtonTemplate")
logFilterAllButton:SetSize(72, 20)
logFilterAllButton:SetPoint("BOTTOMLEFT", logFilterBox, "BOTTOMLEFT", 8, 8)
logFilterAllButton:SetText("All")
logFilterAllButton:SetScript("OnClick", function()
  for eventType, cb in pairs(logFilterCheckboxes) do
    cb:SetChecked(true)
    Girudo.logFilter[eventType] = true
  end
  Girudo:UpdateLogDisplay()
end)

local logFilterNoneButton = CreateFrame("Button", "GirudoLogFilterNoneButton", logFilterBox, "UIPanelButtonTemplate")
logFilterNoneButton:SetSize(72, 20)
logFilterNoneButton:SetPoint("BOTTOMRIGHT", logFilterBox, "BOTTOMRIGHT", -8, 8)
logFilterNoneButton:SetText("None")
logFilterNoneButton:SetScript("OnClick", function()
  for eventType, cb in pairs(logFilterCheckboxes) do
    cb:SetChecked(false)
    Girudo.logFilter[eventType] = false
  end
  Girudo:UpdateLogDisplay()
end)

Girudo.logSortKey = "date"
Girudo.logSortAscending = false

local function ActionLabel(eventType)
  if eventType == EVENT_INVITE then
    return "Invited"
  end
  if eventType == EVENT_JOIN then
    return "Joined"
  end
  if eventType == EVENT_QUIT then
    return "Left"
  end
  if eventType == EVENT_PROMOTE then
    return "Promoted"
  end
  if eventType == EVENT_DEMOTE then
    return "Demoted"
  end
  if eventType == EVENT_UNINVITE then
    return "Kicked"
  end
  if eventType == EVENT_SIGN_ON then
    return "Signed On"
  end
  if eventType == EVENT_SIGN_OFF then
    return "Signed Off"
  end
  if eventType == EVENT_MOTD then
    return "MOTD Changed"
  end
  if eventType == EVENT_PUBLIC_NOTE then
    return "Public Note"
  end
  if eventType == EVENT_OFFICER_NOTE then
    return "Officer Note"
  end
  return "Unknown (" .. tostring(eventType) .. ")"
end

local function NormalizeEventType(raw)
  if type(raw) == "number" then
    return raw
  end
  if type(raw) ~= "string" then
    return nil
  end
  local s = raw:lower():gsub("_", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if s == "invite" or s == "invited" or s == "invitation" then
    return EVENT_INVITE
  end
  if s == "join" or s == "joined" or s == "member joined" then
    return EVENT_JOIN
  end
  if s == "leave" or s == "left" or s == "quit" or s == "member left" then
    return EVENT_QUIT
  end
  if s == "promote" or s == "promoted" or s == "rank up" then
    return EVENT_PROMOTE
  end
  if s == "demote" or s == "demoted" or s == "rank down" then
    return EVENT_DEMOTE
  end
  if s == "uninvite" or s == "uninvited" or s == "remove" or s == "removed" or s == "kick" or s == "kicked" then
    return EVENT_UNINVITE
  end
  if s == "sign on" or s == "signed on" or s == "login" then
    return EVENT_SIGN_ON
  end
  if s == "sign off" or s == "signed off" or s == "logout" then
    return EVENT_SIGN_OFF
  end
  if s == "motd" or s == "motd changed" then
    return EVENT_MOTD
  end
  return nil
end

-- Two conventions observed:
--   * Absolute: year >= 1970 and month 1-12 → time({year, month, day, hour})
--   * Relative: year=0 and month=0 → day=daysAgo, hour=hoursAgo
local function SafeEventTime(year, month, day, hour, index)
  if (year or 0) >= 1970 and (month or 0) >= 1 and (month or 0) <= 12 and (day or 0) >= 1 and (day or 0) <= 31 then
    local t = time({
      year = year,
      month = month,
      day = day,
      hour = hour or 0,
      min = 0,
      sec = 0,
    })
    if t then
      return t
    end
  end

  if (year or 0) == 0 and (month or 0) == 0 then
    local totalHoursAgo = (day or 0) * 24 + (hour or 0)
    if totalHoursAgo >= 0 and totalHoursAgo < 87600 then
      return time() - totalHoursAgo * 3600
    end
  end

  return time() - ((index or 1) - 1) * 60
end

-- Class-colored name.
local function FormatPlayerName(name, cache)
  if not name or name == "" then
    return "?"
  end
  if cache and cache.classFileName and RAID_CLASS_COLORS[cache.classFileName] then
    local c = RAID_CLASS_COLORS[cache.classFileName]
    return string.format("|cff%02x%02x%02x%s|r", c.r * 255, c.g * 255, c.b * 255, name)
  end
  return name
end

local function BuildLogDetails(eventType, name1, name2, rank)
  local cache1 = name1 and GirudoDB.playerCache[name1]
  local cache2 = name2 and GirudoDB.playerCache[name2]

  if eventType == EVENT_JOIN then
    local lvl = (cache1 and cache1.level) or "?"
    return FormatPlayerName(name1, cache1) .. " (lvl " .. tostring(lvl) .. ") joined the guild"
  elseif eventType == EVENT_QUIT then
    local lvl = (cache1 and cache1.level) or "?"
    local rk = (cache1 and cache1.rank) or "?"
    return FormatPlayerName(name1, cache1) .. " (lvl " .. tostring(lvl) .. " " .. tostring(rk) .. ") left the guild"
  elseif eventType == EVENT_PROMOTE or eventType == EVENT_DEMOTE then
    -- On this server: name1 = the actor (promoter / demoter),
    --                 name2 = the target (promoted / demoted).
    local actor = name1 or "?"
    local target = name2 or "?"
    local actorCache = cache1
    local targetCache = cache2
    local newRank = rank or "?"
    local oldRank = "?"

    -- Derive the old rank index from the target's cached rankIndex. That
    -- index is unambiguous even when two ranks share a name.
    local oldRankIndex
    if targetCache and targetCache.rankIndex and Girudo.rankByIndex then
      local cachedIndexName = Girudo.rankByIndex[targetCache.rankIndex]
      if cachedIndexName == newRank then
        -- Cache is current: cached rank == new rank. Promote moves toward
        -- lower indices (0 = GM), demote moves toward higher.
        if eventType == EVENT_PROMOTE then
          oldRankIndex = targetCache.rankIndex + 1
        else
          oldRankIndex = targetCache.rankIndex - 1
        end
      else
        -- Cache is stale: cached rankIndex is the OLD index already.
        oldRankIndex = targetCache.rankIndex
      end
    else
      -- No cached rankIndex: fall back to first index matching the new
      -- rank name. Ambiguous with duplicate names but the best we can do.
      local fallbackIndex = Girudo.indexByRank and Girudo.indexByRank[newRank]
      if fallbackIndex then
        if eventType == EVENT_PROMOTE then
          oldRankIndex = fallbackIndex + 1
        else
          oldRankIndex = fallbackIndex - 1
        end
      end
    end

    if oldRankIndex and Girudo.rankByIndex then
      local derived = Girudo.rankByIndex[oldRankIndex]
      if derived and derived ~= "" then
        oldRank = derived
      end
    end

    if oldRank == "?" and targetCache and targetCache.rank and targetCache.rank ~= newRank then
      oldRank = targetCache.rank
    end

    local verb = (eventType == EVENT_PROMOTE) and "promoted" or "demoted"
    return FormatPlayerName(actor, actorCache)
      .. " "
      .. verb
      .. " "
      .. FormatPlayerName(target, targetCache)
      .. " from "
      .. tostring(oldRank)
      .. " to "
      .. tostring(newRank)
  elseif eventType == EVENT_INVITE then
    local invitee = name2 or "?"
    local inviter = name1 or "?"
    return FormatPlayerName(inviter, cache1) .. " invited " .. FormatPlayerName(invitee, cache2)
  elseif eventType == EVENT_UNINVITE then
    -- Same convention as promote/demote on this server: name1 = actor,
    -- name2 = target. So the kicker is name1, the kicked player is name2.
    local kicker = name1 or "?"
    local kicked = name2 or "?"
    local kickerCache = cache1
    local kickedCache = cache2
    local lvl = (kickedCache and kickedCache.level) or "?"
    local rk = (kickedCache and kickedCache.rank) or "?"
    return FormatPlayerName(kicker, kickerCache)
      .. " kicked "
      .. FormatPlayerName(kicked, kickedCache)
      .. " (lvl "
      .. tostring(lvl)
      .. " "
      .. tostring(rk)
      .. ") from the guild"
  elseif eventType == EVENT_SIGN_ON or eventType == EVENT_SIGN_OFF then
    return FormatPlayerName(name1, cache1)
  elseif eventType == EVENT_MOTD then
    return name1 or ""
  elseif eventType == EVENT_PUBLIC_NOTE or eventType == EVENT_OFFICER_NOTE then
    local who = name1 or "?"
    local newNote = name2 or ""
    local oldNote = "?"
    if cache1 then
      local cached
      if eventType == EVENT_PUBLIC_NOTE then
        cached = cache1.publicNote
      else
        cached = cache1.officerNote
      end
      if cached and cached ~= newNote then
        oldNote = cached
      end
    end
    local changerName = UnitName("player") or "You"
    local changerCache = GirudoDB.playerCache[changerName]
    return FormatPlayerName(changerName, changerCache)
      .. ": "
      .. FormatPlayerName(who, cache1)
      .. ' - "'
      .. tostring(oldNote)
      .. '" → "'
      .. tostring(newNote)
      .. '"'
  end

  return tostring(name1 or "") .. " " .. tostring(name2 or "")
end

local function AddLogEntry(entry)
  local list = GirudoDB.logEntries
  local key
  if entry.rawKey then
    key = entry.rawKey
  else
    key = tostring(entry.time) .. "|" .. tostring(entry.eventType) .. "|" .. (entry.detailKey or "")
  end
  for i = #list, 1, -1 do
    local existing = list[i]
    if existing.key == key then
      -- Backfill seq for entries recorded before this fix existed.
      if not existing.seq and entry.seq then
        existing.seq = entry.seq
      end
      return false
    end
  end
  entry.key = key
  table.insert(list, entry)
  local MAX_ENTRIES = 2000
  while #list > MAX_ENTRIES do
    table.remove(list, 1)
  end
  return true
end

function Girudo:ScanGuildLog()
  if not IsInGuild() then
    return
  end
  GirudoDB.logEntries = GirudoDB.logEntries or {}
  GirudoDB.playerCache = GirudoDB.playerCache or {}

  local numEvents = GetNumGuildEvents()
  if not numEvents or numEvents == 0 then
    self:UpdateLogDisplay()
    return
  end

  local changed = false
  local scanTime = time()
  for i = 1, numEvents do
    local rawType, name1, name2, rank, year, month, day, hour = GetGuildEventInfo(i)
    local eventType = NormalizeEventType(rawType)
    -- Skip Signed On / Signed Off entirely. They are not surfaced in the
    -- filter UI, so logging them would produce entries that cannot be
    -- hidden by the user.
    if eventType == EVENT_SIGN_ON or eventType == EVENT_SIGN_OFF then
      eventType = nil
    end
    if eventType then
      local eventTime = SafeEventTime(year, month, day, hour, i)
      local detailText = BuildLogDetails(eventType, name1, name2, rank)
      local rawKey = table.concat({
        tostring(rawType),
        tostring(year or 0),
        tostring(month or 0),
        tostring(day or 0),
        tostring(hour or 0),
        tostring(name1 or ""),
        tostring(name2 or ""),
        tostring(rank or ""),
      }, "|")
      if
        AddLogEntry({
          time = eventTime,
          eventType = eventType,
          action = ActionLabel(eventType),
          details = detailText,
          detailKey = tostring(name1 or "") .. "|" .. tostring(name2 or ""),
          rawKey = rawKey,
          -- Position within the API response. On this server i=1 is the
          -- OLDEST entry, so the index is added rather than subtracted:
          -- higher i (newer event) yields a higher seq.
          seq = scanTime * 10000 + i,
        })
      then
        changed = true
      end
    end
  end

  if changed then
    table.sort(GirudoDB.logEntries, function(a, b)
      if a.time == b.time then
        return (a.eventType or 0) > (b.eventType or 0)
      end
      return a.time > b.time
    end)
  end

  self:UpdateLogDisplay()
end

function Girudo:RefreshGuildLog()
  if IsInGuild() then
    QueryGuildEventLog()
  end
end

local function RecordNoteChange(eventType, index, newNote)
  if not IsInGuild() then
    return
  end
  GirudoDB.logEntries = GirudoDB.logEntries or {}
  GirudoDB.playerCache = GirudoDB.playerCache or {}
  newNote = newNote or ""

  -- Live roster is authoritative: at hook time, GetGuildRosterInfo still
  -- reflects the pre-change note because the server round-trip has not
  -- yet landed. Read both note fields in one call.
  local name, _, _, _, _, _, liveNote, liveOfficerNote = GetGuildRosterInfo(index)
  if not name then
    return
  end

  local oldNote
  if eventType == EVENT_PUBLIC_NOTE then
    oldNote = liveNote
  else
    oldNote = liveOfficerNote
  end

  -- If live matched the new note (e.g. the client optimistically updated),
  -- fall back to the last-scanned cache value.
  if not oldNote or oldNote == newNote then
    local cache = GirudoDB.playerCache[name]
    if cache then
      local cached
      if eventType == EVENT_PUBLIC_NOTE then
        cached = cache.publicNote
      else
        cached = cache.officerNote
      end
      if cached and cached ~= newNote then
        oldNote = cached
      end
    end
  end

  local displayOld = (oldNote and oldNote ~= "") and oldNote or "?"
  local cache = GirudoDB.playerCache[name]

  local changerName = UnitName("player") or "You"
  local changerCache = GirudoDB.playerCache[changerName]
  local details = FormatPlayerName(changerName, changerCache)
    .. ": "
    .. FormatPlayerName(name, cache)
    .. ' - "'
    .. tostring(displayOld)
    .. '" → "'
    .. tostring(newNote)
    .. '"'

  AddLogEntry({
    time = time(),
    eventType = eventType,
    action = ActionLabel(eventType),
    details = details,
    detailKey = name .. "|" .. tostring(newNote),
    rawKey = "note|" .. tostring(eventType) .. "|" .. time() .. "|" .. name .. "|" .. tostring(newNote),
    seq = time() * 10000,
  })

  if cache then
    if eventType == EVENT_PUBLIC_NOTE then
      cache.publicNote = newNote
    else
      cache.officerNote = newNote
    end
  end
  Girudo:UpdateLogDisplay()
end

pcall(function()
  hooksecurefunc("GuildRosterSetPublicNote", function(i, n)
    RecordNoteChange(EVENT_PUBLIC_NOTE, i, n)
  end)
end)
pcall(function()
  hooksecurefunc("GuildRosterSetOfficerNote", function(i, n)
    RecordNoteChange(EVENT_OFFICER_NOTE, i, n)
  end)
end)

function Girudo:SetLogSort(key)
  if self.logSortKey == key then
    self.logSortAscending = not self.logSortAscending
  else
    self.logSortKey = key
    self.logSortAscending = (key ~= "date")
  end
  self:UpdateLogDisplay()
end

local function GetLogSortValue(entry, key)
  if key == "date" then
    return entry.time
  end
  if key == "action" then
    return entry.action
  end
  if key == "details" then
    return entry.details
  end
  return entry.time
end

function Girudo:UpdateLogDisplay()
  GirudoDB.logEntries = GirudoDB.logEntries or {}

  local term = logSearchBox:GetText():lower()
  local filtered = {}

  for _, e in ipairs(GirudoDB.logEntries) do
    local passes = true

    -- Action-type filter (checkbox panel).
    if not Girudo.logFilter[e.eventType] then
      passes = false
    end

    -- Text search filter.
    if passes then
      local haystack = (e.action or "") .. " " .. (e.details or "")
      if term ~= "" and not haystack:lower():find(term, 1, true) then
        passes = false
      end
    end

    if passes then
      table.insert(filtered, e)
    end
  end

  local key = self.logSortKey
  local asc = self.logSortAscending
  table.sort(filtered, function(a, b)
    local av = GetLogSortValue(a, key)
    local bv = GetLogSortValue(b, key)
    if av == bv then
      -- Same-value entries: preserve Blizzard's API order (higher seq first,
      -- because seq=1 is the newest entry in the list).
      return (a.seq or 0) > (b.seq or 0)
    end
    if asc then
      return av < bv
    else
      return av > bv
    end
  end)

  for k, btn in pairs(logHeaderButtons) do
    if k == key then
      btn.arrow:SetText(asc and "↑" or "↓")
    else
      btn.arrow:SetText("")
    end
  end

  local numEntries = #filtered
  FauxScrollFrame_Update(logScrollFrame, numEntries, NUM_ROWS, ROW_HEIGHT)
  local offset = FauxScrollFrame_GetOffset(logScrollFrame)

  for i = 1, NUM_ROWS do
    local idx = offset + i
    local row = logRows[i]
    if idx <= numEntries then
      local e = filtered[idx]
      row.cells[1]:SetText(date("%Y-%m-%d %H:%M", e.time or 0))
      row.cells[1]:SetTextColor(1, 1, 1)

      row.cells[2]:SetText(e.action or "")
      local ac = ACTION_COLORS[e.eventType]
      if ac then
        row.cells[2]:SetTextColor(ac[1], ac[2], ac[3])
      else
        row.cells[2]:SetTextColor(1, 0.82, 0)
      end

      row.cells[3]:SetText(e.details or "")
      row.cells[3]:SetTextColor(1, 1, 1)
      row:Show()
    else
      row:Hide()
    end
  end
end

-- ===========================================================================
-- 9. Periodic refresh
-- ===========================================================================
local updateTimer = 0
frame:SetScript("OnUpdate", function(self, elapsed)
  if not self:IsShown() then
    updateTimer = 0
    return
  end
  updateTimer = updateTimer + elapsed
  if updateTimer >= 30 then
    updateTimer = 0
    Girudo:ScanRoster()
  end
end)

-- ===========================================================================
-- 10. Default guild frame hook
-- ===========================================================================
local function HookGuildFrame()
  if not GuildFrame or GuildFrame.girudoHooked then
    return
  end
  GuildFrame.girudoHooked = true

  GuildFrame:HookScript("OnShow", function()
    GirudoFrame:Show()
    if ns.activePage == 0 then
      ns.ShowPage(3)
    end
    Girudo:ScanRoster()
  end)

  GuildFrame:HookScript("OnHide", function()
    GirudoFrame:Hide()
    if GirudoMemberPopup then
      GirudoMemberPopup:Hide()
    end
  end)

  if GuildFrame:IsShown() then
    GirudoFrame:Show()
    if ns.activePage == 0 then
      ns.ShowPage(3)
    end
    Girudo:ScanRoster()
  end
end

-- ===========================================================================
-- 11. Events
-- ===========================================================================
Girudo:RegisterEvent("ADDON_LOADED")
Girudo:RegisterEvent("PLAYER_ENTERING_WORLD")
Girudo:RegisterEvent("GUILD_ROSTER_UPDATE")
Girudo:RegisterEvent("PLAYER_GUILD_UPDATE")
Girudo:RegisterEvent("GUILD_EVENT_LOG_UPDATE")

Girudo:SetScript("OnEvent", function(self, event, arg1)
  if event == "ADDON_LOADED" and arg1 == "Blizzard_GuildUI" then
    HookGuildFrame()
  elseif event == "PLAYER_ENTERING_WORLD" then
    GirudoDB = GirudoDB or {}
    GirudoDB.lastSeenOnline = GirudoDB.lastSeenOnline or {}
    if IsAddOnLoaded("Blizzard_GuildUI") then
      HookGuildFrame()
    end
    Girudo:UpdateHeader()
  elseif event == "GUILD_ROSTER_UPDATE" then
    HookGuildFrame()
    Girudo:ScanRoster()
    -- If the Log tab is visible, re-merge so note changes appear promptly.
    if ns.activePage == 1 and Girudo.ScanGuildLog then
      Girudo:ScanGuildLog()
    end
  elseif event == "PLAYER_GUILD_UPDATE" then
    Girudo:UpdateHeader()
  elseif event == "GUILD_EVENT_LOG_UPDATE" then
    Girudo:ScanGuildLog()
  end
end)

hooksecurefunc("SetGuildRosterShowOffline", function()
  if not GirudoFrame then
    return
  end
  -- The original function has already updated GUILD_ROSTER_SHOW_OFFLINE,
  -- so this reflects the new state immediately, without waiting for the
  -- GUILD_ROSTER_UPDATE that may not fire when nothing else changed.
  Girudo:UpdateWarning()
  if GirudoFrame:IsShown() then
    Girudo:UpdateRosterDisplay()
  end
end)

-- ===========================================================================
-- 12. Slash command
-- ===========================================================================
SLASH_GIRUDO1 = "/girudo"
SlashCmdList["GIRUDO"] = function()
  ToggleFriendsFrame(3)
end

-- ===========================================================================
-- 13. Initialise active page
-- ===========================================================================
ns.activePage = 0
ns.ShowPage(3)
