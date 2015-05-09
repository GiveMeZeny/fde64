use64

	include 'common.inc'

  ; decoding routine

decode:
    virtual at rdx
	.out	fde64s
    end virtual
	push	rbx rsi rdi

	; prepare stuff
	mov	rsi,rcx
	mov	r8,rcx

	; zero-out result
	xor	ecx,ecx
	xor	al,al
	mov	rdi,rdx
	mov	cl,sizeof.fde64s
	rep	stosb

	; process prefixes
    .prefix:
	lodsb
    .restart:
	mov	cl,al
	mov	ch,al
	and	cl,0FEh
	and	ch,0E7h
	cmp	al,PREFIX_LOCK
	je	.lock
	cmp	cl,PREFIX_REPNZ
	je	.rep
	cmp	al,PREFIX_OPERAND_SIZE
	je	.66
	cmp	al,PREFIX_ADDRESS_SIZE
	je	.67
	cmp	cl,PREFIX_SEGMENT_FS
	je	.seg
	cmp	ch,PREFIX_SEGMENT_CS
	jnz	.rex
      .seg:
	or	[.out.prefix],PRE_SEG
	mov	[.out.prefix.seg],al
	jmp	.prefix
      .lock:
	or	[.out.prefix],PRE_LOCK
	mov	[.out.prefix.lock],al
	jmp	.prefix
      .rep:
	or	[.out.prefix],PRE_REP
	mov	[.out.prefix.rep],al
	jmp	.prefix
      .66:
	or	[.out.prefix],PRE_66
	mov	[.out.prefix.66],al
	jmp	.prefix
      .67:
	or	[.out.prefix],PRE_67
	mov	[.out.prefix.67],al
	jmp	.prefix

	; process rex prefix
    .rex:
	mov	cl,al
	and	cl,0F0h
	cmp	cl,PREFIX_REX_START
	jnz	.vex
	or	[.out.prefix],PRE_REX
	mov	[.out.rex],al
	mov	ah,al
	mov	cl,al
	mov	ch,al
	shr	al,3
	shr	ah,2
	shr	cl,1
	and	al,1
	and	ah,1
	and	cl,1
	and	ch,1
	mov	word [.out.rex.w],ax
	mov	word [.out.rex.x],cx
	lodsb

	; process vex prefix
    .vex:
	mov	cl,al
	and	cl,0FEh
	cmp	cl,PREFIX_VEX_3_BYTE
	jnz	.opcode
	mov	[.out.opcode],0Fh
	or	[.out.prefix],PRE_VEX
	mov	[.out.vex],al
	mov	cl,al
	lodsb
	mov	[.out.vex2],al
	test	[.out.prefix],PRE_LOCK+PRE_REP+PRE_66+PRE_REX
	je	.vex_2_byte
	or	[.out.flags],F_VEX_BAD_PREFIX
      .vex_2_byte:
	cmp	cl,PREFIX_VEX_2_BYTE
	jnz	.vex_3_byte
	mov	ah,al
	mov	cl,al
	mov	ch,al
	shl	ah,1
	shl	cl,5
	shr	al,7
	shr	ah,4
	shr	cl,7
	and	ch,3
	or	al,0FEh
	or	ah,0F0h
	not	al
	not	ah
	mov	[.out.vex.r],al
	mov	[.out.vex.vvvv],ah
	mov	word [.out.vex.l],cx
	jmp	.vex_0F
      .vex_3_byte:
	mov	ah,al
	mov	cl,al
	mov	ch,al
	shl	ah,1
	shl	cl,2
	shr	al,7
	shr	ah,7
	shr	cl,7
	and	ch,01Fh
	or	al,0FEh
	or	ah,0FEh
	or	cl,0FEh
	not	al
	not	ah
	not	cl
	mov	word [.out.vex.r],ax
	mov	word [.out.vex.b],cx
	lodsb
	mov	[.out.vex3],al
	mov	ah,al
	mov	cl,al
	mov	bl,al
	shl	ah,1
	shl	cl,5
	shr	al,7
	shr	ah,4
	shr	cl,7
	and	bl,3
	or	ah,0F0h
	not	ah
	mov	word [.out.vex.w],ax
	mov	[.out.vex.l],cl
	mov	[.out.vex.pp],bl
	cmp	ch,M_MMMM_0F
	jnz	.vex_0F_38_3A
      .vex_0F:
	mov	bl,C_0F
	jmp	.2_byte
      .vex_0F_38_3A:
	mov	bl,C_3BYTE
	mov	bh,38h
	mov	[.out.opcode2],bh
	cmp	ch,M_MMMM_0F_38
	je	.3_byte
	mov	bh,3Ah
	mov	[.out.opcode2],bh
	jmp	.3_byte

	; process opcode
    .opcode:
	mov	[.out.opcode.len],1
	mov	[.out.opcode],al
	lea	rbx,[opcode_table]
      .next_opcode:
	mov	ah,al
	xlatb
	xchg	eax,ebx

	; unable to handle opcode
	cmp	bl,C_UNDEFINED
	jnz	.prefix_error
    .undefined:
	or	[.out.flags],F_ERROR_OPCODE
    .exit:
	xor	bl,bl
	jmp	.check_if_lock_is_valid

	; process prefix errors
    .prefix_error:
	cmp	bl,C_PREFIX
	jnz	.2_byte
	or	[.out.flags],F_REX_IGNORED
	and	[.out.prefix],not PRE_REX
	xor	eax,eax
	mov	dword [.out.rex],eax
	mov	[.out.rex.b],al
	mov	al,bh
	jmp	.restart

	; process 2-byte opcodes
    .2_byte:
	cmp	bl,C_0F
	jnz	.3_byte
	lodsb
	mov	[.out.opcode.len],2
	mov	[.out.opcode2],al
	lea	rbx,[opcode_table_0F]
	jmp	.next_opcode

	; process 3-byte opcodes
    .3_byte:
	cmp	bl,C_3BYTE
	jnz	.moffs
	lodsb
	mov	[.out.opcode.len],3
	mov	[.out.opcode3],al
	xor	ecx,ecx
	mov	ah,sizeof.opcode_table_0F_38_V
	mov	cl,sizeof.opcode_table_0F_38
	test	[.out.prefix],PRE_VEX
	je	.skip_0F_38_V
	mov	cl,ah
      .skip_0F_38_V:
	lea	rdi,[opcode_table_0F_38]
	mov	bl,C_MODRM
	cmp	bh,38h
	je	.lookup
	mov	ah,sizeof.opcode_table_0F_3A_V
	mov	cl,sizeof.opcode_table_0F_3A
	test	[.out.prefix],PRE_VEX
	je	.skip_0F_3A_V
	mov	cl,ah
      .skip_0F_3A_V:
	lea	rdi,[opcode_table_0F_3A]
	mov	bl,C_MODRM+C_IMM8
      .lookup:
	repnz	scasb
	jnz	.undefined
	mov	bh,al
	jmp	.modrm

	; process direct memory-offsets
    .moffs:
	cmp	bl,C_MOFFS
	jnz	.modrm
	lea	rdi,[.out.disp8]
	test	[.out.prefix],PRE_67
	je	.disp64
	or	[.out.flags],F_DISP32
	movsd
	jmp	.exit
      .disp64:
	or	[.out.flags],F_DISP64
	movsq
	jmp	.exit

	; process modr/m-byte
    .modrm:
	test	bl,C_MODRM
	je	.imm
	lodsb
	or	[.out.flags],F_MODRM
	mov	[.out.modrm],al
	mov	cl,al
	mov	ch,al
	shl	ch,2
	shr	cl,6
	shr	ch,5
	and	al,7
	mov	word [.out.modrm.mod],cx
	mov	[.out.modrm.rm],al

	; F6/F7 have immediate-bytes only if modrm.reg=0 (test)
	mov	ah,[.out.opcode]
	and	ah,0FEh
	cmp	ah,0F6h
	jnz	.no_F6_F7
	test	ch,ch
	je	.no_F6_F7
	and	bl,not (C_IMM8+C_IMM32)
      .no_F6_F7:

	; any displacement?
	cmp	cl,MOD_DISP32
	je	.modrm_disp32
	cmp	cl,MOD_DISP8
	je	.modrm_disp8
	test	cl,cl
	jnz	.sib
	cmp	al,RM_DISP32
	jnz	.sib
	or	[.out.flags],F_RELATIVE+F_RIPDISP32
      .modrm_disp32:
	or	[.out.flags],F_DISP32
	jmp	.sib
      .modrm_disp8:
	or	[.out.flags],F_DISP8

	; process sib-byte
    .sib:
	cmp	cl,MOD_REG
	je	.disp
	cmp	al,RM_SIB
	jnz	.disp
	lodsb
	or	[.out.flags],F_SIB
	mov	[.out.sib],al
	mov	ah,al
	mov	ch,al
	shl	ah,2
	shr	al,6
	shr	ah,5
	and	ch,7
	mov	word [.out.sib.scale],ax
	mov	[.out.sib.base],ch

	; any displacement?
	test	cl,cl
	jnz	.disp
	cmp	ch,REG_RBP
	jnz	.disp
	or	[.out.flags],F_DISP32	; scale with disp32 but w/o base if modrm.mod=0 and sib.base=5

	; process displacement
    .disp:
	lea	rdi,[.out.disp8]
	test	[.out.flags],F_DISP32
	je	.disp8
	movsd
    .disp8:
	test	[.out.flags],F_DISP8
	je	.imm
	movsb

	; process immediate-bytes
    .imm:
	lea	rdi,[.out.imm8]
	test	bl,C_IMM32
	je	.imm16

	; B8-BF have a 64bit immediate if rex.w=1
	mov	al,[.out.opcode]
	and	al,0F8h
	cmp	al,0B8h
	jnz	.no_B8_BF
	cmp	[.out.rex.w],1
	jnz	.no_B8_BF
	or	[.out.flags],F_IMM64
	movsq
	jmp	.exit
      .no_B8_BF:

	test	bl,C_REL		; ignore operand-override if rel32
	jnz	.imm32
	cmp	[.out.rex.w],1		; or if rex.w=1
	je	.imm32
	test	[.out.prefix],PRE_66
	je	.imm32
	or	[.out.flags],F_IMM16
	movsw
	jmp	.got_either_32_or_16
      .imm32:
	or	[.out.flags],F_IMM32
	movsd
      .got_either_32_or_16:
	lea	rdi,[.out.imm8_2]
    .imm16:
	test	bl,C_IMM16
	je	.imm8
	or	[.out.flags],F_IMM16
	movsw
	lea	rdi,[.out.imm8_2]
    .imm8:
	test	bl,C_IMM8
	je	.check_if_lock_is_valid
	or	[.out.flags],F_IMM8
	movsb

	; guess what
    .check_if_lock_is_valid:
	test	[.out.prefix],PRE_LOCK
	je	.check_if_erroneous
	test	bl,C_MODRM
	je	.lock_error
	cmp	cl,3
	je	.lock_error
	mov	ecx,sizeof.lock_table_0F
	lea	rdi,[lock_table_0F]
	cmp	[.out.opcode],0Fh
	je	.search_for_opcode
	and	bh,0FEh
	mov	ecx,sizeof.lock_table
	lea	rdi,[lock_table]
      .search_for_opcode:
	cmp	[rdi],bh
	lea	rdi,[rdi+2]
	loopnz	.search_for_opcode
	jnz	.lock_error
	mov	cl,[.out.modrm.reg]
	mov	al,[rdi-1]
	inc	cl
	shr	al,cl
	jnc	.check_if_erroneous
      .lock_error:
	or	[.out.flags],F_ERROR_LOCK

	; set F_ERROR_X86_64, F_RELATIVE and F_GROUP
    .check_if_erroneous:
	test	bl,C_ERROR
	je	.check_if_relative
	or	[.out.flags],F_ERROR_X86_64
    .check_if_relative:
	test	bl,C_REL
	je	.check_if_group
	or	[.out.flags],F_RELATIVE
    .check_if_group:
	test	bl,C_GROUP
	je	.fin
	or	[.out.flags],F_GROUP

	; finish stuff
    .fin:
	sub	rsi,r8
	mov	[.out.len],sil

	cmp	sil,15
	jb	.15
	or	[.out.flags],F_ERROR_LENGTH
      .15:

	xor	eax,eax
	test	[.out.flags],F_ERROR_OPCODE+F_ERROR_LENGTH+F_ERROR_X86_64+F_ERROR_LOCK+F_VEX_BAD_PREFIX
	sete	al			; return zero if any error-flag is set, otherwise nonzero

	pop	rdi rsi rbx
	retn

  ; opcode table flags

  C_NONE	      = 000h
  C_MODRM	      = 001h
  C_IMM8	      = 002h
  C_IMM16	      = 004h
  C_IMM32	      = 008h
  C_REL 	      = 010h
  C_GROUP	      = 020h
  C_ERROR	      = 040h
  ; special encodings
  C_MOFFS	      = 0FBh
  C_PREFIX	      = 0FCh
  C_0F		      = 0FDh
  C_3BYTE	      = 0FEh
  C_UNDEFINED	      = 0FFh

  ; opcode table obviously

opcode_table:

	db	C_MODRM 		; 00h - add r/m8, r8
	db	C_MODRM 		; 01h - add r/m32, r32
	db	C_MODRM 		; 02h - add r8, r/m8
	db	C_MODRM 		; 03h - add r32, r/m32
	db	C_IMM8			; 04h - add al, imm8
	db	C_IMM32 		; 05h - add eax, imm32
	db	C_ERROR+C_NONE		; 06h - push es
	db	C_ERROR+C_NONE		; 07h - pop es
	db	C_MODRM 		; 08h - or r/m8, r8
	db	C_MODRM 		; 09h - or r/m32, r32
	db	C_MODRM 		; 0Ah - or r8, r/m8
	db	C_MODRM 		; 0Bh - or r32, r/m32
	db	C_IMM8			; 0Ch - or al, imm8
	db	C_IMM32 		; 0Dh - or eax, imm32
	db	C_ERROR+C_NONE		; 0Eh - push cs
	db	C_0F			; 0Fh - escape opcode
	db	C_MODRM 		; 10h - adc r/m8, r8
	db	C_MODRM 		; 11h - adc r/m32, r32
	db	C_MODRM 		; 12h - adc r8, r/m8
	db	C_MODRM 		; 13h - adc r32, r/m32
	db	C_IMM8			; 14h - adc al, imm8
	db	C_IMM32 		; 15h - adc eax, imm32
	db	C_ERROR+C_NONE		; 16h - push ss
	db	C_ERROR+C_NONE		; 17h - pop ss
	db	C_MODRM 		; 18h - sbb r/m8, r8
	db	C_MODRM 		; 19h - sbb r/m32, r32
	db	C_MODRM 		; 1Ah - sbb r8, r/m8
	db	C_MODRM 		; 1Bh - sbb r32, r/m32
	db	C_IMM8			; 1Ch - sbb al, imm8
	db	C_IMM32 		; 1Dh - sbb eax, imm32
	db	C_ERROR+C_NONE		; 1Eh - push ds
	db	C_ERROR+C_NONE		; 1Fh - pop ds
	db	C_MODRM 		; 20h - and r/m8, r8
	db	C_MODRM 		; 21h - and r/m32, r32
	db	C_MODRM 		; 22h - and r8, r/m8
	db	C_MODRM 		; 23h - and r32, r/m32
	db	C_IMM8			; 24h - and al, imm8
	db	C_IMM32 		; 25h - and eax, imm32
	db	C_PREFIX		; 26h - es:
	db	C_ERROR+C_NONE		; 27h - daa
	db	C_MODRM 		; 28h - sub r/m8, r8
	db	C_MODRM 		; 29h - sub r/m32, r32
	db	C_MODRM 		; 2Ah - sub r8, r/m8
	db	C_MODRM 		; 2Bh - sub r32, r/m32
	db	C_IMM8			; 2Ch - sub al, imm8
	db	C_IMM32 		; 2Dh - sub eax, imm32
	db	C_PREFIX		; 2Eh - cs:
	db	C_ERROR+C_NONE		; 2Fh - das
	db	C_MODRM 		; 30h - xor r/m8, r8
	db	C_MODRM 		; 31h - xor r/m32, r32
	db	C_MODRM 		; 32h - xor r8, r/m8
	db	C_MODRM 		; 33h - xor r32, r/m32
	db	C_IMM8			; 34h - xor al, imm8
	db	C_IMM32 		; 35h - xor eax, imm32
	db	C_PREFIX		; 36h - ss:
	db	C_ERROR+C_NONE		; 37h - aaa
	db	C_MODRM 		; 38h - cmp r/m8, r8
	db	C_MODRM 		; 39h - cmp r/m32, r32
	db	C_MODRM 		; 3Ah - cmp r8, r/m8
	db	C_MODRM 		; 3Bh - cmp r32, r/m32
	db	C_IMM8			; 3Ch - cmp al, imm8
	db	C_IMM32 		; 3Dh - cmp eax, imm32
	db	C_PREFIX		; 3Eh - ds:
	db	C_ERROR+C_NONE		; 3Fh - aas
	db	C_PREFIX		; 40h - inc eax 	  (rex-prefix under x64)
	db	C_PREFIX		; 41h - inc ecx 	  (^)
	db	C_PREFIX		; 42h - inc edx 	  (^)
	db	C_PREFIX		; 43h - inc ebx 	  (^)
	db	C_PREFIX		; 44h - inc esp 	  (^)
	db	C_PREFIX		; 45h - inc ebp 	  (^)
	db	C_PREFIX		; 46h - inc esi 	  (^)
	db	C_PREFIX		; 47h - inc edi 	  (^)
	db	C_PREFIX		; 48h - dec eax 	  (^)
	db	C_PREFIX		; 49h - dec ecx 	  (^)
	db	C_PREFIX		; 4Ah - dec edx 	  (^)
	db	C_PREFIX		; 4Bh - dec ebx 	  (^)
	db	C_PREFIX		; 4Ch - dec esp 	  (^)
	db	C_PREFIX		; 4Dh - dec ebp 	  (^)
	db	C_PREFIX		; 4Eh - dec esi 	  (^)
	db	C_PREFIX		; 4Fh - dec edi 	  (^)
	db	C_NONE			; 50h - push rax
	db	C_NONE			; 51h - push rcx
	db	C_NONE			; 52h - push rdx
	db	C_NONE			; 53h - push rbx
	db	C_NONE			; 54h - push rsp
	db	C_NONE			; 55h - push rbp
	db	C_NONE			; 56h - push rsi
	db	C_NONE			; 57h - push rdi
	db	C_NONE			; 58h - pop rax
	db	C_NONE			; 59h - pop rcx
	db	C_NONE			; 5Ah - pop rdx
	db	C_NONE			; 5Bh - pop rbx
	db	C_NONE			; 5Ch - pop rsp
	db	C_NONE			; 5Dh - pop rbp
	db	C_NONE			; 5Eh - pop rsi
	db	C_NONE			; 5Fh - pop rdi
	db	C_ERROR+C_NONE		; 60h - pushad|pusha
	db	C_ERROR+C_NONE		; 61h - popad|popa
	db	C_ERROR+C_MODRM 	; 62h - bound r32, m32&32
	db	C_MODRM 		; 63h - movsxd r32, r/m32 (arpl r/m16, r16 under x86)
	db	C_PREFIX		; 64h - fs:
	db	C_PREFIX		; 65h - gs:
	db	C_PREFIX		; 66h - operand-size override
	db	C_PREFIX		; 67h - address-size override
	db	C_IMM32 		; 68h - push imm32
	db	C_MODRM+C_IMM32 	; 69h - imul r32, r/m32, imm32
	db	C_IMM8			; 6Ah - push imm8
	db	C_MODRM+C_IMM8		; 6Bh - imul r32, r/m32, imm8
	db	C_NONE			; 6Ch - insb
	db	C_NONE			; 6Dh - insd|insw
	db	C_NONE			; 6Eh - outsb
	db	C_NONE			; 6Fh - outsd|outsw
	db	C_REL+C_IMM8		; 70h - jo rel8
	db	C_REL+C_IMM8		; 71h - jno rel8
	db	C_REL+C_IMM8		; 72h - jb rel8
	db	C_REL+C_IMM8		; 73h - jnb rel8
	db	C_REL+C_IMM8		; 74h - je rel8
	db	C_REL+C_IMM8		; 75h - jnz rel8
	db	C_REL+C_IMM8		; 76h - jna rel8
	db	C_REL+C_IMM8		; 77h - ja rel8
	db	C_REL+C_IMM8		; 78h - js rel8
	db	C_REL+C_IMM8		; 79h - jns rel8
	db	C_REL+C_IMM8		; 7Ah - jp rel8
	db	C_REL+C_IMM8		; 7Bh - jnp rel8
	db	C_REL+C_IMM8		; 7Ch - jl rel8
	db	C_REL+C_IMM8		; 7Dh - jnl rel8
	db	C_REL+C_IMM8		; 7Eh - jng rel8
	db	C_REL+C_IMM8		; 7Fh - jg rel8
	db	C_GROUP+C_MODRM+C_IMM8	; 80h - add r/m8, imm8	  (also or, adc, sbb, and, sub, xor, cmp)
	db	C_GROUP+C_MODRM+C_IMM32 ; 81h - add r/m32, imm32  (also ^)
	db	C_GROUP+C_MODRM+C_IMM8	; 82h - same as 80h	  (also ^)
	db	C_GROUP+C_MODRM+C_IMM8	; 83h - add r/m32, imm8   (also ^)
	db	C_MODRM 		; 84h - test r/m8, r8
	db	C_MODRM 		; 85h - test r/m32, r32
	db	C_MODRM 		; 86h - xchg r/m8, r8
	db	C_MODRM 		; 87h - xchg r/m32, r32
	db	C_MODRM 		; 88h - mov r/m8, r8
	db	C_MODRM 		; 89h - mov r/m32, r32
	db	C_MODRM 		; 8Ah - mov r8, r/m8
	db	C_MODRM 		; 8Bh - mov r32, r/m32
	db	C_MODRM 		; 8Ch - mov r/m16, Sreg
	db	C_MODRM 		; 8Dh - lea r32, m
	db	C_MODRM 		; 8Eh - mov Sreg, r/m16
	db	C_MODRM 		; 8Fh - pop r/m64	  (if modrm.reg is not zero, xop coding scheme is used)
	db	C_NONE			; 90h - xchg eax, eax aka nop										    [F3] pause
	db	C_NONE			; 91h - xchg eax, ecx
	db	C_NONE			; 92h - xchg eax, edx
	db	C_NONE			; 93h - xchg eax, ebx
	db	C_NONE			; 94h - xchg eax, esp
	db	C_NONE			; 95h - xchg eax, ebp
	db	C_NONE			; 96h - xchg eax, esi
	db	C_NONE			; 97h - xchg eax, edi
	db	C_NONE			; 98h - cdqe|cwde|cbw
	db	C_NONE			; 99h - cqo|cdq|cwd
	db	C_ERROR+C_IMM32+C_IMM16 ; 9Ah - call ptr16:32
	db	C_NONE			; 9Bh - fwait		  (used as prefix for fstcw, fstenv, fsave, fstsw, flcex and finit)
	db	C_NONE			; 9Ch - pushfq|pushfd|pushf
	db	C_NONE			; 9Dh - popfq|popfd|popf
	db	C_NONE			; 9Eh - sahf		  (only valid if cpuid.80000001h:ecx.lahf-sahf[bit0]=1)
	db	C_NONE			; 9Fh - lahf		  (^)
	db	C_MOFFS 		; A0h - mov al, moffs8
	db	C_MOFFS 		; A1h - mov eax, moffs64
	db	C_MOFFS 		; A2h - mov moffs8, al
	db	C_MOFFS 		; A3h - mov moffs64, eax
	db	C_NONE			; A4h - movsb
	db	C_NONE			; A5h - movsq|movsd|movsw
	db	C_NONE			; A6h - cmpsb
	db	C_NONE			; A7h - cmpsq|cmpsd|cmpsw
	db	C_IMM8			; A8h - test al, imm8
	db	C_IMM32 		; A9h - test eax, imm32
	db	C_NONE			; AAh - stosb
	db	C_NONE			; ABh - stosq|stosd|stosw
	db	C_NONE			; ACh - lodsb
	db	C_NONE			; ADh - lodsq|lodsd|lodsw
	db	C_NONE			; AEh - scasb
	db	C_NONE			; AFh - scasq|scasd|scasw
	db	C_IMM8			; B0h - mov al, imm8
	db	C_IMM8			; B1h - mov cl, imm8
	db	C_IMM8			; B2h - mov dl, imm8
	db	C_IMM8			; B3h - mov bl, imm8
	db	C_IMM8			; B4h - mov ah, imm8
	db	C_IMM8			; B5h - mov ch, imm8
	db	C_IMM8			; B6h - mov dh, imm8
	db	C_IMM8			; B7h - mov bh, imm8
	db	C_IMM32 		; B8h - mov eax, imm32
	db	C_IMM32 		; B9h - mov ecx, imm32
	db	C_IMM32 		; BAh - mov edx, imm32
	db	C_IMM32 		; BBh - mov ebx, imm32
	db	C_IMM32 		; BCh - mov esp, imm32
	db	C_IMM32 		; BDh - mov ebp, imm32
	db	C_IMM32 		; BEh - mov esi, imm32
	db	C_IMM32 		; BFh - mov edi, imm32
	db	C_GROUP+C_MODRM+C_IMM8	; C0h - rol r/m8, imm8	  (also ror, rcl, rcr, shl, shr, <sal>, sar)
	db	C_GROUP+C_MODRM+C_IMM8	; C1h - rol r/m32, imm8   (also ^)
	db	C_IMM16 		; C2h - retn imm16
	db	C_NONE			; C3h - retn
	db	C_ERROR+C_MODRM 	; C4h - les r32, m16:32   (always vex-prefix under x64)
	db	C_ERROR+C_MODRM 	; C5h - lds r32, m16:32   (^)
	db	C_MODRM+C_IMM8		; C6h - mov r/m8, imm8	  (modrm.reg must be zero)
	db	C_MODRM+C_IMM32 	; C7h - mov r/m32, imm32  (^)
	db	C_IMM16+C_IMM8		; C8h - enter imm16, imm8
	db	C_NONE			; C9h - leave
	db	C_IMM16 		; CAh - retf imm16
	db	C_NONE			; CBh - retf
	db	C_NONE			; CCh - int3
	db	C_IMM8			; CDh - int imm8
	db	C_ERROR+C_NONE		; CEh - into
	db	C_NONE			; CFh - iretq|iretd|iret
	db	C_GROUP+C_MODRM 	; D0h - rol r/m8, 1	  (also ror, rcl, rcr, shl, shr, <sal>, sar)
	db	C_GROUP+C_MODRM 	; D1h - rol r/m32, 1	  (also ^)
	db	C_GROUP+C_MODRM 	; D2h - rol r/m8, cl	  (also ^)
	db	C_GROUP+C_MODRM 	; D3h - rol r/m32, cl	  (also ^)
	db	C_ERROR+C_IMM8		; D4h - aam		  (imm8=0Ah)
	db	C_ERROR+C_IMM8		; D5h - aad		  (^)
	db	C_NONE			; D6h - salc		  (set al=-1 if carry flag else al=0)							   ; || means "or X if modrm.mod=3"
	db	C_NONE			; D7h - xlatb
	db	C_GROUP+C_MODRM 	; D8h - fadd m32fp	  (also fmul, fcom, fcomp, fsub, fsubr, fdiv, fdivr)					     || fadd st0, st	  (also fmul, fcom, fcomp, fsub, fsubr, fdiv, fdivr)
	db	C_GROUP+C_MODRM 	; D9h - fld m32fp	  (also <>, fst, fstp, fldenv m14/28byte, fldcw m2byte, fnstenv m14/28byte, fnstcw m2byte)   || fld st		  (also fxch, {*})
	db	C_GROUP+C_MODRM 	; DAh - fiadd m32int	  (also fimul, ficom, ficomp, fisub, fisubr, fidiv, fidivr)				     || fcmovb st0, st	  (also fcmove, fcmovbe, fcmovu, <>, [modrm.rm=1] fucompp, <>, <>)
	db	C_GROUP+C_MODRM 	; DBh - fild m32int	  (also fisttp, fist, fistp, <>, fld m80fp, <>, fstp m80fp)				     || fcmovnb st0, st   (also fcmovne, fcmovnbe, fcmovnu, [modrm.rm=2|3] fnclex|fninit, fucomi, fcomi)
	db	C_GROUP+C_MODRM 	; DCh - fadd m64fp	  (also fmul, fcom, fcomp, fsub, fsubr, fdiv, fdivr)					     || fadd st, st0	  (also fmul, fcom, fcomp, fsubr, fsub, fdivr, fdiv)
	db	C_GROUP+C_MODRM 	; DDh - fld m64fp	  (also fisttp m64int, fst, fstp, frstor m94/108byte, <>, fnsave m94/108byte, fnstsw m2byte) || ffree st	  (also <>, fst, fstp, fucom, fucomp, <>, <>)
	db	C_GROUP+C_MODRM 	; DEh - fiadd m16int	  (also fimul, ficom, ficomp, fisub, fisubr, fidiv, fidivr)				     || faddp st, st0	  (also fmulp, <>, [modrm.rm=1] fcompp, fsubrp, fsubp, fdivrp, fdivp)
	db	C_GROUP+C_MODRM 	; DFh - fild m16int	  (also fisttp, fist, fistp, fbld m80bcd, fild m64int, fbstp m80bcd, fistp m64int)	     || ffreep st	  (also <>, <>, <>, [modrm.rm=0] fnstsw ax, fucomip, fcomip, <>)
	db	C_REL+C_IMM8		; E0h - loopnz rel8
	db	C_REL+C_IMM8		; E1h - loope rel8
	db	C_REL+C_IMM8		; E2h - loop rel8
	db	C_REL+C_IMM8		; E3h - jecxz rel8
	db	C_IMM8			; E4h - in al, imm8
	db	C_IMM8			; E5h - in eax, imm8
	db	C_IMM8			; E6h - out imm8, al
	db	C_IMM8			; E7h - out imm8, eax
	db	C_REL+C_IMM32		; E8h - call rel32
	db	C_REL+C_IMM32		; E9h - jmp rel32
	db	C_ERROR+C_IMM32+C_IMM16 ; EAh - jmp ptr16:32
	db	C_REL+C_IMM8		; EBh - jmp rel8
	db	C_NONE			; ECh - in al, dx
	db	C_NONE			; EDh - in eax, dx
	db	C_NONE			; EEh - out dx, al
	db	C_NONE			; EFh - out dx, eax
	db	C_PREFIX		; F0h - lock
	db	C_NONE			; F1h - int 1
	db	C_PREFIX		; F2h - repnz
	db	C_PREFIX		; F3h - rep
	db	C_NONE			; F4h - hlt
	db	C_NONE			; F5h - cmc
	db	C_GROUP+C_MODRM+C_IMM8	; F6h - test r/m8, imm8   (also <test>, {no immediate->} not, neg, mul, imul, div, idiv)
	db	C_GROUP+C_MODRM+C_IMM32 ; F7h - test r/m32, imm32 (also ^)
	db	C_NONE			; F8h - clc
	db	C_NONE			; F9h - stc
	db	C_NONE			; FAh - cli
	db	C_NONE			; FBh - sti
	db	C_NONE			; FCh - cld
	db	C_NONE			; FDh - std
	db	C_GROUP+C_MODRM 	; FEh - inc r/m8	  (also dec, <>, <>, <>, <>, <>, <>)
	db	C_GROUP+C_MODRM 	; FFh - inc r/m32	  (also dec, call, call m16:32, jmp, jmp m16:32, push, <>)
					;
					; * fnop	       11'010'000b D0
					;   fchs	       11'100'000b E0
					;   fabs	       11'100'001b E1
					;   ftst	       11'100'100b E4
					;   fxam	       11'100'101b E5
					;   fld1	       11'101'000b E8
					;   fldl2t	       11'101'001b E9
					;   fldl2e	       11'101'010b EA
					;   fldpi	       11'101'011b EB
					;   fldlg2	       11'101'100b EC
					;   fldln2	       11'101'101b ED
					;   fldz	       11'101'110b EE
					;   f2xm1	       11'110'000b F0
					;   fyl2x	       11'110'001b F1
					;   fptan	       11'110'010b F2
					;   fpatan	       11'110'011b F3
					;   fxtract	       11'110'100b F4
					;   fprem1	       11'110'101b F5
					;   fdecstp	       11'110'110b F6
					;   fincstp	       11'110'111b F7
					;   fprem	       11'111'000b F8
					;   fyl2xp1	       11'111'001b F9
					;   fsqrt	       11'111'010b FA
					;   fsincos	       11'111'011b FB
					;   frndint	       11'111'100b FC
					;   fscale	       11'111'101b FD
					;   fsin	       11'111'110b FE
					;   fcos	       11'111'111b FF

  ; escaped opcode table

opcode_table_0F:

	db	C_GROUP+C_MODRM 	; 00h - sldt r/m16	  (also str, lldt, ltr, verr, verw, <>, <>)
	db	C_GROUP+C_MODRM 	; 01h - sgdt m || vm*	  (also sidt || [modrm.rm=0|1|2|3] monitor|mwait|clac|stac, lgdt m16&64 || [modrm.rm=0|1|4|5|6] xgetbv|xsetbv|vmfunc|xend|xtest, lidt m16&64, smsw r32/m16, <>, lmsw r/m16, invlpg m || [modrm.rm=0|1] swapgs|rdtscp) *[modrm.rm=1|2|3|4] vmcall|vmlaunch|vmresume|vmxoff
	db	C_MODRM 		; 02h - lar r32, r32/m16
	db	C_MODRM 		; 03h - lsl r32, r32/m16
	db	C_UNDEFINED		; 04h
	db	C_NONE			; 05h - syscall
	db	C_NONE			; 06h - clts
	db	C_NONE			; 07h - sysretq|sysret
	db	C_NONE			; 08h - invd
	db	C_NONE			; 09h - wbinvd
	db	C_UNDEFINED		; 0Ah
	db	C_NONE			; 0Bh - ud2
	db	C_UNDEFINED		; 0Ch
	db	C_GROUP+C_MODRM 	; 0Dh - prefetch m8	  (also prefetchw, <>, <>, <>, <>, <>, <>)
	db	C_NONE			; 0Eh - femms
	db	C_MODRM+C_IMM8		; 0Fh - 3DNow!
	db	C_MODRM 		; 10h - movups xmm1, xmm2/m128	      [66] movupd xmm1, xmm2/m128	 [F2] movsd xmm1, xmm2/m64	    [F3] movss xmm1, xmm2/m32
	db	C_MODRM 		; 11h - movups xmm2/m128, xmm1	      [66] movupd xmm2/m128, xmm1	 [F2] movsd xmm2/m64, xmm1	    [F3] movss xmm2/m32, xmm1
	db	C_MODRM 		; 12h - movlps xmm, m64 	      [66] movlpd xmm, m64		 [F2] movddup xmm1, xmm2/m64	    [F3] movsldup xmm1, xmm2/m128      || movhlps xmm1, xmm2
	db	C_MODRM 		; 13h - movlps m64, xmm 	      [66] movlpd m64, xmm
	db	C_MODRM 		; 14h - unpcklps xmm1, xmm2/m128      [66] unpcklpd xmm1, xmm2/m128
	db	C_MODRM 		; 15h - unpckhps xmm1, xmm2/m128      [66] unpckhpd xmm1, xmm2/m128
	db	C_MODRM 		; 16h - movhps xmm, m64 	      [66] movhpd xmm, m64		 || movlhps xmm1, xmm2
	db	C_MODRM 		; 17h - movhps m64, xmm 	      [66] movhpd m64, xmm
	db	C_NONE			; 18h - prefetchnta m8	  (also prefetcht0, prefetcht1, prefetcht2, {->} hint_nop)
	db	C_MODRM 		; 19h - hint_nop
	db	C_MODRM 		; 1Ah - ^
	db	C_MODRM 		; 1Bh - ^
	db	C_MODRM 		; 1Ch - ^
	db	C_MODRM 		; 1Dh - ^
	db	C_MODRM 		; 1Eh - ^
	db	C_MODRM 		; 1Fh - nop r/m32
	db	C_MODRM 		; 20h - mov r64, cr0-cr7
	db	C_MODRM 		; 21h - mov r64, dr0-dr7
	db	C_MODRM 		; 22h - mov cr0-cr7, r64
	db	C_MODRM 		; 23h - mov dr0-dr7, r64
	db	C_UNDEFINED		; 24h
	db	C_UNDEFINED		; 25h
	db	C_UNDEFINED		; 26h
	db	C_UNDEFINED		; 27h
	db	C_MODRM 		; 28h - movaps xmm1, xmm2/m128	      [66] movapd xmm1, xmm2/m128
	db	C_MODRM 		; 29h - movaps xmm2/m128, xmm1	      [66] movapd xmm2/m128, xmm1
	db	C_MODRM 		; 2Ah - cvtpi2ps xmm, mm/m64	      [66] cvtpi2pd xmm, mm/m64 	 [F2] cvtsi2sd xmm, r/m32	    [F3] cvtsi2ss xmm, r/m32
	db	C_MODRM 		; 2Bh - movntps m128, xmm	      [66] movntpd m128, xmm
	db	C_MODRM 		; 2Ch - cvttps2pi mm, xmm/m64	      [66] cvttpd2pi mm, xmm/m128	 [F2] cvttsd2si r32, xmm/m64	    [F3] cvttss2si r32, xmm/m32
	db	C_MODRM 		; 2Dh - cvtps2pi mm, xmm/m64	      [66] cvtpd2pi mm, xmm/m128	 [F2] cvtsd2si r32, xmm/m64	    [F3] cvtss2si r32, xmm/m32
	db	C_MODRM 		; 2Eh - ucomiss xmm1, xmm2/m32	      [66] ucomisd xmm1, xmm2/m64
	db	C_MODRM 		; 2Fh - comiss xmm1, xmm2/m32	      [66] comisd xmm1, xmm2/m64
	db	C_NONE			; 30h - wrmsr
	db	C_NONE			; 31h - rdtsc
	db	C_NONE			; 32h - rdmsr
	db	C_NONE			; 33h - rdpmc
	db	C_NONE			; 34h - sysenter
	db	C_NONE			; 35h - sysexitq|sysexit
	db	C_UNDEFINED		; 36h
	db	C_NONE			; 37h - getsec		  ({eax=0-8->} capabilities, <>, enteraccs, exitac, senter, sexit, parameters, smctrl, wakeup)
	db	C_3BYTE 		; 38h - 3-byte opcode
	db	C_UNDEFINED		; 39h
	db	C_3BYTE 		; 3Ah - 3-byte opcode
	db	C_UNDEFINED		; 3Bh
	db	C_UNDEFINED		; 3Ch
	db	C_UNDEFINED		; 3Dh
	db	C_UNDEFINED		; 3Eh
	db	C_UNDEFINED		; 3Fh
	db	C_MODRM 		; 40h - cmovo r32, r/m32
	db	C_MODRM 		; 41h - cmovno r32, r/m32
	db	C_MODRM 		; 42h - cmovb r32, r/m32
	db	C_MODRM 		; 43h - cmovnb r32, r/m32
	db	C_MODRM 		; 44h - cmove r32, r/m32
	db	C_MODRM 		; 45h - cmovnz r32, r/m32
	db	C_MODRM 		; 46h - cmovna r32, r/m32
	db	C_MODRM 		; 47h - cmova r32, r/m32
	db	C_MODRM 		; 48h - cmovs r32, r/m32
	db	C_MODRM 		; 49h - cmovns r32, r/m32
	db	C_MODRM 		; 4Ah - cmovpe r32, r/m32
	db	C_MODRM 		; 4Bh - cmovpo r32, r/m32
	db	C_MODRM 		; 4Ch - cmovl r32, r/m32
	db	C_MODRM 		; 4Dh - cmovnl r32, r/m32
	db	C_MODRM 		; 4Eh - cmovng r32, r/m32
	db	C_MODRM 		; 4Fh - cmovg r32, r/m32
	db	C_MODRM 		; 50h - movmskps r32, xmm	      [66] movmskpd r32, xmm
	db	C_MODRM 		; 51h - sqrtps xmm1, xmm2/m128	      [66] sqrtpd xmm1, xmm2/m128	 [F2] sqrtsd xmm1, xmm2/m64	    [F3] sqrtss xmm1, xmm2/m32
	db	C_MODRM 		; 52h - rsqrtps xmm1, xmm2/m128 									    [F3] rsqrtss xmm1, xmm2/m32
	db	C_MODRM 		; 53h - rcpps xmm, xmm2/m128										    [F3] rcpss xmm1, xmm2/m32
	db	C_MODRM 		; 54h - andps xmm1, xmm2/m128	      [66] andpd xmm1, xmm2/m128
	db	C_MODRM 		; 55h - andnps xmm1, xmm2/m128	      [66] andnpd xmm1, xmm2/m128
	db	C_MODRM 		; 56h - orps xmm1, xmm2/m128	      [66] orpd xmm1, xmm2/m128
	db	C_MODRM 		; 57h - xorps xmm1, xmm2/m128	      [66] xorpd xmm1, xmm2/m128
	db	C_MODRM 		; 58h - addps xmm1, xmm2/m128	      [66] addpd xmm1, xmm2/m128	 [F2] addsd xmm1, xmm2/m64	    [F3] addss xmm1, xmm2/m32
	db	C_MODRM 		; 59h - mulps xmm1, xmm2/m128	      [66] mulpd xmm1, xmm2/m128	 [F2] mulsd xmm1, xmm2/m64	    [F3] mulss xmm1, xmm2/m32
	db	C_MODRM 		; 5Ah - cvtps2pd xmm1, xmm2/64	      [66] cvtpd2ps xmm1, xmm2/m128	 [F2] cvtsd2ss xmm1, xmm2/m64	    [F3] cvtss2sd xmm1, xmm2/m32
	db	C_MODRM 		; 5Bh - cvtdq2ps xmm1, xmm2/m128      [66] cvtps2dq xmm1, xmm2/m128
	db	C_MODRM 		; 5Ch - subps xmm1, xmm2/m128	      [66] subpd xmm1, xmm2/m128	 [F2] subsd xmm1, xmm2/m64	    [F3] subss xmm1, xmm2/m32
	db	C_MODRM 		; 5Dh - minps xmm1, xmm2/m128	      [66] minpd xmm1, xmm2/m128	 [F2] minsd xmm1, xmm2/m64	    [F3] minss xmm1, xmm2/m32
	db	C_MODRM 		; 5Eh - divps xmm1, xmm2/m128	      [66] divpd xmm1, xmm2/m128	 [F2] divsd xmm1, xmm2/m64	    [F3] divss xmm1, xmm2/m32
	db	C_MODRM 		; 5Fh - maxps xmm1, xmm2/m128	      [66] maxpd xmm1, xmm2/m128	 [F2] maxsd xmm1, xmm2/m64	    [F3] maxss xmm1, xmm2/m32
	db	C_MODRM 		; 60h - punpcklbw mm1, mm2/m32	      [66] punpcklbw xmm1, xmm2/m128
	db	C_MODRM 		; 61h - punpcklwd mm1, mm2/m32	      [66] punpcklwd xmm1, xmm2/m128
	db	C_MODRM 		; 62h - punpckldq mm1, mm2/m32	      [66] punpckldq xmm1, xmm2/m128
	db	C_MODRM 		; 63h - packsswb mm1, mm2/m64	      [66] packsswb xmm1, xmm2/m128
	db	C_MODRM 		; 64h - pcmpgtb mm1, mm2/m64	      [66] pcmpgtb xmm1, xmm2/m128
	db	C_MODRM 		; 65h - pcmpgtw mm1, mm2/m64	      [66] pcmpgtw xmm1, xmm2/m128
	db	C_MODRM 		; 66h - pcmpgtd mm1, mm2/m64	      [66] pcmpgtd xmm1, xmm2/m128
	db	C_MODRM 		; 67h - packuswb mm1, mm2/m64	      [66] packuswb xmm1, xmm2/m128
	db	C_MODRM 		; 68h - punpckhbw mm1, mm2/m64	      [66] punpckhbw xmm1, xmm2/m128
	db	C_MODRM 		; 69h - punpckhwd mm1, mm2/m64	      [66] punpckhwd xmm1, xmm2/m128
	db	C_MODRM 		; 6Ah - punpckhdq mm1, mm2/m64	      [66] punpckhdq xmm1, xmm2/m128
	db	C_MODRM 		; 6Bh - packssdw mm1, mm2/m64	      [66] packssdw xmm1, xmm2/m128
	db	C_MODRM 		; 6Ch ->			      [66] punpcklqdq xmm1, xmm2/m128
	db	C_MODRM 		; 6Dh ->			      [66] punpckhqdq xmm1, xmm2/m128
	db	C_MODRM 		; 6Eh - movq|movd mm, r/m32	      [66] movq|movd xmm, r/m32
	db	C_MODRM 		; 6Fh - movq mm1, mm2/m64	      [66] movdqa xmm1, xmm2/m128					    [F3] movdqu xmm1, xmm2/m128
	db	C_MODRM+C_IMM8		; 70h - pshufw mm1, mm2/m64, imm8     [66] pshufd xmm1, xmm2/m128, imm8  [F2] pshuflw xmm1, xmm2/m128, imm8 [F3] pshufhw xmm1, xmm2/m128, imm8
	db	C_GROUP+C_MODRM+C_IMM8	; 71h - <> mm, imm8		      [66] <> xmm, imm8      (also <>, psrlw, <>, psraw, <>, psllw, <>)
	db	C_GROUP+C_MODRM+C_IMM8	; 72h - <> mm, imm8		      [66] <> xmm, imm8      (also <>, psrld, <>, psrad, <>, pslld, <>)
	db	C_GROUP+C_MODRM+C_IMM8	; 73h - <> mm, imm8		      [66] <> xmm, imm8      (also <>, psrlq, psrldq*, psraq, <>, psllq, pslldq*) *[66]-only
	db	C_MODRM 		; 74h - pcmpeqb mm1, mm2/m64	      [66] pcmpeqb mm1, mm2/m128
	db	C_MODRM 		; 75h - pcmpeqw mm1, mm2/m64	      [66] pcmpeqw mm1, mm2/m128
	db	C_MODRM 		; 76h - pcmpeqd mm1, mm2/m64	      [66] pcmpeqd mm1, mm2/m128
	db	C_NONE			; 77h - emms		  ([vex.l=128|256] vzeroupper|vzeroall)
	db	C_MODRM 		; 78h - vmread r/m64, r64
	db	C_MODRM 		; 79h - vmwrite r64, r/m64
	db	C_UNDEFINED		; 7Ah
	db	C_UNDEFINED		; 7Bh
	db	C_MODRM 		; 7Ch ->			      [66] haddpd xmm1, xmm2/m128	 [F2] haddps  xmm1, xmm2/m128
	db	C_MODRM 		; 7Dh ->			      [66] hsubpd xmm1, xmm2/m128	 [F2] hsubps  xmm1, xmm2/m128
	db	C_MODRM 		; 7Eh - movq|movd r/m32, mm	      [66] movq|movd r/m32, xmm 					    [F3] movq xmm1, xmm2/m64
	db	C_MODRM 		; 7Fh - movq mm2/m64, mm1	      [66] movdqa xmm2/m128, xmm1					    [F3] movdqu xmm2/m128, xmm1
	db	C_REL+C_IMM32		; 80h - jo rel32
	db	C_REL+C_IMM32		; 81h - jno rel32
	db	C_REL+C_IMM32		; 82h - jb rel32
	db	C_REL+C_IMM32		; 83h - jnb rel32
	db	C_REL+C_IMM32		; 84h - je rel32
	db	C_REL+C_IMM32		; 85h - jnz rel32
	db	C_REL+C_IMM32		; 86h - jna rel32
	db	C_REL+C_IMM32		; 87h - ja rel32
	db	C_REL+C_IMM32		; 88h - js rel32
	db	C_REL+C_IMM32		; 89h - jns rel32
	db	C_REL+C_IMM32		; 8Ah - jpe rel32
	db	C_REL+C_IMM32		; 8Bh - jpo rel32
	db	C_REL+C_IMM32		; 8Ch - jl rel32
	db	C_REL+C_IMM32		; 8Dh - jnl rel32
	db	C_REL+C_IMM32		; 8Eh - jng rel32
	db	C_REL+C_IMM32		; 8Fh - jg rel32
	db	C_MODRM 		; 90h - seto r/m8
	db	C_MODRM 		; 91h - setno r/m8
	db	C_MODRM 		; 92h - setb r/m8
	db	C_MODRM 		; 93h - setnb r/m8
	db	C_MODRM 		; 94h - sete r/m8
	db	C_MODRM 		; 95h - setnz r/m8
	db	C_MODRM 		; 96h - setna r/m8
	db	C_MODRM 		; 97h - seta r/m8
	db	C_MODRM 		; 98h - sets r/m8
	db	C_MODRM 		; 99h - setns r/m8
	db	C_MODRM 		; 9Ah - setpe r/m8
	db	C_MODRM 		; 9Bh - setpo r/m8
	db	C_MODRM 		; 9Ch - setl r/m8
	db	C_MODRM 		; 9Dh - setnl r/m8
	db	C_MODRM 		; 9Eh - setng r/m8
	db	C_MODRM 		; 9Fh - setg r/m8
	db	C_NONE			; A0h - push fs
	db	C_NONE			; A1h - pop fs
	db	C_NONE			; A2h - cpuid
	db	C_MODRM 		; A3h - bt r/m32, r32
	db	C_MODRM+C_IMM8		; A4h - shld r/m32, r32, imm8
	db	C_MODRM 		; A5h - shld r/m32, r32, cl
	db	C_UNDEFINED		; A6h
	db	C_UNDEFINED		; A7h
	db	C_NONE			; A8h - push gs
	db	C_NONE			; A9h - pop gs
	db	C_ERROR+C_NONE		; AAh - rsm
	db	C_MODRM 		; ABh - bts r/m32, r32
	db	C_MODRM+C_IMM8		; ACh - shrd r/m32, r32, imm8
	db	C_MODRM 		; ADh - shrd r/m32, r32, cl
	db	C_GROUP+C_MODRM 	; AEh - fxsave64|fxsave m512byte (also fxrstor64|fxrstor, ldmxcsr m32, stmxcsr m32, xsave64|xsave, xrstor64|xrstor, xsaveopt64|xsaveopt, clflush m8) || [F3] rdfsbase (also rdgsbase, wrfsbase, wrgsbase, <>, {no prefix->} lfence, mfence, sfence)
	db	C_MODRM 		; AFh - imul r32, r/m32
	db	C_MODRM 		; B0h - cmpxchg r/m8, r8
	db	C_MODRM 		; B1h - cmpxchg r/m32, r32
	db	C_MODRM 		; B2h - lss r32, m16:32
	db	C_MODRM 		; B3h - btr r/m32, r32
	db	C_MODRM 		; B4h - lfs r32, m16:32
	db	C_MODRM 		; B5h - lgs r32, m16:32
	db	C_MODRM 		; B6h - movzx r32, r/m8
	db	C_MODRM 		; B7h - movzx r32, r/m16
	db	C_MODRM 		; B8h ->												    [F3] popcnt r32, r/m32 (only valid if cpuid.01h:ecx.popcnt[bit23]=1)
	db	C_MODRM 		; B9h - ud1
	db	C_GROUP+C_MODRM+C_IMM8	; BAh - <> r/m32, imm8	  (also <>, <>, <>, bt, bts, btr, btc)
	db	C_MODRM 		; BBh - btc r/m32, r32
	db	C_MODRM 		; BCh - bsf r32, r/m32											    [F3] tzcnt r32, r/m32
	db	C_MODRM 		; BDh - bsr r32, r/m32											    [F3] lzcnt r32, r/m32
	db	C_MODRM 		; BEh - movsx r32, r/m8
	db	C_MODRM 		; BFh - movsx r32, r/m16
	db	C_MODRM 		; C0h - xadd r/m8, r8
	db	C_MODRM 		; C1h - xadd r/m32, r32
	db	C_MODRM+C_IMM8		; C2h - cmpps xmm1, xmm2/m128, imm8   [66] cmppd xmm1, xmm2/m128, imm8	 [F2] cmpsd xmm1, xmm2/m64, imm8    [F3] cmpss xmm1, xmm2/m32, imm8
	db	C_MODRM 		; C3h - movnti m32, r32
	db	C_MODRM+C_IMM8		; C4h - pinsrw mm, r32/m16, imm8      [66] pinsrw xmm, r32/m16, imm8
	db	C_MODRM+C_IMM8		; C5h - pextrw r32, mm, imm8	      [66] pextrw r32, xmm, imm8
	db	C_MODRM+C_IMM8		; C6h - shufps xmm1, xmm2/m128, imm8  [66] shufpd xmm1, xmm2/m128, imm8
	db	C_GROUP+C_MODRM 	; C7h - <>		  (also cmpxchg16b m128|cmpxchg8b m64, <>, <>, <>, <>, vmptrld m64|[66] vmclear m64|[F3] vmxon m64 || rdrand r32, vmptrst m64|[F3] vmptrst m64 || rdseed r32)
	db	C_NONE			; C8h - bswap eax
	db	C_NONE			; C9h - bswap ecx
	db	C_NONE			; CAh - bswap edx
	db	C_NONE			; CBh - bswap ebx
	db	C_NONE			; CCh - bswap esp
	db	C_NONE			; CDh - bswap ebp
	db	C_NONE			; CEh - bswap esi
	db	C_NONE			; CFh - bswap edi
	db	C_MODRM 		; D0h ->			      [66] addsubpd xmm1, xmm2/m128	 [F2] addsubps xmm1, xmm2/m128
	db	C_MODRM 		; D1h - psrlw mm1, mm2/m64	      [66] psrlw xmm1, xmm2/m128
	db	C_MODRM 		; D2h - psrld mm1, mm2/m64	      [66] psrld xmm1, xmm2/m128
	db	C_MODRM 		; D3h - psrlq mm1, mm2/m64	      [66] psrlq xmm1, xmm2/m128
	db	C_MODRM 		; D4h - paddq mm1, mm2/m64	      [66] paddq xmm1, xmm2/m128
	db	C_MODRM 		; D5h - pmullw mm1, mm2/m64	      [66] pmullw xmm1, xmm2/m128
	db	C_MODRM 		; D6h ->			      [66] movq xmm2/m64, xmm1		 [F2] movdq2q mm, xmm		    [F3] movq2dq xmm, mm
	db	C_MODRM 		; D7h - pmovmskb r32, mm	      [66] pmovmskb r32, xmm
	db	C_MODRM 		; D8h - psubusb mm1, mm2/m64	      [66] psubusb xmm1, xmm2/m128
	db	C_MODRM 		; D9h - psubusw mm1, mm2/m64	      [66] psubusw xmm1, xmm2/m128
	db	C_MODRM 		; DAh - pminub mm1, mm2/m64	      [66] pminub xmm1, xmm2/m128
	db	C_MODRM 		; DBh - pand mm1, mm2/m64	      [66] pand xmm1, xmm2/m128
	db	C_MODRM 		; DCh - paddusb mm1, mm2/m64	      [66] paddusb xmm1, xmm2/m128
	db	C_MODRM 		; DDh - paddusw mm1, mm2/m64	      [66] paddusw xmm1, xmm2/m128
	db	C_MODRM 		; DEh - pmaxub mm1, mm2/m64	      [66] pmaxub xmm1, xmm2/m128
	db	C_MODRM 		; DFh - pandn mm1, mm2/m64	      [66] pandn xmm1, xmm2/m128
	db	C_MODRM 		; E0h - pavgb mm1, mm2/m64	      [66] pavgb xmm1, xmm2/m128
	db	C_MODRM 		; E1h - psraw mm1, mm2/m64	      [66] psraw xmm1, xmm2/m128
	db	C_MODRM 		; E2h - psrad mm1, mm2/m64	      [66] psrad xmm1, xmm2/m128
	db	C_MODRM 		; E3h - pavgw mm1, mm2/m64	      [66] pavgw xmm1, xmm2/m128
	db	C_MODRM 		; E4h - pmulhuw mm1, mm2/m64	      [66] pmulhuw xmm1, xmm2/m128
	db	C_MODRM 		; E5h - pmulhw mm1, mm2/m64	      [66] pmulhw xmm1, xmm2/m128
	db	C_MODRM 		; E6h ->			      [66] cvttpd2dq xmm1, xmm2/m128	 [F2] cvtpd2dq xmm1, xmm2/m128	    [F3] cvtdq2pd xmm1, xmm2/m64
	db	C_MODRM 		; E7h - movntq m64, mm		      [66] movntdq m128, xmm
	db	C_MODRM 		; E8h - psubsb mm1, mm2/m64	      [66] psubsb xmm1, xmm2/m128
	db	C_MODRM 		; E9h - psubsw mm1, mm2/m64	      [66] psubsw xmm1, xmm2/m128
	db	C_MODRM 		; EAh - pminsw mm1, mm2/m64	      [66] pminsw xmm1, xmm2/m128
	db	C_MODRM 		; EBh - por mm1, mm2/m64	      [66] por xmm1, xmm2/m128
	db	C_MODRM 		; ECh - paddsb mm1, mm2/m64	      [66] paddsb xmm1, xmm2/m128
	db	C_MODRM 		; EDh - paddsw mm1, mm1/m64	      [66] paddsw xmm1, xmm2/m128
	db	C_MODRM 		; EEh - pmaxsw mm1, mm2/m64	      [66] pmaxsw xmm1, xmm2/m128
	db	C_MODRM 		; EFh - pxor mm1, mm2/m64	      [66] pxor xmm1, xmm2/m128
	db	C_MODRM 		; F0h ->								 [F2] lddqu xmm1, m128
	db	C_MODRM 		; F1h - psllw mm1, mm2/m64	      [66] psllw xmm1, xmm2/m128
	db	C_MODRM 		; F2h - pslld mm1, mm2/m64	      [66] pslld xmm1, xmm2/m128
	db	C_MODRM 		; F3h - psllq mm1, mm2/m64	      [66] psllq xmm1, xmm2/m128
	db	C_MODRM 		; F4h - pmuludq mm1, mm2/m64	      [66] pmuludq xmm1, xmm2/m128
	db	C_MODRM 		; F5h - pmaddwd mm1, mm2/m64	      [66] pmaddwd xmm1, xmm2/m128
	db	C_MODRM 		; F6h - psadbw mm1, mm2/m64	      [66] psadbw xmm1, xmm2/m128
	db	C_MODRM 		; F7h - maskmovq mm1, mm2	      [66] maskmovdqu xmm1, xmm2
	db	C_MODRM 		; F8h - psubb mm1, mm2/m64	      [66] psubb xmm1, xmm2/m128
	db	C_MODRM 		; F9h - psubw mm1, mm2/m64	      [66] psubw xmm1, xmm2/m128
	db	C_MODRM 		; FAh - psubd mm1, mm2/m64	      [66] psubd xmm1, xmm2/m128
	db	C_MODRM 		; FBh - psubq mm1, mm2/m64	      [66] psubq xmm1, xmm2/m128
	db	C_MODRM 		; FCh - paddb mm1, mm2/m64	      [66] paddb xmm1, xmm2/m128
	db	C_MODRM 		; FDh - paddw mm1, mm2/m64	      [66] paddw xmm1, xmm2/m128
	db	C_MODRM 		; FEh - paddd mm1, mm2/m64	      [66] paddd xmm1, xmm2/m128
	db	C_NONE			; FFh - ud

  ; 3-byte opcode table for 0F 38

opcode_table_0F_38:			; C_MODRM

	db	000h			; 00h - pshufb mm1, mm2/m64	      [66] pshufb xmm1, xmm2/m128
	db	001h			; 01h - phaddw mm1, mm2/m64	      [66] phaddw xmm1, xmm2/m128
	db	002h			; 02h - phaddd mm1, mm2/m64	      [66] phaddd xmm1, xmm2/m128
	db	003h			; 03h - phaddsw mm1, mm2/m64	      [66] phaddsw xmm1, xmm2/m128
	db	004h			; 04h - pmaddubsw mm1, mm2/m64	      [66] pmaddubsw xmm1, xmm2/m128
	db	005h			; 05h - phsubw mm1, mm2/m64	      [66] phsubw xmm1, xmm2/m128
	db	006h			; 06h - phsubd mm1, mm2/m64	      [66] phsubd xmm1, xmm2/m128
	db	007h			; 07h - phsubsw mm1, mm2/m64	      [66] phsubsw xmm1, xmm2/m128
	db	008h			; 08h - psignb mm1, mm2/m64	      [66] psignb xmm1, xmm2/m128
	db	009h			; 09h - psignw mm1, mm2/m64	      [66] psignw xmm1, xmm2/m128
	db	00Ah			; 0Ah - psignd mm1, mm2/m64	      [66] psignd xmm1, xmm2/m128
	db	00Bh			; 0Bh - pmulhrsw mm1, mm2/m64	      [66] pmulhrsw xmm1, xmm2/m128
	db	010h			; 10h ->			      [66] pblendvb xmm1, xmm2/m128, <xmm0>
	db	014h			; 14h ->			      [66] blendvps xmm1, xmm2/m128, <xmm0>
	db	015h			; 15h ->			      [66] blendvpd xmm1, xmm2/m128, <xmm0>
	db	017h			; 17h ->			      [66] ptest xmm1, xmm2/m128
	db	01Ch			; 1Ch - pabsb mm1, mm2/m64	      [66] pabsb xmm1, xmm2/m128
	db	01Dh			; 1Dh - pabsw mm1, mm2/m64	      [66] pabsw xmm1, xmm2/m128
	db	01Eh			; 1Eh - pabsd mm1, mm2/m64	      [66] pabsd xmm1, xmm2/m128
	db	020h			; 20h ->			      [66] pmovsxbw xmm1, xmm2/m64
	db	021h			; 21h ->			      [66] pmovsxbd xmm1, xmm2/m32
	db	022h			; 22h ->			      [66] pmovsxbq xmm1, xmm2/m16
	db	023h			; 23h ->			      [66] pmovsxwd xmm1, xmm2/m64
	db	024h			; 24h ->			      [66] pmovsxwq xmm1, xmm2/m32
	db	025h			; 25h ->			      [66] pmovsxdq xmm1, xmm2/m64
	db	028h			; 28h ->			      [66] pmuldq xmm1, xmm2/m128
	db	029h			; 29h ->			      [66] pcmpeqq xmm1, xmm2/m128
	db	02Ah			; 2Ah ->			      [66] movntdqa xmm1, m128
	db	02Bh			; 2Bh ->			      [66] packusdw xmm1, xmm2/m128
	db	030h			; 30h ->			      [66] pmovzxbw xmm1, xmm2/m64
	db	031h			; 31h ->			      [66] pmovzxbd xmm1, xmm2/m32
	db	032h			; 32h ->			      [66] pmovzxbq xmm1, xmm2/m16
	db	033h			; 33h ->			      [66] pmovzxwd xmm1, xmm2/m64
	db	034h			; 34h ->			      [66] pmovzxwq xmm1, xmm2/m32
	db	035h			; 35h ->			      [66] pmovzxdq xmm1, xmm2/m64
	db	037h			; 37h ->			      [66] pcmpgtq xmm1, xmm2/m128
	db	038h			; 38h ->			      [66] pminsb xmm1, xmm2/m128
	db	039h			; 39h ->			      [66] pminsd xmm1, xmm2/m128
	db	03Ah			; 3Ah ->			      [66] pminuw xmm1, xmm2/m128
	db	03Bh			; 3Bh ->			      [66] pminud xmm1, xmm2/m128
	db	03Ch			; 3Ch ->			      [66] pmaxsb xmm1, xmm2/m128
	db	03Dh			; 3Dh ->			      [66] pmaxsd xmm1, xmm2/m128
	db	03Eh			; 3Eh ->			      [66] pmaxuw xmm1, xmm2/m128
	db	03Fh			; 3Fh ->			      [66] pmaxud xmm1, xmm2/m128
	db	040h			; 40h ->			      [66] pmulld xmm1, xmm2/m128
	db	041h			; 41h ->			      [66] phminposuw xmm1, xmm2/m128
	db	080h			; 80h ->			      [66] invept r64, m128
	db	081h			; 81h ->			      [66] invvpid r64, m128
	db	082h			; 82h ->			      [66] invpcid r64, m128
	db	0DBh			; DBh ->			      [66] aesimc xmm1, xmm2/m128
	db	0DCh			; DCh ->			      [66] aesenc xmm1, xmm2/m128
	db	0DDh			; DDh ->			      [66] aesenclast xmm1, xmm2/m128
	db	0DEh			; DEh ->			      [66] aesdec xmm1, xmm2/m128
	db	0DFh			; DFh ->			      [66] aesdeclast xmm1, xmm2/m128
	db	0F0h			; F0h - movbe r32, m32							 [F2] crc32 r32, r/m8
	db	0F1h			; F1h - movbe m32, r32							 [F2] crc32 r32, r/m32

sizeof.opcode_table_0F_38 = $-opcode_table_0F_38

	db	00Ch			; 0Ch ->			      [66] vpermilps xmm1, xmm2, xmm3/m128
	db	00Dh			; 0Dh ->			      [66] vpermilpd xmm1, xmm2, xmm3/m128
	db	00Eh			; 0Eh ->			      [66] vtestps xmm1, xmm2/m128
	db	00Fh			; 0Fh ->			      [66] vtestpd xmm1, xmm2/m128
	db	018h			; 18h ->			      [66] vbroadcastss xmm1, m32
	db	019h			; 19h ->			      [66] vbroadcastsd xmm1, m64
	db	01Ah			; 1Ah ->			      [66] vbroadcastf128 ymm1, m128
	db	02Ch			; 2Ch ->			      [66] vmaskmovps xmm1, xmm2, m128
	db	02Dh			; 2Dh ->			      [66] vmaskmovpd xmm1, xmm2, m128
	db	02Eh			; 2Eh ->			      [66] vmaskmovps m128, xmm1, xmm2
	db	02Fh			; 2Fh ->			      [66] vmaskmovpd m128, xmm1, xmm2

sizeof.opcode_table_0F_38_V = $-opcode_table_0F_38

  ; 3-byte opcode table for 0F 3A

opcode_table_0F_3A:			; C_MODRM+C_IMM8

	db	008h			; 08h ->			      [66] roundps xmm1, xmm2/m128, imm8
	db	009h			; 09h ->			      [66] roundpd xmm1, xmm2/m128, imm8
	db	00Ah			; 0Ah ->			      [66] roundss xmm1, xmm2/m128, imm8
	db	00Bh			; 0Bh ->			      [66] roundsd xmm1, xmm2/m128, imm8
	db	00Ch			; 0Ch ->			      [66] blendps xmm1, xmm2/m128, imm8
	db	00Dh			; 0Dh ->			      [66] blendpd xmm1, xmm2/m128, imm8
	db	00Eh			; 0Eh ->			      [66] pblendw xmm1, xmm2/m128, imm8
	db	00Fh			; 0Fh - palignr mm1, mm2/m64, imm8    [66] palignr xmm1, xmm2/m128, imm8
	db	014h			; 14h ->			      [66] pextrb r32/m8, xmm2, imm8
	db	015h			; 15h ->			      [66] pextrw r32/m16, xmm2, imm8
	db	016h			; 16h ->			      [66] pextrd r32/m32, xmm2, imm8
	db	017h			; 17h ->			      [66] extractps r32/m32, xmm2, imm8
	db	020h			; 20h ->			      [66] pinsrb xmm1, r32/m8, imm8
	db	021h			; 21h ->			      [66] insertps xmm1, xmm2/m32, imm8
	db	022h			; 22h ->			      [66] pinsrd xmm1, r/m32, imm8
	db	040h			; 40h ->			      [66] dpps xmm1, xmm2/m128, imm8
	db	041h			; 41h ->			      [66] dppd xmm1, xmm2/m128, imm8
	db	042h			; 42h ->			      [66] mpsadbw xmm1, xmm2/m128, imm8
	db	044h			; 44h ->			      [66] pclmulqdq xmm1, xmm2/m128, imm8
	db	060h			; 60h ->			      [66] pcmpestrm xmm1, xmm2/m128, imm8
	db	061h			; 61h ->			      [66] pcmpestri xmm1, xmm2/m128, imm8
	db	062h			; 62h ->			      [66] pcmpistrm xmm1, xmm2/m128, imm8
	db	063h			; 63h ->			      [66] pcmpistri xmm1, xmm2/m128, imm8
	db	0DFh			; DFh ->			      [66] aeskeygenassist xmm1, xmm2/m128, imm8

sizeof.opcode_table_0F_3A = $-opcode_table_0F_3A

	db	004h			; 04h ->			      [66] vpermilps xmm1, xmm2/m128, imm8
	db	005h			; 05h ->			      [66] vpermilpd xmm1, xmm2/m128, imm8
	db	006h			; 06h ->			      [66] vperm2f128 ymm1, ymm2, ymm3/m256, imm8
	db	018h			; 18h ->			      [66] vinsertf128 ymm1, ymm2, xmm3/m128, imm8
	db	019h			; 19h ->			      [66] vextractf128 xmm1/m128, ymm2, imm8
	db	04Ah			; 4Ah ->			      [66] vblendvps xmm1, xmm2, xmm3/m128, xmm4
	db	04Bh			; 4Bh ->			      [66] vblendvpd xmm1, xmm2, xmm3/m128, xmm4
	db	04Ch			; 4Ch ->			      [66] vpblendvb xmm1, xmm2, xmm3/m128, xmm4

sizeof.opcode_table_0F_3A_V = $-opcode_table_0F_3A

  ; opcodes with possible LOCK-prefix

lock_table:

	db	000h, 0 		; add
	db	008h, 0 		; or
	db	010h, 0 		; adc
	db	018h, 0 		; sbb
	db	020h, 0 		; and
	db	028h, 0 		; sub
	db	030h, 0 		; xor
	db	080h, 10000000b 	; add|or|adc|sbb|and|sub|xor reg=0-6
	db	082h, 10000000b 	; ^
	db	086h, 0 		; xchg
	db	0F6h, 11110011b 	; not|neg reg=2|3
	db	0FEh, 11111100b 	; inc|dec reg=0|1

sizeof.lock_table = $-lock_table

  ; escaped opcodes with possible LOCK-prefix

lock_table_0F:

	db	0ABh, 0 		; bts
	db	0B0h, 0 		; cmpxchg
	db	0B1h, 0 		; ^
	db	0B3h, 0 		; btr
	db	0BAh, 00011111b 	; bts|btr|btc reg=5-7
	db	0BBh, 0 		; btc
	db	0C0h, 0 		; xadd
	db	0C1h, 0 		; ^
	db	0C7h, 11111101b 	; cmpxchg16b|cmpxchg8b reg=1

sizeof.lock_table_0F = $-lock_table_0F
