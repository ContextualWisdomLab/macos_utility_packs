-- Built-in macOS Sebeolsik toggle for Hammerspoon.
-- The Korean input source must first be enabled in System Settings.

local koreanMethod = os.getenv("MACOS_AI_KOREAN_INPUT_METHOD") or "3-Set Korean (390)"
local englishLayout = os.getenv("MACOS_AI_ENGLISH_INPUT_LAYOUT") or "ABC"
local leftShiftDown = false

local function toggleInputSource()
  if hs.keycodes.currentMethod() == koreanMethod then
    if not hs.keycodes.setLayout(englishLayout) then
      hs.alert.show("English input source not enabled: " .. englishLayout)
    end
  else
    if not hs.keycodes.setMethod(koreanMethod) then
      hs.alert.show("Korean input source not enabled: " .. koreanMethod)
    end
  end
end

macosAiImeFlagsTap = hs.eventtap.new(
  {hs.eventtap.event.types.flagsChanged},
  function(event)
    local keyCode = event:getKeyCode()
    if keyCode == 56 then
      leftShiftDown = event:getFlags().shift == true
    end
    return false
  end
)

macosAiImeSpaceTap = hs.eventtap.new(
  {hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp},
  function(event)
    local keyCode = event:getKeyCode()
    if keyCode == 49 and leftShiftDown then
      if event:getType() == hs.eventtap.event.types.keyDown then
        toggleInputSource()
      end
      return true
    end
    return false
  end
)

macosAiImeFlagsTap:start()
macosAiImeSpaceTap:start()
