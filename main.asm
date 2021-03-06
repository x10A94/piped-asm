; main asm source file
; over here will be global attributes, linker data, etc.

Start:
	SEI				; disable interrupts
	CLC : XCE		; switch to native mode
	SEP #$30		; A and XY 8-bit
	STZ $420D		; slow rom access
	STZ $420B		; \ disable any (H)DMA
	STZ $420C		; /
	LDA #$00		; disable joypad, set NMI and V/H count to 0
	STA $4200

	LDA #%10000000	; turn screen off, activate vblank
	STA $2100
	REP #$10		; turn XY 16-bit

	BRA +
.data
	db $01
	dl Graphics01
	dw $0000, $4000
	db $00
	dl Palette
	dw $0000, $0080
	db $01
	dl BGTilemap01
	dw $4000, $2000
	db $FF

+	LDX.w #.data
	JSL LoadDataQueue
	SEP #$10		; turn XY 8-bit

	LDA #%00000010 ; bg mode 1, 8x8 tiles
	STA $2105

	LDA #%01000001	; tilemap at 0x8000, no mirroring
	STA $2107
	LDA #%01001001	; tilemap at 0x9000, no mirroring
	STA $2108
	LDA #%01010001	; tilemap at 0xA000, no mirroring
	STA $2109

	LDA #%00000011	; enable BG1-2
	STA $212C
	LDA #%00000011	; enable BG1-2
	STA $212D

	INC A
	; Clean memory
	LDX #$00
-	INX
	STZ $00,x
	CPX #$00
	BNE -


	; Set up IRQ to split the screen in two

	REP #$20
	LDA #$0030
	STA $4209
	LDA.w #SplitIRQ
	STA $80
	SEP #$20

	LDA #%00001111	; end vblank, setting brightness to 15
	STA $2100

	LDA #%10100001	; enable NMI, IRQ & joypad
	STA $4200

	CLI				; enable interrupts
	STA $20
	JMP MainLoop

SplitIRQ:
	PHP
	REP #$20
	SEP #$10
	LDA $24		; load layer 2 x pos
	LSR			; half it
	TAX
	STX $210F
	XBA
	TAX
	STX $210F
	PLP
	RTI

MainLoop:
	LDA $10
	BEQ MainLoop
	CLI
	JSR RunFrame
	STZ $10
	BRA MainLoop

incsrc "runframe.asm"

VBlank:
	; sync camera scroll values
	LDA $20
	STA $210D
	LDA $21
	STA $210D
	LDA $22
	STA $210E
	LDA $23
	STA $210E
	LDA $24
	STA $210F
	LDA $25
	STA $210F
	LDA $26
	STA $2110
	LDA $27
	STA $2110

	; finish
	LDA #$01
	STA $10
	RTI

; IRQ handler

IRQ:
	CMP $4211	; Dummy read
	JMP ($0080)

; DMA queue
; Loads a queue from the first bank. Uses the accumulator as the data pointer.
; Format:
; OP AA AA AA BB BB SS SS
; OP: $00 - load into VRAM
;     $01 - load into CGRAM
;     $FF - quit
LoadDataQueue:
	PHP
	PHA
	PHY
	SEP #$20	; 8-bit A
.loop:
	LDA $00,x	; offset $01: command
	BMI .end	; if $FF, end
	LDY $01,x	; A bus address
	STY $4302
	LDA $03,x
	STA $4304
	LDY $06,x	; Write size
	STY $4305
	LDY $00,x
	BEQ .loadCGRAM
.loadVRAM:
	LDY $04,x	; B bus address
	STY $2116
	LDA #$80	; Video port control
	STA $2115
	LDA #$01	; Word increment mode
	STA $4300
	LDA #$18	; Destination: VRAM
	STA $4301
	BRA .startDMA
.loadCGRAM:
	LDA $04,x	; B bus address in CGRAM
	STA $2121
	LDA #%00000000
	STA $4300	; 1 byte increment
	LDA #$22	; Destination: CGRAM
	STA $4301
.startDMA:
	LDA #$01	; Turn on DMA
	STA $420B
	REP #$20
	TXA
	CLC : ADC #$0008
	TAX
	SEP #$20
	BRA .loop	; Loop again
.end:
	PLY
	PLA
	PLP
	RTS

; Scratch RAM arguments:
; AA AA AA BB BB SS SS CC
; A: A bus address
; B: B bus address
; S: Size in bytes
; C: 0 - VRAM, 1 - palette

LoadData:
	PHA
	PHY
	PHP
	REP #$20
	SEP #$10
	LDA $00		; A bus address
	STA $4302
	LDY $02		; Bank
	STY $4304
	LDA $05		; Write size
	STA $4305

	LDY $07
	BEQ +
	LDA $03		; B bus address
	STA $2116
	LDY #$80	; Video port control
	STY $2115
	LDY #$01	; Word increment mode
	STY $4300
	LDY #$18	; Destination: VRAM
	STY $4301
	BRA .end

+	LDY $03		; B bus address in CGRAM
	STY $2121
	LDY #%00000000
	STY $4300	; 1 byte increment
	LDY #$22		; Destination: CGRAM
	STY $4301
.end:
	LDY #$01	; Turn on DMA
	STY $420B

	PLP
	PLY
	PLA
	RTS


#[bank(01)]
Graphics01:
	incbin "graphics.bin"

BGTilemap01:
	incbin "map4.bin"
	incbin "map3.bin"

Palette:
	dw $7eee, $7fdd, $0000, $0d71, $13ff, $1e9b, $137f, $03ff
	dw $0000, $0000, $194f, $3e78, $573e, $03ff, $7bde, $7c1f
	dw $0000, $7fdd, $0960, $01a4, $01e8, $022c, $0291, $02f5
	dw $7393, $0000, $0cfb, $2feb, $7393, $0000, $7fdd, $2d7f
	dw $0000, $7fdd, $0000, $0daf, $2e79, $25e0, $2b1c, $0320
	dw $0000, $7fff, $0000, $0320, $0016, $001f, $017f, $029f
	dw $0000, $7fdd, $0000, $2d6b, $3def, $4e73, $6318, $739c
	dw $0000, $7fff, $0000, $0320, $347d, $551e, $65ff, $7b1f

