; Shadow screen. While it is on, presentation output is not sent: OUTBYT
; feeds this interpreter of the editor's own terminal subset, which draws into
; the wanted screen and marks the rows it writes. Before the editor waits for
; a key, TRMFLU compares each marked row with the shown screen, sends only the
; span that differs, uses ESC [ K for a blank tail, and then places the
; cursor. A keystroke that changes one cell sends a few bytes instead of a
; repainted row and status row.
;
; Cells hold ASCII with bit 7 set for reverse video. Each screen row is found
; through a row map (TRMWMAP, TRMSMAP), so moving rows rotates the maps. The
; bell is sent at once.

; EditorTerminalCodeStart
TRMCODST:

; Clear the terminal directly, then route output through the shadow screen
; with both screens blank. Used for every full repaint.
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorTerminalOn
TRMON:
            CALL TRMOFF
            LD   DE,CLEHOM
            CALL OUTTEX
            LD   A,(TRMICH)      ; TEC-OS: the text rows are the scroll region,
            OR   A               ; so moving them never disturbs the status row
            CALL NZ,TRMREG
            LD   HL,SCRWAN
            LD   DE,SCRWAN+1
            LD   BC,2*MAXCOL*MAXROW-1
            LD   (HL),' '
            LDIR
            LD   HL,TRMWMAP      ; rows in order: want slots, then shown slots
            XOR  A
; EditorTerminalOnMap
TRMONMP:
            LD   (HL),A
            INC  HL
            INC  A
            CP   2*MAXROW
            JR   NZ,TRMONMP
            LD   HL,SCRDIR
            LD   B,MAXROW
            CALL TRMZERO
            LD   (TRMPV),A
            LD   HL,TRMROW
            LD   B,TRMSTAN
            CALL TRMZERO
            LD   (TRMHINT),A
            INC  A
            LD   (TRMSHA),A
            RET

; Send ESC [ 1 ; T r: the text rows are the scroll region. The terminal homes
; its cursor, where the clear left it.
;@ROUTINE out A clobbers carry,zero,sign,parity,halfCarry,BC
; EditorTerminalRegion
TRMREG:
            LD   A,27
            CALL TRMRAW
            LD   A,'['
            CALL TRMRAW
            LD   A,'1'
            CALL TRMRAW
            LD   A,';'
            CALL TRMRAW
            LD   A,(TEXROWS)
            CALL TRMDEC
            LD   A,'r'
            JP   TRMRAW

; Zero B bytes from HL. Returns A = 0.
;@ROUTINE in B,HL out A,B,HL clobbers carry,zero,sign,parity,halfCarry
; EditorTerminalZero
TRMZERO:
            XOR  A
; EditorTerminalZeroLoop
TRMZERLO:
            LD   (HL),A
            INC  HL
            DJNZ TRMZERLO
            RET

;@ROUTINE out A clobbers carry,zero,sign,parity,halfCarry
; EditorTerminalOff
TRMOFF:
            XOR  A
            LD   (TRMSHA),A
            RET

; Interpret one presentation byte in E.
;@ROUTINE in E out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
; EditorTerminalPut
TRMPUT:
            LD   A,(TRMESC)
            OR   A
            JR   NZ,TRMSEQ
            LD   A,E
            CP   ' '
            JR   NC,TRMCHR
            CP   27
            JR   Z,TRMESCST
            CP   13
            JR   Z,TRMCR
            CP   10
            JR   Z,TRMLF
            CP   7
            RET  NZ
            LD   C,6
            JP   CALLBDOS
; EditorTerminalEscapeStart
TRMESCST:
            LD   A,1
            LD   (TRMESC),A
            RET
; EditorTerminalCarriageReturn
TRMCR:
            XOR  A
            LD   (TRMCOL),A
            LD   (TRMPV),A
            RET
; EditorTerminalLineFeed
TRMLF:
            LD   HL,TRMROW
            INC  (HL)
            XOR  A
            LD   (TRMPV),A
            RET
; Characters follow each other along a row, so the cell address is worked
; out once after each cursor move and then advanced.
; EditorTerminalCharacter
TRMCHR:
            LD   A,(TRMCOL)
            LD   HL,COLUMNS
            CP   (HL)
            RET  NC
            LD   C,A
            INC  A
            LD   (TRMCOL),A
            LD   A,(TRMATT)
            OR   E
            LD   E,A
            LD   HL,(TRMPTR)
            LD   A,(TRMPV)
            OR   A
            JR   NZ,TRMCHRP
            LD   A,(TRMROW)
            CALL TRMWAD
            LD   A,1
            LD   (TRMPV),A
; EditorTerminalCharacterPointer
TRMCHRP:
            LD   A,(HL)
            INC  HL
            LD   (TRMPTR),HL
            CP   E
            RET  Z
            DEC  HL
            LD   (HL),E
            LD   A,(TRMROW)
; Mark row A as written since the last flush.
; EditorTerminalMark
TRMMARK:
            LD   E,A
            LD   D,0
            LD   HL,SCRDIR
            ADD  HL,DE
            LD   (HL),1
            RET

; Escape sequences. TRMESC is 1 after ESC, 2 in the first parameter and 3 in
; the second.
; EditorTerminalSequence
TRMSEQ:
            CP   1
            JR   NZ,TRMPARB
            LD   A,E
            CP   '['
            LD   A,0
            JR   NZ,TRMSETST
            LD   (TRMPAR),A
            LD   (TRMPA2),A
            LD   A,2
; EditorTerminalSetState
TRMSETST:
            LD   (TRMESC),A
            RET
; EditorTerminalParameterByte
TRMPARB:
            LD   A,E
            SUB  '0'
            CP   10
            JR   NC,TRMNODIG
            LD   D,A
            LD   HL,TRMPAR
            LD   A,(TRMESC)
            CP   2
            JR   Z,TRMPARD
            INC  HL
; EditorTerminalParameterDigit
TRMPARD:
            LD   A,(HL)
            ADD  A,A
            LD   C,A
            ADD  A,A
            ADD  A,A
            ADD  A,C
            ADD  A,D
            LD   (HL),A
            RET
; EditorTerminalNotDigit
TRMNODIG:
            LD   A,E
            CP   ';'
            LD   A,3
            JR   Z,TRMSETST
            XOR  A
            LD   (TRMESC),A
            LD   A,E
            CP   'H'
            JR   Z,TRMPOS
            CP   'J'
            JR   Z,TRMCLS
            CP   'K'
            JR   Z,TRMEL
            CP   'm'
            RET  NZ
            LD   A,(TRMPAR)
            CP   7
            LD   A,$80
            JR   Z,TRMSATT
            XOR  A
; EditorTerminalSetAttribute
TRMSATT:
            LD   (TRMATT),A
            RET
; EditorTerminalPosition
TRMPOS:
            LD   A,(TRMPAR)
            OR   A
            JR   Z,TRMPOSR
            DEC  A
; EditorTerminalPositionRow
TRMPOSR:
            LD   (TRMROW),A
            LD   A,(TRMPA2)
            OR   A
            JR   Z,TRMPOSC
            DEC  A
; EditorTerminalPositionColumn
TRMPOSC:
            LD   (TRMCOL),A
            XOR  A
            LD   (TRMPV),A
            RET
; EditorTerminalClearScreen
TRMCLS:
            LD   HL,SCRWAN
            LD   DE,SCRWAN+1
            LD   BC,MAXCOL*MAXROW-1
            LD   (HL),' '
            LDIR
            LD   HL,SCRDIR
            LD   B,MAXROW
; EditorTerminalClearMark
TRMCLSMA:
            LD   (HL),1
            INC  HL
            DJNZ TRMCLSMA
            RET
; EditorTerminalEraseLine
TRMEL:
            LD   A,(TRMCOL)
            LD   C,A
            LD   A,(COLUMNS)
            SUB  C
            RET  Z
            RET  C
            LD   B,A
            LD   A,(TRMROW)
            CALL TRMWAD
; EditorTerminalEraseLoop
TRMELLO:
            LD   (HL),' '
            INC  HL
            DJNZ TRMELLO
            LD   A,(TRMROW)
            JP   TRMMARK

; HL = wanted cell and DE = shown cell at row A, column C. Preserves BC.
;@ROUTINE in A,C out HL,DE clobbers A,carry,zero,sign,parity,halfCarry
; EditorTerminalBothAddresses
TRMRWS:
            PUSH AF
            LD   HL,TRMSMAP
            CALL TRMMAPA
            EX   DE,HL
            POP  AF
; HL = wanted cell at row A, column C. Preserves BC, DE.
;@ROUTINE in A,C out HL clobbers A,carry,zero,sign,parity,halfCarry
; EditorTerminalWantAddress
TRMWAD:
            PUSH DE
            LD   HL,TRMWMAP
            CALL TRMMAPA
            POP  DE
            RET

; HL = SCRWAN + slot * MAXCOL + C, the slot read from the row map at HL for
; row A. Preserves BC.
;@ROUTINE in A,C,HL out HL clobbers A,carry,zero,sign,parity,halfCarry,DE
; EditorTerminalMapAddress
TRMMAPA:
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   L,(HL)
            LD   H,D
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,HL
            LD   D,H
            LD   E,L
            ADD  HL,HL
            ADD  HL,HL
            ADD  HL,DE
            LD   E,C
            LD   D,0
            ADD  HL,DE
            LD   DE,SCRWAN
            ADD  HL,DE
            RET

; Rotate the first T entries of the row map at HL (T text rows): A = 4 moves
; the rows up, so row 0's slot becomes the last text row's; otherwise down.
;@ROUTINE in A,HL clobbers A,carry,zero,sign,parity,halfCarry,BC,DE,HL
; EditorTerminalRotate
TRMROT:
            LD   D,A
            LD   A,(TEXROWS)
            DEC  A
            LD   C,A
            LD   B,0
            LD   A,D
            CP   4
            JR   NZ,TRMRODN
            LD   A,(HL)
            LD   D,H
            LD   E,L
            INC  HL
            LDIR
            LD   (DE),A
            RET
; EditorTerminalRotateDown
TRMRODN:
            ADD  HL,BC
            LD   A,(HL)
            LD   D,H
            LD   E,L
            DEC  HL
            LDDR
            LD   (DE),A
            RET

; Move the wanted text rows one row up (A = 4) or down (A = 5) after the view
; moved a line; the vacated row is drawn next. On TEC-OS's console the flush
; is told to move the terminal's rows the same way (TRMHINT) and only the new
; row is marked; elsewhere every text row is marked and redrawn.
;@ROUTINE in A clobbers A,carry,zero,sign,parity,halfCarry,C,DE,HL
; EditorTerminalMove
TRMMOVE:
            PUSH BC
            LD   HL,TRMWMAP
            CALL TRMROT
            XOR  A
            LD   (TRMPV),A
            POP  BC              ; B = the new row
            LD   A,(TRMICH)
            OR   A
            JR   Z,TRMMVALL
            LD   A,B
            OR   A
            LD   A,5             ; new row 0: the text moved down
            JR   Z,TRMMVHI
            LD   A,4
; EditorTerminalMoveHintSet
TRMMVHI:
            LD   (TRMHINT),A
            LD   A,B
            JP   TRMMARK
; EditorTerminalMoveAll
TRMMVALL:
            LD   HL,SCRDIR
            LD   A,(TEXROWS)
            LD   C,A
; EditorTerminalMoveMarkLoop
TRMMVML:
            LD   (HL),1
            INC  HL
            DEC  C
            JR   NZ,TRMMVML
            RET

; Send the differences of every marked row, then place the cursor where the
; presentation left it.
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorTerminalFlush
TRMFLU:
            LD   A,(TRMSHA)
            OR   A
            RET  Z
            CALL TRMSCRL
            XOR  A
            LD   (TRMFR),A
; EditorTerminalFlushRow
TRMFLRO:
            LD   A,(TRMFR)
            LD   E,A
            LD   D,0
            LD   HL,SCRDIR
            ADD  HL,DE
            LD   A,(HL)
            OR   A
            JR   Z,TRMFLNX
            LD   (HL),0
            CALL TRMROWF
; EditorTerminalFlushNext
TRMFLNX:
            LD   HL,TRMFR
            INC  (HL)
            LD   A,(TEXROWS)
            CP   (HL)
            JR   NC,TRMFLRO
            LD   A,(TRMROW)
            LD   B,A
            LD   A,(TRMCOL)
            LD   C,A
            JP   TRMGO

; On TEC-OS's console, when the first and last text rows were both written
; and the wanted text rows are the shown ones moved up or down a line, move
; the terminal's rows instead of redrawing them: one line delete or insert at
; the top of the scroll region, which is the text rows, so the status row
; stays put.
; The shown screen moves the same way and the rows are then compared as
; usual, which leaves only the new line to draw.
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorTerminalScroll
TRMSCRL:
            LD   A,(TRMICH)
            OR   A
            RET  Z
            LD   A,(TEXROWS)
            DEC  A
            RET  Z
            LD   E,A
            LD   D,0
            LD   HL,SCRDIR
            LD   B,(HL)
            ADD  HL,DE
            LD   A,(HL)
            OR   B
            RET  Z               ; neither end written
            LD   A,(TRMHINT)
            OR   A
            JR   NZ,TRMSCHI
            LD   A,(HL)
            AND  B
            RET  Z               ; a moved picture writes both ends
; EditorTerminalScrollHinted
TRMSCHI:
            LD   HL,TRMHINT
            LD   A,(HL)
            LD   (HL),0
            OR   A
            JR   NZ,TRMSCGO      ; the presenter moved the text itself
            LD   DE,$0001        ; want rows 0.. against shown rows 1..
            CALL TRMRCMP
            LD   A,4
            JR   Z,TRMSCGO
            LD   DE,$0100        ; want rows 1.. against shown rows 0..
            CALL TRMRCMP
            RET  NZ
            LD   A,5
; EditorTerminalScrollGo
TRMSCGO:
            LD   (TRMKB),A       ; 4: text moved up, 5: down
            CP   4
            LD   A,'M'
            JR   Z,TRMSCG1
            LD   A,'L'
; EditorTerminalScrollGoLine
TRMSCG1:
            LD   B,0             ; one line delete or insert at the top of the
            CALL TRMLINE         ; scroll region, which ends above the status row
            LD   A,(TRMKB)
            LD   HL,TRMSMAP
            CALL TRMROT
            LD   A,(TRMKB)       ; the shown row that came free is blank
            CP   4
            LD   A,0
            JR   NZ,TRMSCBR
            LD   A,(TEXROWS)
            DEC  A
; EditorTerminalScrollBlankRow
TRMSCBR:
            LD   C,0
            CALL TRMRWS
            LD   B,MAXCOL
            LD   A,' '
; EditorTerminalScrollBlankLoop
TRMSCBLO:
            LD   (DE),A
            INC  DE
            DJNZ TRMSCBLO
            RET

; Z when the T-1 wanted rows from row D equal the shown rows from row E.
;@ROUTINE in DE out A,zero clobbers carry,sign,parity,halfCarry,BC,DE,HL
; EditorTerminalRowsCompare
TRMRCMP:
            LD   A,(TEXROWS)
            DEC  A
            LD   B,A
; EditorTerminalRowsCompareLoop
TRMRCLO:
            PUSH BC
            PUSH DE
            LD   A,E
            LD   C,0
            CALL TRMRWS          ; DE = shown row E
            POP  HL
            PUSH HL
            LD   A,H
            CALL TRMWAD          ; HL = wanted row D
            LD   A,(COLUMNS)
            LD   B,A
            CALL TRMSAMB
            POP  DE
            POP  BC
            RET  NZ
            INC  D
            INC  E
            DJNZ TRMRCLO
            RET

; Send ESC [ A at row B, column 1: insert (L) or delete (M) a line there.
; TEC-OS leaves the cursor in column 1.
;@ROUTINE in A,B out A clobbers carry,zero,sign,parity,halfCarry,BC
; EditorTerminalLine
TRMLINE:
            LD   (TRMKK),A
            LD   C,0
            CALL TRMGO
            LD   A,27
            CALL TRMRAW
            LD   A,'['
            CALL TRMRAW
            LD   A,(TRMKK)
            JP   TRMRAW

; One marked row: F is the first differing cell, L1 one past the last, and K
; one past the last cell the row wants that is not a plain space. Cells F to
; min(L1, K) - 1 are sent; differences from K on are cleared with ESC [ K.
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorTerminalRowFlush
TRMROWF:
            LD   A,(TRMFR)
            LD   C,0
            CALL TRMRWS
            LD   (TRMWP),HL
            LD   (TRMSP),DE
            LD   A,(COLUMNS)
            LD   B,A
            LD   C,0
; EditorTerminalFirstLoop
TRMFIRLO:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,TRMFIRST
            INC  HL
            INC  DE
            INC  C
            DJNZ TRMFIRLO
            RET
; EditorTerminalFirst
TRMFIRST:
            LD   A,C
            LD   (TRMFC),A
            LD   A,(COLUMNS)
            LD   B,A
            LD   E,A
            LD   D,0
            LD   HL,(TRMSP)
            ADD  HL,DE
            PUSH HL
            LD   HL,(TRMWP)
            ADD  HL,DE
            POP  DE
; EditorTerminalLastLoop
TRMLASLO:
            DEC  HL
            DEC  DE
            LD   A,(DE)
            CP   (HL)
            JR   NZ,TRMLAST
            DJNZ TRMLASLO
; EditorTerminalLast
TRMLAST:
            LD   A,B
            LD   (TRMLL),A
            CALL TRMSHIFT
            JP   Z,TRMROWF
            LD   A,(COLUMNS)
            LD   B,A
            LD   E,A
            LD   D,0
            LD   HL,(TRMWP)
            ADD  HL,DE
; EditorTerminalKeepLoop
TRMKEELO:
            DEC  HL
            LD   A,(HL)
            CP   ' '
            JR   NZ,TRMKEEP
            DJNZ TRMKEELO
; EditorTerminalKeep
TRMKEEP:
            LD   A,(TRMLL)
            CP   B
            JR   C,TRMSPAN
            LD   A,B
; EditorTerminalSpan
TRMSPAN:
            LD   (TRMKK),A
            LD   A,B
            LD   (TRMKB),A
            LD   A,(TRMKK)
            LD   HL,TRMFC
            SUB  (HL)
            JR   Z,TRMTAIL
            JR   C,TRMTAIL
            LD   A,(TRMFR)
            LD   B,A
            LD   C,(HL)
            CALL TRMGO
            LD   A,(TRMFR)
            LD   HL,TRMFC
            LD   C,(HL)
            CALL TRMRWS
            LD   A,(TRMFC)
            LD   B,A
            LD   A,(TRMKK)
            LD   (PHYCOL),A
            SUB  B
            LD   B,A
; EditorTerminalWriteLoop
TRMWRLO:
            LD   A,(HL)
            PUSH AF
            AND  $80
            CALL TRMATR
            POP  AF
            LD   (DE),A
            AND  $7F
            CALL TRMRAW
            INC  HL
            INC  DE
            DJNZ TRMWRLO
; Differences past the last kept cell are blanks the row wants: clear them.
; EditorTerminalTail
TRMTAIL:
            LD   A,(TRMKB)
            LD   HL,TRMLL
            CP   (HL)
            RET  NC
            LD   HL,TRMFC
            CP   (HL)
            JR   NC,TRMTAILP
            LD   A,(HL)
; EditorTerminalTailPosition
TRMTAILP:
            LD   C,A
            LD   A,(TRMFR)
            LD   B,A
            CALL TRMGO
            XOR  A
            CALL TRMATR
            LD   A,27
            CALL TRMRAW
            LD   A,'['
            CALL TRMRAW
            LD   A,'K'
            CALL TRMRAW
            LD   A,(PHYCOL)
            LD   C,A
            LD   A,(COLUMNS)
            SUB  C
            LD   B,A
            LD   A,(TRMFR)
            CALL TRMRWS
; EditorTerminalTailLoop
TRMTALO:
            LD   A,' '
            LD   (DE),A
            INC  DE
            DJNZ TRMTALO
            RET

; On TEC-OS's console, a differing span of five or more cells that is the
; shown row moved one cell right or left from F is an inserted or deleted
; character: send ESC [ @ or ESC [ P at F, move the shown row the same way,
; and return Z so the row is compared again. NZ otherwise.
;@ROUTINE out A,zero clobbers carry,sign,parity,halfCarry,BC,DE,HL
; EditorTerminalShift
TRMSHIFT:
            LD   A,(TRMICH)
            OR   A
            JR   Z,TRMSHNO
            LD   A,(TRMLL)
            LD   HL,TRMFC
            SUB  (HL)
            CP   5
            JR   C,TRMSHNO
            DEC  A
            LD   (TRMKK),A
            LD   A,(TRMFR)
            LD   C,(HL)
            CALL TRMRWS
            PUSH HL
            PUSH DE
            INC  HL
            CALL TRMSAME
            POP  DE
            POP  HL
            LD   A,'@'
            JR   Z,TRMSHGO
            INC  DE
            CALL TRMSAME
            LD   A,'P'
            JR   Z,TRMSHGO
; EditorTerminalShiftNo
TRMSHNO:
            OR   1
            RET
; EditorTerminalShiftGo
TRMSHGO:
            LD   (TRMKB),A       ; the final byte, until the row is compared again
            LD   A,(TRMFR)
            LD   B,A
            LD   A,(TRMFC)
            LD   C,A
            CALL TRMGO
            LD   A,27
            CALL TRMRAW
            LD   A,'['
            CALL TRMRAW
            LD   A,(TRMKB)
            CALL TRMRAW
            LD   A,(TRMFC)
            LD   C,A
            LD   A,(COLUMNS)
            DEC  A
            SUB  C
            LD   B,0
            LD   C,A             ; cells that move: F+1 to the last column
            PUSH BC
            LD   A,(COLUMNS)
            DEC  A
            LD   C,A
            LD   A,(TRMFR)
            CALL TRMRWS          ; DE = last shown cell of the row
            POP  BC
            LD   A,(TRMKB)
            CP   '@'
            JR   NZ,TRMSHDEL
            LD   H,D
            LD   L,E
            DEC  HL
            LDDR                 ; a shift spans at least five cells
            INC  HL
            LD   (HL),' '
            XOR  A
            RET
; EditorTerminalShiftDelete
TRMSHDEL:
            PUSH DE
            LD   A,(TRMFR)
            LD   HL,TRMFC
            LD   C,(HL)
            CALL TRMRWS
            POP  HL              ; HL = last shown cell
            PUSH HL
            LD   A,(TRMFC)
            LD   C,A
            LD   A,(COLUMNS)
            DEC  A
            SUB  C
            LD   C,A
            LD   B,0
            LD   H,D
            LD   L,E
            INC  HL
            LDIR
            POP  HL
            LD   (HL),' '
            XOR  A
            RET

; Z when the TRMKK cells at HL equal those at DE; TRMSAMB compares B cells.
;@ROUTINE in DE,HL out A,zero clobbers carry,sign,parity,halfCarry,B,DE,HL
; EditorTerminalSame
TRMSAME:
            LD   A,(TRMKK)
            LD   B,A
; EditorTerminalSameCount
TRMSAMB:
; EditorTerminalSameLoop
TRMSAMLO:
            LD   A,(DE)
            CP   (HL)
            RET  NZ
            INC  HL
            INC  DE
            DJNZ TRMSAMLO
            RET

; Move the terminal cursor to row B, column C unless it is already there. The
; position is kept in PHYROW and PHYCOL before it is sent, so nothing here
; needs the stack beyond the output call.
;@ROUTINE in B,C out A clobbers carry,zero,sign,parity,halfCarry,BC
; EditorTerminalGo
TRMGO:
            LD   A,(PHYROW)
            CP   B
            JR   NZ,TRMGOSE
            LD   A,(PHYCOL)
            CP   C
            RET  Z
; EditorTerminalGoSend
TRMGOSE:
            LD   A,B
            LD   (PHYROW),A
            LD   A,C
            LD   (PHYCOL),A
            LD   A,27
            CALL TRMRAW
            LD   A,'['
            CALL TRMRAW
            LD   A,(PHYROW)
            INC  A
            CALL TRMDEC
            LD   A,';'
            CALL TRMRAW
            LD   A,(PHYCOL)
            INC  A
            CALL TRMDEC
            LD   A,'H'
            JR   TRMRAW

; Select reverse video when A is 80h, normal when 0, unless already selected.
;@ROUTINE in A out A clobbers carry,zero,sign,parity,halfCarry
; EditorTerminalAttribute
TRMATR:
            PUSH HL
            LD   HL,PHYATT
            CP   (HL)
            POP  HL
            RET  Z
            LD   (PHYATT),A
            OR   A
            LD   A,'0'
            JR   Z,TRMATRS
            LD   A,'7'
; EditorTerminalAttributeSend
TRMATRS:
            PUSH AF
            LD   A,27
            CALL TRMRAW
            LD   A,'['
            CALL TRMRAW
            POP  AF
            CALL TRMRAW
            LD   A,'m'
            JR   TRMRAW

; Send A (1-99) in decimal.
;@ROUTINE in A out A clobbers carry,zero,sign,parity,halfCarry,BC
; EditorTerminalDecimal
TRMDEC:
            LD   B,'0'-1
; EditorTerminalDecimalTens
TRMDECTE:
            INC  B
            SUB  10
            JR   NC,TRMDECTE
            ADD  A,10+'0'
            LD   C,A
            LD   A,B
            CP   '0'
            CALL NZ,TRMRAW
            LD   A,C
; Send A to the console now. Preserves BC, DE, HL in TRMSAV.
;@ROUTINE in A out A clobbers carry,zero,sign,parity,halfCarry
; EditorTerminalRaw
TRMRAW:
            LD   (TRMSAV),HL
            LD   (TRMSAV+2),DE
            LD   (TRMSAV+4),BC
            LD   E,A
            LD   C,6
            CALL CALLBDOS
            LD   HL,(TRMSAV)
            LD   DE,(TRMSAV+2)
            LD   BC,(TRMSAV+4)
            RET

; EditorTerminalCodeEnd
TRMCODEN:
