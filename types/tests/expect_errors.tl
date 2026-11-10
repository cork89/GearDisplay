-- Every line marked with the ERR marker must produce exactly one type error.
-- types/check.sh counts them; a mismatch means the declarations got looser or stricter.

local f = CreateFrame("Frame")
f:SetFrameStrata("NOPE")                              -- ERR (not a FrameStrata)
f:SetPoint("MIDDLE")                                  -- ERR (not a FramePoint)
f:Bogus()                                             -- ERR (unknown method)
f:SetScript("OnBogus", function() end)                -- ERR (unknown script)
local b = CreateFrame("Button")
b:SetScript("OnClick", function(_: Button, x: number) print(x) end) -- ERR (button arg is a string)
C_Item.NoSuchFunction()                               -- ERR (unknown C API)
local t = C_Timer.NewTimer(1, function() end)
t:Nope()                                              -- ERR (FunctionContainer has no Nope)
