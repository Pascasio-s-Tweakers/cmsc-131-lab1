;
; encode.asm - build a 20-byte IPv4 header from the field struct.
;
; This is your starting point. It assembles and links as-is, so the build
; works before you write any code. Right now it writes nothing, so the
; twenty bytes driver.c saves are whatever the buffer held. Your job is to
; replace that with the construction described below.
;
; The contract, from driver.c:
;
;       unsigned char *hdr        [ebp+12]
;       struct ipv4_fields *in    [ebp+8]
;
; driver.c documents the struct layout:
;
;   +0 version   +4 ihl    +8 dscp   +12 ecn   +16 total_length
;   +20 identification    +24 flags  +28 fragment_offset
;   +32 ttl      +36 protocol       +40 checksum
;   +44 src[0..3]                   +48 dst[0..3]
;
; You write twenty bytes into hdr. Every multi-byte field goes out
; big-endian: the high byte first. The fragment offset's top five bits share
; byte 6 with the three flag bits. Its bottom eight bits are byte 7.
;
; The checksum is your job too. Bytes 10-11 must read as zero while the
; checksum is computed. Write them as zero, call ip_checksum over the
; finished header, and store its result into the field. The struct's
; checksum member is read on the decode path only. Don't copy it here.
;
; Do not clobber ebx, esi, edi, or ebp. C assumes they survive your call.
; Return in eax (driver.c ignores it here, so returning 0 is fine).
;

; Windows C puts a leading underscore on every exported name. Linux C does
; not. The Makefile passes -d ELF_TYPE on Linux. This block then respells
; the names below to match. asm_io.inc does the same for _asm_main in the
; bootcamp blocks. Leave this block alone.
%ifdef ELF_TYPE
  %define _ip_checksum ip_checksum
  %define _encode_header encode_header
  section .note.GNU-stack noalloc noexec nowrite progbits
%endif

extern _ip_checksum

segment .text
        global  _encode_header
_encode_header:
        enter   0,0
        pusha

        ;
        ; TODO: build the header from the struct.
        ;
        ; This is the reverse of decode. Mask each field to its width,
        ; shift it up to where it lives, or the pieces of a shared byte
        ; together, then store the byte. The fields that do not straddle
        ; anything are one store each.
        ;
        ; The checksum comes last, after every other byte is written. Write
        ; bytes 10-11 as zero, call ip_checksum with the header and 20, and
        ; store its result (in ax) into the field big-endian. Computing it
        ; before the rest of the header is in place sums whatever garbage
        ; was in the buffer. ip_checksum preserves ebx, esi, edi, and ebp,
        ; so a pointer kept in one of those survives the call. eax, ecx, and
        ; edx do not.
        ;
        mov     esi, [ebp+8]                 ; esi = in  (the struct, we read it)
        mov     edi, [ebp+12]                ; edi = hdr (the 20 bytes, we write them)

        ; Byte 0: version in the top 4 bits, IHL in the bottom 4.
        mov     eax, [esi+0]                 ; version
        shl     eax, 4                       ; move it up to bits 7-4
        mov     edx, [esi+4]                 ; ihl
        and     edx, 0xF                     ; keep 4 bits so it cant spill into version
        or      eax, edx
        mov     byte [edi+0], al             ; store one byte

        ; Byte 1: DSCP in the top 6 bits, ECN in the bottom 2.
        mov     eax, [esi+8]                 ; dscp
        shl     eax, 2                       ; move it up to bits 7-2
        mov     edx, [esi+12]                ; ecn
        and     edx, 0b11                    ; keep 2 bits so it cant spill into dscp
        or      eax, edx
        mov     byte [edi+1], al             ; store one byte

        ; Bytes 2-3: total_length, big-endian.
        mov     eax, [esi+16]                ; total_length
        mov     byte [edi+2], ah             ; high byte first (big-endian)
        mov     byte [edi+3], al             ; then the low byte

        ; Bytes 4-5: identification, big-endian.
        mov     eax, [esi+20]                ; identification
        mov     byte [edi+4], ah             ; high byte first (big-endian)
        mov     byte [edi+5], al             ; then the low byte

        ; Bytes 6-7: flags in the top 3 bits, fragment offset in the bottom 13.
        ; Build the 16-bit word first, because the offset straddles both bytes.
        mov     eax, [esi+24]                ; flags
        shl     eax, 13                      ; 16 - 3 = 13, move it up to bits 15-13
        mov     edx, [esi+28]                ; fragment_offset
        and     edx, 0x1FFF                  ; keep 13 bits so it cant spill into flags
        or      eax, edx
        mov     byte [edi+6], ah             ; flags and the top 5 offset bits
        mov     byte [edi+7], al             ; the bottom 8 offset bits

        ; Bytes 8 and 9: ttl and protocol fill a whole byte each, so no shift.
        mov     eax, [esi+32]                ; ttl
        mov     byte [edi+8], al             ; store one byte
        mov     eax, [esi+36]                ; protocol
        mov     byte [edi+9], al             ; store one byte

        ; Bytes 12-15: source address. The struct holds the octets in
        ; network order already, so copy them one byte at a time.
        mov     al, byte [esi+44]            ; src[0]
        mov     byte [edi+12], al
        mov     al, byte [esi+45]            ; src[1]
        mov     byte [edi+13], al
        mov     al, byte [esi+46]            ; src[2]
        mov     byte [edi+14], al
        mov     al, byte [esi+47]            ; src[3]
        mov     byte [edi+15], al

        ; Bytes 16-19: destination address, copied the same way.
        mov     al, byte [esi+48]            ; dst[0]
        mov     byte [edi+16], al
        mov     al, byte [esi+49]            ; dst[1]
        mov     byte [edi+17], al
        mov     al, byte [esi+50]            ; dst[2]
        mov     byte [edi+18], al
        mov     al, byte [esi+51]            ; dst[3]
        mov     byte [edi+19], al

        ; Bytes 10-11: checksum. This comes last, because ip_checksum sums
        ; all 20 bytes. The field must read as zero while it is computed.
        mov     word [edi+10], 0             ; clear both checksum bytes

        push    dword 20                     ; 2nd argument: header length in bytes
        push    edi                          ; 1st argument: hdr
        call    _ip_checksum                 ; result comes back in ax
        add     esp, 8                       ; remove the 2 arguments (4 bytes each)

        mov     byte [edi+10], ah            ; high byte first (big-endian)
        mov     byte [edi+11], al            ; then the low byte

        popa
        mov     eax, 0
        leave
        ret
