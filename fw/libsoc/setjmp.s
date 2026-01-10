;	// setjmp() / longjmp() implementation for 68k
	
; int setjmp(__reg("a0") jmp_buf env);

	XDEF _setjmp
_setjmp:
	lea 48(a0),a0
	movem.l a2-7/d2-7,-(a0)
	moveq	#0,d0
	rts	


; int longjmp(__reg("a0") jmp_buf env, __reg("d0") int val);

	XDEF _longjmp
_longjmp:
	movem.l (a0)+,a2-7/d2-7
	rts

