-- Modified just to support completing with cursor in middle of word

setfenv(1, ConsolePP.env)

local WordPredictor = require "util/wordpredictor"
AssertDefinitionSource(WordPredictor, "Apply", "scripts/util/wordpredictor.lua")
function WordPredictor:Apply(prediction_index)
    -- COPY PASTED
	local new_text = nil
	local new_cursor_pos = nil
	if self.prediction ~= nil then
		local new_word = self.prediction.matches[math.clamp(prediction_index or 1, 1, #self.prediction.matches)]

		new_text = self.text:sub(1, self.prediction.start_pos) .. new_word .. self.prediction.dictionary.postfix
		new_cursor_pos = #new_text

        --[[OLD]]--local endpos = FindEndCursorPos(self.text, self.cursor_pos)
		--[[NEW]]local endpos = self.prediction.start_pos + (delim and #delim or 0)
		local remainder_text = self.text:sub(endpos+1) or ""
		local remainder_strip_pos = remainder_text:find("[^a-zA-Z0-9_]") or (#remainder_text + 1)
		if self.prediction.dictionary.postfix ~= "" and remainder_text:sub(remainder_strip_pos, remainder_strip_pos + (#self.prediction.dictionary.postfix-1)) == self.prediction.dictionary.postfix then
			remainder_strip_pos = remainder_strip_pos + #self.prediction.dictionary.postfix
		end

		new_text = new_text .. remainder_text:sub(remainder_strip_pos)
	end

	self:Clear()
	return new_text, new_cursor_pos
end

