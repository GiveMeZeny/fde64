unit untFDE64;

interface

const
  F_NONE              = $00000000;
  F_MODRM             = $00000001;
  F_SIB               = $00000002;
  F_DISP8             = $00000004;
  F_DISP32            = $00000008;
  F_DISP64            = $00000010;
  F_DISP              = F_DISP8 or F_DISP32 or F_DISP64;
  F_IMM8              = $00000020;
  F_IMM16             = $00000040;
  F_IMM32             = $00000080;
  F_IMM64             = $00000100;
  F_IMM               = F_IMM8 or F_IMM16 or F_IMM32 or F_IMM64;
  F_RELATIVE          = $00000200;
  F_RIPDISP32         = $00000400;
  F_GROUP             = $00000800;
  F_REX_IGNORED       = $00001000;
  F_VEX_BAD_PREFIX    = $00002000;
  F_ERROR_LOCK        = $00004000;
  F_ERROR_X86_64      = $00008000;
  F_ERROR_LENGTH      = $00010000;
  F_ERROR_OPCODE      = $00020000;

const
  PRE_NONE            = $00;
  PRE_LOCK            = $01;
  PRE_REP             = $02;
  PRE_SEG             = $04;
  PRE_66              = $08;
  PRE_67              = $10;
  PRE_REX             = $20;
  PRE_VEX             = $40;
  PRE_ALL             = PRE_LOCK or PRE_REP or PRE_SEG or PRE_66 or PRE_67;
  PRE_ALL64           = PRE_ALL or PRE_REX or PRE_VEX;

const
  M_MMMM_0F           = 1;
  M_MMMM_0F_38        = 2;
  M_MMMM_0F_3A        = 3;

const
  L_SCALAR            = 0;
  L_128_VECTOR        = 0;
  L_256_VECTOR        = 1;

const
  PP_NONE             = 0;
  PP_66               = 1;
  PP_F3               = 2;
  PP_F2               = 3;

const
  MOD_NODISP          = 0;
  MOD_DISP8           = 1;
  MOD_DISP32          = 2;
  MOD_REG             = 3;

const
  REG_RAX             = 0;
  REG_RCX             = 1;
  REG_RDX             = 2;
  REG_RBX             = 3;
  REG_RSP             = 4;
  REG_RBP             = 5;
  REG_RSI             = 6;
  REG_RDI             = 7;
  REG_R8              = REG_RAX;
  REG_R9              = REG_RCX;
  REG_R10             = REG_RDX;
  REG_R11             = REG_RBX;
  REG_R12             = REG_RSP;
  REG_R13             = REG_RBP;
  REG_R14             = REG_RSI;
  REG_R15             = REG_RDI;
  REG_AL              = REG_RAX;
  REG_AH              = REG_RSP;
  REG_CL              = REG_RCX;
  REG_CH              = REG_RBP;
  REG_DL              = REG_RDX;
  REG_DH              = REG_RSI;
  REG_BL              = REG_RBX;
  REG_BH              = REG_RDI;
  REG_SPL             = REG_AH;
  REG_SBL             = REG_CH;
  REG_SIL             = REG_DH;
  REG_DIL             = REG_BH;
  REG_DR0             = REG_RAX;
  REG_DR1             = REG_RCX;
  REG_DR2             = REG_RDX;
  REG_DR3             = REG_RBX;
  REG_DR4             = REG_RSP;
  REG_DR5             = REG_RBP;
  REG_DR6             = REG_RSI;
  REG_DR7             = REG_RDI;
  REG_CR0             = REG_RAX;
  REG_CR2             = REG_RDX;
  REG_CR3             = REG_RBX;
  REG_CR4             = REG_RSP;
  REG_CR8             = REG_RAX;
  REG_SIMD0           = REG_RAX;
  REG_SIMD1           = REG_RCX;
  REG_SIMD2           = REG_RDX;
  REG_SIMD3           = REG_RBX;
  REG_SIMD4           = REG_RSP;
  REG_SIMD5           = REG_RBP;
  REG_SIMD6           = REG_RSI;
  REG_SIMD7           = REG_RDI;
  REG_SIMD8           = REG_RAX;
  REG_SIMD9           = REG_RCX;
  REG_SIMD10          = REG_RDX;
  REG_SIMD11          = REG_RBX;
  REG_SIMD12          = REG_RSP;
  REG_SIMD13          = REG_RBP;
  REG_SIMD14          = REG_RSI;
  REG_SIMD15          = REG_RDI;
  REG_ST0             = REG_RAX;
  REG_ST1             = REG_RCX;
  REG_ST2             = REG_RDX;
  REG_ST3             = REG_RBX;
  REG_ST4             = REG_RSP;
  REG_ST5             = REG_RBP;
  REG_ST6             = REG_RSI;
  REG_ST7             = REG_RDI;
  SEG_ES              = REG_RAX;
  SEG_CS              = REG_RCX;
  SEG_SS              = REG_RDX;
  SEG_DS              = REG_RBX;
  SEG_FS              = REG_RSP;
  SEG_GS              = REG_RBP;

const
  RM_SIB              = REG_RSP;
  RM_DISP32           = REG_RBP;

const
  SCALE_1             = 0;
  SCALE_2             = 1;
  SCALE_4             = 2;
  SCALE_8             = 3;

const
  PREFIX_SEGMENT_CS   = $2E;
  PREFIX_SEGMENT_SS   = $36;
  PREFIX_SEGMENT_DS   = $3E;
  PREFIX_SEGMENT_ES   = $26;
  PREFIX_SEGMENT_FS   = $64;
  PREFIX_SEGMENT_GS   = $65;
  PREFIX_LOCK         = $F0;
  PREFIX_REPNZ        = $F2;
  PREFIX_REP          = $F3;
  PREFIX_OPERAND_SIZE = $66;
  PREFIX_ADDRESS_SIZE = $67;
  PREFIX_REX_START    = $40;
  PREFIX_REX_END      = $4F;
  PREFIX_VEX_2_BYTE   = $C5;
  PREFIX_VEX_3_BYTE   = $C4;

type
  TFDE64S = packed record
    len: Byte;
    prefix: Byte;
    prefix_lock: Byte;
    prefix_rep: Byte;
    prefix_seg: Byte;
    prefix_66: Byte;
    prefix_67: Byte;
    rex: Byte;
    rex_w: Byte;
    rex_r: Byte;
    rex_x: Byte;
    rex_b: Byte;
    vex: Byte;
    vex2: Byte;
    vex3: Byte;
    vex_r: Byte;
    vex_x: Byte;
    vex_b: Byte;
    vex_m_mmmm: Byte;
    vex_w: Byte;
    vex_vvvv: Byte;
    vex_l: Byte;
    vex_pp: Byte;
    opcode_len: Byte;
    opcode: Byte;
    opcode2: Byte;
    opcode3: Byte;
    modrm: Byte;
    modrm_mod: Byte;
    modrm_reg: Byte;
    modrm_rm: Byte;
    sib: Byte;
    sib_scale: Byte;
    sib_index: Byte;
    sib_base: Byte;
    disp: packed record case Byte of
      0: (disp8 : Byte);
      1: (disp32: LongWord);
      2: (disp64: UInt64);
    end;
    imm: packed record case Byte of
      0: (imm8 : Byte);
      1: (imm16: Word);
      2: (imm32: LongWord);
      3: (imm64: UInt64);
    end;
    imm2: packed record case Byte of
      0: (imm8 : Byte);
      1: (imm16: Word);
    end;
    flags: LongWord;
  end;

function FDE64Decode(lpCode: Pointer; var FDE: TFDE64S): LongWord;
  external name 'decode';
function FDE64Encode(lpCode: Pointer; var FDE: TFDE64S): LongWord;
  external name 'encode';

{$L FDE64.obj}

implementation

end.
