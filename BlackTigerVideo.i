;@ ASM header for the Capcom BlackTigerVideo emulator
;@

/** \brief  Game screen height in pixels */
#define GAME_HEIGHT (224)
/** \brief  Game screen width in pixels */
#define GAME_WIDTH  (256)

	.equ CHRSRCTILECOUNTBITS,	11
	.equ CHRDSTTILECOUNTBITS,	9
	.equ CHRGROUPTILECOUNTBITS,	1
	.equ CHRBLOCKCOUNT,			(1<<(CHRSRCTILECOUNTBITS - CHRGROUPTILECOUNTBITS))
	.equ CHRTILESIZEBITS,		5

	.equ BGRSRCTILECOUNTBITS,	11
	.equ BGRDSTTILECOUNTBITS,	10
	.equ BGRSRCGROUPTILECOUNTBITS,	1
	.equ BGRDSTGROUPTILECOUNTBITS,	3
	.equ BGRBLOCKCOUNT,			(1<<(BGRSRCTILECOUNTBITS - BGRSRCGROUPTILECOUNTBITS))

	.equ SPRSRCTILECOUNTBITS,	11
	.equ SPRDSTTILECOUNTBITS,	10
	.equ SPRSRCGROUPTILECOUNTBITS,	1
	.equ SPRDSTGROUPTILECOUNTBITS,	3
	.equ SPRBLOCKCOUNT,			(1<<(SPRSRCTILECOUNTBITS - SPRSRCGROUPTILECOUNTBITS))
	.equ SPRTILESIZEBITS,		5


	btptr		.req r12
						;@ BlackTigerVideo.s
	.struct 0
scanline:		.long 0			;@ These 3 must be first in state.
nextLineChange:	.long 0
lineState:		.long 0

frameIrqFunc:	.long 0

blkTgrState:				;@
blkTgrRegs:					;@
btSoundLatch:	.byte 0
btRomBank:		.byte 0
btEmpty0:		.space 1
btCoinLockOut:	.byte 0
btIrqControl:	.byte 0
btEmpty1:		.space 1
btWatchDog:		.byte 0
btProtection:	.byte 0
btScrlXReg:		.short 0
btScrlYReg:		.short 0
btVideoEnable:	.byte 0
btGfxBank:		.byte 0
btScreenLayout:	.byte 0
btEmpty2:		.space 1

scrlXOld:		.short 0
scrlYOld:		.short 0

ramPage0:		.long 0
ramPage1:		.long 0
ramPage2:		.long 0

chrMemAlloc:	.long 0
bgrMemAlloc:	.long 0
sprMemAlloc:	.long 0

palMemAlloc:	.byte 0
paletteSlots:	.byte 0
btPadding0:		.space 2

gfxReload:
chrMemReload:	.byte 0
bgrMemReload:	.byte 0
sprMemReload:	.byte 0
palMemReload:	.byte 0

chrRomBase:		.long 0
chrGfxDest:		.long 0
bgrRomBase:		.long 0
bgrGfxDest:		.long 0
sprRomBase:		.long 0

dirtyMem:		.space 8
gfxRAM:			.long 0
chrBlockLUT:	.long 0
bgrBlockLUT:	.long 0
sprBlockLUT:	.long 0
palBlockLUT:	.long 0

blkTgrSize:

;@----------------------------------------------------------------------------
