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

-- ===========================================================================
-- 3. Constants
-- ===========================================================================
local FRAME_WIDTH = 980
local FRAME_HEIGHT = 566
local ROW_HEIGHT = 14
local NUM_ROWS = 28
local SCROLLBAR_PAD = 25
local ICON_SIZE = 12

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
  rows[i] = row
end

local statusBar = CreateFrame("Frame", "GirudoStatusBar", frame)
statusBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 12, 12)
statusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
statusBar:SetHeight(20)

local warningText = statusBar:CreateFontString("GirudoStatusBarText", "OVERLAY", "GameFontNormal")
warningText:SetAllPoints(statusBar)
warningText:SetJustifyH("CENTER")
warningText:SetTextColor(1, 0.2, 0.2)
warningText:Hide()

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

      row:Show()
    else
      row:Hide()
    end
  end

  self:UpdateSortArrows()
  self:UpdateWarning()
  self:UpdateHeader()
end

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
  elseif event == "PLAYER_GUILD_UPDATE" then
    Girudo:UpdateHeader()
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
