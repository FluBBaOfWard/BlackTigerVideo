// Capcom BlackTigerVideo Chip emulation

#ifdef __arm__

#ifdef GBA
#include "../Shared/gba_asm.h"
#elif NDS
#include "../Shared/nds_asm.h"
#endif
#include "../Equates.h"
#include "BlackTigerVideo.i"

	.global blkTgrInit
	.global blkTgrReset
	.global blkTgrSaveState
	.global blkTgrLoadState
	.global blkTgrGetStateSize
	.global doScanline
	.global preparePalette
	.global convertChrMapBlkTgr
	.global convertBgrMapBlkTgr
	.global convertSpritesBlkTgr
	.global blkTgrRamCD_R
	.global blkTgrRamEF_R
	.global blkTgrRamCD_W
	.global blkTgrRamEF_W
	.global blkTgrIOWrite


	.syntax unified
	.arm

#ifdef GBA
	.section .ewram, "ax"		;@ For the GBA
#else
	.section .text
#endif
	.align 2
;@----------------------------------------------------------------------------
blkTgrInit:					;@ Only need to be called once
;@----------------------------------------------------------------------------
	mov r1,#0xffffff00			;@ Build chr decode tbl
	ldr r2,=CHR_DECODE			;@ 0x400
ppi:
	mov r0,#0
	tst r1,#0x01
	orreq r0,r0,#0x2000
	tst r1,#0x02
	orreq r0,r0,#0x0200
	tst r1,#0x04
	orreq r0,r0,#0x0020
	tst r1,#0x08
	orreq r0,r0,#0x0002
	tst r1,#0x10
	orreq r0,r0,#0x1000
	tst r1,#0x20
	orreq r0,r0,#0x0100
	tst r1,#0x40
	orreq r0,r0,#0x0010
	tst r1,#0x80
	orreq r0,r0,#0x0001
	str r0,[r2],#4
	adds r1,r1,#1
	bne ppi

	bx lr
;@----------------------------------------------------------------------------
blkTgrReset:				;@ r0=IRQ(frameIrqFunc), r1= RAM
;@----------------------------------------------------------------------------
	stmfd sp!,{r0,r1,lr}

	mov r0,btptr
	ldr r1,=blkTgrSize/4
	bl memclr_					;@ Clear VDP state

	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#-1
	stmia btptr,{r0-r2}			;@ Reset scanline, nextChange & lineState

//	mov r0,#-1
	str r0,[btptr,#gfxReload]
	mov r0,#16
	strb r0,[btptr,#paletteSlots]

	ldmfd sp!,{r0,r1}

	cmp r0,#0
	adreq r0,dummyIrqFunc
	str r0,[btptr,#frameIrqFunc]

	str r1,[btptr,#gfxRAM]
	add r1,r1,#0x4000-0x1000
	str r1,[btptr,#ramPage1]
	add r1,r1,#0x2000
	str r1,[btptr,#ramPage2]
	add r1,r1,#0x2000
	str r1,[btptr,#chrBlockLUT]
	add r1,r1,#CHRBLOCKCOUNT*4
	str r1,[btptr,#bgrBlockLUT]
	add r1,r1,#BGRBLOCKCOUNT*4
	str r1,[btptr,#sprBlockLUT]
	add r1,r1,#SPRBLOCKCOUNT*4
	str r1,[btptr,#palBlockLUT]

	bl updateBanks

	ldmfd sp!,{lr}
dummyIrqFunc:
	bx lr

;@----------------------------------------------------------------------------
updateBanks:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldrb r0,[btptr,#btGfxBank]
	bl switchGfxBankW
	ldmfd sp!,{lr}
	ldrb r0,[btptr,#btRomBank]
	b blkTgrMapper
;@----------------------------------------------------------------------------
blkTgrSaveState:		;@ In r0=destination, r1=btptr. Out r0=state size.
	.type   blkTgrSaveState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r4,r0					;@ Store destination
	mov r5,r1					;@ Store btptr (r1)

	ldr r1,[r5,#gfxRAM]
	mov r2,#0x7000
	bl memcpy

	add r0,r4,#0x7000
	add r1,r5,#blkTgrRegs
	mov r2,#0x10
	bl memcpy

	ldmfd sp!,{r4,r5,lr}
	ldr r0,=0x7010
	bx lr
;@----------------------------------------------------------------------------
blkTgrLoadState:		;@ In r0=btptr, r1=source. Out r0=state size.
	.type   blkTgrLoadState STT_FUNC
;@----------------------------------------------------------------------------
	stmfd sp!,{r4,r5,lr}
	mov r5,r0					;@ Store btptr (r0)
	mov r4,r1					;@ Store source

	ldr r0,[r5,#gfxRAM]
	mov r2,#0x7000
	bl memcpy

	add r0,r5,#blkTgrRegs
	add r1,r4,#0x7000
	mov r2,#0x10
	bl memcpy

	mov r0,#-1
	str r0,[r5,#gfxReload]
	mov btptr,r5				;@ Restore btptr (r12)
	bl updateBanks
	bl refreshGfx

	ldmfd sp!,{r4,r5,lr}
;@----------------------------------------------------------------------------
blkTgrGetStateSize:			;@ Out r0=state size.
	.type   blkTgrGetStateSize STT_FUNC
;@----------------------------------------------------------------------------
	ldr r0,=0x7010
	bx lr

;@----------------------------------------------------------------------------
blkTgrRamCD_R:				;@ Ram read (0xC000-0xDFFF)
;@----------------------------------------------------------------------------
	movs r1,r1,lsl#19
	ldrpl r2,[btptr,#ramPage0]
	ldrmi r2,[btptr,#ramPage1]
	ldrb r0,[r2,r1,lsr#19]
	bx lr
;@----------------------------------------------------------------------------
blkTgrRamEF_R:				;@ Ram read (0xE000-0xFFFF)
;@----------------------------------------------------------------------------
	mov r1,r1,lsl#19
	ldr r2,[btptr,#ramPage2]
	ldrb r0,[r2,r1,lsr#19]
	bx lr

;@----------------------------------------------------------------------------
blkTgrRamCD_W:				;@ Ram write (0xC000-0xDFFF)
;@----------------------------------------------------------------------------
	movs r1,r1,lsl#19
	ldrpl r2,[btptr,#ramPage0]
	ldrmi r2,[btptr,#ramPage1]
	strb r0,[r2,r1,lsr#19]
	add r2,btptr,#dirtyMem
	mov r0,#-1
	strb r0,[r2,r1,lsr#30]
	bx lr
;@----------------------------------------------------------------------------
blkTgrRamEF_W:				;@ Ram write (0xE000-0xFFFF)
;@----------------------------------------------------------------------------
	mov r1,r1,lsl#19
	ldr r2,[btptr,#ramPage2]
	strb r0,[r2,r1,lsr#19]
	add r2,btptr,#dirtyMem+4
	mov r0,#-1
	strb r0,[r2,r1,lsr#30]
	bx lr

;@----------------------------------------------------------------------------
blkTgrIOWrite:				;@ r0=val, r1=IO adr
;@----------------------------------------------------------------------------
	cmp r1,#0xF
	addmi r2,btptr,#blkTgrRegs
	strbmi r0,[r2,r1]
	ldrmi pc,[pc,r1,lsl#2]
;@---------------------------
	b empty_IO_W
;@io_read_tbl
	.long soundLatchW			;@ 0x0, SoundLatch
	.long blkTgrMapper			;@ 0x1
	.long empty_IO_W			;@ 0x2
	.long coinLockOutW			;@ 0x3, CoinLockOut?
	.long miscW					;@ 0x4, Coin count, Flip, 2nd CPU reset, chars enable
	.long empty_IO_W			;@ 0x5
	.long watchDogW				;@ 0x6
	.long protectionW			;@ 0x7
	.long scrollX_L				;@ 0x8
	.long scrollX_H				;@ 0x9
	.long scrollY_L				;@ 0xA
	.long scrollY_H				;@ 0xB
	.long videoEnableW			;@ 0xC, Video enable
	.long switchGfxBankW		;@ 0xD
	.long screenLayoutW			;@ 0xE
;@----------------------------------------------------------------------------
;@switchRomBankW:				;@ 0x1, switch bank for 0x8000-0xBFFF, 16 banks.
;@----------------------------------------------------------------------------
;@----------------------------------------------------------------------------
coinLockOutW:				;@ 0x3
;@----------------------------------------------------------------------------
	// bit 0 and 1 locks coin slot when set.
	bx lr
;@----------------------------------------------------------------------------
miscW:						;@ 0x4
;@----------------------------------------------------------------------------
	tst r0,#1
	ldrne r2,=coinCounter0
	ldrne r1,[r2]
	addne r1,r1,#1
	strne r1,[r2]
	tst r0,#2
	ldrne r2,=coinCounter1
	ldrne r1,[r2]
	addne r1,r1,#1
	strne r1,[r2]

	// bit 5 reset line on sound cpu
	// bit 6 flip screen
	// bit 7 enables characters?
	bx lr
;@----------------------------------------------------------------------------
watchDogW:					;@ 0x6
;@----------------------------------------------------------------------------
	mov r0,#0x00
	ldr pc,[btptr,#frameIrqFunc]
;@----------------------------------------------------------------------------
protectionW:				;@ 0x7
;@----------------------------------------------------------------------------
	mov r11,r11					;@ No$GBA breakpoint
	adr r1,protText
	b debugOutput_asm
//	bx lr
protText:
	.string "Protection device written."
	.align 2
;@----------------------------------------------------------------------------
scrollX_L:					;@ 0x8
;@----------------------------------------------------------------------------
scrollX_H:					;@ 0x9
;@----------------------------------------------------------------------------
scrollY_L:					;@ 0xA
;@----------------------------------------------------------------------------
scrollY_H:					;@ 0xB
;@----------------------------------------------------------------------------
videoEnableW:				;@ 0xC
;@----------------------------------------------------------------------------
screenLayoutW:				;@ 0xE
;@----------------------------------------------------------------------------
	bx lr
;@----------------------------------------------------------------------------
switchGfxBankW:				;@ 0xD
;@----------------------------------------------------------------------------
	and r0,r0,#3
	ldr r1,[btptr,#gfxRAM]
	add r1,r1,r0,lsl#12
	str r1,[btptr,#ramPage0]
	bx lr

;@----------------------------------------------------------------------------
preparePalette:
;@----------------------------------------------------------------------------
	ldrb r0,[btptr,#palMemReload]
	cmp r0,#0
	bxeq lr
	mov r0,#0
	strb r0,[btptr,#palMemReload]	;@ Clear pal mem reload.
	ldrb r0,[btptr,#paletteSlots]	;@ How many slots we allow.
	strb r0,[btptr,#palMemAlloc]
	mov r1,#-1						;@ r1=value
	str r1,[btptr,#dirtyMem]		;@ repaint tiles.
	ldr r0,[btptr,#palBlockLUT]		;@ r0=destination
	mov r2,#(16+32)/4				;@ Palette entries
	b memset_						;@ Prepare LUT

;@----------------------------------------------------------------------------
chrReload:
;@----------------------------------------------------------------------------
	strb r0,[btptr,#dirtyMem+2]		;@ Make sure chr is updated on reload
	mov r0,#1<<CHRDSTTILECOUNTBITS
	str r0,[btptr,#chrMemAlloc]
	mov r1,#0x80000000				;@ r1=value
	strb r1,[btptr,#chrMemReload]	;@ Clear chr mem reload.
	mov r0,r9						;@ r0=destination
	mov r2,#CHRBLOCKCOUNT			;@ Tile entries
	b memset_						;@ Prepare LUT
;@----------------------------------------------------------------------------
convertChrMapBlkTgr:		;@ r0 = destination
;@----------------------------------------------------------------------------
	stmfd sp!,{r3-r11,lr}
	add r6,r0,#32*2*2			;@ Destination,  Skip first 2 rows

	ldr r9,[btptr,#chrBlockLUT]
	ldrb r0,[btptr,#chrMemReload]
	cmp r0,#0
	blne chrReload

#ifdef GBA
	ldr r0,=frameTotal
	ldr r0,[r0]
	tst r0,#7
	ldmfdne sp!,{r3-r11,pc}
#endif

	ldrb r0,[btptr,#dirtyMem+2]
	cmp r0,#0
	ldmfdeq sp!,{r3-r11,pc}
	mov r0,#0
	strb r0,[btptr,#dirtyMem+2]

	ldr r7,[btptr,#ramPage1]
	add r7,r7,#0x1000
	add r7,r7,#32*2				;@ Skip first 2 rows
	bl chrMapRender

	ldmfd sp!,{r3-r11,pc}
;@----------------------------------------------------------------------------
bgrReload:
;@----------------------------------------------------------------------------
	strb r0,[btptr,#dirtyMem]		;@ Make sure BGR is updated on reload
	mov r0,#1<<BGRDSTTILECOUNTBITS
	str r0,[btptr,#bgrMemAlloc]
	mov r1,#0x80000000				;@ r1=value
	strb r1,[btptr,#bgrMemReload]	;@ Clear bgr mem reload.
	mov r0,r9						;@ r0=destination
	mov r2,#BGRBLOCKCOUNT			;@ Tile entries
	b memset_						;@ Prepare LUT
;@----------------------------------------------------------------------------
convertBgrMapBlkTgr:		;@ r0 = destination
;@----------------------------------------------------------------------------
	ldrb r1,[btptr,#btVideoEnable]
	tst r1,#0x2					;@ bit 1 bgr enable?
	bxne lr
	stmfd sp!,{r3-r11,lr}
	mov r10,r0					;@ Destination

	ldr r9,[btptr,#bgrBlockLUT]
	ldrb r0,[btptr,#bgrMemReload]
	cmp r0,#0
	blne bgrReload

	ldr r1,=g_scaling
	ldrb r1,[r1]
	cmp r1,#UNSCALED
	moveq r11,#SCREEN_HEIGHT
	movne r11,#GAME_HEIGHT
	ldreq r0,=yStart			;@ First scanline?
	ldrbeq r0,[r0]

	ldr r4,[btptr,#btScrlXReg]	;@ This is both X & Y
	add r4,r4,#0x100000
	addeq r4,r4,r0,lsl#16

	ldr r2,=0x00FE00FE
	ldr r1,[btptr,#scrlXOld]
	and r0,r2,r4,lsr#3
	eors r1,r1,r0
	strne r0,[btptr,#scrlXOld]
	ldrheq r0,[btptr,#dirtyMem]
	cmpeq r0,#0
	ldmfdeq sp!,{r3-r11,pc}
	mov r0,#0
	strh r0,[btptr,#dirtyMem]

	mov r4,r4,lsr#16
	add r11,r11,r4				;@ r11 = last line to render
	mov r8,#0x00000001			;@ Tile adder
	orr r8,r8,#0x00010000		;@ Tile adder

	ldrb r0,[btptr,#btScreenLayout]
	cmp r0,#0
	adr lr,bgrEnd
	bne bgrMap8x4Render
	beq bgrMap4x8Render
bgrEnd:
	ldmfd sp!,{r3-r11,pc}

;@----------------------------------------------------------------------------
checkFrameIRQ:
;@----------------------------------------------------------------------------
//	ldrb r1,[btptr,#irqControl]
//	ands r0,r1,#2				;@ IRQ enabled? Every frame.
	mov r0,#1
	ldr pc,[btptr,#frameIrqFunc]
//	bx lr

;@----------------------------------------------------------------------------
frameEndHook:
	mov r0,#0					;@ Turn off IRQ.
	mov lr,pc
	ldr pc,[btptr,#frameIrqFunc]

	ldr r2,=lineStateTable
	ldr r1,[r2],#4
	mov r0,#0
	stmia btptr,{r0-r2}			;@ Reset scanline, nextChange & lineState

//	mov r0,#0					;@ Must return 0 to end frame.
	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
newFrame:					;@ Called before line 0
;@----------------------------------------------------------------------------
	bx lr

;@----------------------------------------------------------------------------
lineStateTable:
	.long 0, newFrame			;@ zeroLine
	.long 224, checkFrameIRQ	;@ frameIRQ
	.long 262, convertGfx		;@ Last scanline
	.long 263, frameEndHook		;@ totalScanlines
;@----------------------------------------------------------------------------
;@ Code in fastmem.
;@----------------------------------------------------------------------------
#ifdef NDS
	.section .itcm						;@ For the NDS
#elif GBA
	.section .iwram, "ax", %progbits	;@ For the GBA
#endif
;@----------------------------------------------------------------------------
redoScanline:
	ldmfd sp!,{lr}
;@----------------------------------------------------------------------------
doScanline:
;@----------------------------------------------------------------------------
	ldmia btptr,{r1,r2}			;@ Read scanLine & nextLineChange
	subs r0,r1,r2
	addmi r1,r1,#1
	strmi r1,[btptr,#scanline]
	bxmi lr
;@----------------------------------------------------------------------------
excuteScanline:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	ldr r2,[btptr,#lineState]
	ldmia r2!,{r0,r1}
	stmib btptr,{r1,r2}			;@ Write nextLineChange & lineState
	adr lr,redoScanline
	bx r0
;@----------------------------------------------------------------------------
chrMapRender:
;@----------------------------------------------------------------------------
	stmfd sp!,{lr}
	mov r5,#32*28				;@ Total tiles. Skip top 2 and bottom 2 rows.
chrMapLoop:
	ldrb r4,[r7,#0x400]			;@ Read from BlackTiger Charmap RAM
	ldrb r0,[r7],#1				;@ Read from BlackTiger Charmap RAM
	and r1,r4,#0xE0
	orr r0,r0,r1,lsl#3
	bl VRAM_chr_8
	bl remapChrPalette
	orr r0,r0,r4,lsl#12			;@ Color
	strh r0,[r6],#2				;@ Write to GBA/NDS Tilemap RAM
	subs r5,r5,#1
	bne chrMapLoop

	ldmfd sp!,{pc}

;@----------------------------------------------------------------------------
pal32CacheFull:
;@----------------------------------------------------------------------------
	strb r4,[btptr,#palMemReload]
	bx lr
;@----------------------------------------------------------------------------
remapChrPalette:
;@----------------------------------------------------------------------------
	and r1,r4,#0x1F
	ldr r2,[btptr,#palBlockLUT]	;@ r0=destination
	add r2,r2,#16				;@ Skip background pallete map.
	ldrb r4,[r2,r1]
	tst r4,#0xF0
	bxeq lr
allocPal32:
	ldrb r4,[btptr,#palMemAlloc]
	subs r4,r4,#1
	bmi pal32CacheFull
	strb r4,[btptr,#palMemAlloc]

	strb r4,[r2,r1]
	bx lr
;@----------------------------------------------------------------------------
chr8CacheFull:
;@----------------------------------------------------------------------------
	strb r0,[btptr,#chrMemReload]
	bx lr
;@----------------------------------------------------------------------------
VRAM_chr_8:			;@ Takes tilenumber in r0, returns new tilenumber in r0
;@----------------------------------------------------------------------------
	mov r1,r0,lsr#CHRGROUPTILECOUNTBITS		;@ Mask tile number
	and r2,r0,#(1<<CHRGROUPTILECOUNTBITS)-1
	ldr r0,[r9,r1,lsl#2]		;@ Check cache, uncached = 0x80000000
	orrs r0,r0,r2
	bxpl lr						;@ Allready cached
alloc8:
	ldr r0,[btptr,#chrMemAlloc]
	subs r0,r0,#1<<CHRGROUPTILECOUNTBITS
	bmi chr8CacheFull
	str r0,[btptr,#chrMemAlloc]

	str r0,[r9,r1,lsl#2]
	orr r2,r0,r2
;@----------------------------------------------------------------------------
do8:
	stmfd sp!,{r2,lr}
	ldr r2,[btptr,#chrRomBase]	;@ r0 = bitplane 0 & 1
	ldr r3,[btptr,#chrGfxDest]
	add r1,r2,r1,lsl#CHRGROUPTILECOUNTBITS+4
	add r3,r3,r0,lsl#5			;@
	ldr r2,=CHR_DECODE			;@ 0x400
chrLoop:
	ldrb r0,[r1],#1				;@ Read plane 0 & 1
	ldr r0,[r2,r0,lsl#2]
	strh r0,[r3],#2

	tst r3,#(1<<(CHRGROUPTILECOUNTBITS+5))-2	;@ ? tiles at a time
	bne chrLoop

	ldmfd sp!,{r0,pc}
;@----------------------------------------------------------------------------
bgrMap8x4Render:
	stmfd sp!,{lr}

bgRLoop8x4:
	mov r10,#BG_GFX
	and r0,r4,#0xF0
	add r10,r10,r0,lsl#3

	ldr r7,[btptr,#gfxRAM]
	and r1,r4,#0x300
	add r0,r0,r1,lsl#3
	add r7,r7,r0,lsl#1			;@ 128x64 tiles

	ldrh r5,[btptr,#scrlXOld]

	mov r3,#17					;@ Width/16
bgTrLoop8x4:
	and r5,r5,#0xFE
	orr r0,r5,r5,lsl#4			;@ Move 0x20 to 0x200
	bic r0,r0,#0x01E0
	ldrh r6,[r7,r0]				;@ Read from BlackTiger Tilemap RAM
	mov r6,r6,ror#11
	mov r0,r6,lsr#21			;@ Tilenum
	bl VRAM_bgr_16
	bl remapBgrPalette
	orrs r0,r0,r6,lsl#28		;@ Color bits + check Xflip
	orrcs r0,r0,#0x0400			;@ Xflip
	orr r0,r0,r0,ror#16
	add r0,r0,#0x00020000

	movcs r0,r0,ror#16

	orr r1,r5,r5,lsl#5			;@ Move 0x20 to 0x400
	mov r1,r1,lsl#1
	bic r1,r1,#0x37C0
	str r0,[r1,r10]!			;@ Write to GBA/NDS Tilemap RAM
	orr r0,r0,r8
	str r0,[r1,#0x40]			;@ Write to GBA/NDS Tilemap RAM row 2
	add r5,r5,#2
	subs r3,r3,#1
	bne bgTrLoop8x4

	add r4,r4,#0x10
	cmp r4,r11					;@ Last rendered line
	ble bgRLoop8x4

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
bgrMap4x8Render:
	stmfd sp!,{lr}

bgRLoop4x8:
	mov r10,#BG_GFX
	and r0,r4,#0xF0
	add r10,r10,r0,lsl#3

	ldr r7,[btptr,#gfxRAM]
	and r1,r4,#0x700
	add r0,r0,r1,lsl#2
	add r7,r7,r0,lsl#1			;@ 64x128 tiles

	ldrh r5,[btptr,#scrlXOld]

	mov r3,#17					;@ Width/16 + 1
bgTrLoop4x8:
	and r5,r5,#0x7E
	orr r0,r5,r5,lsl#4			;@ Move 0x20 to 0x200
	bic r0,r0,#0x01E0
	ldrh r6,[r7,r0]				;@ Read from BlackTiger Tilemap RAM
	mov r6,r6,ror#11
	mov r0,r6,lsr#21			;@ Tilenum
	bl VRAM_bgr_16
	bl remapBgrPalette
	orrs r0,r0,r6,lsl#28		;@ Color bits + check Xflip
	orrcs r0,r0,#0x0400			;@ Xflip
	orr r0,r0,r0,ror#16
	add r0,r0,#0x00020000

	movcs r0,r0,ror#16

	orr r1,r5,r5,lsl#5			;@ Move 0x20 to 0x400
	mov r1,r1,lsl#1
	bic r1,r1,#0x37C0
	str r0,[r1,r10]!			;@ Write to GBA/NDS Tilemap RAM
	orr r0,r0,r8
	str r0,[r1,#0x40]			;@ Write to GBA/NDS Tilemap RAM row 2
	add r5,r5,#2
	subs r3,r3,#1
	bne bgTrLoop4x8

	add r4,r4,#0x10
	cmp r4,r11					;@ Last rendered line
	ble bgRLoop4x8

	ldmfd sp!,{pc}
;@----------------------------------------------------------------------------
pal16CacheFull:
;@----------------------------------------------------------------------------
	strb r1,[btptr,#palMemReload]
	mov r6,r6,ror#28
	bx lr
;@----------------------------------------------------------------------------
remapBgrPalette:
;@----------------------------------------------------------------------------
	mov r6,r6,ror#4
	ldr r2,[btptr,#palBlockLUT]	;@ r0=destination
	ldrb r1,[r2,r6,lsr#28]
	tst r1,#0xF0
	orreq r6,r1,r6,lsl#4
	bxeq lr
allocPal16:
	ldrb r1,[btptr,#palMemAlloc]
	subs r1,r1,#1
	bmi pal16CacheFull
	strb r1,[btptr,#palMemAlloc]

	strb r1,[r2,r6,lsr#28]
	orr r6,r1,r6,lsl#4
	bx lr

;@----------------------------------------------------------------------------
bgr16CacheFull:
;@----------------------------------------------------------------------------
	strb r0,[btptr,#bgrMemReload]
	bx lr
;@----------------------------------------------------------------------------
VRAM_bgr_16:		;@ Takes tilenumber in r0, returns new tilenumber in r0
;@----------------------------------------------------------------------------
	mov r1,r0,lsr#BGRSRCGROUPTILECOUNTBITS		;@ Mask tile number
	and r2,r0,#(1<<BGRSRCGROUPTILECOUNTBITS)-1
	ldr r0,[r9,r1,lsl#2]		;@ Check cache, uncached = 0x80000000
	orrs r0,r0,r2,lsl#BGRDSTGROUPTILECOUNTBITS-BGRSRCGROUPTILECOUNTBITS
	bxpl lr						;@ Allready cached
allocBgr:
	ldr r0,[btptr,#bgrMemAlloc]
	subs r0,r0,#1<<BGRDSTGROUPTILECOUNTBITS
	bmi bgr16CacheFull
	str r0,[btptr,#bgrMemAlloc]

	str r0,[r9,r1,lsl#2]
	orr r2,r0,r2,lsl#BGRDSTGROUPTILECOUNTBITS-BGRSRCGROUPTILECOUNTBITS
;@----------------------------------------------------------------------------
doBgr:
	stmfd sp!,{r2-r5,lr}
	ldr r4,[btptr,#bgrRomBase]	;@ r4 = bitplane 0 & 1
	ldr r5,[btptr,#bgrGfxDest]
	add r1,r4,r1,lsl#BGRSRCGROUPTILECOUNTBITS+6
	add r3,r5,r0,lsl#5
	add r4,r1,#0x20000
	ldr r2,=CHR_DECODE			;@ 0x400
bgrLoop:
	ldrb r0,[r1],#1				;@ Read plane 0 & 1
	ldr r0,[r2,r0,lsl#2]
	ldrb r5,[r4],#1				;@ Read plane 2 & 3
	ldr r5,[r2,r5,lsl#2]
	orr r0,r0,r5,lsl#2
	strh r0,[r3],#2

	tst r3,#(1<<(BGRDSTGROUPTILECOUNTBITS+5))-2	;@ 2 tiles at a time
	bne bgrLoop

	ldmfd sp!,{r0,r3-r5,pc}
;@----------------------------------------------------------------------------
reloadSprites:
;@----------------------------------------------------------------------------
	mov r0,#1<<SPRDSTTILECOUNTBITS
	str r0,[btptr,#sprMemAlloc]
	mov r1,#0x80000000				;@ r1=value
	strb r1,[btptr,#sprMemReload]	;@ Clear spr mem reload.
	mov r0,r9						;@ r0=destination
	mov r2,#SPRBLOCKCOUNT			;@ Tile entries
	b memset_						;@ prepare lut
;@----------------------------------------------------------------------------
	.equ PRIORITY,	0x800		;@ 0x800=AGB OBJ priority 2
;@----------------------------------------------------------------------------
convertSpritesBlkTgr:		;@ in r0 = destination.
;@----------------------------------------------------------------------------
	ldrb r1,[btptr,#btVideoEnable]
	tst r1,#0x4					;@ bit 2 spr enable?
	bxne lr
	stmfd sp!,{r4-r11,lr}

	mov r11,r0					;@ Destination

	ldr r9,[btptr,#sprBlockLUT]
	ldrb r0,[btptr,#sprMemReload]
	cmp r0,#0
	blne reloadSprites

	ldr r10,[btptr,#gfxRAM]
	add r10,r10,#0x6E00			;@ Source

	ldr r7,=g_scaling
	ldrb r7,[r7]
	cmp r7,#UNSCALED			;@ Do autoscroll
	ldreq r7,=0x01000000		;@ No scaling
//	ldrne r7,=0x00DB6DB6		;@ 192/224, 6/7, scaling. 0xC0000000/0xE0 = 0x00DB6DB6.
//	ldrne r7,=0x00B6DB6D		;@ 160/224, 5/7, scaling. 0xA0000000/0xE0 = 0x00B6DB6D.
	ldrne r7,=(SCREEN_HEIGHT<<19)/(GAME_HEIGHT>>5)		;@ 192/224, 6/7, scaling. 0xC0000000/0xE0 = 0x00DB6DB6.
	mov r0,#0
	ldreq r0,=yStart			;@ First scanline?
	ldrbeq r0,[r0]
	add r6,r0,#0x10-8

	mov r5,#0x40000000			;@ 16x16 size
	orrne r5,r5,#0x100			;@ Scale obj

	mov r8,#128					;@ Number of sprites
dm5:
	ldr r4,[r10],#4				;@ BlackTiger OBJ, r4=Xpos,Ypos,Attrib,Tile.
	ands r0,r4,#0xFF0000		;@ Mask Y
	cmpne r0,#0xE00000
	beq dm10					;@ Skip if sprite Y=0 or 0xE0
	rsb r0,r6,r0,lsr#16
	mov r1,r4,lsr#24
	tst r4,#0x1000
	subne r1,r1,#0x100			;@ Attrib bit4
	sub r1,r1,#(GAME_WIDTH-SCREEN_WIDTH)/2
	mov r1,r1,lsl#23			;@ Mask X

	mul r0,r7,r0				;@ Y = scaled Y
	sub r0,r0,#0x08000000
	orr r0,r5,r0,lsr#24			;@ Size + Scaling
	orr r0,r0,r1,lsr#7

	and r1,r4,#0x0800			;@ Xflip
	orr r0,r0,r1,lsl#17
	str r0,[r11],#4				;@ Store OBJ Atr 0,1. Xpos, ypos, flip, scale/rot, size, shape.

	and r1,r4,#0xFF
	and r0,r4,#0xE000
	orr r0,r1,r0,lsr#5

	mov r1,r0,ror#SPRSRCGROUPTILECOUNTBITS
	ldr r0,[r9,r1,lsl#2]		;@ Look up pattern conversion
	orrs r0,r0,r1,lsr#32-BGRDSTGROUPTILECOUNTBITS
	blmi VRAM_spr_16			;@ Jump to spr copy, takes tile# in r0, gives new tile# in r0
ret01:
	and r1,r4,#0x0700			;@ Color
	eor r1,r1,#0x0700
	orr r0,r0,r1,lsl#4
	orr r0,r0,#PRIORITY			;@ Priority
	strh r0,[r11],#4			;@ Store OBJ Atr 2. Pattern, prio & palette.
dm9:
	subs r8,r8,#1
	bne dm5
	ldmfd sp!,{r4-r11,pc}
dm10:
	mov r0,#0x200+SCREEN_HEIGHT	;@ Double, y=SCREEN_HEIGHT
	str r0,[r11],#8
	b dm9

;@----------------------------------------------------------------------------
spriteCacheFull:
	strb r2,[btptr,#sprMemReload]
	ldmfd sp!,{r4-r11,pc}
;@----------------------------------------------------------------------------
VRAM_spr_16:		;@ Takes tilenumber in r1, returns new tilenumber in r0
;@----------------------------------------------------------------------------
	ldr r2,[btptr,#sprMemAlloc]
	subs r2,r2,#1<<BGRDSTGROUPTILECOUNTBITS
	bmi spriteCacheFull
	str r2,[btptr,#sprMemAlloc]

	str r2,[r9,r1,lsl#2]
	orr r0,r2,r1,lsr#32-BGRDSTGROUPTILECOUNTBITS
;@----------------------------------------------------------------------------
do16:
	stmfd sp!,{r0-r5,lr}
	ldr r4,[btptr,#sprRomBase]	;@ r4 = bitplane 0 & 1
	ldr r5,=SPRITE_GFX			;@ r5=GBA/NDS SPR tileset
	add r1,r4,r1,lsl#SPRSRCGROUPTILECOUNTBITS+6
	add r3,r5,r2,lsl#5
	mov r4,#0x20000
	ldr r2,=CHR_DECODE			;@ 0x400
spr1:
	ldrb r5,[r1,r4]				;@ Read plane 2 & 3
	ldrb r0,[r1],#1				;@ Read plane 0 & 1
	ldr r0,[r2,r0,lsl#2]
	ldr r5,[r2,r5,lsl#2]
	orr r0,r0,r5,lsl#2
	strh r0,[r3],#2

	tst r3,#0x1E				;@ 8 rows
	bne spr1

	add r1,r1,#0x10

	tst r3,#0x20				;@ 2 tiles
	bne spr1

	sub r1,r1,#0x30

	tst r3,#0x40				;@ 16 rows
	bne spr1

	add r1,r1,#0x20

	tst r3,#(1<<(SPRDSTGROUPTILECOUNTBITS+5))-2	;@ 2 tiles at a time
	bne spr1

	ldmfd sp!,{r0-r5,pc}

;@----------------------------------------------------------------------------

#ifdef GBA
	.section .sbss				;@ For the GBA
#else
	.section .bss
#endif
CHR_DECODE:
	.space 0x400

;@----------------------------------------------------------------------------
	.end
#endif // #ifdef __arm__
