;
; un[f]ancy [d]isassembler [e]ngine (fde64) v0.04
;

  ; structure representing any instruction

struct fde64s
  len	      rb 1
  prefix      rb 1
  prefix.lock rb 1
  prefix.rep  rb 1
  prefix.seg  rb 1
  prefix.66   rb 1
  prefix.67   rb 1
  rex	      rb 1
  rex.w       rb 1
  rex.r       rb 1
  rex.x       rb 1
  rex.b       rb 1
  vex	      rb 1
  vex2	      rb 1
  vex3	      rb 1
  vex.r       rb 1
  vex.x       rb 1
  vex.b       rb 1
  vex.m_mmmm  rb 1
  vex.w       rb 1
  vex.vvvv    rb 1
  vex.l       rb 1
  vex.pp      rb 1
  opcode.len  rb 1
  opcode      rb 1
  opcode2     rb 1
  opcode3     rb 1
  modrm       rb 1
  modrm.mod   rb 1
  modrm.reg   rb 1
  modrm.rm    rb 1
  sib	      rb 1
  sib.scale   rb 1
  sib.index   rb 1
  sib.base    rb 1
  union
    disp8     rb 1
    disp32    rd 1
    disp64    rq 1
  ends
  union
    imm8      rb 1
    imm16     rw 1
    imm32     rd 1
    imm64     rq 1
  ends
  union
    imm8_2    rb 1
    imm16_2   rw 1
  ends
  flags       rd 1
ends

  ; flags

  F_NONE	      = 00000000h
  F_MODRM	      = 00000001h
  F_SIB 	      = 00000002h
  F_DISP8	      = 00000004h
  F_DISP32	      = 00000008h
  F_DISP64	      = 00000010h
  F_DISP	      = F_DISP8+F_DISP32+F_DISP64
  F_IMM8	      = 00000020h
  F_IMM16	      = 00000040h
  F_IMM32	      = 00000080h
  F_IMM64	      = 00000100h
  F_IMM 	      = F_IMM8+F_IMM16+F_IMM32+F_IMM64
  F_RELATIVE	      = 00000200h
  F_RIPDISP32	      = 00000400h
  F_GROUP	      = 00000800h	; index specified in modrm.reg
  F_REX_IGNORED       = 00001000h
  F_VEX_BAD_PREFIX    = 00002000h
  F_ERROR_LOCK	      = 00004000h	; lock-prefix not possible
  F_ERROR_X86_64      = 00008000h	; invalid under x64
  F_ERROR_LENGTH      = 00010000h
  F_ERROR_OPCODE      = 00020000h	; undefined opcode

  ; prefix flags

  PRE_NONE	      = 000h
  PRE_LOCK	      = 001h
  PRE_REP	      = 002h
  PRE_SEG	      = 004h
  PRE_66	      = 008h		; ignored if rex.w=1
  PRE_67	      = 010h
  PRE_REX	      = 020h
  PRE_VEX	      = 040h		; partly encoded in complements to distinguish from les/lds
  PRE_ALL	      = PRE_LOCK+PRE_REP+PRE_SEG+PRE_66+PRE_67
  PRE_ALL64	      = PRE_ALL+PRE_REX+PRE_VEX

  ; vex-prefix m-mmmm

  M_MMMM_0F	      = 1
  M_MMMM_0F_38	      = 2
  M_MMMM_0F_3A	      = 3

  ; vex-prefix l

  L_SCALAR	      = 0
  L_128_VECTOR	      = 0
  L_256_VECTOR	      = 1

  ; vex-prefix pp

  PP_NONE	      = 0
  PP_66 	      = 1
  PP_F3 	      = 2
  PP_F2 	      = 3

  ; modr/m mod

  MOD_NODISP	      = 0
  MOD_DISP8	      = 1
  MOD_DISP32	      = 2
  MOD_REG	      = 3

  ; modr/m reg

  ; GPRs
  REG_RAX	      = 0		; x64 gprs are being used if rex.w=1
  REG_RCX	      = 1
  REG_RDX	      = 2
  REG_RBX	      = 3
  REG_RSP	      = 4
  REG_RBP	      = 5
  REG_RSI	      = 6
  REG_RDI	      = 7
  REG_R8	      = REG_RAX 	; r8-r15 are being used if rex.rxb=1
  REG_R9	      = REG_RCX
  REG_R10	      = REG_RDX
  REG_R11	      = REG_RBX
  REG_R12	      = REG_RSP
  REG_R13	      = REG_RBP
  REG_R14	      = REG_RSI
  REG_R15	      = REG_RDI
  REG_AL	      = REG_RAX
  REG_AH	      = REG_RSP
  REG_CL	      = REG_RCX
  REG_CH	      = REG_RBP
  REG_DL	      = REG_RDX
  REG_DH	      = REG_RSI
  REG_BL	      = REG_RBX
  REG_BH	      = REG_RDI
  REG_SPL	      = REG_AH		; spl-dil are being used if rex (rex.rb=1 is for r8l-r15l)
  REG_SBL	      = REG_CH
  REG_SIL	      = REG_DH
  REG_DIL	      = REG_BH
  ; special
  REG_DR0	      = REG_RAX
  REG_DR1	      = REG_RCX
  REG_DR2	      = REG_RDX
  REG_DR3	      = REG_RBX
  REG_DR4	      = REG_RSP 	; refers to DR6 if CR4.DE is cleared
  REG_DR5	      = REG_RBP 	; refers to DR7 ^
  REG_DR6	      = REG_RSI
  REG_DR7	      = REG_RDI
  REG_CR0	      = REG_RAX
  REG_CR2	      = REG_RDX
  REG_CR3	      = REG_RBX
  REG_CR4	      = REG_RSP
  REG_CR8	      = REG_RAX 	; cr8 is being used if rex.r=1
  ; MMX/XMM/YMM
  REG_SIMD0	      = REG_RAX
  REG_SIMD1	      = REG_RCX
  REG_SIMD2	      = REG_RDX
  REG_SIMD3	      = REG_RBX
  REG_SIMD4	      = REG_RSP
  REG_SIMD5	      = REG_RBP
  REG_SIMD6	      = REG_RSI
  REG_SIMD7	      = REG_RDI
  REG_SIMD8	      = REG_RAX 	; simd8-simd15 are being used if rex.rb=1 or vex.vvvv=8-15
  REG_SIMD9	      = REG_RCX
  REG_SIMD10	      = REG_RDX
  REG_SIMD11	      = REG_RBX
  REG_SIMD12	      = REG_RSP
  REG_SIMD13	      = REG_RBP
  REG_SIMD14	      = REG_RSI
  REG_SIMD15	      = REG_RDI
  ; FPU
  REG_ST0	      = REG_RAX
  REG_ST1	      = REG_RCX
  REG_ST2	      = REG_RDX
  REG_ST3	      = REG_RBX
  REG_ST4	      = REG_RSP
  REG_ST5	      = REG_RBP
  REG_ST6	      = REG_RSI
  REG_ST7	      = REG_RDI
  ; Sregs
  SEG_ES	      = REG_RAX
  SEG_CS	      = REG_RCX
  SEG_SS	      = REG_RDX
  SEG_DS	      = REG_RBX
  SEG_FS	      = REG_RSP
  SEG_GS	      = REG_RBP

  ; modr/m r/m

  RM_SIB	      = REG_RSP
  RM_DISP32	      = REG_RBP

  ; sib scale

  SCALE_1	      = 0
  SCALE_2	      = 1
  SCALE_4	      = 2
  SCALE_8	      = 3

  ; prefixes

  PREFIX_SEGMENT_CS   = 02Eh
  PREFIX_SEGMENT_SS   = 036h
  PREFIX_SEGMENT_DS   = 03Eh
  PREFIX_SEGMENT_ES   = 026h
  PREFIX_SEGMENT_FS   = 064h
  PREFIX_SEGMENT_GS   = 065h
  PREFIX_LOCK	      = 0F0h
  PREFIX_REPNZ	      = 0F2h
  PREFIX_REP	      = 0F3h
  PREFIX_OPERAND_SIZE = 066h
  PREFIX_ADDRESS_SIZE = 067h
  PREFIX_REX_START    = 040h
  PREFIX_REX_END      = 04Fh
  PREFIX_VEX_2_BYTE   = 0C5h
  PREFIX_VEX_3_BYTE   = 0C4h

  ; encoding routine

if used encode
encode: 				; 468 bytes

	db	$56, $57, $48, $89, $CF, $49, $89, $C8, $48, $89, $D6, $8A, $4E, $01, $F6, $C1
	db	$04, $74, $04, $8A, $46, $04, $AA, $F6, $C1, $10, $74, $03, $B0, $67, $AA, $F6
	db	$C1, $40, $75, $4D, $F6, $C1, $01, $74, $03, $B0, $F0, $AA, $F6, $C1, $02, $74
	db	$04, $8A, $46, $03, $AA, $F6, $C1, $08, $74, $03, $B0, $66, $AA, $F6, $C1, $20
	db	$74, $26, $80, $7E, $08, $FF, $75, $06, $8A, $46, $07, $AA, $EB, $1A, $66, $8B
	db	$46, $08, $66, $8B, $4E, $0A, $C0, $E0, $03, $C0, $E4, $02, $D0, $E1, $80, $CD
	db	$40, $08, $E0, $08, $E9, $08, $C8, $AA, $F6, $C1, $40, $0F, $84, $8C, $00, $00
	db	$00, $8A, $46, $0C, $AA, $88, $C4, $80, $7E, $0F, $FF, $75, $0F, $8A, $46, $0D
	db	$AA, $80, $FC, $C4, $75, $77, $8A, $46, $0E, $AA, $EB, $71, $80, $FC, $C5, $75
	db	$25, $8A, $46, $0F, $8A, $66, $14, $8A, $4E, $15, $8A, $6E, $16, $F6, $D0, $F6
	db	$D4, $C0, $E0, $07, $C0, $E4, $03, $C0, $E1, $02, $08, $E0, $08, $E9, $08, $C8
	db	$AA, $8A, $46, $19, $EB, $4A, $66, $8B, $46, $0F, $66, $8B, $4E, $11, $66, $F7
	db	$D0, $F6, $D1, $C0, $E0, $07, $C0, $E4, $06, $C0, $E1, $05, $08, $E0, $08, $E9
	db	$08, $C8, $AA, $66, $8B, $46, $13, $66, $8B, $4E, $15, $F6, $D4, $C0, $E0, $07
	db	$C0, $E4, $03, $C0, $E1, $02, $08, $E0, $08, $E9, $08, $C8, $AA, $8A, $66, $12
	db	$8A, $46, $19, $80, $FC, $01, $74, $08, $8A, $46, $1A, $EB, $03, $8A, $46, $18
	db	$AA, $F6, $46, $01, $40, $75, $14, $3C, $0F, $75, $10, $8A, $46, $19, $AA, $3C
	db	$38, $74, $04, $3C, $3A, $75, $04, $8A, $46, $1A, $AA, $8B, $4E, $35, $F7, $C1
	db	$01, $00, $00, $00, $74, $1E, $80, $7E, $1C, $FF, $75, $06, $8A, $46, $1B, $AA
	db	$EB, $12, $66, $8B, $46, $1C, $8A, $56, $1E, $C0, $E0, $06, $C0, $E4, $03, $08
	db	$E0, $08, $D0, $AA, $F7, $C1, $02, $00, $00, $00, $74, $1E, $80, $7E, $20, $FF
	db	$75, $06, $8A, $46, $1F, $AA, $EB, $12, $66, $8B, $46, $20, $8A, $56, $22, $C0
	db	$E0, $06, $C0, $E4, $03, $08, $E0, $08, $D0, $AA, $F7, $C1, $10, $00, $00, $00
	db	$74, $08, $48, $8B, $46, $23, $48, $AB, $EB, $1A, $F7, $C1, $08, $00, $00, $00
	db	$74, $06, $8B, $46, $23, $AB, $EB, $0C, $F7, $C1, $04, $00, $00, $00, $74, $04
	db	$8A, $46, $23, $AA, $F7, $C1, $00, $01, $00, $00, $74, $08, $48, $8B, $46, $2B
	db	$48, $AB, $EB, $26, $F7, $C1, $80, $00, $00, $00, $74, $04, $8B, $46, $2B, $AB
	db	$F7, $C1, $40, $00, $00, $00, $74, $06, $66, $8B, $46, $2B, $66, $AB, $F7, $C1
	db	$20, $00, $00, $00, $74, $04, $8A, $46, $2B, $AA, $4C, $29, $C7, $40, $88, $3E
	db	$97, $5F, $5E, $C3
end if

  ; decoding routine

if used decode
decode: 				; 1337 bytes

	db	$53, $56, $57, $48, $89, $CE, $49, $89, $C8, $31, $C9, $30, $C0, $48, $89, $D7
	db	$B1, $39, $F3, $AA, $AC, $88, $C1, $88, $C5, $80, $E1, $FE, $80, $E5, $E7, $3C
	db	$F0, $74, $20, $80, $F9, $F2, $74, $24, $3C, $66, $74, $29, $3C, $67, $74, $2E
	db	$80, $F9, $64, $74, $05, $80, $FD, $2E, $75, $2D, $80, $4A, $01, $04, $88, $42
	db	$04, $EB, $D1, $80, $4A, $01, $01, $88, $42, $02, $EB, $C8, $80, $4A, $01, $02
	db	$88, $42, $03, $EB, $BF, $80, $4A, $01, $08, $88, $42, $05, $EB, $B6, $80, $4A
	db	$01, $10, $88, $42, $06, $EB, $AD, $88, $C1, $80, $E1, $F0, $80, $F9, $40, $75
	db	$29, $80, $4A, $01, $20, $88, $42, $07, $88, $C4, $88, $C1, $88, $C5, $C0, $E8
	db	$03, $C0, $EC, $02, $D0, $E9, $24, $01, $80, $E4, $01, $80, $E1, $01, $80, $E5
	db	$01, $66, $89, $42, $08, $66, $89, $4A, $0A, $AC, $88, $C1, $80, $E1, $FE, $80
	db	$F9, $C4, $0F, $85, $C2, $00, $00, $00, $C6, $42, $18, $0F, $80, $4A, $01, $40
	db	$88, $42, $0C, $88, $C1, $AC, $88, $42, $0D, $F6, $42, $01, $2B, $74, $07, $81
	db	$4A, $35, $00, $20, $00, $00, $80, $F9, $C5, $75, $2C, $88, $C4, $88, $C1, $88
	db	$C5, $D0, $E4, $C0, $E1, $05, $C0, $E8, $07, $C0, $EC, $04, $C0, $E9, $07, $80
	db	$E5, $03, $0C, $FE, $80, $CC, $F0, $F6, $D0, $F6, $D4, $88, $42, $0F, $88, $62
	db	$14, $66, $89, $4A, $15, $EB, $5C, $88, $C4, $88, $C1, $88, $C5, $D0, $E4, $C0
	db	$E1, $02, $C0, $E8, $07, $C0, $EC, $07, $C0, $E9, $07, $80, $E5, $1F, $0C, $FE
	db	$80, $CC, $FE, $80, $C9, $FE, $F6, $D0, $F6, $D4, $F6, $D1, $66, $89, $42, $0F
	db	$66, $89, $4A, $11, $AC, $88, $42, $0E, $88, $C4, $88, $C1, $88, $C3, $D0, $E4
	db	$C0, $E1, $05, $C0, $E8, $07, $C0, $EC, $04, $C0, $E9, $07, $80, $E3, $03, $80
	db	$CC, $F0, $F6, $D4, $66, $89, $42, $13, $88, $4A, $15, $88, $5A, $16, $80, $FD
	db	$01, $75, $04, $B3, $FD, $EB, $73, $B3, $FE, $B7, $38, $88, $7A, $19, $80, $FD
	db	$02, $74, $7D, $B7, $3A, $88, $7A, $19, $EB, $76, $C6, $42, $17, $01, $88, $42
	db	$18, $48, $8D, $1D, $8E, $02, $00, $00, $88, $C4, $8A, $0B, $8A, $2B, $C0, $E9
	db	$05, $80, $E5, $1F, $FE, $C1, $48, $FF, $C3, $28, $C8, $73, $ED, $88, $E8, $48
	db	$8D, $1D, $5A, $02, $00, $00, $D7, $93, $80, $FB, $FF, $75, $0E, $81, $4A, $35
	db	$00, $00, $02, $00, $30, $DB, $E9, $B0, $01, $00, $00, $80, $FB, $FC, $75, $1A
	db	$81, $4A, $35, $00, $10, $00, $00, $80, $62, $01, $DF, $31, $C0, $89, $42, $07
	db	$88, $42, $0B, $88, $F8, $E9, $4B, $FE, $FF, $FF, $80, $FB, $FD, $75, $11, $AC
	db	$C6, $42, $17, $02, $88, $42, $19, $48, $8D, $1D, $8B, $02, $00, $00, $EB, $98
	db	$80, $FB, $FE, $75, $45, $AC, $C6, $42, $17, $03, $88, $42, $1A, $31, $C9, $B4
	db	$43, $B1, $38, $F6, $42, $01, $40, $74, $02, $88, $E1, $48, $8D, $3D, $AA, $02
	db	$00, $00, $B3, $01, $80, $FF, $38, $74, $15, $B4, $20, $B1, $18, $F6, $42, $01
	db	$40, $74, $02, $88, $E1, $48, $8D, $3D, $D3, $02, $00, $00, $B3, $03, $F2, $AE
	db	$0F, $85, $77, $FF, $FF, $FF, $88, $C7, $EB, $24, $80, $FB, $FB, $75, $1F, $48
	db	$8D, $7A, $23, $F6, $42, $01, $10, $74, $0A, $83, $4A, $35, $08, $A5, $E9, $61
	db	$FF, $FF, $FF, $83, $4A, $35, $10, $48, $A5, $E9, $56, $FF, $FF, $FF, $F6, $C3
	db	$01, $0F, $84, $A0, $00, $00, $00, $AC, $83, $4A, $35, $01, $88, $42, $1B, $88
	db	$C1, $88, $C5, $C0, $E5, $02, $C0, $E9, $06, $C0, $ED, $05, $24, $07, $66, $89
	db	$4A, $1C, $88, $42, $1E, $8A, $62, $18, $80, $E4, $FE, $80, $FC, $F6, $75, $07
	db	$84, $ED, $74, $03, $80, $E3, $F5, $80, $F9, $02, $74, $14, $80, $F9, $01, $74
	db	$15, $84, $C9, $75, $15, $3C, $05, $75, $11, $81, $4A, $35, $00, $06, $00, $00
	db	$83, $4A, $35, $08, $EB, $04, $83, $4A, $35, $04, $80, $F9, $03, $74, $30, $3C
	db	$04, $75, $2C, $AC, $83, $4A, $35, $02, $88, $42, $1F, $88, $C4, $88, $C5, $C0
	db	$E4, $02, $C0, $E8, $06, $C0, $EC, $05, $80, $E5, $07, $66, $89, $42, $20, $88
	db	$6A, $22, $84, $C9, $75, $09, $80, $FD, $05, $75, $04, $83, $4A, $35, $08, $48
	db	$8D, $7A, $23, $F7, $42, $35, $08, $00, $00, $00, $74, $01, $A5, $F7, $42, $35
	db	$04, $00, $00, $00, $74, $01, $A4, $48, $8D, $7A, $2B, $F6, $C3, $08, $74, $42
	db	$8A, $42, $18, $24, $F8, $3C, $B8, $75, $14, $80, $7A, $08, $01, $75, $0E, $81
	db	$4A, $35, $00, $01, $00, $00, $48, $A5, $E9, $87, $FE, $FF, $FF, $F6, $C3, $10
	db	$75, $14, $80, $7A, $08, $01, $74, $0E, $F6, $42, $01, $08, $74, $08, $83, $4A
	db	$35, $40, $66, $A5, $EB, $08, $81, $4A, $35, $80, $00, $00, $00, $A5, $48, $8D
	db	$7A, $33, $F6, $C3, $04, $74, $0A, $83, $4A, $35, $40, $66, $A5, $48, $8D, $7A
	db	$33, $F6, $C3, $02, $74, $05, $83, $4A, $35, $20, $A4, $F6, $42, $01, $01, $74
	db	$48, $F6, $C3, $01, $74, $3C, $80, $F9, $03, $74, $37, $B9, $12, $00, $00, $00
	db	$48, $8D, $3D, $B0, $01, $00, $00, $80, $7A, $18, $0F, $74, $0F, $80, $E7, $FE
	db	$B9, $18, $00, $00, $00, $48, $8D, $3D, $83, $01, $00, $00, $38, $3F, $48, $8D
	db	$7F, $02, $E0, $F8, $75, $0C, $8A, $4A, $1D, $8A, $47, $FF, $FE, $C1, $D2, $E8
	db	$73, $07, $81, $4A, $35, $00, $40, $00, $00, $F6, $C3, $40, $74, $07, $81, $4A
	db	$35, $00, $80, $00, $00, $F6, $C3, $10, $74, $07, $81, $4A, $35, $00, $02, $00
	db	$00, $F6, $C3, $20, $74, $07, $81, $4A, $35, $00, $08, $00, $00, $4C, $29, $C6
	db	$40, $88, $32, $40, $80, $FE, $0F, $72, $07, $81, $4A, $35, $00, $00, $01, $00
	db	$31, $C0, $F7, $42, $35, $00, $E0, $03, $00, $0F, $94, $C0, $5F, $5E, $5B, $C3
	db	$00, $01, $03, $09, $02, $04, $06, $08, $12, $18, $21, $23, $29, $40, $41, $42
	db	$4C, $FB, $FC, $FD, $FE, $FF, $61, $04, $07, $2D, $61, $04, $07, $0D, $13, $61
	db	$04, $07, $2D, $61, $04, $07, $2D, $61, $04, $07, $12, $0D, $61, $04, $07, $12
	db	$0D, $61, $04, $07, $12, $0D, $61, $04, $07, $12, $0D, $F2, $F2, $E0, $E0, $2D
	db	$0E, $01, $72, $07, $03, $04, $02, $60, $E8, $E8, $0B, $0C, $2B, $E1, $61, $E0
	db	$20, $10, $80, $71, $60, $04, $07, $A0, $E4, $E7, $2B, $05, $00, $2E, $02, $03
	db	$06, $00, $05, $20, $04, $0D, $00, $6A, $2F, $20, $EA, $68, $64, $29, $10, $08
	db	$60, $12, $00, $32, $20, $0B, $0C, $A0, $2A, $2A, $21, $15, $80, $15, $00, $15
	db	$0A, $00, $02, $E1, $00, $E1, $41, $75, $E1, $A0, $15, $00, $14, $15, $14, $95
	db	$E1, $E1, $E1, $E1, $E1, $E1, $02, $4B, $41, $00, $21, $35, $61, $E9, $E9, $E1
	db	$E1, $40, $01, $02, $01, $35, $20, $0D, $01, $02, $01, $0A, $E1, $41, $0B, $C1
	db	$02, $01, $42, $0A, $E0, $E1, $E1, $E1, $E1, $E1, $C1, $00, $00, $01, $02, $03
	db	$04, $05, $06, $07, $08, $09, $0A, $0B, $10, $14, $15, $17, $1C, $1D, $1E, $20
	db	$21, $22, $23, $24, $25, $28, $29, $2A, $2B, $30, $31, $32, $33, $34, $35, $37
	db	$38, $39, $3A, $3B, $3C, $3D, $3E, $3F, $40, $41, $80, $81, $82, $DB, $DC, $DD
	db	$DE, $DF, $F0, $F1, $0C, $0D, $0E, $0F, $18, $19, $1A, $2C, $2D, $2E, $2F, $08
	db	$09, $0A, $0B, $0C, $0D, $0E, $0F, $14, $15, $16, $17, $20, $21, $22, $40, $41
	db	$42, $44, $60, $61, $62, $63, $DF, $04, $05, $06, $18, $19, $4A, $4B, $4C, $00
	db	$00, $08, $00, $10, $00, $18, $00, $20, $00, $28, $00, $30, $00, $80, $80, $82
	db	$80, $86, $00, $F6, $F3, $FE, $FC, $AB, $00, $B0, $00, $B1, $00, $B3, $00, $BA
	db	$1F, $BB, $00, $C0, $00, $C1, $00, $C7, $FD
end if
