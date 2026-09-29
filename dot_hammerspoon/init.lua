-- ============================================================
-- iPhone Mirroring always-on-top
-- ============================================================
local function keepiPhoneMirroringOnTop()
    local app = hs.application.get("com.apple.ScreenContinuity")
    if app then
        local win = app:mainWindow()
        if win then
            win:setLevel(hs.window.levels.floating)
        end
    end
end

-- Run when Hammerspoon starts
keepiPhoneMirroringOnTop()

-- Run whenever windows change
hs.window.filter.new('iPhone Mirroring')
    :subscribe(hs.window.filter.windowFocused, keepiPhoneMirroringOnTop)
    :subscribe(hs.window.filter.windowCreated, keepiPhoneMirroringOnTop)
