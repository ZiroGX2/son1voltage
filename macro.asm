
; =============================================================
; Joypad button indexes & values
; For theld and tpress macros
; -------------------------------------------------------------
iStart		equ 	7
iA		equ 	6
iB		equ 	5
iC		equ 	4
iRight		equ 	3
iLeft		equ 	2
iDown		equ 	1
iUp		equ 	0

Start		equ 	1<<7
A		equ 	1<<6
C		equ 	1<<5
B		equ 	1<<4
Right		equ 	1<<3
Left		equ 	1<<2
Down		equ 	1<<1
Up		equ 	1

SonicControl	equ	$FFFFF602
Joypad		equ	$FFFFF604

Held		equ	0
Press		equ	1

*$FFFFF602	SonicControl|Held
*$FFFFF603	SonicControl|Press
*$FFFFF604	Joypad|Held
*$FFFFF605	Joypad|Press

; =============================================================
; Macro to check button presses
; Arguments:	1 - buttons to check
;		2 - bitfield to check
; -------------------------------------------------------------
tpress	macro
	move.b	(\2+1),d0
	andi.b	#\1,d0
	endm

; =============================================================
; Macro to check if buttons are held
; Arguments:	1 - buttons to check
;		2 - bitfield to check
; -------------------------------------------------------------
theld	macro
	move.b	\2,d0
	andi.b	#\1,d0
	endm

; =============================================================
; Macro to align data
; Arguments:	1 - align value
; -------------------------------------------------------------
align	macro
	cnop 0,\1
	endm

; =============================================================
; Macro to set VRAM write access
; Arguments:	1 - raw VRAM offset
;		2 - register to write access bitfield in (Optional)
; -------------------------------------------------------------
vram	macro
	if (narg=1)
		move.l	#($40000000+((\1&$3FFF)<<16)+((\1&$C000)>>14)),($C00004).l
	else
		move.l	#($40000000+((\1&$3FFF)<<16)+((\1&$C000)>>14)),\2
	endc
	endm

; =============================================================
; Macro to raise an error in vectors
; Arguments:	1 - error number
;		2 - branch location
;		3 - if exists, adds 2 to stack pointer
; -------------------------------------------------------------
raise	macro
	move.b	#\1,($FFFFFC44).w
	if narg=3
		addq.l	#2,2(sp)
	endc
	bra.s	\2
	endm
	
	; simplifying macros

; tells the VDP to copy a region of 68k memory to VRAM or CRAM or VSRAM
dma68kToVDP macro source,dest,length,type
	lea	(VDP_control_port).l,a5
	move.l	#(($9400|((((length)>>1)&$FF00)>>8))<<16)|($9300|(((length)>>1)&$FF)),(a5)
	move.l	#(($9600|((((source)>>1)&$FF00)>>8))<<16)|($9500|(((source)>>1)&$FF)),(a5)
	move.w	#$9700|(((((source)>>1)&$FF0000)>>16)&$7F),(a5)
	move.w	#((dest)&$3FFF)|((type&1)<<15)|$4000,(a5)
	move.w	#$80|(((dest)&$C000)>>14)|((type&2)<<3),(DMA_data_thunk).w
	move.w	(DMA_data_thunk).w,(a5)
    endm
    ; values for the type argument
    ;enum VRAM=0,CRAM=1,VSRAM=2

; tells the VDP to fill a region of VRAM with a certain byte
dmaFillVRAM macro byte,addr,length
	lea	(VDP_control_port).l,a5
	move.w	#$8F01,(a5) ; VRAM pointer increment: $0001
	move.l	#(($9400|((((length)-1)&$FF00)>>8))<<16)|($9300|(((length)-1)&$FF)),(a5) ; DMA length ...
	move.w	#$9780,(a5) ; VRAM fill
	move.l	#$40000080|(((addr)&$3FFF)<<16)|(((addr)&$C000)>>14),(a5) ; Start at ...
	move.w	#(byte)<<8,(VDP_data_port).l ; Fill with byte
-	move.w	(a5),d1
	btst	#1,d1
	bne.s	- ; busy loop until the VDP is finished filling...
	move.w	#$8F02,(a5) ; VRAM pointer increment: $0002
    endm

; calculates initial loop counter value for a dbf loop
; that writes n bytes total at 4 bytes per iteration
;bytesToLcnt function n,n>>2-1

; fills a region of 68k RAM with 0 (4 bytes at a time)
clearRAM macro addr,length
    if length&3
	fatal "clearRAM len must be divisible by 4, but was length"
    endif
	lea	(addr).w,a1
	moveq	#0,d0
	move.w	#bytesToLcnt(length),d1
-	move.l	d0,(a1)+
	dbf	d1,-
    endm

; tells the Z80 to stop, and waits for it to finish stopping (acquire bus)
stopZ80 macro
	move.w	#$100,(Z80_Bus_Request).l ; stop the Z80
-	btst	#0,(Z80_Bus_Request).l
	bne.s	- ; loop until it says it's stopped
    endm

; tells the Z80 to start again
startZ80 macro
	move.w	#0,(Z80_Bus_Request).l    ; start the Z80
    endm

; function to make a little-endian 16-bit pointer for the Z80 sound driver
;z80_ptr function x,(x)<<8&$FF00|(x)>>8&$7F|$80

; macro to declare a little-endian 16-bit pointer for the Z80 sound driver
rom_ptr_z80 macro addr
		dc.w z80_ptr(addr)
	endm