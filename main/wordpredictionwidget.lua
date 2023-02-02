local WordPredictionWidget = require "widgets/wordpredictionwidget"
local Button = require "widgets/button"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local G = GLOBAL

local FONT_SIZE = 22
local PADDING = 10
local CHATFONT, UICOLOURS = G.CHATFONT, G.UICOLOURS
local DEBUG_SHOW_MAX_WITH = false
local WICKERBOTTOM_REFRESH_RELEASED = CurrentRelease.GreaterOrEqualTo("R23_REFRESH_WICKERBOTTOM")

local function build_prediction_buttons(self, start_index)
    local Vector3 = Point
	self.prediction_btns = {}
	--self.active_prediction_btn = nil
	self.prediction_root:KillAllChildren()

    self:Show()
    self:Enable()

    local prediction = self.word_predictor.prediction
    -- WICKERBOTTOM_REFRESH_RELEASED
    local offset = self.starting_offset or self.starting_offset_x

    for match_index = start_index, #prediction.matches do
        local display_index = match_index - start_index + 1
        local str = self.word_predictor:GetDisplayInfo(match_index)

        local btn = self.prediction_root:AddChild(Button())
        btn:SetFont(CHATFONT)
        btn:SetDisabledFont(CHATFONT)
        btn:SetTextColour(UICOLOURS.GOLD_CLICKABLE)
        btn:SetTextFocusColour(UICOLOURS.GOLD_CLICKABLE)
        btn:SetTextSelectedColour(UICOLOURS.GOLD_FOCUS)
        btn:SetText(str)
        btn:SetTextSize(FONT_SIZE)
        btn.clickoffset = Vector3(0,0,0)

        btn.bg = btn:AddChild(Image("images/ui.xml", "blank.tex"))
        --btn.bg = btn:AddChild(Image("images/global.xml", "square.tex"))
        local w,h = btn.text:GetRegionSize()
        btn.bg:ScaleToSize(w, h)
        btn.bg:SetPosition(0,0)
        btn.bg:MoveToBack()

        -- temp fix inject match_index
        btn._match_index = match_index

        btn:SetOnClick(function() if self.active_prediction_btn ~= nil then self.text_edit:ApplyWordPrediction(self.active_prediction_btn) end end)
        btn:SetOnSelect(function() if self.active_prediction_btn ~= nil and self.active_prediction_btn ~= display_index then self.prediction_btns[self.active_prediction_btn]:Unselect() end self.active_prediction_btn = display_index end)
        btn.ongainfocus = function() btn:Select() end
        btn.AllowOnControlWhenSelected = true

        if self:IsMouseOnly() then
            btn.onlosefocus = function() if btn.selected then btn:Unselect() self.active_prediction_btn = nil end end
        end

        local sx, sy = btn.text:GetRegionSize()
        btn:SetPosition(sx * 0.5 + offset, 0)

        if offset + sx > self.max_width then
            if DEBUG_SHOW_MAX_WITH then
                offset = self.max_width
            end
            btn:Kill()
            break
        else
            offset = offset + sx + PADDING

            table.insert(self.prediction_btns, btn)
            if prev_active_prediction ~= nil and btn.name == prev_active_prediction then
                self.active_prediction_btn = display_index
            end
        end
    end

	self.cpm_right_arrow:SetPosition(offset, 0)
    self.backing:SetSize(offset, self.sizey + 4)
end

local function update_arrow_texture(self)
    if not self.word_predictor.prediction then return end
    local nummatches = #self.word_predictor.prediction.matches
    local numbuttons = #self.prediction_btns
    local start = self.start_index

    if nummatches >= start + numbuttons then self.cpm_right_arrow:Enable() else self.cpm_right_arrow:Disable() end

    if start > 1 then self.cpm_left_arrow:Enable() else self.cpm_left_arrow:Disable() end
end

local scroll_left, scroll_right
if WICKERBOTTOM_REFRESH_RELEASED then
    scroll_left = function (self)
        -- Setting active index to nil so RefreshPredictions defaults to 1
        self.active_prediction_btn = nil
        self.scrollleft_btn.onclick()
    end
    scroll_right  = function (self)
        self.scrollright_btn.onclick()

        if self.active_prediction_btn then
            local buttons = self.prediction_btns
            local selected_index = self.active_prediction_btn

            buttons[selected_index]:Unselect()

            selected_index = math.min(#buttons, selected_index + 1)

            buttons[selected_index]:Select()

            self.active_prediction_btn = selected_index
        end
        --self.active_prediction_btn = #self.prediction_btns
    end

else
    scroll_left = function (self)
        if not self.active_prediction_btn then return end
        self.start_index = math.max(1, self.start_index - self.active_prediction_btn)
        build_prediction_buttons(self, self.start_index)
        self.active_prediction_btn = #self.prediction_btns
        self.prediction_btns[self.active_prediction_btn]:Select()
        update_arrow_texture(self)
    end
    scroll_right = function (self)
        if not self.active_prediction_btn then return end
        self.start_index = self.start_index + self.active_prediction_btn
        build_prediction_buttons(self, self.start_index)
        self.active_prediction_btn = 1
        self.prediction_btns[self.active_prediction_btn]:Select()
        update_arrow_texture(self)
    end
end

if not WICKERBOTTOM_REFRESH_RELEASED then
    Hook(WordPredictionWidget, "RefreshPredictions", function (orig, self, ...)
        orig(self, ...)
        self.start_index = 0
        if self.word_predictor.prediction then
            self.active_prediction_btn = not self:IsMouseOnly() and 1 or nil
            self.cpm_right_arrow:SetPosition((self.backing:GetSize()), 0)
            update_arrow_texture(self)
        end
    end)

    Hook(WordPredictionWidget, "_ctor", function (orig, self, ...)
        self.start_index = 1
        orig(self, ...)

        local root = next(self.children)

        local left_arrow = root:AddChild(ImageButton("images/global_redux.xml", "arrow2_left.tex", "arrow2_left_over.tex", "arrow_left_disabled.tex", "arrow2_left_down.tex", nil, {0.5,0.5}, {0,0}))
        left_arrow:SetOnClick(function() scroll_left(self) end)
        left_arrow:SetPosition(-15, 0)
        self.cpm_left_arrow = left_arrow

        local right_arrow = root:AddChild(ImageButton("images/global_redux.xml", "arrow2_right.tex", "arrow2_right_over.tex", "arrow_right_disabled.tex", "arrow2_right_down.tex", nil, {0.5,0.5}, {0,0}))
        right_arrow:SetOnClick(function() scroll_right(self) end)
        right_arrow:SetPosition(0, 0) -- set in button generation
        self.cpm_right_arrow = right_arrow
    end)

    Hook(WordPredictionWidget, "ResolvePrediction", function (orig, self, prediction_index)
        return orig(self, self.prediction_btns[prediction_index]._match_index)
    end)

else
    Hook(WordPredictionWidget, "_ctor", function (orig, self, ...)
        orig(self, ...)
        self.scrollright_btn.AllowOnControlWhenSelected = true
        self.scrollleft_btn.AllowOnControlWhenSelected = true
    end)
end


AssertDefinitionSource(WordPredictionWidget, "OnRawKey", "scripts/widgets/wordpredictionwidget.lua")
function WordPredictionWidget:OnRawKey(key, down)
	if key == KEY_BACKSPACE or key == KEY_DELETE then
		self.active_prediction_btn = nil
        -- Wait till text is updated
		self.inst:DoTaskInTime(0, function() self:RefreshPredictions() end)
		return false  -- do not consume the key press

	elseif self.word_predictor.prediction ~= nil then
		if key == KEY_TAB then
			return self.tab_complete
		elseif key == KEY_ENTER then
			return self.enter_complete
		elseif key == KEY_LEFT and not self:IsMouseOnly() then
			if down and self.active_prediction_btn then
                if self.active_prediction_btn > 1 then
                    self.prediction_btns[self.active_prediction_btn - 1]:Select()
                --- new ---
                elseif self.start_index > 1 then
                    scroll_left(self)
                end
                -----------
			end
			return true
		elseif key == KEY_RIGHT and not self:IsMouseOnly() then
			if down and self.active_prediction_btn then
                if self.active_prediction_btn < #self.prediction_btns then
                    self.prediction_btns[self.active_prediction_btn + 1]:Select()
                --- new ---
                elseif #self.word_predictor.prediction.matches > #self.prediction_btns + self.start_index then
                    scroll_right(self)
                end
                -----------
			end
			return true
		elseif key == KEY_ESCAPE then
			return true
		end
	end

	return false
end


