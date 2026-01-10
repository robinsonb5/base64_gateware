
;	// char *strcpy(__reg("a0") char *dst,__reg("a1") const char *src);

	section	CODE
	global	___strcpy
___strcpy:
	move.l	a0,d0
.loop
	move.b	(a1)+,(a0)+
	bne	.loop
	rts


;	// char *strncpy(__reg("a0") char *dst,__reg("a1") const char *src,__reg("d0") size_t size);

	section	CODE
	global	___strncpy
___strncpy:
	move.l	d0,d1
	beq	.end
	move.l	a0,d0
.loop
	move.b	(a1)+,(a0)+
	dbeq	d0,.loop
.tail
	tst	d0
	beq	.end
.tailloop
	move.b #0,(a0)+
	dbf	d0,.tailloop
.end
	move.l	d1,d0
	rts


;	// char *memcpy(__reg("a0") char *dst,__reg("a1") const char *src,__reg("d0") size_t size);

	section CODE
	global ___memcpy
___memcpy:
	move.l	a0,d1
	tst.l	d0
	beq	.done
.loop
	move.b	(a1)+,(a0)+
	dbf	d0,.loop
.done
	move	d1,d0
	rts


;	// size_t strlen(__reg("a0" const char *);

	section	CODE
	global	___strlen
___strlen:
	moveq	#0,d0
.loop
	addq	#1,d0
	move.b	(a0)+,d1
	bne	.loop
	subq	#1,d0
	rts

;	int strcmp(__reg("a0") const char *s1,__reg("a1") const char *s2)
	section CODE
	global	___strcmp
___strcmp:
	moveq	#0,d0
	moveq	#0,d1
.loop
	move.b	(a0)+,d0
	beq	.tail
	move.b	(a1)+,d1
	sub.l	d1,d0
	beq	.loop
	rts
.tail
	moveq #0,d0
	move.b	(a1)+,d0
	rts


;	int strcasecmp(__reg("a0") const char *s1,__reg("a1") const char *s2)
	section CODE
	global	___strcasecmp
___strcasecmp:
	moveq	#0,d0
	moveq	#0,d1
.loop
	move.b	(a0)+,d0
	beq	.tail
	move.b	(a1)+,d1
	and.b	#$df,d0
	and.b	#$df,d1	
	sub.l	d1,d0
	beq	.loop
	rts
.tail
	moveq	#0,d0
	move.b	(a1)+,d0
	rts


;	int strncmp(__reg("a0") const char *s1,__reg("a1") const char *s2,__reg("d0") int n)
	section CODE
	global	___strncmp
___strncmp:
	move.l	d2,-(a7)
	move.l	d0,d2
	beq	.exit
	
	moveq	#0,d0
	moveq	#0,d1
.loop
	move.b	(a0)+,d0
	beq	.tail
	move.b	(a1)+,d1
	sub.l	d1,d0
	bne	.exit
	subq	#1,d2
	bne	.loop
.exit
	move.l	(a7)+,d2
	rts
.tail
	moveq	#0,d0
	move.b	(a1)+,d0
	bra .exit


;	int strncasecmp(__reg("a0") const char *s1,__reg("a1") const char *s2,__reg("d0") int n)
	section CODE
	global	___strncasecmp
___strncasecmp:
	move.l	d2,-(a7)
	move.l	d0,d2
	beq	.exit
	
	moveq	#0,d0
	moveq	#0,d1
.loop
	move.b	(a0)+,d0
	beq	.tail
	move.b	(a1)+,d1
	and.b	#$df,d0
	and.b	#$df,d1	
	sub.l	d1,d0
	bne	.exit
	subq	#1,d2
	bne	.loop
.exit
	move.l	(a7)+,d2
	rts
.tail
	moveq	#0,d0
	move.b	(a1)+,d0
	bra .exit

;	int memset(__reg("a0") const char *d,__reg("d0") int c,__reg("d1") int n)
	global ___memset
___memset:
	move.l	a0,a1
	subq #1,d1
	beq	.exit
.loop
	move.b d0,(a0)+
	dbf d1,.loop
.exit
	rts
	
