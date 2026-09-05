; Logical-character movement and visual-column mapping.

EditorNavigationCodeStart:
.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
EditorMoveLeft:
            LD   HL,(EditorCursor)
            LD   A,H
            OR   L
            JR   Z,EditorBufferBoundary
            DEC  HL
            PUSH HL
            CALL EditorBufferByteAt
            POP  HL
            CP   10
            JR   NZ,EditorMoveLeftStore
            LD   A,H
            OR   L
            JR   Z,EditorMoveLeftStore
            DEC  HL
            PUSH HL
            CALL EditorBufferByteAt
            POP  HL
            CP   13
            JR   Z,EditorMoveLeftStore
            INC  HL
EditorMoveLeftStore:
            LD   (EditorCursor),HL
            JR   EditorNavigationHorizontalDone

.routine out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
EditorMoveRight:
            LD   HL,(EditorCursor)
            PUSH HL
            CALL EditorBufferByteAt
            POP  HL
            JR   C,EditorBufferBoundary
            INC  HL
            CP   13
            JR   NZ,EditorMoveRightStore
            INC  HL
EditorMoveRightStore:
            LD   (EditorCursor),HL
EditorNavigationHorizontalDone:
            LD   A,(EditorFlags)
            AND  $F9
            LD   (EditorFlags),A
            XOR  A
            LD   (EditorStatus),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorMoveUp:
            CALL EditorNavigationPrepareVertical
            LD   HL,(EditorCursor)
            CALL EditorNavigationLineStart
            LD   A,H
            OR   L
            JR   Z,EditorBufferBoundary
            DEC  HL
            CALL EditorNavigationLineStart
            LD   DE,(EditorDesiredColumn)
            LD   A,(EditorDesiredColumnHigh)
            CALL EditorNavigationOffsetForColumn
            LD   (EditorCursor),HL
            XOR  A
            LD   (EditorStatus),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorMoveDown:
            CALL EditorNavigationPrepareVertical
            LD   HL,(EditorCursor)
            CALL EditorNavigationLineStart
            CALL EditorNavigationNextLine
            JP   C,EditorBufferBoundary
            LD   DE,(EditorDesiredColumn)
            LD   A,(EditorDesiredColumnHigh)
            CALL EditorNavigationOffsetForColumn
            LD   (EditorCursor),HL
            XOR  A
            LD   (EditorStatus),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorNavigationPrepareVertical:
            LD   A,(EditorFlags)
            AND  EditorFlagDesiredValid
            JR   NZ,EditorNavigationVerticalReady
            CALL EditorNavigationCursorColumn
            LD   (EditorDesiredColumn),HL
            LD   (EditorDesiredColumnHigh),A
            LD   A,(EditorFlags)
            OR   EditorFlagDesiredValid
            LD   (EditorFlags),A
EditorNavigationVerticalReady:
            LD   A,(EditorFlags)
            AND  $FD
            LD   (EditorFlags),A
            RET

.routine in HL out HL,carry,zero clobbers sign,parity,halfCarry,A,DE
EditorNavigationLineStart:
            LD   A,H
            OR   L
            RET  Z
EditorNavigationLineStartLoop:
            DEC  HL
            PUSH HL
            CALL EditorBufferByteAt
            POP  HL
            CP   10
            JR   NZ,EditorNavigationLineStartContinue
            INC  HL
            RET
EditorNavigationLineStartContinue:
            LD   A,H
            OR   L
            JR   NZ,EditorNavigationLineStartLoop
            RET

.routine in HL out HL,carry,zero clobbers sign,parity,halfCarry,A,DE
EditorNavigationNextLine:
            PUSH HL
            CALL EditorBufferByteAt
            POP  HL
            RET  C
            INC  HL
            CP   10
            JR   NZ,EditorNavigationNextLine
            OR   A
            RET

; Return the visual column in A:HL (24 bits).
.routine out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
EditorNavigationCursorColumn:
            XOR  A
            LD   (EditorColumnHigh),A
            LD   HL,(EditorCursor)
            LD   (EditorScratchA),HL
            CALL EditorNavigationLineStart
            LD   DE,0
EditorNavigationColumnLoop:
            PUSH HL
            LD   BC,(EditorScratchA)
            OR   A
            SBC  HL,BC
            POP  HL
            JR   Z,EditorNavigationColumnDone
            PUSH HL
            PUSH DE
            CALL EditorBufferByteAt
            POP  DE
            POP  HL
            JR   C,EditorNavigationColumnDone
            CP   9
            JR   Z,EditorNavigationColumnTab
            INC  DE
            LD   A,D
            OR   E
            JR   NZ,EditorNavigationColumnNext
            JR   EditorNavigationColumnCarry
EditorNavigationColumnTab:
            EX   DE,HL
            CALL EditorNavigationNextTab
            EX   DE,HL
            JR   NC,EditorNavigationColumnNext
EditorNavigationColumnCarry:
            LD   A,(EditorColumnHigh)
            INC  A
            LD   (EditorColumnHigh),A
EditorNavigationColumnNext:
            INC  HL
            JR   EditorNavigationColumnLoop
EditorNavigationColumnDone:
            EX   DE,HL
            LD   A,(EditorColumnHigh)
            OR   A
            RET

; Advance the low word to the next tab stop; carry reports a 16-bit wrap.
.routine in HL out HL,carry,zero clobbers sign,parity,halfCarry,A
EditorNavigationNextTab:
            LD   A,L
            OR   7
            INC  A
            LD   L,A
            RET  NZ
            INC  H
            RET  NZ
            SCF
            RET

; Return the insertion offset on the line beginning at HL whose visual column
; is nearest to, but does not exceed, A:DE.
.routine in A,DE,HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
EditorNavigationOffsetForColumn:
            LD   (EditorTargetColumnHigh),A
            XOR  A
            LD   (EditorColumnHigh),A
            LD   (EditorScratchA),DE
            LD   BC,0
EditorNavigationOffsetLoop:
            LD   (EditorScratchC),HL
            PUSH HL
            CALL EditorBufferByteAt
            POP  HL
            RET  C
            CP   10
            RET  Z
            CP   13
            RET  Z
            CP   9
            JR   Z,EditorNavigationOffsetTab
            INC  BC
            LD   A,B
            OR   C
            JR   NZ,EditorNavigationOffsetCompare
            JR   EditorNavigationOffsetCarry
EditorNavigationOffsetTab:
            LD   H,B
            LD   L,C
            CALL EditorNavigationNextTab
            LD   B,H
            LD   C,L
            JR   NC,EditorNavigationOffsetCompare
EditorNavigationOffsetCarry:
            LD   A,(EditorColumnHigh)
            INC  A
            LD   (EditorColumnHigh),A
EditorNavigationOffsetCompare:
            LD   A,(EditorTargetColumnHigh)
            LD   D,A
            LD   A,(EditorColumnHigh)
            CP   D
            JR   C,EditorNavigationOffsetTake
            JR   NZ,EditorNavigationOffsetReject
            LD   H,B
            LD   L,C
            LD   DE,(EditorScratchA)
            OR   A
            SBC  HL,DE
            JR   C,EditorNavigationOffsetTake
            JR   Z,EditorNavigationOffsetTake
EditorNavigationOffsetReject:
            LD   HL,(EditorScratchC)
            RET
EditorNavigationOffsetTake:
            LD   HL,(EditorScratchC)
            INC  HL
            JR   EditorNavigationOffsetLoop
EditorNavigationCodeEnd:
