local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs

local codeSnippetsFrame
local topPane, codePane, bottomPane, renameEB, newBtn, errorPopup
local buttons = {}
local selected
local LoadList, LoadSnippet, RunSnippet

local function CreateCodeSnippetsFrame()
    codeSnippetsFrame = Cell:CreateMovableFrame("Cell "..L["Code Snippets"], "CellCodeSnippetsFrame", 640, 550, "HIGH")
    Cell.frames.codeSnippetsFrame = codeSnippetsFrame
    codeSnippetsFrame:SetToplevel(true)
    codeSnippetsFrame:SetPoint("CENTER")

    P:SetEffectiveScale(codeSnippetsFrame)

    local tips = Cell:CreateScrollTextFrame(codeSnippetsFrame, "|cffb7b7b7"..L["SNIPPETS_TIPS"])
    tips:SetPoint("TOPLEFT", 10, -10)
    tips:SetPoint("TOPRIGHT", -10, -10)

    -- rename box
    renameEB = Cell:CreateEditBox(codeSnippetsFrame, 20, 20)
    Cell:StylizeFrame(renameEB, {0.115, 0.115, 0.115, 0.9}, Cell:GetAccentColorTable())
    renameEB:Hide()
    renameEB:SetScript("OnEscapePressed", function()
        renameEB:Hide()
    end)
    renameEB:SetScript("OnHide", function()
        renameEB:Hide()
    end)

    -- top
    topPane = CreateFrame("Frame", nil, codeSnippetsFrame, "BackdropTemplate")
    -- Cell:StylizeFrame(topPane, {0,1,0,0.1}, {0,0,0,0})
    topPane:SetPoint("TOPLEFT", 10, -40)
    topPane:SetPoint("TOPRIGHT", -10, -40)
    topPane:SetHeight(20)

    -- add
    newBtn = Cell:CreateButton(topPane, "", "accent-hover", {155, 20})
    newBtn.tex = newBtn:CreateTexture(nil, "ARTWORK")
    newBtn.tex:SetPoint("CENTER")
    newBtn.tex:SetSize(12, 12)
    newBtn.tex:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\add.tga")
    newBtn:SetScript("OnClick", function()
        tinsert(CellDB["snippets"], {
            ["name"] = L["unnamed"],
            ["autorun"] = false,
            ["code"] = "\n\n", -- NOTE: FAIAP
        })
        LoadList()
    end)

    -- bottom
    bottomPane = CreateFrame("Frame", nil, codeSnippetsFrame, "BackdropTemplate")
    -- Cell:StylizeFrame(bottomPane, {0,1,0,0.1}, {0,0,0,0})
    bottomPane:SetPoint("BOTTOMLEFT", 10, 10)
    bottomPane:SetPoint("BOTTOMRIGHT", -10, 10)
    bottomPane:SetHeight(20)

    local runBtn = Cell:CreateButton(bottomPane, L["Run"], "red", {200, 20})
    bottomPane.runBtn = runBtn
    runBtn:SetPoint("BOTTOMLEFT")
    runBtn:SetEnabled(false)
    runBtn:SetScript("OnClick", function()
        local errorMsg = RunSnippet(codePane:GetText())
        if errorMsg then
            errorPopup.text:SetText(errorMsg)
            errorPopup.count = 1
            errorPopup:SetScript("OnUpdate", function(self, elapsed)
                errorPopup.count = errorPopup.count + 1
                errorPopup:SetHeight(errorPopup.text:GetStringHeight() + 40)
                if errorPopup.count >= 5 then
                    errorPopup:SetScript("OnUpdate", nil)
                end
            end)
            errorPopup:Show()
        end
    end)

    local discardBtn = Cell:CreateButton(bottomPane, L["Discard"], "red", {200, 20})
    bottomPane.discardBtn = discardBtn
    discardBtn:SetPoint("BOTTOMRIGHT")
    discardBtn:SetEnabled(false)
    discardBtn:SetScript("OnClick", function()
        codePane:SetText(CellDB["snippets"][selected]["code"])
        discardBtn:SetEnabled(false)
        bottomPane.saveBtn:SetEnabled(false)
    end)
    
    local saveBtn = Cell:CreateButton(bottomPane, L["Save"], "red", {200, 20})
    bottomPane.saveBtn = saveBtn
    saveBtn:SetPoint("BOTTOMLEFT", runBtn, "BOTTOMRIGHT", 10, 0)
    saveBtn:SetPoint("BOTTOMRIGHT", discardBtn, "BOTTOMLEFT", -10, 0)
    saveBtn:SetEnabled(false)
    saveBtn:SetScript("OnClick", function()
        CellDB["snippets"][selected]["code"] = codePane:GetText()
        saveBtn:SetEnabled(false)
        bottomPane.discardBtn:SetEnabled(false)
    end)

    -- current line number
    local lineNumber = codeSnippetsFrame.header:CreateFontString(nil, "OVERLAY", "CELL_FONT_CLASS")
    lineNumber:SetPoint("LEFT", 5, 0)

    -- code
    codePane = Cell:CreateScrollEditBox(codeSnippetsFrame, nil, 3)
    codePane.scrollFrame:SetScrollStep(1000)
    codePane.eb:SetEnabled(false)
    codePane.eb:SetFontObject(ChatFontNormal)
    Cell:StylizeFrame(codePane.scrollFrame, {0.115, 0.115, 0.115, 0.9})
    codePane:SetPoint("TOPLEFT", topPane, "BOTTOMLEFT", 0, -10)
    codePane:SetPoint("BOTTOMRIGHT", bottomPane, "TOPRIGHT", 0, 10)
    codePane.eb:SetSpacing(3)

    codePane.eb:HookScript("OnTextChanged", function(self, userChanged)
        if selected then
            local changed =  CellDB["snippets"][selected]["code"] ~= codePane:GetText()
            saveBtn:SetEnabled(changed)
            discardBtn:SetEnabled(changed)
        end
    end)

    codePane.eb:SetScript("OnEditFocusGained", function()
        lineNumber:Show()
    end)
    codePane.eb:SetScript("OnEditFocusLost", function()
        lineNumber:Hide()
    end)

    codePane.OriginalGetText = codePane.eb.GetText -- NOTE: FAIAP overrides GetText
    codePane.eb:HookScript("OnCursorChanged", function(self, x, y)
        if not codePane.eb:HasFocus() then return end

        local cursorPosition = codePane.eb:GetCursorPosition()
        local next = -1
        local line = 0
        while (next and cursorPosition >= next) do
            next = codePane.OriginalGetText(codePane.eb):find("[\n]", next + 1)
            line = line + 1
        end
        
        lineNumber:SetText(line)
    end)
    
    -- NOTE: indentation
    Cell.IndentationLib.enable(codePane.eb)

    -- errorPopup
    errorPopup = CreateFrame("Frame", nil, codePane, "BackdropTemplate")
    errorPopup:SetFrameStrata("DIALOG")
    Cell:StylizeFrame(errorPopup, {0.15, 0.1, 0.1, 0.95})
    errorPopup:SetWidth(200)
    errorPopup:SetPoint("BOTTOMLEFT")
    errorPopup:SetPoint("BOTTOMRIGHT")
    errorPopup:Hide()

    errorPopup.close = Cell:CreateButton(errorPopup, "×", "red", {18, 18}, false, false, "CELL_FONT_SPECIAL", "CELL_FONT_SPECIAL")
    errorPopup.close:SetPoint("TOPRIGHT")
    errorPopup.close:SetScript("OnClick", function()
        errorPopup:Hide()
    end)

    errorPopup.text = errorPopup:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    errorPopup.text:SetTextColor(1, 0.19, 0.19)
    errorPopup.text:SetPoint("TOPLEFT", 20, -20)
    errorPopup.text:SetPoint("TOPRIGHT", -20, -20)
    errorPopup.text:SetJustifyH("LEFT")
    errorPopup.text:SetWordWrap(true)
    errorPopup.text:SetSpacing(3)
end

LoadList = function()
    for i, t in ipairs(CellDB["snippets"]) do
        if not buttons[i] then
            local width
            if i % 4 == 0 then
                width = 155
            else
                width = 156
            end

            buttons[i] = Cell:CreateButton(topPane, "", "accent-hover", {width, 20})
            buttons[i].id = i -- for highlight
            
            -- rename
            buttons[i]:SetScript("OnDoubleClick", function()
                renameEB:ClearAllPoints()
                renameEB:SetAllPoints(buttons[i])
                renameEB:SetFrameLevel(buttons[i]:GetFrameLevel()+7)
                renameEB:SetText(CellDB["snippets"][i]["name"])
                renameEB:Show()
                renameEB:SetFocus(true)
                renameEB:SetScript("OnEnterPressed", function()
                    renameEB:Hide()
                    CellDB["snippets"][i]["name"] = strtrim(renameEB:GetText())
                    buttons[i].label:SetText(i.."."..CellDB["snippets"][i]["name"])
                end)
            end)
            
            -- checkbox
            buttons[i].cb = Cell:CreateCheckButton(buttons[i], "", function(checked)
                CellDB["snippets"][i]["autorun"] = checked
            end)
            buttons[i].cb:SetPoint("LEFT", 3, 0)
            buttons[i].cb:HookScript("OnEnter", function()
                buttons[i]:GetScript("OnEnter")(buttons[i])
            end)
            buttons[i].cb:HookScript("OnLeave", function()
                buttons[i]:GetScript("OnLeave")(buttons[i])
            end)

            -- delete
            buttons[i].del = CreateFrame("Button", nil, buttons[i])
            buttons[i].del:SetPoint("RIGHT", -1, 0)
            buttons[i].del:SetSize(12, 12)
            buttons[i].del.tex = buttons[i].del:CreateTexture(nil, "ARTWORK")
            buttons[i].del.tex:SetAllPoints(buttons[i].del)
            buttons[i].del.tex:SetTexture("Interface\\AddOns\\Cell\\Media\\Icons\\close.tga")
            buttons[i].del.tex:SetVertexColor(0.4, 0.4, 0.4, 1)
            buttons[i].del:SetScript("OnEnter", function()
                buttons[i]:GetScript("OnEnter")(buttons[i])
                buttons[i].del.tex:SetVertexColor(1, 1, 1, 1)
            end)
            buttons[i].del:SetScript("OnLeave", function()
                buttons[i]:GetScript("OnLeave")(buttons[i])
                buttons[i].del.tex:SetVertexColor(0.4, 0.4, 0.4, 1)
            end)
            buttons[i].del:SetScript("OnClick", function()
                if IsShiftKeyDown() then
                    tremove(CellDB["snippets"], i)
                    if selected then
                        if selected == i then -- delete selected
                            selected = nil
                        elseif selected > i then -- before selected
                            selected = selected - 1
                        end
                    end
                    LoadList()
                end
            end)
            
            -- label
            buttons[i].label = buttons[i]:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
            buttons[i].label:SetPoint("LEFT", buttons[i].cb, "RIGHT", 3, 0)
            buttons[i].label:SetPoint("RIGHT", buttons[i].del, "LEFT", -3, 0)
            buttons[i].label:SetJustifyH("LEFT")
            buttons[i].label:SetWordWrap(false)

            -- tooltip
            buttons[i].ShowTooltip = function()
                if buttons[i].label:IsTruncated() then
                    CellTooltip:SetOwner(buttons[i], "ANCHOR_NONE")
                    CellTooltip:SetPoint("BOTTOMLEFT", buttons[i], "TOPLEFT", 0, 1)
                    CellTooltip:AddLine(buttons[i].label:GetText())
                    CellTooltip:Show()
                end
            end
            buttons[i].HideTooltip = function()
                CellTooltip:Hide()
            end
        end
        
        buttons[i].cb:SetChecked(t["autorun"])
        buttons[i].label:SetText(i.."."..t["name"])

        buttons[i]:ClearAllPoints()
        if i == 1 then
            buttons[i]:SetPoint("TOPLEFT")
        elseif i % 4 == 1 then
            buttons[i]:SetPoint("TOPLEFT", buttons[i-4], "BOTTOMLEFT", 0, 1)
        else
            buttons[i]:SetPoint("TOPLEFT", buttons[i-1], "TOPRIGHT", -1, 0)
        end

        buttons[i]:Show()
    end

    -- update NEW button
    local total = #CellDB["snippets"]
    if total == 0 then
        newBtn:ClearAllPoints()
        newBtn:SetPoint("TOPLEFT")
        newBtn:Show()
    elseif total == 20 then
        newBtn:ClearAllPoints()
        newBtn:Hide()
    elseif total % 4 == 0 then
        newBtn:ClearAllPoints()
        newBtn:SetPoint("TOPLEFT", buttons[total-3], "BOTTOMLEFT", 0, 1)
        newBtn:Show()
    else
        newBtn:ClearAllPoints()
        newBtn:SetPoint("TOPLEFT", buttons[total], "TOPRIGHT", -1, 0)
        newBtn:Show()
    end

    -- highlight
    local Highlight = Cell:CreateButtonGroup(buttons, function(index)
        renameEB:Hide()
        errorPopup:Hide()
        LoadSnippet(index)
    end)

    if selected then
        Highlight(selected)
    else
        Highlight()
        bottomPane.saveBtn:SetEnabled(false)
        bottomPane.discardBtn:SetEnabled(false)
        bottomPane.runBtn:SetEnabled(false)
        codePane:SetEnabled(false)
        codePane:SetText("")
        errorPopup:Hide()
    end

    -- update height
    local rows
    if total == 20 then
        rows = 5
    else
        rows = math.ceil((total+1) / 4)
    end
    topPane:SetHeight(rows*20 - (rows-1))
    
    -- update scroll
    codePane.scrollFrame:UpdateSize()

    -- hide spare buttons
    for i = total+1, #buttons do
        buttons[i]:ClearAllPoints()
        buttons[i]:Hide()
    end
end

LoadSnippet = function(index)
    if selected ~= index then
        selected = index
        codePane:SetText(CellDB["snippets"][index]["code"])
        codePane:SetEnabled(true)
        bottomPane.runBtn:SetEnabled(true)
        bottomPane.saveBtn:SetEnabled(false)
        bottomPane.discardBtn:SetEnabled(false)
    end
end

RunSnippet = function(snippet)
    -- https://wowpedia.fandom.com/wiki/API_loadstring
    local func, errorMessage = loadstring(snippet)
    if (not func) then
        return errorMessage
    end
    local success, errorMessage = pcall(func)
    if (not success) then
        return errorMessage
    end
end

function F:ShowCodeSnippets()
    if not codeSnippetsFrame then
        CreateCodeSnippetsFrame()
        LoadList()
    end

    if codeSnippetsFrame:IsShown() then
        codeSnippetsFrame:Hide()
    else
        codeSnippetsFrame:Show()
    end
end

function F:RunSnippets()
    for i, t in pairs(CellDB["snippets"]) do
        if t["autorun"] then
            local errorMsg = RunSnippet(t["code"])
            if errorMsg then
                F:Print("|cFFFF3030Snippet Error ("..i.."."..t["name"].."):|r "..errorMsg)
            end
        end
    end
end