format PE64 GUI 5.0
entry start

include 'win64a.inc'

macro init_str b,f
 { local is_dword
   virtual
    inc f
    load is_dword from $$
    is_dword = is_dword and 1
   end virtual
   lea rbx,[b]
   if is_dword
    mov esi,f
   else
    movzx esi,f
   end if
   mov byte [rbx],0 }

macro if_set_then_cat f,s
 { local .skip
   test esi,f
   je .skip
   lea rdx,[s]
   mov rcx,rbx
   call [lstrcat]
  .skip: }

macro fin_str n
 { local .empty,.ok
   cmp byte [rbx],0
   je .empty
   mov rcx,rbx
   call [lstrlen]
   mov byte [rbx+rax-1],0
   jmp .ok
  .empty:
   lea rdx,[n]
   mov rcx,rbx
   call [lstrcpy]
  .ok: }

macro init_push_stuff n
 { push_stuff_counter = n }

macro push_stuff v,b
 { local size_of_v
   if v eqtype ptr
    virtual
     inc v
     load size_of_v from $$
     if (size_of_v and 0F0h)=40h
      size_of_v = 2
     else
      size_of_v = size_of_v and 1
     end if
    end virtual
    if size_of_v=2
     if push_stuff_counter=0
      mov rcx,v
     else if push_stuff_counter=1
      mov rdx,v
     else if push_stuff_counter=2
      mov r8,v
     else if push_stuff_counter=3
      mov r9,v
     else
      mov rax,v
      mov [rsp+8*(push_stuff_counter)],rax
     end if
    else
     if push_stuff_counter=0
      if size_of_v
       mov ecx,v
      else
       movzx ecx,v
      end if
     else if push_stuff_counter=1
      if size_of_v
       mov edx,v
      else
       movzx edx,v
      end if
     else if push_stuff_counter=2
      if size_of_v
       mov r8d,v
      else
       movzx r8d,v
      end if
     else if push_stuff_counter=3
      if size_of_v
       mov r9d,v
      else
       movzx r9d,v
      end if
     else
      if size_of_v
       mov eax,v
      else
       movzx eax,v
      end if
      mov [rsp+8*(push_stuff_counter)],eax
     end if
    end if
   else
    if push_stuff_counter=0
     lea rcx,[v]
    else if push_stuff_counter=1
     lea rdx,[v]
    else if push_stuff_counter=2
     lea r8,[v]
    else if push_stuff_counter=3
     lea r9,[v]
    else
     lea rax,[v]
     mov [rsp+8*(push_stuff_counter)],rax
    end if
   end if
   if b eq
    push_stuff_counter = push_stuff_counter+1
   end if }

section '.code' code readable executable writeable

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  testcode:

	nop				; por xmm7,xmm4
	nop
	nop
	nop
					; same instruction, but encoded with a vex-prefix which adds xmm3:
	nop				; vpor xmm7,xmm3,xmm4
	nop
	nop
	nop

	db	0C4h,0E2h,079h,018h,006h ; vbroadcastss xmm0,[rsi]
					 ; would be like this without vex:
	db	066h,00Fh,038h,018h,006h ; however, vbroadcastss can only be encoded with a vex-prefix
					 ; thus 018h will lead to F_ERROR_OPCODE
					 ; leaving 006h alone, making it "push es"

	vextractf128 xmm1,ymm2,88

	vblendvpd xmm2,xmm3,xmm4,xmm7

	db	4Fh,49h,49h,49h,49h,49h,4Ch ; bunch of rex-prefixes
	mov	eax,ebx

	mov	eax,[testcode]		; RIP-relative disp32 (F_RELATIVE|F_RIPDISP32)

	jnc	testcode		; RIP-relative imm8 (F_RELATIVE)

	mov	r15,1122334455667788h

	mov	eax,[qword 1122334455667788h]

	db	67h
	mov	eax,[qword 9090909011223344h] ; moffset with address-override

	enter	1122h,11h

	add	[eax*4+11223344h],rax

	add	[ebx+eax*8+11h],rax

	movsxd	rax,eax

	add	dil,[rdx+sizeof.fde64s]

	db	66h,4Fh,66h,66h,66h,4Dh,66h,66h,66h,66h,66h,66h ; bunch of prefixes
	mov	rax,[eax]					; pushing the instruction-size over the limit

	pfnacc	mm0,mm1 		; 3DNow!

	lock vpmaxub ymm10,ymm2,[r15]

	vpmaxub xmm10,xmm2,[r15]

	vshufpd ymm8,ymm15,ymm10,11h

	vpor	xmm7,xmm3,xmm4

	imul	eax,[eax*4+11223344h],32

	lock mul dword [eax]

	lock shl dword [eax],1

	rdtsc

	rdtscp

	test	byte [eax],88h

	neg	byte [eax]

	vshufpd ymm1,ymm2,ymm3,11h

	vpslldq xmm1,xmm2,11h

	db	66h
	vpextrq r15,xmm3,99h

	db	67h
	vpalignr xmm1,xmm2,xmm3,88h

	lock add [eax],eax

	lock add eax,[eax]

	sysenter

	use32

	call	1122h:11223344h

	aam	7

	push	cs

	use64

  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  start:
	sub	rsp,8*(4+37)

	; encode example usage

	mov	[cmd.opcode],00Fh	; => por xmm7,xmm4
	mov	[cmd.opcode2],0EBh
	or	[cmd.flags],F_MODRM
	or	[cmd.prefix],PRE_66
       ;mov	[cmd.prefix.66],66h	; not necessary, PRE_66 in .prefix is sufficient
	mov	[cmd.modrm.mod],MOD_REG
	mov	[cmd.modrm.reg],REG_SIMD7
	mov	[cmd.modrm.rm],REG_SIMD4

	lea	rdx,[cmd]
	lea	rcx,[testcode]
	call	encode

	xor	al,al
	lea	rdi,[cmd]
	mov	ecx,sizeof.fde64s
	rep	stosb

       ;mov	[cmd.opcode],00Fh	; leading escape bytes in .opcode/.opcode2 are not necessary if the instruction has a vex-prefix
					; if it's a 2-byte vex-prefix, a leading 0F is implied
					; if it's a 3-byte vex-prefix, pass M_MMMM_0F, M_MMMM_0F_38 or M_MMMM_0F_3A via vex.m_mmmm
	mov	[cmd.opcode2],0EBh	; => vpor xmm7,xmm3,xmm4
					; although there actually are no escape bytes the opcode has to be placed in .opcode2(/.opcode3)
					; as if there was a leading 0F in .opcode (or e.g. 0F 3A in .opcode and .opcode2)
	or	[cmd.flags],F_MODRM
	or	[cmd.prefix],PRE_VEX
	mov	[cmd.vex],PREFIX_VEX_2_BYTE
	mov	[cmd.vex.pp],PP_66
	mov	[cmd.modrm.mod],MOD_REG
	mov	[cmd.modrm.reg],REG_SIMD7
	mov	[cmd.vex.vvvv],REG_SIMD3
	mov	[cmd.modrm.rm],REG_SIMD4

	lea	rdx,[cmd]
	lea	rcx,[testcode+4]
	call	encode

	xor	al,al
	lea	rdi,[cmd]
	mov	ecx,sizeof.fde64s
	rep	stosb

	; decode example usage

	lea	rdi,[testcode]

    .loop:

	lea	rdx,[cmd]
	movzx	eax,[cmd.len]
	add	rdi,rax
	mov	rcx,rdi
	call	decode

	; prepare buffer for messagebox

	init_str flags,[cmd.flags]
	if_set_then_cat F_GROUP,_F_GROUP
	if_set_then_cat F_MODRM,_F_MODRM
	if_set_then_cat F_SIB,_F_SIB
	if_set_then_cat F_DISP8,_F_DISP8
	if_set_then_cat F_DISP32,_F_DISP32
	if_set_then_cat F_DISP64,_F_DISP64
	if_set_then_cat F_IMM64,_F_IMM64
	if_set_then_cat F_IMM32,_F_IMM32
	if_set_then_cat F_IMM16,_F_IMM16
	if_set_then_cat F_IMM8,_F_IMM8
	if_set_then_cat F_RELATIVE,_F_RELATIVE
	if_set_then_cat F_RIPDISP32,_F_RIPDISP32
	if_set_then_cat F_REX_IGNORED,_F_REX_IGNORED
	if_set_then_cat F_VEX_BAD_PREFIX,_F_VEX_BAD_PREFIX
	if_set_then_cat F_ERROR_X86_64,_F_ERROR_X86_64
	if_set_then_cat F_ERROR_LOCK,_F_ERROR_LOCK
	if_set_then_cat F_ERROR_LENGTH,_F_ERROR_LENGTH
	if_set_then_cat F_ERROR_OPCODE,_F_ERROR_OPCODE
	fin_str _F_NONE

	init_str prefixes,[cmd.prefix]
	if_set_then_cat PRE_LOCK,_PRE_LOCK
	if_set_then_cat PRE_REP,_PRE_REP
	if_set_then_cat PRE_SEG,_PRE_SEG
	if_set_then_cat PRE_66,_PRE_66
	if_set_then_cat PRE_67,_PRE_67
	if_set_then_cat PRE_REX,_PRE_REX
	if_set_then_cat PRE_VEX,_PRE_VEX
	fin_str _PRE_NONE

	init_push_stuff 2

	push_stuff [cmd.len]
	push_stuff prefixes
	push_stuff [cmd.prefix.lock]
	push_stuff [cmd.prefix.rep]
	push_stuff [cmd.prefix.seg]
	push_stuff [cmd.prefix.66]
	push_stuff [cmd.prefix.67]
	push_stuff [cmd.rex]
	push_stuff [cmd.rex.w]
	push_stuff [cmd.rex.r]
	push_stuff [cmd.rex.x]
	push_stuff [cmd.rex.b]
	push_stuff [cmd.vex]
	push_stuff [cmd.vex2]
	push_stuff [cmd.vex3]
	push_stuff [cmd.vex.r]
	push_stuff [cmd.vex.x]
	push_stuff [cmd.vex.b]

	test	[cmd.prefix],PRE_VEX
	je	.m_mmmm_empty
	cmp	[cmd.vex],0C5h
	je	.m_mmmm_0F
	cmp	[cmd.vex.m_mmmm],M_MMMM_0F
	je	.m_mmmm_0F
	cmp	[cmd.vex.m_mmmm],M_MMMM_0F_38
	je	.m_mmmm_0F_38
	push_stuff _M_MMMM_0F_3A,1
	jmp	.m_mmmm_done
      .m_mmmm_0F:
	push_stuff _M_MMMM_0F,1
	jmp	.m_mmmm_done
      .m_mmmm_0F_38:
	push_stuff _M_MMMM_0F_38,1
	jmp	.m_mmmm_done
      .m_mmmm_empty:
	push_stuff _EMPTY
      .m_mmmm_done:

	push_stuff [cmd.vex.w]
	push_stuff [cmd.vex.vvvv]

	test	[cmd.prefix],PRE_VEX
	je	.l_empty
	cmp	[cmd.vex.l],L_128_VECTOR
	je	.l_128
	push_stuff _L_256_VECTOR,1
	jmp	.l_done
      .l_128:
	push_stuff _L_128_VECTOR,1
	jmp	.l_done
      .l_empty:
	push_stuff _EMPTY
      .l_done:

	test	[cmd.prefix],PRE_VEX
	je	.pp_empty
	cmp	[cmd.vex.pp],PP_NONE
	je	.pp_none
	cmp	[cmd.vex.pp],PP_66
	je	.pp_66
	cmp	[cmd.vex.pp],PP_F3
	je	.pp_f3
	push_stuff _PP_F2,1
	jmp	.pp_done
      .pp_none:
	push_stuff _PP_NONE,1
	jmp	.pp_done
      .pp_66:
	push_stuff _PP_66,1
	jmp	.pp_done
      .pp_f3:
	push_stuff _PP_F3,1
	jmp	.pp_done
      .pp_empty:
	push_stuff _EMPTY
      .pp_done:

	push_stuff [cmd.opcode.len]
	push_stuff [cmd.opcode]
	push_stuff [cmd.opcode2]
	push_stuff [cmd.opcode3]
	push_stuff [cmd.modrm]

	test	[cmd.flags],F_MODRM
	je	.mod_empty
	cmp	[cmd.modrm.mod],MOD_NODISP
	je	.mod_nodisp
	cmp	[cmd.modrm.mod],MOD_DISP8
	je	.mod_disp8
	cmp	[cmd.modrm.mod],MOD_DISP32
	je	.mod_disp32
	push_stuff _MOD_REG,1
	jmp	.mod_done
      .mod_nodisp:
	push_stuff _MOD_NODISP,1
	jmp	.mod_done
      .mod_disp8:
	push_stuff _MOD_DISP8,1
	jmp	.mod_done
      .mod_disp32:
	push_stuff _MOD_DISP32,1
	jmp	.mod_done
      .mod_empty:
	push_stuff _EMPTY
      .mod_done:

	push_stuff [cmd.modrm.reg]
	push_stuff [cmd.modrm.rm]
	push_stuff [cmd.sib]

	test	[cmd.flags],F_SIB
	je	.scale_empty
	cmp	[cmd.sib.scale],SCALE_1
	je	.scale_1
	cmp	[cmd.sib.scale],SCALE_2
	je	.scale_2
	cmp	[cmd.sib.scale],SCALE_4
	je	.scale_4
	push_stuff _SCALE_8,1
	jmp	.scale_done
      .scale_1:
	push_stuff _SCALE_1,1
	jmp	.scale_done
      .scale_2:
	push_stuff _SCALE_2,1
	jmp	.scale_done
      .scale_4:
	push_stuff _SCALE_4,1
	jmp	.scale_done
      .scale_empty:
	push_stuff _EMPTY
      .scale_done:

	push_stuff [cmd.sib.index]
	push_stuff [cmd.sib.base]
	push_stuff [cmd.disp64]
	push_stuff [cmd.imm64]
	push_stuff [cmd.imm16_2]
	push_stuff flags

	lea	rdx,[_msg]
	lea	rcx,[buf]
	call	[wsprintf]

	; show messagebox

	mov	r9d,MB_OKCANCEL
	lea	r8,[_title]
	lea	rdx,[buf]
	xor	ecx,ecx
	call	[MessageBox]

	cmp	eax,IDOK
	je	.loop

	xor	ecx,ecx
	call	[ExitProcess]

	include 'fde64.inc'

section '.data' data readable writeable

  _title db 'disassembling..',0

  _msg db 'len:',9,9,'%d',13,10,13,10,\
	 'prefix:',9,9,'%s',13,10,\
	 'prefix.lock:',9,'%02X',13,10,\
	 'prefix.rep:',9,9,'%02X',13,10,\
	 'prefix.seg:',9,9,'%02X',13,10,\
	 'prefix.66:',9,9,'%02X',13,10,\
	 'prefix.67:',9,9,'%02X',13,10,13,10,\
	 'rex:',9,9,'%02X',13,10,\
	 'rex.w:',9,9,'%02X',13,10,\
	 'rex.r:',9,9,'%02X',13,10,\
	 'rex.x:',9,9,'%02X',13,10,\
	 'rex.b:',9,9,'%02X',13,10,13,10,\
	 'vex:',9,9,'%02X',13,10,\
	 'vex2:',9,9,'%02X',13,10,\
	 'vex3:',9,9,'%02X',13,10,\
	 'vex.r:',9,9,'%02X',13,10,\
	 'vex.x:',9,9,'%02X',13,10,\
	 'vex.b:',9,9,'%02X',13,10,\
	 'vex.m_mmmm:',9,'%s',13,10,\
	 'vex.w:',9,9,'%02X',13,10,\
	 'vex.vvvv:',9,9,'%02X',13,10,\
	 'vex.l:',9,9,'%s',13,10,\
	 'rex.pp:',9,9,'%s',13,10,13,10,\
	 'opcode.len:',9,'%d',13,10,\
	 'opcode:',9,9,'%02X',13,10,\
	 'opcode2:',9,9,'%02X',13,10,\
	 'opcode3:',9,9,'%02X',13,10,13,10,\
	 'modrm:',9,9,'%02X',13,10,\
	 'modrm.mod:',9,'%s',13,10,\
	 'modrm.reg:',9,'%02X',13,10,\
	 'modrm.rm:',9,'%02X',13,10,13,10,\
	 'sib:',9,9,'%02X',13,10,\
	 'sib.scale:',9,9,'%s',13,10,\
	 'sib.index:',9,9,'%02X',13,10,\
	 'sib.base:',9,9,'%02X',13,10,13,10,\
	 'disp:',9,9,'%02I64X',13,10,\
	 'imm:',9,9,'%02I64X',13,10,\
	 'imm_2:',9,9,'%02X',13,10,13,10,\
	 'flags:',9,9,'%s',13,10,0

  _F_NONE	       db 'F_NONE',0
  _F_MODRM	       db 'F_MODRM|',0
  _F_SIB	       db 'F_SIB|',0
  _F_DISP8	       db 'F_DISP8|',0
  _F_DISP32	       db 'F_DISP32|',0
  _F_DISP64	       db 'F_DISP64|',0
  _F_IMM8	       db 'F_IMM8|',0
  _F_IMM16	       db 'F_IMM16|',0
  _F_IMM32	       db 'F_IMM32|',0
  _F_IMM64	       db 'F_IMM64|',0
  _F_RELATIVE	       db 'F_RELATIVE|',0
  _F_RIPDISP32	       db 'F_RIPDISP32|',0
  _F_GROUP	       db 'F_GROUP|',0
  _F_REX_IGNORED       db 'F_REX_IGNORED|',0
  _F_VEX_BAD_PREFIX    db 'F_VEX_BAD_PREFIX(!)|',0
  _F_ERROR_X86_64      db 'F_ERROR_X86_64(!)|',0
  _F_ERROR_LOCK        db 'F_ERROR_LOCK(!)|',0
  _F_ERROR_LENGTH      db 'F_ERROR_LENGTH(!)|',0
  _F_ERROR_OPCODE      db 'F_ERROR_OPCODE(!)|',0

  _PRE_NONE	       db 'PRE_NONE',0
  _PRE_LOCK	       db 'PRE_LOCK|',0
  _PRE_REP	       db 'PRE_REP|',0
  _PRE_SEG	       db 'PRE_SEG|',0
  _PRE_66	       db 'PRE_66|',0
  _PRE_67	       db 'PRE_67|',0
  _PRE_REX	       db 'PRE_REX|',0
  _PRE_VEX	       db 'PRE_VEX|',0

  _MOD_NODISP	       db 'MOD_NODISP',0
  _MOD_DISP8	       db 'MOD_DISP8',0
  _MOD_DISP32	       db 'MOD_DISP32',0
  _MOD_REG	       db 'MOD_REG',0

  _SCALE_1	       db 'SCALE_1',0
  _SCALE_2	       db 'SCALE_2',0
  _SCALE_4	       db 'SCALE_4',0
  _SCALE_8	       db 'SCALE_8',0

  _M_MMMM_0F	       db 'M_MMMM_0F',0
  _M_MMMM_0F_38        db 'M_MMMM_0F_38',0
  _M_MMMM_0F_3A        db 'M_MMMM_0F_3A',0

  _L_128_VECTOR        db 'L_128_VECTOR',0
  _L_256_VECTOR        db 'L_256_VECTOR',0

  _PP_NONE	       db 'PP_NONE',0
  _PP_66	       db 'PP_66',0
  _PP_F3	       db 'PP_F3',0
  _PP_F2	       db 'PP_F2',0

  _EMPTY	       db '00',0

  buf rb 400h
  flags rb 256
  prefixes rb 256
  cmd fde64s

section '.idata' import data readable

  library kernel32,'KERNEL32.DLL',\
	  user32,'USER32.DLL'

  include 'api\kernel32.inc'
  include 'api\user32.inc'
