  un[f]ancy [d]isassembler [e]ngine (fde64) v0.04

  fde64 is an extended length disassembler engine
  it's written in x64 asm for use with x64 instructions
  and supports the following instruction sets:
    * general-purpose instructions
    * FPU, MMX, 3DNow!
    * SSE-SSE4.2, AVX
    * VMX, SMX


how to compile:

  use fasm (http://flatassembler.net/) to compile encode.asm and decode.asm,
  place the bin-files into bin/ and compile fde64.asm to a x64 coff obj-file.
  you can also compile and exec packtbl.c and redirect its output into a new
  decode.asm to get one that is a little smaller.


how to use:

    int encode(void *dest, fde64s *cmd);
    int decode(void *src,  fde64s *cmd);

    lea     rdx,[fde64s_struct]
    mov     rcx,[destination]
    call    encode

    lea     rdx,[fde64s_struct]
    mov     rcx,[source]
    call    decode

  encode returns the number of bytes written to the buffer
  decode returns either 1 if the instruction is valid or 0 if any error-flag is set


fde64s-struct explanation:

  len
    contains the instruction's size
  prefix
    specifies the prefix flags (PRE_LOCK, PRE_REP, PRE_SEG, PRE_66, PRE_67, PRE_REX, PRE_VEX)
  prefix.lock
    equal to PREFIX_LOCK if PRE_LOCK is set, zero elsewise
  prefix.rep
    equal to PREFIX_REPNZ/PREFIX_REP if PRE_REP is set, zero elsewise
  prefix.seg
    equal to PREFIX_SEGMENT_XX if PRE_SEG is set, zero elsewise
  prefix.66
    equal to PREFIX_OPERAND_SIZE if PRE_66 is set, zero elsewise
  prefix.67
    equal to PREFIX_ADDRESS_SIZE if PRE_67 is set, zero elsewise
  rex
    full rex-byte
  rex.w
    extracted w-component of rex-byte
  rex.r
    extracted r-component of rex-byte
  rex.x
    extracted x-component of rex-byte
  rex.b
    extracted b-component of rex-byte
  vex
    vex escape-byte (C4h/C5h)
  vex2
    full second vex-byte
  vex3
    full third vex-byte
  vex.r
    extracted r-component of vex-byte
  vex.x
    extracted x-component of vex-byte
  vex.b
    extracted b-component of vex-byte
  vex.m_mmmm
    extracted m_mmmm-component of vex-byte
  vex.w
    extracted w-component of vex-byte
  vex.vvvv
    extracted vvvv-component of vex-byte
  vex.l
    extracted l-component of vex-byte
  vex.pp
    extracted pp-component of vex-byte
  opcode.len
    amount of opcode-bytes (1-3, necessary prefixes for various SSE instruction are not counted in)
  opcode
    first opcode
  opcode2
    second opcode
  opcode3
    third opcode
  modrm
    full modr/m-byte
  modrm.mod
    extracted mod-component of modr/m-byte
  modrm.reg
    extracted reg-component of modr/m-byte
  modrm.rm
    extracted rm-component of modr/m-byte
  sib
    full sib-byte
  sib.scale
    extracted scale-component of sib-byte
  sib.index
    extracted index-component of sib-byte
  sib.base
    extracted base-component of sib-byte
  dispXX
    displacement, check flags for size
  immXX
    immediate, check flags for size
  immXX_2
    second immediate, only relevant to call/jmp ptr16:32 and enter imm16, imm8
  flags
    see below


flags explanation:

  F_MODRM, F_SIB, F_DISP8/32, F_IMM8/16/32
    self-explanatory
  F_DISP64
    means the disassembled instruction uses a direct memory-offset (an absolute memory address)
  F_IMM64
    means the disassembled instruction is specifically encoded to move a whole x64 immediate into a general-purpose register
  F_RELATIVE
    is for instructions with RIP-relative immediates like calls and jmps, but also for those with RIP-relative displacements
  F_RIPDISP32
    means the modrm-byte contains a RIP-relative 4-byte displacement (if this is set, then so is F_RELATIVE, but not vice versa)
  F_GROUP
    means modrm.reg is used as an opcode extension
  F_REX_IGNORED
    warning: there are rex-prefixes which do not precede the opcode and thus are being ignored
  F_VEX_BAD_PREFIX
    error-flag: an avx instruction has illegally either a opsize-override-, rep-, rex- or lock-prefix
  F_ERROR_LOCK
    error-flag: the disassembled instruction is not allowed to have a lock-prefix
  F_ERROR_X86_64
    error-flag: the disassembled instruction is invalid under x64 (like e.g. push cs, les, bound, aaa, pushad, etc.)
  F_ERROR_LENGTH
    error-flag: the instruction-size limit of 15 bytes is exceeded (the said instruction will cause an exception)
  F_ERROR_OPCODE
    error-flag: the disassembled opcode is undefined (aborts forthwith, so far disassembled prefixes are kept)

  if any of those error-flags is set, the disassembled instruction will #UD


notes:

* encode simply writes one byte after another to the buffer if appropriate flags are set.
  e.g. if fde64s.prefix specifies PRE_66 , 66h gets written to the buffer.
                                  PRE_REP, fde64s.prefix.rep gets written.
                                  PRE_VEX, either the full bytes (fde64s.vex2/.vex3) get written or the vex-bytes get reconstructed (see below).

       if fde64s.flags  specifies F_MODRM, either the modr/m-byte gets reconstructed by using fde64s.modrm.mod, fde64s.modrm.reg and fde64s.modrm.rm
                                           or fde64s.modrm gets written directly to the buffer if fde64s.modrm.mod is equal to -1/FFh.
       (same rule applies to the rex-, the vex-prefix and the sib-byte according to fde64s.rex.w, fde64s.vex.r and fde64s.sib.scale)

* an instruction encoded with a vex-prefix actually only has one opcode, but leading escape opcodes are implied via the m_mmmm-component.
  for convenience, decode will write these to fde64s.opcode (and fde64s.opcode2 if necessary) so the actual instruction-opcode will be written to
  either fde64s.opcode2 or fde64s.opcode3 (so you can e.g. search for specific instructions using only the very opcode without ambiguities).
  encode also expects the actual opcode in either of those depending on the m_mmmm-component.

* F_ERROR_OPCODE: only the three opcode bytes get validated. however, opcode extensions like modrm.reg from F_GROUP-instructions,
  the imm8 following the modrm-byte from 3DNow!-instructions or opcode-prefix combinations are not checked for correctness.
  example: FE C0 gets decoded to PRE_NONE / F_GROUP | F_MODRM (modrm.reg=0 => "inc al")
           FE C8 gets decoded to PRE_NONE / F_GROUP | F_MODRM (modrm.reg=1 => "dec al")
           FE D0 gets decoded to PRE_NONE / F_GROUP | F_MODRM (modrm.reg=2 => #UD),
                 it's actually an erroneous opcode, F_ERROR_OPCODE won't be set, though, as such extensions are not being validated
           66 7D gets decoded to PRE_66 / F_MODRM (=> "hsubpd xmm1, xmm2/m128")
              7D gets decoded to          F_MODRM (=> #UD)
                 actually an erroneous opcode again, but prefixes are not checked for necessity, thus F_ERROR_OPCODE won't be set

* some instructions like enter have two immediates, the first one is contained in fde64s.imm32/fde64s.imm16 depending on the immediate's size,
  the second one in fde64s.imm16_2/fde64s.imm8_2 (there are no instructions with a second immediate bigger than 2 bytes).
  the flags, however, are not seperated means if an instruction had 2 word immediates like call ptr16:16 (66h-prefix) the flags would specify F_IMM16 which represents both immediates.
  it's not really important, though, as there are only 3 instructions which have 2 immediates (see immXX_2) and only 2 of them might have overlapping flags but are invalid under x64 in any case.










version 0.01

[!] Initial release

version 0.02

[+] added F_ERROR_LENGTH for instructions bigger than 15 bytes

[-] now handles too many prefixes and wrong rex-prefixes correctly

[-] fixed operand-override prefix when rex.w=1

version 0.03

[+] now fills the opcode of vex-prefixed instructions into the appropriate fde64s.opcode-field
    and precedes it with the implied leading escape opcodes (see notes)

[-] now handles consecutive rex-prefixes correctly

version 0.04

[+] added fde64s.opcode.len and F_RIPDISP32 (for distinguishing between RIP-disps and -imms)

[+] added some missing opcodes like 3DNow!, VMX and AVX-opcodes only encodable with a vex-prefix

[+] added checking of F_ERROR_OPCODE for vex-prefixed instructions

[-] decreased size from >1650 to 1337 bytes

[-] fixed operand-override prefix for rel32 instructions
