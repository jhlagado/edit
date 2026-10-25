; Bounded forward literal search with one committed query per execution.

; EditorSearchCodeStart
SEACODST:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
; EditorSearchBegin
SEABEG:
            LD   HL,QUELEN
            LD   DE,DMA
            LD   BC,QUECAP+1
            LDIR
            LD   HL,QUELEN
            LD   DE,SEAPRO
            CALL LITINP
            JR   C,SEACAN
            LD   A,(QUELEN)
            OR   A
            JP   NZ,SEAACC
; EditorSearchCancel
SEACAN:
            LD   HL,DMA
            LD   DE,QUELEN
            LD   BC,QUECAP+1
            LDIR
; EditorReadyReturn
REARET:
            XOR  A
            LD   (STATUS),A
            RET

; Read one bounded literal into the length byte and contiguous payload at HL.
; DE selects its reverse-video prompt. Escape returns carry set; Return returns
; carry clear. Unsupported controls ring locally and leave the literal intact.
;@ROUTINE in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorLiteralInput
LITINP:
            XOR  A
            LD   (DISSTAVA),A
            LD   (RENPOI),HL
            LD   (RENCOL),DE
; EditorLiteralInputRender
LITINPR1:
            LD   DE,(RENCOL)
            CALL RENLIT
; EditorLiteralInputRead
LITINPRE:
            CALL READBYTE
            CP   27
            JR   Z,LITINPCA
            CP   13
            RET  Z
            CP   8
            JR   Z,LITINPDE
            CP   9
            JR   Z,LITINPAP
            CP   32
            JR   C,LITINPRI
            CP   127
            JR   C,LITINPAP
            JR   Z,LITINPDE
; EditorLiteralInputRing
LITINPRI:
            LD   A,7
            CALL OUTBYT
            JR   LITINPRE
; EditorLiteralInputDelete
LITINPDE:
            LD   HL,(RENPOI)
            LD   A,(HL)
            OR   A
            JR   Z,LITINPRI
            DEC  (HL)
            JR   LITINPR1
; EditorLiteralInputAppend
LITINPAP:
            LD   C,A
            LD   HL,(RENPOI)
            LD   A,(HL)
            CP   QUECAP
            JR   NC,LITINPRI
            INC  (HL)
            INC  HL
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   (HL),C
            JR   LITINPR1
; EditorLiteralInputCancel
LITINPCA:
            SCF
            RET

; EditorSearchAccepted
SEAACC:
            LD   A,OPFIND
            JP   SESEXE

; Render the prompt in DE and the literal's final bytes on the status row. A
; literal wider than the cells after the prompt shows only its tail, so the
; cursor after it stays inside the final column.
;@ROUTINE in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorRenderLiteral
RENLIT:
            CALL STABEG
            LD   HL,(RENPOI)
            LD   B,(HL)
            INC  HL
            LD   A,(COLUMNS)
            DEC  A
            LD   C,A
            LD   A,(RENCOU)
            ADD  A,B
            SUB  C
            JR   C,RENLITVI
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   A,B
            SUB  E
            LD   B,A
; EditorRenderLiteralVisible
RENLITVI:
            LD   A,B
            OR   A
            JR   Z,RENLITFI
; EditorRenderLiteralLoop
RENLITLO:
            LD   A,(HL)
            CP   9
            JR   NZ,RENLITBY
            LD   A,'>'
; EditorRenderLiteralByte
RENLITBY:
            PUSH HL
            PUSH BC
            CALL STABYT
            POP  BC
            POP  HL
            INC  HL
            DJNZ RENLITLO
; EditorRenderLiteralFill
RENLITFI:
            LD   A,(RENCOU)
            LD   H,A
            LD   A,(TEXROWS)
            LD   L,A
            LD   (CURSCRRO),HL
            JP   STAFIL

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
; EditorSearchInitial
SEAINI:
            LD   HL,(CURSOR)
            JR   SEACHEQU

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorSearchRepeat
SEAREP:
            LD   HL,(CURSOR)
            INC  HL
; EditorSearchCheckQuery
SEACHEQU:
            LD   A,(QUELEN)
            OR   A
            JR   Z,SEANOQUE
            LD   C,A

; EditorSearchStart
SEASTA:
            LD   A,STAFOU
            LD   (STATUS),A
            LD   DE,(LENGTH)
            LD   (SCRATCHA),DE
            JR   SEANOR

; EditorSearchAdvance
SEAADV:
            LD   HL,(SCRATCHB)
            INC  HL
            LD   DE,(LENGTH)
; EditorSearchNormalize
SEANOR:
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,SEASTARE
            SBC  HL,HL
            LD   A,STAWRA
            LD   (STATUS),A
; EditorSearchStartReady
SEASTARE:
            LD   (SCRATCHB),HL

; EditorSearchLoop
SEALOO:
            LD   HL,(SCRATCHA)
            LD   A,H
            OR   L
            JR   Z,SEANOTFO
            DEC  HL
            LD   (SCRATCHA),HL
            LD   HL,(SCRATCHB)
            CALL REPMATAT
            JR   NZ,SEAADV
; EditorSearchFound
SEAFOU:
            LD   HL,(SCRATCHB)
            LD   (CURSOR),HL
            LD   HL,FLAGS
            RES  2,(HL)
            LD   A,(STATUS)
            OR   A
            RET

; EditorSearchNoQuery
SEANOQUE:
            LD   A,STANOSEA
            JR   SEAFAI
; EditorSearchNotFound
SEANOTFO:
            LD   A,STANOTFO
; EditorSearchFailure
SEAFAI:
            LD   (STATUS),A
            SCF
            RET
; EditorSearchCodeEnd
SEACODEN:
