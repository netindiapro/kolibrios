if tup.getconfig("NO_FASM") ~= "" then return end
tup.rule("2.Cyclops.asm", 'fasm "%f" "%o" ' .. tup.getconfig("KPACK_CMD"), "2.Cyclops.skn")
