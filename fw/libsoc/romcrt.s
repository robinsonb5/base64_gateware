	section start,code
	global __bss_start__
	global __bss_end__
	global _main

	xref ___CTOR_LIST__

STACKSIZE	equ $1000
_start:
	dc.l	0
	dc.l	__entry
__args:
	dc.b	"SoC",0
__dummyint:
	rte
	cnop 0,4
	ds.l	60,0 ; Leave space for interrupt vectors

__entry:
	; Set stack
	lea		__bss_end__,a7
	add.l	#STACKSIZE,a7

	; Initialise interrupts.
	move.w	#$2700,sr	; Disable interrupts
	; Set dummy interrupt handlers
	lea	__dummyint,a0
	move.l	a0,$64
	move.l	a0,$68
	move.l	a0,$6C
	move.l	a0,$70
	move.l	a0,$74
	move.l	a0,$78
	move.l	a0,$7C

	; clear bss
    lea.l   __bss_start__,a0
    move.l  #__bss_end__,d0
    sub.l	a0,d0
    move.l	d0,d1
    lsr.l	#2,d1
    and.l	#3,d0
    moveq	#0,d2
.l1:
	move.l	#0,(a0)+
	dbf		d1,.l1
.l2:
	move.b	#0,(a0)+
	dbf		d0,.l2

	; Execute constructors...
	lea ___CTOR_LIST__+4,a6 ; First entry is a count
	bsr .ctordtor

	; Execute main()
	pea	__args
	pea	0
	jsr _main

.end:
	; Execute destructors...
	lea ___DTOR_LIST__+4,a6 ; First entry is a count
	bsr .ctordtor

	bra.s	.end

.ctordtor:
	move.l 	(a6)+,d0
	beq .done
	move.l	d0,a0
	jsr	(a0)
	bra	.ctordtor
.done
	rts	


