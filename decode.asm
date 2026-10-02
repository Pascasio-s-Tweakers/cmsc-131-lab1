;
; decode.asm - extract every field from a 20-byte IPv4 header.
;
; This is your starting point. It assembles and links as-is, so the build
; works before you write any code. Right now it stores nothing, so renpkt
; prints the zeros driver.c put in the struct. Your job is to replace that
; with the extraction described below.
;
; The contract, from driver.c:
;
;       struct ipv4_fields *out   [ebp+12]
;       unsigned char *hdr        [ebp+8]
;
; hdr points at twenty bytes in network byte order. out points at the struct
; documented in driver.c. Its offsets are:
;
;   +0 version   +4 ihl    +8 dscp   +12 ecn   +16 total_length
;   +20 identification    +24 flags  +28 fragment_offset
;   +32 ttl      +36 protocol       +40 checksum
;   +44 src[0..3]                   +48 dst[0..3]
;
; Every int member is 4 bytes, so a plain 32-bit store fills one. The
; addresses are four single-byte stores each.
;
; Do not clobber ebx, esi, edi, or ebp. C assumes they survive your call.
; Return in eax (driver.c ignores it here, so returning 0 is fine).
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _decode_header decode_header
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

segment .text
        global  _decode_header
_decode_header:
        enter   0,0
        pusha

        ;
        ; TODO: read the header and fill the struct.
        ;
        ; The field-by-field layout is the table in the manual. The notes
        ; that matter before you start:
        ;
        ;   * Every multi-byte field is big-endian, so load it byte by byte
        ;     and recombine. A single 16-bit load gives you the bytes
        ;     reversed.
        ;   * The fragment offset straddles a byte boundary. Its top five
        ;     bits live in byte 6 and its bottom eight in byte 7. Combine
        ;     both bytes into one word first, then shift and mask.
        ;   * The flags are the top three bits of the same word.
        ;   * Read and store the checksum field like any other field.
        ;     ip_checksum computes the VALID line separately.
        ;   * src and dst are four single-byte stores each. No shifting.
        ;
        ; Nothing here reads the file or prints. This routine only fills
        ; the struct, and driver.c does the rest.
        ;

        ; pusha runs after enter has fixed ebp, so the 32 bytes it pushes
        ; sit below ebp and the argument offsets do not move.
        mov     esi, [ebp+8]            ; esi = hdr
        mov     edi, [ebp+12]           ; edi = out

        ; Byte 0 holds version (high nibble) and IHL (low nibble). movzx
        ; zeroes bits 31-8, so each 32-bit store below holds only the field.
        movzx   eax, byte [esi]
        mov     edx, eax                ; keep a copy; the shift destroys the low nibble

        ; Version is the high nibble. A 4-bit right shift moves it down to
        ; bits 3-0. The bits that shift in are zero, so no mask is needed.
        shr     eax, 4
        mov     [edi+0], eax            ; out->version

        ; IHL is the low nibble. 0x0F keeps bits 3-0 and clears the version
        ; bits. Store the count of 32-bit words. driver.c prints the *4.
        and     edx, 0x0F
        mov     [edi+4], edx            ; out->ihl

        ; Byte 1: DSCP uses the upper six bits; ECN uses the lower two.
        movzx   eax, byte [esi+1]
        mov     edx, eax
        shr     eax, 2
        and     edx, 0x03
        mov     [edi+8], eax            ; out->dscp
        mov     [edi+12], edx           ; out->ecn

        ; Bytes 2-3: combine the high and low bytes in network order.
        movzx   eax, byte [esi+2]
        shl     eax, 8
        movzx   edx, byte [esi+3]
        or      eax, edx
        mov     [edi+16], eax           ; out->total_length

        ; Bytes 4-5: identification has the same big-endian layout.
        movzx   eax, byte [esi+4]
        shl     eax, 8
        movzx   edx, byte [esi+5]
        or      eax, edx
        mov     [edi+20], eax           ; out->identification

        ; Bytes 6-7: split the three flag bits from the 13-bit offset.
        movzx   eax, byte [esi+6]
        shl     eax, 8
        movzx   edx, byte [esi+7]
        or      eax, edx
        mov     edx, eax
        shr     eax, 13
        and     edx, 0x1FFF
        mov     [edi+24], eax           ; out->flags
        mov     [edi+28], edx           ; out->fragment_offset

        ; Byte 8-11:
        movzx   eax, byte [esi+8]
        mov     [edi+32], eax
        movzx   eax, byte [esi+9]
        mov     [edi+36], eax
        movzx   eax, byte [esi+10]      ;checksum
        shl     eax, 8
        movzx   edx, byte [esi+11]
        or      eax, edx
        mov     [edi+40], eax

        ; Byte 12-15 Source Bytes:
        mov     al, byte [esi+12]
        mov     [edi+44], eax
        mov     al, byte [esi+13]
        mov     [edi+45], eax
        mov     al, byte [esi+14]
        mov     [edi+46], eax
        mov     al, byte [esi+15]
        mov     [edi+47], eax
        
        

        ; Byte 16-19 Destination Bytes:
        mov     al, byte [esi+16]
        mov     [edi+48], eax
        mov     al, byte [esi+17]
        mov     [edi+49], eax
        mov     al, byte [esi+18]
        mov     [edi+50], eax
        mov     al, byte [esi+19]
        mov     [edi+51], eax


        

        


        popa
        mov     eax, 0
        leave
        ret
