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
	move.b #3,$bfe201	; Set OVL and LED to output
	move.b #$fe,$bfe001

	lea $7fffc,a7 ; initial stack pointer

	lea $10000,a0
	move.l #320*256/2,d0
	bsr doblit
	bsr waitblit

	bsr	fillplanes
	bsr setplayfields

	; repeatedly fill memory with a pattern
	moveq #0,d7
.loop
	bsr testblit
	bne .skipblit
	lea $10000,a0
	move.l #320*256/2,d0
	bsr doblit
.skipblit
	bsr fillplanes
	addq #1,d7
	bra.s .loop

	; repeatedly update the colour 0 register
	moveq #0,d0
	moveq #0,d1
	move.w d5,(a0)
	move.b $bfe001,d1
	or.w #$bf,d1
	eor.w d1,d5
	addq.w #1,d5
	bra.s .loop

fillplanes:
	lea $10000,a0
	move.l #320*256/4,d6
	move.l d7,d0
.fillloop
	add.w d0,(a0)+
	addq #1,d0
	btst #6,$bfe001
	bne .black
	move.w #$fff,$dff180
	bra .skip
.black
	move.w #$000,$dff180
.skip
	dbf d6,.fillloop
	rts

doblit:


setplayfields:
	lea $dff000,a0
	move.w #$c200,$100(a0)
	move.w #0,$102(a0)
	move.w #0,$104(a0)
	move.w #0,$106(a0)
	move.w #0,$108(a0)
	move.w #$38,$92(a0)
	move.w #$d0,$94(a0)
	move.w #$2c81,$8e(a0)
	move.w #$2cc1,$90(a0)
	move.w #$0fff,$182(a0)

	move.l #$10000,$e0(a0)

	lea $20000,a1
	move.l a1,$80(a0)
	lea copperlist,a2
.copyloop
	move.l (a2),(a1)+
	cmp.l #$fffffffe,(a2)+
	bne .copyloop

    move.w #0,$88(a0)

	move.w #$87c0,$dff096 ; Blitter nasty, Blitter, Bitplane and Copper DMA
	rts

copperlist:
	dc.w $182,$f00
	dc.w $184,$0f0
	dc.w $186,$00f
	dc.w $188,$ff0

	dc.w $18a,$0ff
	dc.w $18c,$f0f
	dc.w $18e,$f70
	dc.w $190,$0f7

	dc.w $192,$70f
	dc.w $194,$7f0
	dc.w $196,$07f
	dc.w $198,$f07

	dc.w $19a,$000
	dc.w $19c,$333
	dc.w $19a,$777
	dc.w $19c,$ccc

	dc.w $e0,$0001	; bplptr1 to $10000
	dc.w $e2,$0000
	dc.w $e4,$0001	; bplptr1 to $11000
	dc.w $e6,$2000
	dc.w $e8,$0001	; bplptr1 to $12000
	dc.w $ea,$4000
	dc.w $ec,$0001	; bplptr1 to $13000
	dc.w $ee,$6000
	dc.w $ffff,$fffe

testblit:
	moveq #0,d0
	move.b $dff002,d0
	move.b $dff002,d0
	and.b #$40,d0
	rts

waitblit:
        btst.b  #6,$dff002 ; DMACONR(a1)
.waitblit2
        btst.b  #6,$dff002 ; DMACONR(a1)
        bne     .waitblit2
        rts
; a0 - address to be cleared
; d0 - number of bytes to clear (must be even)

clearmem:
        lea     $dff000,a1      ; Get pointer to chip registers
        bsr     waitblit        ; Make sure previous blit is done
        move.l  a0,$dff054      ; Set up the D pointer to the region to clear
        clr.w   $dff066         ; Clear the D modulo (don't skip no bytes)
        asr.l   #1,d0           ; Get number of words from number of bytes
        clr.w   $dff042         ; No special modes
        move.w  #$100,$dff040   ; only enable destination
;
;   First we deal with the smaller blits
;
        moveq   #$3f,d1         ; Mask out mod 64 words
        and.w   d0,d1
        beq     dorest          ; none?  good, do one blit
        sub.l   d1,d0           ; otherwise remove remainder
        or.l    #$40,d1         ; set the height to 1, width to n
        move.w  d1,$dff058      ; trigger the blit
;
;   Here we do the rest of the words, as chunks of 128k
;
dorest:
        move.w  #$ffc0,d1       ; look at some more upper bits
        and.w   d0,d1           ; extract 10 more bits
        beq     dorest2         ; any to do?
        sub.l   d1,d0           ; pull of the ones we're doing here
        bsr     waitblit        ; wait for prev blit to complete
        move.w  d0,$dff058      ; do another blit
dorest2:
        swap    d0              ; more?
        beq     done            ; nope.
        clr.w   d1              ; do a 1024x64 word blit (128K)
keepon:
        bsr     waitblit        ; finish up this blit
        move.w  d1,$dff058      ; and again, blit
        subq.w  #1,d0           ; still more?
        bne     keepon          ; keep on going.
done:
        rts                     ; finished.  Blit still in progress.
        end
