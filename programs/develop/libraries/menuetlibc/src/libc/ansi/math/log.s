/* Copyright (C) 1994 DJ Delorie, see COPYING.DJ for details */
#include<libc/asm.h>
MK_C_SYM(log)
	fldln2
	fldl	4(%esp)
	fyl2x
	ret
