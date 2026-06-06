STACKSIZE	equ $1000

	org $f80000

_start:
	dc.l	0
	dc.l	__entry

__args:
        dc.b    "SoC",0

__dummyint:
	rte
	cnop 0,4
	ds.l	60,0 ; Leave space for interrupt vectors

__entry:
	lea $dff180,a0
	lea $bfe001,a1
	moveq #0,d0
	moveq #0,d1
.loop
	move.w d0,(a0)
	move.b (a1),d1
	eor.w d1,d0
	addq.w #1,d0
	bra.s .loop
