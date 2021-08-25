// Capcom Black Tiger Video Chip emulation

#ifndef BLACKTIGERVIDEO_HEADER
#define BLACKTIGERVIDEO_HEADER

#ifdef __cplusplus
extern "C" {
#endif

/** \brief  Game screen height in pixels */
#define GAME_HEIGHT (224)
/** \brief  Game screen width in pixels */
#define GAME_WIDTH  (256)

typedef struct {
	u32 scanline;
	u32 nextLineChange;
	u32 lineState;

	void *frameIrqFunc;

//blkTgrState:
//blkTgrRegs:					// 0-4
	u8 btSoundLatch;
	u8 btRomBank;
	u8 btEmpty0;
	u8 btCoinLockOut;
	u8 btIrqControl;
	u8 screenLayout;
	u8 btEmpty1;
	u8 btWatchDog;
	u8 btProtection;
	u16 btScrlXReg;
	u16 btScrlYReg;
	u8 btVideoEnable;
	u8 btGfxBank;
	u8 btScreenLayout;
	u8 btEmpty2;

	u32 scrlXOld;
	u32 scrlYOld;

	u32 ramPage0;
	u32 ramPage1;
	u32 ramPage2;

	u32 chrMemAlloc;
	u32 bgrMemAlloc;
	u32 sprMemAlloc;

	u8 palMemAlloc;
	u8 paletteSlots;
	u8 btPadding0[2];

	u8 chrMemReload;
	u8 bgrMemReload;
	u8 sprMemReload;
	u8 palMemReload;

	u32 chrRomBase;
	u32 chrGfxDest;
	u32 bgrRomBase;
	u32 bgrGfxDest;
	u32 spriteRomBase;

	u8 dirtyMem[8];
	u8 *gfxRAM;			// Should be 0x7000 in size.
	u32 *chrBlockLUT;
	u32 *bgrBlockLUT;
	u32 *sprBlockLUT;
	u32 *palBlockLUT;
} BlkTgrVideo;

void blkTgrReset(void *frameIrqFunc(), u8 *ram);

/**
 * Saves the state of the chip to the destination.
 * @param  *destination: Where to save the state.
 * @param  *chip: The BlkTgrVideo chip to save.
 * @return The size of the state.
 */
int blkTgrSaveState(void *destination, const BlkTgrVideo *chip);

/**
 * Loads the state of the chip from the source.
 * @param  *chip: The BlkTgrVideo chip to load a state into.
 * @param  *source: Where to load the state from.
 * @return The size of the state.
 */
int blkTgrLoadState(BlkTgrVideo *chip, const void *source);

/**
 * Gets the state size of a BlkTgrVideo state.
 * @return The size of the state.
 */
int blkTgrGetStateSize(void);

void convertTileMapBlkTgr(void *destination, const void *source, int length);
void convertSpritesBlkTgr(void *destination);
void doScanline(void);

#ifdef __cplusplus
} // extern "C"
#endif

#endif // BLACKTIGERVIDEO_HEADER
