	include 'win64w.inc'

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
  REG_CR0	      = REG_RAX
  REG_CR2	      = REG_RDX
  REG_CR3	      = REG_RBX
  REG_CR4	      = REG_RSP
  REG_CR8	      = REG_RAX 	; cr8 is being used if rex.r=1
  REG_DR0	      = REG_RAX
  REG_DR1	      = REG_RCX
  REG_DR2	      = REG_RDX
  REG_DR3	      = REG_RBX
  REG_DR4	      = REG_RSP 	; refers to DR6 if CR4.DE is cleared
  REG_DR5	      = REG_RBP 	; refers to DR7 ^
  REG_DR6	      = REG_RSI
  REG_DR7	      = REG_RDI
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
