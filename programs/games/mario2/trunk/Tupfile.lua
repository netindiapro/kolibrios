if tup.getconfig("NO_FASM") ~= "" then return end
tup.rule("MARIO.ASM", "fasm %f %o " .. tup.getconfig("KPACK_CMD"), "MARIO")
