	section start,code
	global __bss_start__
	global __bss_end__
	global __premain

	xref ___CTOR_LIST__
	xref ___DTOR_LIST__

STACKSIZE	equ $1000

_start:

	; Set stack
	lea		__bss_end__,a7
	add.l	#STACKSIZE,a7
	
	; Disable interrupts
	move.w	#$2700,sr

	; Clear bss
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

	; Set up interrupt vectors...
	lea	.int1,a0
	move.l	a0,$64
	lea	.int2,a0
	move.l	a0,$68
	lea	.int3,a0
	move.l	a0,$6C
	lea	.int4,a0
	move.l	a0,$70
	lea	.int5,a0
	move.l	a0,$74
	lea	.int6,a0
	move.l	a0,$78
	lea	.int7,a0
	move.l	a0,$7C

	; Execute constructors...
	lea ___CTOR_LIST__+4,a6 ; First entry is a count
	bsr .ctordtor

	; Execute _premain()
	jsr __premain

	; Execute destructors...
	lea ___DTOR_LIST__+4,a6 ; First entry is a count
	bsr .ctordtor
	
	; Infinite loop
.end:
	bra.s	.end

.ctordtor:
	move.l 	(a6)+,d0
	beq .done
	move.l	d0,a0
	jsr	(a0)
	bra	.ctordtor
.done
	rts	

.int1:
	movem.l	d0-7/a0-6,-(a7)	; Preserve scratch registers
	pea	.intend1	; A stub to restore the scratch registers
	move.l	_IntHandler1,-(a7)	; equivalent to move.l IntHandler1,reg; jmp reg - without using registers
	rts

.int2:
	movem.l	d0-7/a0-6,-(a7)	; Preserve scratch registers
	pea	.intend1
	move.l	_IntHandler2,-(a7)
	rts

.int3:
	movem.l	d0-7/a0-6,-(a7)	; Preserve scratch registers
	pea	.intend1
	move.l	_IntHandler3,-(a7)
	rts

.int4:
	movem.l	d0-7/a0-6,-(a7)	; Preserve scratch registers
	pea	.intend1
	move.l	_IntHandler4,-(a7)
	rts

.int5
	movem.l	d0-7/a0-6,-(a7)	; Preserve scratch registers
	pea	.intend1
	move.l	_IntHandler5,-(a7)
	rts

.int6
	movem.l	d0-7/a0-6,-(a7)	; Preserve scratch registers
	pea	.intend1
	move.l	_IntHandler6,-(a7)
	rts

.int7
	movem.l	d0-7/a0-6,-(a7)	; Preserve scratch registers
	pea	.intend1
	move.l	_IntHandler7,-(a7)
	rts

.intend1
	movem.l	(a7)+,d0-d7/a0-a6
	rte

DummyIntHandler
	rts

; Interrupt handler table, modified by C code.
	xdef _IntHandler1
_IntHandler1	dc.l	DummyIntHandler
_IntHandler2 dc.l	DummyIntHandler
_IntHandler3 dc.l	DummyIntHandler
_IntHandler4 dc.l	DummyIntHandler
_IntHandler5 dc.l	DummyIntHandler
_IntHandler6 dc.l	DummyIntHandler
_IntHandler7 dc.l	DummyIntHandler
	weak _EnableInterrupts
_EnableInterrupts ; FIXME - use a trap or suchlike to make this happen even if we're in user mode.
	move.w	#$2000,SR
	rts

	weak _DisableInterrupts
_DisableInterrupts
	move.w	#$2700,SR
	rts

