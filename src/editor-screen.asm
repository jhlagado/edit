; Full repaint for the selected screen size. Every row except the last shows
; text; the last row is the status row.

EditorAbiBase     .equ $FF00
EditorAbiGeometry .equ $FF09

EditorScreenCodeStart:
; Select the screen size from the TEC-OS console geometry when the probe flag
; is set and the ABI table reports nonzero columns, otherwise from the
; configuration block. Each dimension is clamped to the supported range.
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorSelectScreen:
            LD   HL,(EditorConfigColumns)
            LD   A,(EditorConfigFlags)
            AND  EditorConfigProbe
            JR   Z,EditorSelectScreenClamp
            PUSH HL
            LD   HL,EditorAbiBase
            LD   DE,EditorAbiTag
            CALL EditorCommandExtensionEqual
            POP  HL
            JR   NZ,EditorSelectScreenClamp
            LD   DE,(EditorAbiGeometry)
            LD   A,D
            OR   E
            JR   Z,EditorSelectScreenClamp
            LD   A,(DE)
            OR   A
            JR   Z,EditorSelectScreenClamp
            EX   DE,HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
EditorSelectScreenClamp:
            LD   A,L
            LD   B,EditorMinimumColumns
            CALL EditorClampSize
            LD   (EditorColumns),A
            LD   A,H
            LD   B,EditorMinimumRows
            CALL EditorClampSize
            DEC  A
            LD   (EditorTextRows),A
            RET

.routine in A,B out A,carry,zero clobbers sign,parity,halfCarry
EditorClampSize:
            CP   B
            JR   NC,EditorClampSizeHigh
            LD   A,B
EditorClampSizeHigh:
            CP   EditorMaximumSize+1
            RET  C
            LD   A,EditorMaximumSize
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorRender:
            CALL EditorEnsureViewport
            LD   DE,EditorClearHome
            CALL EditorOutputText
            LD   A,(EditorTextRows)
            LD   B,A
            LD   HL,(EditorTop)
EditorRenderRows:
            PUSH BC
            CALL EditorRenderLine
            LD   (EditorRenderPointer),HL
            LD   A,13
            CALL EditorOutputByte
            LD   A,10
            CALL EditorOutputByte
            LD   HL,(EditorRenderPointer)
            POP  BC
            DJNZ EditorRenderRows
            JP   EditorRenderStatus

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorEnsureViewport:
            LD   HL,(EditorCursor)
            CALL EditorNavigationLineStart
            LD   (EditorScratchA),HL
EditorEnsureVertical:
            LD   DE,(EditorTop)
            OR   A
            SBC  HL,DE
            JR   NC,EditorEnsureCountRows
            LD   HL,(EditorScratchA)
            LD   (EditorTop),HL
EditorEnsureCountRows:
            LD   HL,(EditorTop)
            LD   B,0
EditorEnsureRowLoop:
            LD   DE,(EditorScratchA)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   Z,EditorEnsureRowReady
            CALL EditorNavigationNextLine
            JR   C,EditorEnsureRowReady
            INC  B
            LD   A,(EditorTextRows)
            DEC  A
            CP   B
            JR   NC,EditorEnsureRowLoop
            LD   HL,(EditorTop)
            CALL EditorNavigationNextLine
            JR   C,EditorEnsureRowReady
            LD   (EditorTop),HL
            LD   HL,(EditorScratchA)
            JR   EditorEnsureVertical
EditorEnsureRowReady:
            LD   A,B
            LD   (EditorCursorScreenRow),A
            CALL EditorNavigationCursorColumn
            LD   C,A
            LD   A,(EditorColumns)
            LD   E,A
            LD   D,0
            LD   A,C
            OR   A
            JR   NZ,EditorEnsureHorizontal
            PUSH HL
            SBC  HL,DE
            POP  HL
            JR   C,EditorEnsureNoHorizontal
EditorEnsureHorizontal:
            ; Keep the cursor in the final column: Horizontal = column-(width-1).
            DEC  DE
            OR   A
            SBC  HL,DE
            LD   (EditorHorizontal),HL
            LD   A,C
            SBC  A,0
            LD   (EditorHorizontalHigh),A
            EX   DE,HL
            JR   EditorEnsureColumnReady
EditorEnsureNoHorizontal:
            XOR  A
            LD   (EditorHorizontalHigh),A
            LD   DE,0
            LD   (EditorHorizontal),DE
EditorEnsureColumnReady:
            LD   A,L
            LD   (EditorCursorScreenColumn),A
            RET

; Render one logical line beginning at HL and return the next line's offset or
; logical EOF. RenderColumn is the source visual column; RenderCount is cells.
.routine in HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
EditorRenderLine:
            LD   (EditorRenderPointer),HL
            LD   HL,0
            LD   (EditorRenderColumn),HL
            LD   (EditorRenderCount),HL
            XOR  A
            LD   (EditorRenderColumnHigh),A
EditorRenderLineLoop:
            LD   HL,(EditorRenderPointer)
            PUSH HL
            CALL EditorBufferByteAt
            POP  HL
            JR   C,EditorRenderLineDone
            CP   10
            JR   Z,EditorRenderLineNewline
            CP   13
            JR   Z,EditorRenderLineCr
            CP   9
            JR   Z,EditorRenderLineTab
            CALL EditorRenderCell
            JR   EditorRenderLineAdvance
EditorRenderLineTab:
            LD   HL,(EditorRenderColumn)
            CALL EditorNavigationNextTab
            LD   (EditorScratchB),HL
EditorRenderTabLoop:
            LD   A,' '
            CALL EditorRenderCell
            ; A tab spans at most eight cells: low-word equality also detects
            ; its end across wrap. RenderCell carries into the high byte.
            LD   HL,(EditorRenderColumn)
            LD   DE,(EditorScratchB)
            OR   A
            SBC  HL,DE
            JR   NZ,EditorRenderTabLoop
EditorRenderLineAdvance:
            LD   HL,(EditorRenderPointer)
            INC  HL
            LD   (EditorRenderPointer),HL
            JR   EditorRenderLineLoop
EditorRenderLineCr:
            INC  HL
            LD   (EditorRenderPointer),HL
            PUSH HL
            CALL EditorBufferByteAt
            POP  HL
            JR   C,EditorRenderLineDone
            CP   10
            JR   NZ,EditorRenderLineDone
EditorRenderLineNewline:
            INC  HL
            LD   (EditorRenderPointer),HL
EditorRenderLineDone:
            LD   HL,(EditorRenderPointer)
            RET

; Render one visual cell in A when it lies in the horizontal viewport.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorRenderCell:
            LD   (EditorScratchC),A
            LD   A,(EditorHorizontalHigh)
            LD   D,A
            LD   A,(EditorRenderColumnHigh)
            CP   D
            JR   C,EditorRenderCellAdvance
            JR   NZ,EditorRenderCellVisible
            LD   HL,(EditorRenderColumn)
            LD   DE,(EditorHorizontal)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,EditorRenderCellAdvance
EditorRenderCellVisible:
            LD   A,(EditorColumns)
            LD   D,A
            LD   A,(EditorRenderCount)
            CP   D
            JR   NC,EditorRenderCellAdvance
            LD   A,(EditorScratchC)
            CALL EditorOutputByte
            LD   HL,(EditorRenderCount)
            INC  HL
            LD   (EditorRenderCount),HL
EditorRenderCellAdvance:
            LD   HL,(EditorRenderColumn)
            INC  HL
            LD   (EditorRenderColumn),HL
            LD   A,H
            OR   L
            RET  NZ
            LD   A,(EditorRenderColumnHigh)
            INC  A
            LD   (EditorRenderColumnHigh),A
            RET

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorRenderStatus:
            LD   DE,EditorStatusPrefix
            CALL EditorStatusBegin
            LD   HL,EditorFcb+1
            LD   B,8
EditorStatusNameLoop:
            LD   A,(HL)
            PUSH HL
            PUSH BC
            CALL EditorStatusByte
            POP  BC
            POP  HL
            INC  HL
            DJNZ EditorStatusNameLoop
            LD   A,'.'
            CALL EditorStatusByte
            LD   HL,EditorFcb+9
            LD   B,3
EditorStatusExtensionLoop:
            LD   A,(HL)
            PUSH HL
            PUSH BC
            CALL EditorStatusByte
            POP  BC
            POP  HL
            INC  HL
            DJNZ EditorStatusExtensionLoop
            LD   A,' '
            CALL EditorStatusByte
            LD   A,(EditorFlags)
            AND  EditorFlagDirty
            LD   A,' '
            JR   Z,EditorStatusDirtyReady
            LD   A,'*'
EditorStatusDirtyReady:
            CALL EditorStatusByte
            LD   A,' '
            CALL EditorStatusByte
            LD   A,' '
            CALL EditorStatusByte
            CALL EditorStatusMessage
            ; Key hints appear only when they fit in the remaining cells.
            LD   A,(EditorColumns)
            LD   HL,EditorRenderCount
            SUB  (HL)
            CP   EditorStatusHintsLength
            LD   DE,EditorStatusHints
            CALL NC,EditorStatusText
.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorStatusFill:
            LD   A,(EditorColumns)
            LD   HL,EditorRenderCount
            CP   (HL)
            JR   Z,EditorStatusFilled
            LD   A,' '
            CALL EditorStatusByte
            JR   EditorStatusFill
EditorStatusFilled:
            LD   DE,EditorReverseOff
            CALL EditorOutputText
            JP   EditorPositionCursor

.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorStatusBegin:
            PUSH DE
            LD   A,27
            CALL EditorOutputByte
            LD   A,'['
            CALL EditorOutputByte
            LD   A,(EditorTextRows)
            INC  A
            CALL EditorOutputDecimal
            LD   DE,EditorStatusPosition
            CALL EditorOutputText
            LD   HL,0
            LD   (EditorRenderCount),HL
            POP  DE
            JP   EditorStatusText

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorStatusMessage:
            LD   A,(EditorStatus)
            OR   A
            RET  Z
            ADD  A,A
            JR   C,EditorStatusSearchMessage
            CP   EditorStatusSaved*2
            LD   DE,EditorStatusSavedText
            JR   Z,EditorStatusMessageText
            CP   EditorStatusFull*2
            LD   DE,EditorStatusFullText
            JR   Z,EditorStatusMessageText
            CP   EditorStatusDiscard*2
            LD   DE,EditorStatusDiscardText
            JR   Z,EditorStatusMessageText
            CP   EditorStatusSaveConflict*2
            JR   C,EditorStatusMessageDone
            LD   DE,EditorStatusSaveFailedText
            CALL EditorStatusText
            LD   A,(EditorStatus)
            OR   A
            PUSH AF
            RRCA
            RRCA
            RRCA
            RRCA
            CALL EditorStatusHexNibble
            POP  AF
            CALL EditorStatusHexNibble
EditorStatusMessageDone:
            RET
EditorStatusMessageText:
            JR   EditorStatusText
EditorStatusSearchMessage:
            LD   E,A
            LD   D,0
            LD   HL,EditorStatusFoundText
            ADD  HL,DE
            EX   DE,HL
            JR   EditorStatusText

.routine in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorStatusText:
            LD   A,(DE)
            OR   A
            RET  Z
            INC  DE
            PUSH DE
            CALL EditorStatusByte
            POP  DE
            JR   EditorStatusText

; Output one status cell in A. Cells beyond the screen width are dropped.
.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorStatusByte:
            LD   C,A
            LD   A,(EditorColumns)
            LD   HL,EditorRenderCount
            CP   (HL)
            RET  Z
            INC  (HL)
            LD   A,C
            JP   EditorOutputByte

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorStatusHexNibble:
            AND  $0F
            ADD  A,'0'
            CP   '9'+1
            JR   C,EditorStatusByte
            ADD  A,7
            JR   EditorStatusByte

.routine out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorPositionCursor:
            LD   A,(EditorCursorScreenRow)
            INC  A
            LD   (EditorScratchA),A
            LD   A,(EditorCursorScreenColumn)
            INC  A
            LD   (EditorScratchA+1),A
            LD   A,(EditorScratchA)
            CALL EditorOutputDecimal
            LD   A,';'
            CALL EditorOutputByte
            LD   A,(EditorScratchA+1)
            CALL EditorOutputDecimal
            LD   A,'H'
            JR   EditorOutputByte

.routine in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EditorOutputDecimal:
            LD   B,0
EditorOutputDecimalLoop:
            CP   10
            JR   C,EditorOutputDecimalReady
            SUB  10
            INC  B
            JR   EditorOutputDecimalLoop
EditorOutputDecimalReady:
            LD   (EditorScratchC),A
            LD   A,B
            OR   A
            JR   Z,EditorOutputDecimalOnes
            ADD  A,'0'
            CALL EditorOutputByte
EditorOutputDecimalOnes:
            LD   A,(EditorScratchC)
            ADD  A,'0'
            JR   EditorOutputByte

.routine in A out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EditorOutputByte:
            LD   E,A
            LD   C,6
            JP   EditorCallBdos

.routine in DE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EditorOutputText:
            LD   A,(DE)
            CP   '$'
            RET  Z
            INC  DE
            PUSH DE
            CALL EditorOutputByte
            POP  DE
            JR   EditorOutputText

EditorScreenCodeEnd:
