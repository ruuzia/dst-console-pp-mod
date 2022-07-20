local WordPredictionWidget = require "widgets/wordpredictionwidget"
local Button = require "widgets/button"
local Image = require "widgets/image"
local ImageButton = require "widgets/imagebutton"
local G = GLOBAL

local FONT_SIZE = 22
local PADDING = 10
local CHATFONT, UICOLOURS = G.CHATFONT, G.UICOLOURS
local DEBUG_SHOW_MAX_WITH = false

local function build_prediction_buttons(self, display_start)
    local Vector3 = Point
	self.prediction_btns = {}
	--self.active_prediction_btn = nil
	self.prediction_root:KillAllChildren()

    self:Show()
    self:Enable()

    local prediction = self.word_predictor.prediction
    local offset = self.starting_offset

    for match_index = display_start+1, #prediction.matches do
        local display_index = match_index - display_start
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

	self.right_arrow:SetPosition(offset, 0)
    self.backing:SetSize(offset, self.sizey + 4)
end

local function update_arrow_texture(self)
    --self.left_arrow:SetTexture
end

local function scroll_left(self)
    self._cpm_base_index = math.max(0, self._cpm_base_index - self.active_prediction_btn)
    build_prediction_buttons(self, self._cpm_base_index)
    self.active_prediction_btn = #self.prediction_btns
    self.prediction_btns[self.active_prediction_btn]:Select()
end

local function scroll_right(self)
    self._cpm_base_index = self._cpm_base_index + self.active_prediction_btn
    build_prediction_buttons(self, self._cpm_base_index)
    self.active_prediction_btn = 1
    self.prediction_btns[self.active_prediction_btn]:Select()
end

Hook(WordPredictionWidget, "RefreshPredictions", function (orig, self)
    orig(self)
    self.right_arrow:SetPosition((self.backing:GetSize()), 0)
end)


Hook(WordPredictionWidget, "_ctor", function (orig, self, ...)
    self._cpm_base_index = 0
    orig(self, ...)

    local root = next(self.children)

	local left_arrow = root:AddChild(ImageButton("images/global_redux.xml", "arrow2_left_down.tex"))
	left_arrow:SetOnClick(function() scroll_left(self) end)
	left_arrow:SetScale(.5)
	left_arrow:SetPosition(-15, 0)
    self.left_arrow = left_arrow

	local right_arrow = root:AddChild(ImageButton("images/global_redux.xml", "arrow2_right_down.tex"))
	right_arrow:SetOnClick(function() scroll_right(self) end)
	right_arrow:SetScale(.5)
	right_arrow:SetPosition(0, 0) -- set in button generation
    self.right_arrow = right_arrow
end)

AssertDefinitionSource(WordPredictionWidget, "OnRawKey", "widgets/wordpredictionwidget")
function WordPredictionWidget:OnRawKey(key, down)
	if key == KEY_BACKSPACE or key == KEY_DELETE then
		self.active_prediction_btn = nil
		self:RefreshPredictions()
		return false  -- do not consume the key press

	elseif self.word_predictor.prediction ~= nil then
		if key == KEY_TAB then
			return self.tab_complete
		elseif key == KEY_ENTER then
			return self.enter_complete
		elseif key == KEY_LEFT and not self:IsMouseOnly() then
			if down then
                if self.active_prediction_btn > 1 then
                    self.prediction_btns[self.active_prediction_btn - 1]:Select()
                --- new ---
                elseif self._cpm_base_index > 0 then
                    scroll_left(self)
                end
                -----------
			end
			return true
		elseif key == KEY_RIGHT and not self:IsMouseOnly() then
			if down then
                if self.active_prediction_btn < #self.prediction_btns then
                    self.prediction_btns[self.active_prediction_btn + 1]:Select()
                --- new ---
                elseif #self.word_predictor.prediction.matches > self.active_prediction_btn + self._cpm_base_index then
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


Hook(WordPredictionWidget, "ResolvePrediction", function (orig, self, prediction_index)
	return orig(self, prediction_index + self._cpm_base_index)
end)
