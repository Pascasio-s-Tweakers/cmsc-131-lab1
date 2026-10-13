<!--no-pdf-->
# CMSC 131 Lab 1 Starter

Decode, encode, and checksum 20-byte IPv4 packet headers under a C driver.
The manual is the assignment. This file is the repository's own notes.

## Layout

```text
Makefile            platform preamble and build rules
driver.c            provided: argument parsing and file I/O
cdecl.h             provided: the calling-convention macros
decode.asm          yours
encode.asm          yours
checksum.asm        yours
run_tests.sh        provided: the correctness gate
contract_test.c     provided: the second pass, in C
contract_regs.asm   provided: register discipline checks for contract_test
tests/              provided: the header fixtures, their expected output,
                    and manifest.txt, the list both passes read
LICENSE             CC BY-NC-SA 4.0, inherited from the pcasm material
```

## What to Run

```bash
make
make check
```

`make` builds `renpkt` and `contract_test`. `make check` builds both, then
runs `./run_tests.sh`, which reports each test and exits nonzero when any
of them differ.

The gate has two passes. The first decodes every header listed in
`tests/manifest.txt` and compares the output with `tests/expected/`. The
second is `contract_test`. It decodes and re-encodes every header the
manifest marks valid. It checks a checksum vector that needs the carry
folded twice. It checks that all three routines keep `ebx`, `esi`, `edi`,
and `ebp`, and return with `esp` where the call left it. A program can pass
the first pass and fail the second. That failure is the usual encoder bug.

## Reading Check Results

The assembly routines now decode, encode, and checksum the 20-byte header.
The decode pass identifies fields that differ from expected output. The
contract pass reports the first byte that fails a valid-header round trip,
checks a checksum that needs two carry folds, and checks register preservation.

## Adding a Header

Put the header in `tests/NAME.bin`. Write the output `renpkt --decode`
must print for it in `tests/expected/NAME.out`. Then add one line to
`tests/manifest.txt`:

```text
NAME valid
```

Use `invalid` for a header with a wrong checksum. A valid header joins the
round trip in `contract_test` as well as the decode pass. The gate fails
and names the file when a `.bin` is not in the manifest, and when a listed
header has no expected file.

## The Driver's Argument Checks

`renpkt --encode` refuses a value its field cannot hold, and two values the
standard forbids. `--len` takes 20 through 65535, because the total length
counts the header. It defaults to 20. `--flags` takes 0 through 3, because
the top bit of the field is reserved and must be zero. `--df` sets 2 and
`--mf` sets 1. A refused option exits with status 2 and writes no file.

## Documentation

The three sections at the end of this file are yours. Complete Design Notes
and Subsystem Ownership before the Week 1 progress report. Complete Quirks
and Issues before the Week 3 progress report. Each section says what it
needs. Leave the rest of this file as it is.

## Fixtures

The provided files are fixtures. The grader compares your fork against the
starter. An edit to `driver.c`, `Makefile`, `run_tests.sh`,
`contract_test.c`, `contract_regs.asm`, or a provided `tests/` file appears
as a diff in the open. Your own headers and manifest lines are additions,
not edits.

---

## Design Notes

Complete this section before the Week 1 progress report. The syllabus asks
for problem analysis, a solution architecture, and an estimated timeline.
Keep each part short. Update it when the plan changes.

### Problem analysis

The tool reads a 20-byte IPv4 base header and prints its fields and checksum
validity, or builds a 20-byte header from command-line fields. Byte 0 holds
version and IHL, byte 1 holds DSCP and ECN, bytes 2-5 hold length and ID,
bytes 6-7 share flags and a 13-bit fragment offset, bytes 8-11 hold TTL,
protocol, and checksum, and bytes 12-19 hold the two addresses. The shared
flags/offset word and big-endian 16-bit fields need the most care.

### Solution architecture

`decode_header` reads header bytes through `esi`, combines multi-byte values
in `eax` and `edx`, and stores fields through `edi` at the offsets in
`driver.c`: version/IHL at +0/+4, DSCP/ECN at +8/+12, length/ID at +16/+20,
flags/offset at +24/+28, TTL/protocol/checksum at +32/+36/+40, and address
octets at +44..+51. `encode_header` reads that struct through `esi`, writes
the header through `edi`, uses `eax` and `edx` to pack fields, zeroes bytes
10-11, and calls `ip_checksum` before storing the checksum. `ip_checksum`
walks the header through `esi`, counts bytes in `ecx`, builds each word in
`ebx` and `edx`, and sums and folds it in `eax`.
Each routine preserves the registers required by the C calling convention.

### Timeline

One line per week. Name the subsystem each week finishes and the member
who owns it.

| Week | Goal | Owner |
|---|---|---|
| 1 | Header layout and decode path | Eusef Karl Blancada and Yuan Birondo |
| 2 | Encode path and round-trip checks | JP Salomeo |
| 3 | Checksum, edge fixtures, and integration checks | Renz Banas |
| 4 | Defense and final review | All members |

## Subsystem Ownership

Complete this section before the Week 1 progress report. The manual lists
the three subsystems. Each member owns one. In a group of four, two members
share one. The commit history must agree with this table.

| Subsystem | Owner |
|---|---|
| Decode path (`decode.asm`) | Eusef Karl Blancada and Yuan Birondo |
| Encode path (`encode.asm`) | JP Salomeo |
| Checksum and tests (`checksum.asm`, `tests/`) | Renz Banas |

## Quirks and Issues

Complete this section before the Week 3 progress report. The syllabus asks
for documentation of quirks and issues with the complete implementation.
One entry per item. State what happens, what causes it, and what the group
did about it.

### Known issues

- `ip_checksum` reads a 32-bit value for each two-byte word. On the final
  word of a 20-byte header, that reads two bytes past the buffer; masking
  the unused bytes still gives the expected test result but does not make the
  read safe. The issue is documented; replacing those loads with two byte
  loads remains to be done.

### Quirks

- The tool always reads and writes exactly 20 header bytes, even when the
  total-length field is larger. That field describes the whole IPv4 packet;
  this lab handles only its base header. We keep the scope explicit in the
  driver and test fixtures.
- A valid header can store a checksum of `0x0000`. The checksum routine sums
  the header including that field, so validity depends on a zero result,
  not on the stored field being nonzero. `edge_zero_checksum` tests this case.
