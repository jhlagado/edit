; Presentation for the selected screen size. Every row except the last shows
; text; the last row is the status row.

; EditorAbiBase
ABIBAS      EQU $FF00
; EditorAbiGeometry
ABIGEO      EQU $FF09

; EditorScreenCodeStart
SCRCODST:
; Select the screen size from the TEC-OS console geometry when the probe flag
; is set and the ABI table reports nonzero columns, otherwise from the
; configuration block. Each dimension is clamped to the supported range.
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorSelectScreen
SELSCR:
            LD   HL,(CFGCOL)
            LD   A,(CFGFLA)
            AND  CFGPRO
            JR   Z,SELSCRCL
            PUSH HL
            LD   HL,ABIBAS
            LD   DE,ABITAG
            CALL COMEXTEQ
            POP  HL
            JR   NZ,SELSCRCL
            LD   DE,(ABIGEO)
            LD   A,D
            OR   E
            JR   Z,SELSCRCL
            LD   A,(DE)
            OR   A
            JR   Z,SELSCRCL
            EX   DE,HL
            LD   E,(HL)
            INC  HL
            LD   D,(HL)
            EX   DE,HL
; EditorSelectScreenClamp
SELSCRCL:
            LD   A,L
            LD   BC,MINCOL*256+MAXCOL
            CALL CLASIZ
            LD   (COLUMNS),A
            LD   A,H
            LD   BC,MINROW*256+MAXROW
            CALL CLASIZ
            DEC  A
            LD   (TEXROWS),A
            RET

; Clamp A to the inclusive range B..C.
;@ROUTINE in A,BC out A,carry,zero clobbers sign,parity,halfCarry
; EditorClampSize
CLASIZ:
            CP   B
            JR   NC,CLASIZHI
            LD   A,B
; EditorClampSizeHigh
CLASIZHI:
            CP   C
            RET  C
            LD   A,C
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorRender
RENDER:
            CALL LAYRES
            XOR  A
            LD   (DISSTAVA),A
            JP   PRESENT

; Incremental presentation after one raw command. Layout reports byte-independent
; damage and owns cache invalidation; this adapter emits only affected rows.
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorPresent
PRESENT:
            LD   A,(DOCPENCH)
            OR   A
            JR   Z,PRESNOCH
            XOR  A
            LD   (DISSTAVA),A
; EditorPresentNoDocumentChange
PRESNOCH:
            CALL LAYPRE
            OR   A
            JP   Z,DISSTA
            CP   3
            JR   NZ,DISPAR
            LD   DE,CLEHOM
            CALL OUTTEX
            XOR  A
            LD   (DISSTAVA),A
            LD   B,0
            LD   A,3
; EditorDisplayPartial
DISPAR:
            LD   C,A
            LD   A,B
            LD   (DISROW),A
            INC  A
            LD   D,A
            LD   A,C
            CP   1
            LD   A,(TEXROWS)
            JR   NZ,DISENDRE
            LD   A,D
; EditorDisplayEndReady
DISENDRE:
            LD   (DISENDRO),A
; EditorDisplayRowLoop
DISROWLO:
            LD   DE,CURPRE
            CALL OUTTEX
            LD   A,(DISROW)
            INC  A
            CALL OUTDEC
            LD   A,';'
            CALL OUTBYT
            LD   A,'1'
            CALL OUTBYT
            LD   A,'H'
            CALL OUTBYT
            LD   A,(DISROW)
            CALL LAYGETRO
            JR   C,DISBLARO
            LD   (RENPOI),HL
            LD   (RENCOL),DE
            LD   (RENCOLHI),A
            LD   HL,0
            LD   (RENCOU),HL
            CALL DISPAILI
            LD   A,(COLUMNS)
            LD   HL,RENCOU
            CP   (HL)
            JR   Z,DISNEXRO
; EditorDisplayBlankRow
DISBLARO:
            LD   DE,ERALIN
            CALL OUTTEX
; EditorDisplayNextRow
DISNEXRO:
            LD   HL,DISROW
            INC  (HL)
            LD   A,(DISENDRO)
            CP   (HL)
            JR   NZ,DISROWLO
; EditorDisplayStatus
DISSTA:
            LD   A,(DISSTAVA)
            OR   A
            JR   Z,DISREFST
            LD   A,(FLAGS)
            AND  FLADIR
            LD   B,A
            LD   A,(DISLASFL)
            CP   B
            JR   NZ,DISREFST
            LD   A,(STATUS)
            LD   B,A
            LD   A,(DISLASST)
            CP   B
            JR   NZ,DISREFST
            LD   HL,(CURSOR)
            LD   DE,(DISLASCU)
            OR   A
            SBC  HL,DE
            JR   NZ,DISREFST
            LD   DE,CURPRE
            CALL OUTTEX
            JP   POSCUR
; EditorDisplayRefreshStatus
DISREFST:
            LD   A,(FLAGS)
            AND  FLADIR
            LD   (DISLASFL),A
            LD   A,(STATUS)
            LD   (DISLASST),A
            LD   A,1
            LD   (DISSTAVA),A
            JP   RENSTA

; Each row starts from a cached near-left anchor and stops at its known content
; end or the screen width. Hidden suffixes and whole prefixes are not read.
; EditorDisplayPaintLine
DISPAILI:
            LD   A,(COLUMNS)
            LD   HL,RENCOU
            CP   (HL)
            RET  Z
            LD   HL,(RENPOI)
            LD   DE,(LAYROWEN)
            OR   A
            SBC  HL,DE
            RET  NC
            LD   HL,(RENPOI)
            CALL DOCREABY
            RET  C
            CP   9
            JR   Z,DISTAB
            CALL RENCEL
            JR   DISADV
; EditorDisplayTab
DISTAB:
            LD   HL,(RENCOL)
            CALL NAVNEXTA
            LD   (SCRATCHB),HL
; EditorDisplayTabLoop
DISTABLO:
            LD   A,' '
            CALL RENCEL
            LD   A,(COLUMNS)
            LD   HL,RENCOU
            CP   (HL)
            RET  Z
            LD   HL,(RENCOL)
            LD   DE,(SCRATCHB)
            OR   A
            SBC  HL,DE
            JR   NZ,DISTABLO
; EditorDisplayAdvance
DISADV:
            LD   HL,(RENPOI)
            INC  HL
            LD   (RENPOI),HL
            JR   DISPAILI

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorEnsureViewport
ENSVIE:
            ; A valid viewport already records the cursor's row. Avoid walking
            ; the same row boundaries again through repeated cache lookups.
            LD   HL,(TOP)
            LD   DE,(LAYORITO)
            OR   A
            SBC  HL,DE
            JR   NZ,ENSDIS
            LD   HL,(CURSOR)
            CALL LAYFINLI
            JR   C,ENSDIS
            LD   B,A
            JR   ENSROWRE
; EditorEnsureDiscover
ENSDIS:
            ; Once outside the cached viewport, repeated lookups cannot help
            ; the cold walk. Rebuild after discovery instead of probing each row.
            CALL LAYRES
            LD   HL,(CURSOR)
            CALL NAVLINST
            LD   (SCRATCHA),HL
; EditorEnsureVertical
ENSVER:
            LD   DE,(TOP)
            OR   A
            SBC  HL,DE
            JR   NC,ENSCOURO
            LD   HL,(SCRATCHA)
            LD   (TOP),HL
; EditorEnsureCountRows
ENSCOURO:
            LD   HL,(TOP)
            LD   B,0
; EditorEnsureRowLoop
ENSROWLO:
            LD   DE,(SCRATCHA)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   Z,ENSROWRE
            CALL NAVNEXLI
            JR   C,ENSROWRE
            INC  B
            LD   A,(TEXROWS)
            DEC  A
            CP   B
            JR   NC,ENSROWLO
            LD   HL,(TOP)
            CALL NAVNEXLI
            JR   C,ENSROWRE
            LD   (TOP),HL
            LD   HL,(SCRATCHA)
            JR   ENSVER
; EditorEnsureRowReady
ENSROWRE:
            LD   A,B
            LD   (CURSCRRO),A
            CALL NAVCURCO
            LD   C,A
            LD   A,(COLUMNS)
            LD   E,A
            LD   D,0
            LD   A,C
            OR   A
            JR   NZ,ENSHOR
            PUSH HL
            SBC  HL,DE
            POP  HL
            JR   C,ENSNOHOR
; EditorEnsureHorizontal
ENSHOR:
            ; Keep the cursor in the final column: HOR = column-(width-1).
            DEC  DE
            OR   A
            SBC  HL,DE
            LD   (HOR),HL
            LD   A,C
            SBC  A,0
            LD   (HORHIG),A
            EX   DE,HL
            JR   ENSCOLRE
; EditorEnsureNoHorizontal
ENSNOHOR:
            XOR  A
            LD   (HORHIG),A
            LD   DE,0
            LD   (HOR),DE
; EditorEnsureColumnReady
ENSCOLRE:
            LD   A,L
            LD   (CURSCRCO),A
            CALL LAYTOPUP
            RET

; Render one visual cell in A when it lies in the horizontal viewport.
;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorRenderCell
RENCEL:
            LD   (SCRATCHC),A
            LD   A,(HORHIG)
            LD   D,A
            LD   A,(RENCOLHI)
            CP   D
            JR   C,RENCELAD
            JR   NZ,RENCELVI
            LD   HL,(RENCOL)
            LD   DE,(HOR)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,RENCELAD
; EditorRenderCellVisible
RENCELVI:
            LD   A,(COLUMNS)
            LD   D,A
            LD   A,(RENCOU)
            CP   D
            JR   NC,RENCELAD
            LD   A,(SCRATCHC)
            CALL OUTBYT
            LD   HL,(RENCOU)
            INC  HL
            LD   (RENCOU),HL
; EditorRenderCellAdvance
RENCELAD:
            LD   HL,(RENCOL)
            INC  HL
            LD   (RENCOL),HL
            LD   A,H
            OR   L
            RET  NZ
            LD   A,(RENCOLHI)
            INC  A
            LD   (RENCOLHI),A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorRenderStatus
RENSTA:
            LD   HL,(CURSOR)
            LD   (DISLASCU),HL
            LD   DE,STAPRE
            CALL STABEG
            ; The filename appears without FCB padding, as NAME.EXT or NAME.
            LD   HL,FCB+1
            LD   B,8
            CALL STANAMPA
            LD   A,(FCB+9)
            CP   ' '
            JR   Z,STANAMDO
            LD   A,'.'
            CALL STABYT
            LD   HL,FCB+9
            LD   B,3
            CALL STANAMPA
; EditorStatusNameDone
STANAMDO:
            LD   A,' '
            CALL STABYT
            LD   A,(FLAGS)
            AND  FLADIR
            LD   A,' '
            JR   Z,STADIRRE
            LD   A,'*'
; EditorStatusDirtyReady
STADIRRE:
            CALL STABYT
            LD   A,' '
            CALL STABYT
            LD   A,' '
            CALL STABYT
            CALL STAPOSN
            CALL STAMES
            ; Key hints appear only when they fit in the remaining cells.
            LD   A,(COLUMNS)
            LD   HL,RENCOU
            SUB  (HL)
            CP   STAHINLE
            LD   DE,STAHIN
            CALL NC,STATEX
            JP   STAFIL

; Output the B FCB name bytes at HL, omitting padding spaces.
;@ROUTINE in B,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorStatusNamePart
STANAMPA:
            LD   A,(HL)
            CP   ' '
            JR   Z,STANAMSK
            PUSH HL
            PUSH BC
            CALL STABYT
            POP  BC
            POP  HL
; EditorStatusNameSkip
STANAMSK:
            INC  HL
            DJNZ STANAMPA
            RET

; Compact absolute source position. Line and column are one-based; column is
; the visual column after tab expansion, matching the existing layout model.
; The status row is the only presentation surface; no position is persisted.
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorStatusPositionNumber
STAPOSN:
            LD   A,'L'
            CALL STABYT
            LD   HL,(LAYTOPLI)
            LD   A,(CURSCRRO)
            LD   E,A
            LD   D,0
            ADD  HL,DE
            INC  HL
            XOR  A
            CALL STADEC24
            LD   A,' '
            CALL STABYT
            LD   A,'C'
            CALL STABYT
            LD   HL,(LAYCOL)
            INC  HL
            LD   A,H
            OR   L
            LD   A,(LAYCOL+2)
            JR   NZ,STAPOSC
            INC  A
; EditorStatusPositionColumn
STAPOSC:
            JP   STADEC24

; Output an unsigned 24-bit value in decimal without leading zeroes. The
; final units place is forced, so zero is rendered as "0". SCRATCHA/B hold
; the remaining low word/high byte and SCRATCHC+1 is the started flag.
;@ROUTINE in A,HL out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
; EditorStatusDecimal24
STADEC24:
            LD   (SCRATCHA),HL
            LD   (SCRATCHB),A
            XOR  A
            LD   (SCRATCHC+1),A
            LD   C,1
            LD   DE,34464
            CALL STADECPL
            LD   C,0
            LD   DE,10000
            CALL STADECPL
            LD   C,0
            LD   DE,1000
            CALL STADECPL
            LD   C,0
            LD   DE,100
            CALL STADECPL
            LD   C,0
            LD   DE,10
            CALL STADECPL
            LD   A,1
            LD   (SCRATCHC+1),A
            LD   C,0
            LD   DE,1
; EditorStatusDecimalPlace
STADECPL:
            LD   B,0
; EditorStatusDecimalSubtract
STADECLO:
            LD   A,(SCRATCHB)
            LD   HL,(SCRATCHA)
            OR   A
            SBC  HL,DE
            SBC  A,C
            JR   C,STADECDI
            INC  B
            LD   (SCRATCHA),HL
            LD   (SCRATCHB),A
            JR   STADECLO
; EditorStatusDecimalDigit
STADECDI:
            LD   A,B
            OR   A
            JR   NZ,STADECOU
            LD   A,(SCRATCHC+1)
            OR   A
            RET  Z
; EditorStatusDecimalOutput
STADECOU:
            LD   A,B
            ADD  A,'0'
            CALL STABYT
            LD   A,1
            LD   (SCRATCHC+1),A
            RET
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorStatusFill
STAFIL:
            LD   A,(COLUMNS)
            LD   HL,RENCOU
            CP   (HL)
            JR   Z,STAFIL1
            LD   A,' '
            CALL STABYT
            JR   STAFIL
; EditorStatusFilled
STAFIL1:
            LD   DE,REVOFF
            CALL OUTTEX
            JP   POSCUR

;@ROUTINE in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorStatusBegin
STABEG:
            PUSH DE
            LD   DE,CURPRE
            CALL OUTTEX
            LD   A,(TEXROWS)
            INC  A
            CALL OUTDEC
            LD   DE,STAPOS
            CALL OUTTEX
            LD   HL,0
            LD   (RENCOU),HL
            POP  DE
            JP   STATEX

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorStatusMessage
STAMES:
            LD   A,(STATUS)
            OR   A
            RET  Z
            ADD  A,A
            JR   C,STASEAME
            CP   STASAV*2
            LD   DE,STASAVTE
            JR   Z,STAMESTE
            CP   STAFUL*2
            LD   DE,STAFULTE
            JR   Z,STAMESTE
            CP   STADIS*2
            LD   DE,STADISTE
            JR   Z,STAMESTE
            CP   STASAVCO*2
            JR   C,STAMESDO
            LD   DE,STASAVFA
            CALL STASEPTE
            LD   A,(STATUS)
            OR   A
            PUSH AF
            RRCA
            RRCA
            RRCA
            RRCA
            CALL STAHEXNI
            POP  AF
            CALL STAHEXNI
; EditorStatusMessageDone
STAMESDO:
            RET
; EditorStatusMessageText
STAMESTE:
            JR   STASEPTE
; EditorStatusSearchMessage
STASEAME:
            LD   E,A
            LD   D,0
            LD   HL,STAFOUTE
            ADD  HL,DE
            EX   DE,HL

; Two separator cells after the position, then the text at DE.
;@ROUTINE in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorStatusSeparatedText
STASEPTE:
            PUSH DE
            LD   A,' '
            CALL STABYT
            LD   A,' '
            CALL STABYT
            POP  DE
            JR   STATEX

;@ROUTINE in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorStatusText
STATEX:
            LD   A,(DE)
            OR   A
            RET  Z
            INC  DE
            PUSH DE
            CALL STABYT
            POP  DE
            JR   STATEX

; Output one status cell in A. Cells beyond the screen width are dropped.
;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorStatusByte
STABYT:
            LD   C,A
            LD   A,(COLUMNS)
            LD   HL,RENCOU
            CP   (HL)
            RET  Z
            INC  (HL)
            LD   A,C
            JP   OUTBYT

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorStatusHexNibble
STAHEXNI:
            AND  $0F
            ADD  A,'0'
            CP   '9'+1
            JR   C,STABYT
            ADD  A,7
            JR   STABYT

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorPositionCursor
POSCUR:
            LD   A,(CURSCRRO)
            INC  A
            LD   (SCRATCHA),A
            LD   A,(CURSCRCO)
            INC  A
            LD   (SCRATCHA+1),A
            LD   A,(SCRATCHA)
            CALL OUTDEC
            LD   A,';'
            CALL OUTBYT
            LD   A,(SCRATCHA+1)
            CALL OUTDEC
            LD   A,'H'
            JR   OUTBYT

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorOutputDecimal
OUTDEC:
            LD   B,0
; EditorOutputDecimalLoop
OUTDECLO:
            CP   10
            JR   C,OUTDECRE
            SUB  10
            INC  B
            JR   OUTDECLO
; EditorOutputDecimalReady
OUTDECRE:
            LD   (SCRATCHC),A
            LD   A,B
            OR   A
            JR   Z,OUTDECON
            ADD  A,'0'
            CALL OUTBYT
; EditorOutputDecimalOnes
OUTDECON:
            LD   A,(SCRATCHC)
            ADD  A,'0'
            JR   OUTBYT

;@ROUTINE in A out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
; EditorOutputByte
OUTBYT:
            LD   E,A
            LD   C,6
            JP   CALLBDOS

;@ROUTINE in DE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
; EditorOutputText
OUTTEX:
            LD   A,(DE)
            CP   '$'
            RET  Z
            INC  DE
            PUSH DE
            CALL OUTBYT
            POP  DE
            JR   OUTTEX

; EditorScreenCodeEnd
SCRCODEN:
