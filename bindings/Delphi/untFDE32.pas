unit untFDE32;

interface

const
  F_NONE              = $00000000;
  F_MODRM             = $00000001;
  F_SIB               = $00000002;
  F_DISP8             = $00000004;
  F_DISP16            = $00000008;
  F_DISP32            = $00000010;
  F_DISP              = F_DISP8 or F_DISP16 or F_DISP32;
  F_IMM8              = $00000020;
  F_IMM16             = $00000040;
  F_IMM32             = $00000080;
  F_IMM               = F_IMM8 or F_IMM16 or F_IMM32;
  F_RELATIVE          = $00000100;
  F_GROUP             = $00000200;
  F_VEX_BAD_PREFIX    = $00000400;
  F_ERROR_LOCK        = $00000800;
  F_ERROR_LENGTH      = $00001000;
  F_ERROR_OPCODE      = $00002000;

const
  PRE_NONE            = $00;
  PRE_LOCK            = $01;
  PRE_REP             = $02;
  PRE_SEG             = $04;
  PRE_66              = $08;
  PRE_67              = $10;
  PRE_VEX             = $20;
  PRE_ALL             = PRE_LOCK or PRE_REP or PRE_SEG or PRE_66 or PRE_67;
  PRE_ALL32           = PRE_ALL or PRE_VEX;

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
  REG_EAX             = 0;
  REG_ECX             = 1;
  REG_EDX             = 2;
  REG_EBX             = 3;
  REG_ESP             = 4;
  REG_EBP             = 5;
  REG_ESI             = 6;
  REG_EDI             = 7;
  REG_AL              = REG_EAX;
  REG_AH              = REG_ESP;
  REG_CL              = REG_ECX;
  REG_CH              = REG_EBP;
  REG_DL              = REG_EDX;
  REG_DH              = REG_ESI;
  REG_BL              = REG_EBX;
  REG_BH              = REG_EDI;
  REG_DR0             = REG_EAX;
  REG_DR1             = REG_ECX;
  REG_DR2             = REG_EDX;
  REG_DR3             = REG_EBX;
  REG_DR4             = REG_ESP;
  REG_DR5             = REG_EBP;
  REG_DR6             = REG_ESI;
  REG_DR7             = REG_EDI;
  REG_CR0             = REG_EAX;
  REG_CR2             = REG_EDX;
  REG_CR3             = REG_EBX;
  REG_CR4             = REG_ESP;
  REG_SIMD0           = REG_EAX;
  REG_SIMD1           = REG_ECX;
  REG_SIMD2           = REG_EDX;
  REG_SIMD3           = REG_EBX;
  REG_SIMD4           = REG_ESP;
  REG_SIMD5           = REG_EBP;
  REG_SIMD6           = REG_ESI;
  REG_SIMD7           = REG_EDI;
  REG_ST0             = REG_EAX;
  REG_ST1             = REG_ECX;
  REG_ST2             = REG_EDX;
  REG_ST3             = REG_EBX;
  REG_ST4             = REG_ESP;
  REG_ST5             = REG_EBP;
  REG_ST6             = REG_ESI;
  REG_ST7             = REG_EDI;
  SEG_ES              = REG_EAX;
  SEG_CS              = REG_ECX;
  SEG_SS              = REG_EDX;
  SEG_DS              = REG_EBX;
  SEG_FS              = REG_ESP;
  SEG_GS              = REG_EBP;

const
  RM_SIB              = REG_ESP;
  RM_DISP32           = REG_EBP;

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
  PREFIX_VEX_2_BYTE   = $C5;
  PREFIX_VEX_3_BYTE   = $C4;

type
  TFDE32S = packed record
    len: Byte;
    prefix: Byte;
    prefix_lock: Byte;
    prefix_rep: Byte;
    prefix_seg: Byte;
    prefix_66: Byte;
    prefix_67: Byte;
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
      1: (disp16: Word);
      2: (disp32: LongWord);
    end;
    imm: packed record case Byte of
      0: (imm8 : Byte);
      1: (imm16: Word);
      2: (imm32: LongWord);
    end;
    imm2: packed record case Byte of
      0: (imm8 : Byte);
      1: (imm16: Word);
    end;
    flags: LongWord;
  end;

function FDE32Decode(lpCode: Pointer; var FDE: TFDE32S): LongWord;
function FDE32Encode(lpCode: Pointer; var FDE: TFDE32S): LongWord;

implementation

function _FDE32Decode(lpCode: Pointer; var FDE: TFDE32S): LongWord; cdecl;
  external name 'decode';
function _FDE32Encode(lpCode: Pointer; var FDE: TFDE32S): LongWord; cdecl;
  external name 'encode';

{$L FDE32.obj}

end.
