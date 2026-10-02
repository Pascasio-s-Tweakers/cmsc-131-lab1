;
; checksum.asm - the one's complement internet checksum.
;
; This is your starting point. It assembles and links as-is, so the build
; works before you write any code. Right now it always returns 0, which
; makes every header decode as VALID. The decode path sums the header as it
; stands and tests for zero, so a routine that returns 0 says "valid" for
; everything. Your job is to replace that with the sum described below.
;
; The contract, from driver.c:
;
;       int len                   [ebp+12]
;       unsigned char *hdr        [ebp+8]
;
; Sum len bytes of hdr as len/2 16-bit big-endian words into a 32-bit
; accumulator. Fold the carries until the result fits in 16 bits. Return
; the one's complement of that in ax. The manual's worked example is the
; test. Zero the checksum field, sum the sample header, and you must get
; 0x9CBC.
;
; The decode path calls this over the header as it stands, checksum field
; included. A valid header returns 0 and an invalid one does not. The
; encode path calls it over a header whose checksum field you wrote as zero.
; One routine serves both uses. You don't need to know which one called
; you.
;
; Do not clobber ebx, esi, edi, or ebp. C assumes they survive your call.
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _ip_checksum ip_checksum
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .text
        global  _ip_checksum
_ip_checksum:
        enter   0,0
        push    ebx
        push    esi

        mov     esi, [ebp+8]    ; header_pointer
        mov     ecx, [ebp+12]   ; length         
        mov     eax, 0          ; eax will serve as total

loop_top:
        cmp     ecx, 0
        je      loop_end

        mov     ebx, [esi]
        and     ebx, 0xFF          ; load header_pointer and then mask so its just the first byte

        mov     edx, [esi]
        and     edx, 0xFF00       ; load header_pointer and then mask so its just the second byte, shift it 8 so its at the right bit adresses
        shr     edx, 8

        shl     ebx, 8
        or      ebx, edx        ; combine ebx and edx

        add      eax, ebx        ; add the ebx to total

        add     esi, 2
        sub     ecx, 2             

        jmp     loop_top
loop_end:       ; if length is 0, exit loop        

        ; fold carries

fold_loop_top:
        mov     edx, eax
        shr     edx, 16
        cmp     edx, 0
        jle     fold_loop_end
        and     eax, 0xFFFF
        add     eax, edx
        jmp     fold_loop_top 
fold_loop_end:

        not     eax              ; one's complement
        and     eax, 0xFFFF  
        
        pop     esi
        pop     ebx
        leave
        ret
