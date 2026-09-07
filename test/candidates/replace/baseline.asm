; Native ATOM historical experiment: replace/baseline
; Historical debugger names are recorded in baseline.asm.symbols.json.
; Frozen production editor before literal replacement.

CANDIDAT EQU 1
CANDIDA1 EQU 0

; Complete production editor boundary with only the replacement experiment
; substituted. Unrelated modules use the frozen pre-engine production snapshot.

; Fixed memory partition for the native CP/M editor.

EDITORCO EQU $0100
EDITORC3 EQU $1E00
EDITORWO EQU $1E00
EDITORW2 EQU $2000
EDITORT1 EQU $2000
EDITORT3 EQU $D800
EDITORT2 EQU EDITORT3-EDITORT1
EDITOR1Y EQU $D800
EDITOR1Z EQU $E400

EDITORFC EQU EDITORWO
EDITORT4 EQU EDITORFC+36
EDITORDM EQU EDITORT4+36

EDITORLE EQU EDITORDM+128
EDITOR17 EQU EDITORLE+2
EDITORTO EQU EDITOR17+2
EDITORHO EQU EDITORTO+2
EDITORD1 EQU EDITORHO+2
EDITORF4 EQU EDITORD1+2
EDITOR20 EQU EDITORF4+1
; Loading and interactive search never overlap. A successful load has already
; reduced the pending-CR state to zero, which also resets the committed query.
EDITORL9 EQU EDITOR20+1
EDITORQ2 EQU EDITORL9
EDITORQU EQU EDITORQ2+1
EDITORQ1 EQU 64
EDITORSN EQU EDITORQU+EDITORQ1
EDITORSS EQU EDITORSN+1
EDITORST EQU EDITORSS+2
EDITORSU EQU EDITORST+2
EDITORRG EQU EDITORSU+2
EDITORR6 EQU EDITORRG+2
EDITORR7 EQU EDITORR6+2
EDITOR19 EQU EDITORR7+2
EDITOR18 EQU EDITOR19+1
EDITORW1 EQU EDITOR18+1

EDITORF2 EQU 1
EDITORFL EQU 2
EDITORF1 EQU 4
EDITORF3 EQU $80

EDITOR2Q EQU 0
EDITOR2V EQU 1
EDITOR2C EQU 2
EDITOR22 EQU 3
EDITOR25 EQU 4
; Search statuses carry a high-bit tag and half the byte offset of their
; contiguous message. ADD A,A both classifies the tag and recovers the offset.
EDITOR2A EQU $80
EDITOR33 EQU $83
EDITOR2M EQU $87
EDITOR2K EQU $8C
EDITOR2R EQU $91
EDITOR2T EQU $10
EDITOR2U EQU $11
EDITOR30 EQU $12
EDITOR2S EQU $13
EDITOR2Y EQU $14
EDITOR2Z EQU $15

EDITORE8 EQU 1
EDITORE9 EQU 2
EDITOREC EQU 3
EDITORER EQU 4
EDITOREB EQU 5



CANDIDA2 EQU EDITORW1












            ORG EDITORCO
EDITORT5:
            JP   EDITORE7

EDITORC4:
; CP/M BDOS and FCB helpers. IX and IY are not standardized by CP/M, so the
; wrapper preserves both around every guest operating-system call.

CpmBdos EQU $0005

EDITORB1:
;@ROUTINE in C,DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORCA:
            PUSH IX
            PUSH IY
            CALL CpmBdos
            POP  IY
            POP  IX
            RET

;@ROUTINE in DE,HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
EDITORBK:
            LD   BC,12
            LDIR
            XOR  A
            LD   B,24
EDITORCL:
            LD   (DE),A
            INC  DE
            DJNZ EDITORCL
            RET

;@ROUTINE in DE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITOR1X:
            LD   C,26
            JR   EDITORCA

;@ROUTINE in C out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORTR:
            LD   DE,EDITORT4
            JR   EDITORCA

;@ROUTINE in C out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITOR1W:
            LD   DE,EDITORFC
            JR   EDITORCA
EDITORBD:

; Command-tail parser for EDIT and EDIT NAME.EXT.

EDITORCK EQU $0080
EDITOR14 EQU $0081

EDITORC7:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
EDITORPR:
            LD   HL,EDITORDE
            LD   DE,EDITORFC
            CALL EDITORBK
            LD   (EDITORSN),A
            LD   A,(EDITORCK)
            LD   B,A
            LD   HL,EDITOR14
            CALL EDITOR13
            JR   Z,EDITORCX
            LD   (EDITORSN),A
            PUSH HL
            LD   C,B
            PUSH BC
            XOR  A
            LD   (EDITORFC),A
            LD   HL,EDITORFC+1
            LD   DE,EDITORFC+2
            LD   BC,10
            LD   (HL),' '
            LDIR
            POP  BC
            POP  HL
            CALL EDITORCV
            JR   C,EDITORCJ
            CALL EDITOR13
            JR   NZ,EDITORCJ
EDITORCX:
            LD   HL,EDITORFC+9
            LD   DE,EDITORBA
            CALL EDITORCE
            JR   Z,EDITORCJ
            LD   HL,EDITORFC+9
            LD   DE,EDITORTE
            CALL EDITORCE
            JR   Z,EDITORCJ
            XOR  A
            RET
EDITORCJ:
            LD   A,EDITORE8
            SCF
            RET

;@ROUTINE in B,HL out A,B,HL,zero clobbers carry,sign,parity,halfCarry
EDITOR13:
            LD   A,B
            OR   A
            RET  Z
            LD   A,(HL)
            CP   ' '
            RET  NZ
            INC  HL
            DEC  B
            JR   EDITOR13

;@ROUTINE in B,HL out A,B,HL,carry,zero clobbers sign,parity,halfCarry,C,D,IX
EDITORCV:
            LD   IX,EDITORFC+1
            LD   D,8
            LD   C,0
EDITORCN:
            LD   A,B
            OR   A
            JR   Z,EDITORCR
            LD   A,(HL)
            CP   ' '
            JR   Z,EDITORCR
            CP   '.'
            JR   NZ,EDITORCQ
            LD   A,D
            CP   8
            JR   NZ,EDITORCM
            LD   A,C
            OR   A
            JR   Z,EDITORCM
            LD   IX,EDITORFC+9
            LD   D,3
            LD   C,0
            JR   EDITORCT
EDITORCQ:
            CP   'a'
            JR   C,EDITORCP
            CP   'z'+1
            JR   NC,EDITORCP
            AND  $DF
EDITORCP:
            CP   '!'
            JR   C,EDITORCM
            CP   $7F
            JR   NC,EDITORCM
            CP   '*'
            JR   C,EDITORCG
            CP   '-'
            JR   C,EDITORCM
            CP   '/'
            JR   Z,EDITORCM
            CP   ':'
            JR   C,EDITORCG
            CP   '@'
            JR   C,EDITORCM
EDITORCG:
            CP   '['
            JR   C,EDITORCH
            CP   '^'
            JR   C,EDITORCM
            CP   '_'
            JR   Z,EDITORCM
EDITORCH:
            OR   A
            INC  C
            PUSH AF
            LD   A,D
            CP   C
            JR   C,EDITORCS
            POP  AF
            LD   (IX+0),A
            INC  IX
EDITORCT:
            INC  HL
            DEC  B
            JR   EDITORCN
EDITORCR:
            LD   A,C
            OR   A
            JR   Z,EDITORCM
            RET
EDITORCS:
            POP  AF
EDITORCM:
            SCF
            RET

;@ROUTINE in DE,HL out A,zero clobbers carry,sign,parity,halfCarry,B,DE,HL
EDITORCE:
            LD   B,3
EDITORCF:
            LD   A,(DE)
            CP   (HL)
            RET  NZ
            INC  DE
            INC  HL
            DJNZ EDITORCF
            XOR  A
            RET
EDITORC6:

; Sequential text-file loader and validator.

EDITORL6:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORL7:
            XOR  A
            LD   (EDITORL9),A
            LD   HL,0
            LD   (EDITORLE),HL
            LD   C,15
            CALL EDITOR1W
            INC  A
            JR   Z,EDITORL8
            LD   DE,EDITORDM
            CALL EDITOR1X
EDITORLB:
            LD   C,20
            CALL EDITOR1W
            OR   A
            JR   Z,EDITORLD
            DEC  A
            JR   Z,EDITORLA
            JR   EDITORLF
EDITORLD:
            LD   HL,EDITORDM
            LD   B,128
EDITORL2:
            LD   A,(HL)
            CP   $1A
            JR   Z,EDITORLG
            CALL EDITORLJ
            JR   C,EDITORLH
            PUSH HL
            CALL EDITORLO
            POP  HL
            JR   C,EDITORL3
            INC  HL
            DJNZ EDITORL2
            JR   EDITORLB
EDITORLG:
            LD   A,(EDITORL9)
            OR   A
            JR   NZ,EDITORLH
            JR   EDITORL4
EDITORLA:
            LD   A,(EDITORL9)
            OR   A
            JR   NZ,EDITORLH
EDITORL4:
            LD   C,16
            CALL EDITOR1W
            INC  A
            JR   Z,EDITORLF
            XOR  A
EDITORLC:
            LD   HL,0
            LD   (EDITOR17),HL
            LD   (EDITORTO),HL
            LD   (EDITORHO),HL
            LD   (EDITORD1),HL
            LD   L,A
            LD   (EDITORF4),HL
            RET
EDITORL8:
            LD   A,(EDITORSN)
            OR   A
            CCF
            LD   A,EDITORE9
            RET  Z
            LD   A,EDITORF2|EDITORF3
            OR   A
            JR   EDITORLC
EDITORLH:
            LD   A,EDITOREC
            SCF
            RET
EDITORL3:
            LD   A,EDITORER
            SCF
            RET
EDITORLF:
            LD   A,EDITOREB
            SCF
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,C
EDITORLJ:
            LD   C,A
            LD   A,(EDITORL9)
            OR   A
            JR   Z,EDITORLM
            LD   A,C
            CP   10
            JR   NZ,EDITORLI
            XOR  A
            LD   (EDITORL9),A
            LD   A,C
            RET
EDITORLM:
            LD   A,C
            CP   13
            JR   Z,EDITORLK
            CP   9
            JR   Z,EDITORLL
            CP   10
            JR   Z,EDITORLL
            CP   32
            JR   C,EDITORLI
            CP   127
            JR   NC,EDITORLI
EDITORLL:
            OR   A
            RET
EDITORLK:
            LD   A,1
            LD   (EDITORL9),A
            LD   A,C
            OR   A
            RET
EDITORLI:
            LD   A,C
            SCF
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
EDITORLO:
            LD   DE,(EDITORLE)
            LD   HL,EDITORT2
            OR   A
            SBC  HL,DE
            JR   Z,EDITORL1
            LD   HL,EDITORT1
            ADD  HL,DE
            LD   (HL),A
            INC  DE
            LD   (EDITORLE),DE
            OR   A
            RET
EDITORL1:
            SCF
            RET
EDITORL5:

; Contiguous text editing primitives. Cursor and length are logical offsets.

EDITORB8:
;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORBH:
            LD   (EDITORSU),A
            LD   A,1
            CALL EDITORBJ
            RET  C
            LD   A,(EDITORSU)
            LD   (HL),A
            LD   HL,(EDITOR17)
            INC  HL
            LD   (EDITOR17),HL
            JP   EDITORB6

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORBI:
            LD   A,2
            CALL EDITORBJ
            RET  C
            LD   (HL),13
            INC  HL
            LD   (HL),10
            LD   HL,(EDITOR17)
            INC  HL
            INC  HL
            LD   (EDITOR17),HL
            JP   EDITORB6

; Open A bytes at the cursor and return their first address in HL. The buffer
; and all state remain unchanged on capacity failure.
;@ROUTINE in A out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
EDITORBJ:
            LD   L,A
            LD   H,0
            LD   (EDITORSS),HL
            LD   DE,(EDITORLE)
            LD   HL,EDITORT2
            OR   A
            SBC  HL,DE
            LD   DE,(EDITORSS)
            OR   A
            SBC  HL,DE
            JR   C,EDITORBF
            LD   HL,(EDITORLE)
            LD   DE,(EDITOR17)
            OR   A
            SBC  HL,DE
            LD   B,H
            LD   C,L
            LD   HL,(EDITORLE)
            LD   DE,EDITORT1
            ADD  HL,DE
            DEC  HL
            PUSH HL
            LD   DE,(EDITORSS)
            ADD  HL,DE
            LD   D,H
            LD   E,L
            POP  HL
            LD   A,B
            OR   C
            JR   Z,EDITORBG
            LDDR
EDITORBG:
            LD   HL,(EDITORLE)
            LD   DE,(EDITORSS)
            ADD  HL,DE
            LD   (EDITORLE),HL
            LD   HL,(EDITOR17)
            LD   DE,EDITORT1
            ADD  HL,DE
            OR   A
            RET
EDITORBF:
            LD   A,EDITOR2C
            LD   (EDITOR20),A
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORBU:
            LD   HL,(EDITOR17)
            LD   A,H
            OR   L
            JP   Z,EDITORB3
            DEC  HL
            LD   DE,EDITORT1
            ADD  HL,DE
            LD   A,(HL)
            CP   10
            JR   NZ,EDITORB2
            LD   HL,(EDITOR17)
            DEC  HL
            LD   A,H
            OR   L
            JR   Z,EDITORB2
            DEC  HL
            LD   DE,EDITORT1
            ADD  HL,DE
            LD   A,(HL)
            CP   13
            JR   NZ,EDITORB2
            LD   HL,(EDITOR17)
            DEC  HL
            DEC  HL
            LD   (EDITOR17),HL
            LD   A,2
            JR   EDITORBE
EDITORB2:
            LD   HL,(EDITOR17)
            DEC  HL
            LD   (EDITOR17),HL
            LD   A,1
            JR   EDITORBE

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORB9:
            LD   HL,(EDITOR17)
            LD   DE,(EDITORLE)
            OR   A
            SBC  HL,DE
            JR   Z,EDITORB3
            ADD  HL,DE
            LD   DE,EDITORT1
            ADD  HL,DE
            LD   A,(HL)
            CP   13
            JR   NZ,EDITORBB
            INC  HL
            LD   A,(HL)
            CP   10
            JR   NZ,EDITORBB
            LD   A,2
            JR   EDITORBE
EDITORBB:
            LD   A,1

; Delete A bytes beginning at the current cursor.
;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORBE:
            LD   L,A
            LD   H,0
            LD   (EDITORSS),HL
            LD   HL,(EDITORLE)
            LD   DE,(EDITOR17)
            OR   A
            SBC  HL,DE
            LD   DE,(EDITORSS)
            OR   A
            SBC  HL,DE
            LD   B,H
            LD   C,L
            LD   HL,(EDITOR17)
            LD   DE,EDITORT1
            ADD  HL,DE
            LD   D,H
            LD   E,L
            LD   HL,(EDITORSS)
            ADD  HL,DE
            LD   A,B
            OR   C
            JR   Z,EDITORBC
            LDIR
EDITORBC:
            LD   HL,(EDITORLE)
            LD   DE,(EDITORSS)
            OR   A
            SBC  HL,DE
            LD   (EDITORLE),HL
            JR   EDITORB6

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
EDITORB6:
            LD   HL,EDITORF4
            SET  0,(HL)
            XOR  A
            LD   (EDITOR20),A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry
EDITORB3:
            LD   A,EDITOR22
            LD   (EDITOR20),A
            SCF
            RET

;@ROUTINE in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
EDITORB4:
            LD   DE,(EDITORLE)
            OR   A
            SBC  HL,DE
            JR   NC,EDITORB5
            ADD  HL,DE
            LD   DE,EDITORT1
            ADD  HL,DE
            LD   A,(HL)
            OR   A
            RET
EDITORB5:
            SCF
            RET
EDITORB7:

; Logical-character movement and visual-column mapping.

EDITORN1:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
EDITORM3:
            LD   HL,(EDITOR17)
            LD   A,H
            OR   L
            JR   Z,EDITORB3
            DEC  HL
            PUSH HL
            CALL EDITORB4
            POP  HL
            CP   10
            JR   NZ,EDITORM4
            LD   A,H
            OR   L
            JR   Z,EDITORM4
            DEC  HL
            PUSH HL
            CALL EDITORB4
            POP  HL
            CP   13
            JR   Z,EDITORM4
            INC  HL
EDITORM4:
            LD   (EDITOR17),HL
            JR   EDITORN7

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
EDITORM5:
            LD   HL,(EDITOR17)
            PUSH HL
            CALL EDITORB4
            POP  HL
            JR   C,EDITORB3
            INC  HL
            CP   13
            JR   NZ,EDITORM6
            INC  HL
EDITORM6:
            LD   (EDITOR17),HL
EDITORN7:
            LD   A,(EDITORF4)
            AND  $F9
            LD   (EDITORF4),A
            XOR  A
            LD   (EDITOR20),A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORM7:
            CALL EDITORNJ
            LD   HL,(EDITOR17)
            CALL EDITORN8
            LD   A,H
            OR   L
            JR   Z,EDITORB3
            DEC  HL
            CALL EDITORN8
            LD   DE,(EDITORD1)
            CALL EDITORNF
            LD   (EDITOR17),HL
            XOR  A
            LD   (EDITOR20),A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORMO:
            CALL EDITORNJ
            LD   HL,(EDITOR17)
            CALL EDITORN8
            CALL EDITORNC
            JP   C,EDITORB3
            LD   DE,(EDITORD1)
            CALL EDITORNF
            LD   (EDITOR17),HL
            XOR  A
            LD   (EDITOR20),A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORNJ:
            LD   A,(EDITORF4)
            AND  EDITORF1
            JR   NZ,EDITORNK
            CALL EDITORN6
            LD   (EDITORD1),HL
            LD   A,(EDITORF4)
            OR   EDITORF1
            LD   (EDITORF4),A
EDITORNK:
            LD   A,(EDITORF4)
            AND  $FD
            LD   (EDITORF4),A
            RET

;@ROUTINE in HL out HL,carry,zero clobbers sign,parity,halfCarry,A,DE
EDITORN8:
            LD   A,H
            OR   L
            RET  Z
EDITORNB:
            DEC  HL
            PUSH HL
            CALL EDITORB4
            POP  HL
            CP   10
            JR   NZ,EDITORN9
            INC  HL
            RET
EDITORN9:
            LD   A,H
            OR   L
            JR   NZ,EDITORNB
            RET

;@ROUTINE in HL out HL,carry,zero clobbers sign,parity,halfCarry,A,DE
EDITORNC:
            PUSH HL
            CALL EDITORB4
            POP  HL
            RET  C
            INC  HL
            CP   10
            JR   NZ,EDITORNC
            OR   A
            RET

;@ROUTINE out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
EDITORN6:
            LD   HL,(EDITOR17)
            LD   (EDITORSS),HL
            CALL EDITORN8
            LD   DE,0
EDITORN3:
            PUSH HL
            LD   BC,(EDITORSS)
            OR   A
            SBC  HL,BC
            POP  HL
            JR   Z,EDITORN2
            PUSH HL
            PUSH DE
            CALL EDITORB4
            POP  DE
            POP  HL
            JR   C,EDITORN2
            CP   9
            JR   Z,EDITORN5
            INC  DE
            JR   EDITORN4
EDITORN5:
            EX   DE,HL
            CALL EDITORND
            EX   DE,HL
EDITORN4:
            INC  HL
            JR   EDITORN3
EDITORN2:
            EX   DE,HL
            OR   A
            RET

;@ROUTINE in HL out HL,carry,zero clobbers sign,parity,halfCarry,A
EDITORND:
            LD   A,L
            OR   7
            INC  A
            LD   L,A
            RET  NZ
            INC  H
            RET

; Return the insertion offset on the line beginning at HL whose visual column
; is nearest to, but does not exceed, DE.
;@ROUTINE in DE,HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
EDITORNF:
            LD   (EDITORSS),DE
            LD   BC,0
EDITORNG:
            LD   (EDITORSU),HL
            PUSH HL
            CALL EDITORB4
            POP  HL
            RET  C
            CP   10
            RET  Z
            CP   13
            RET  Z
            CP   9
            JR   Z,EDITORNH
            INC  BC
            JR   EDITORNE
EDITORNH:
            LD   H,B
            LD   L,C
            CALL EDITORND
            LD   B,H
            LD   C,L
EDITORNE:
            LD   H,B
            LD   L,C
            LD   DE,(EDITORSS)
            OR   A
            SBC  HL,DE
            JR   C,EDITORNI
            JR   Z,EDITORNI
            LD   HL,(EDITORSU)
            RET
EDITORNI:
            LD   HL,(EDITORSU)
            INC  HL
            JR   EDITORNG
EDITORNA:

; Full repaint for the 80-by-24 terminal profile.

EDITORSW:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORR3:
            CALL EDITORE6
            LD   DE,EDITORC1
            CALL EDITORO5
            LD   HL,(EDITORTO)
            LD   B,23
EDITORRL:
            PUSH BC
            CALL EDITORR8
            LD   (EDITORRG),HL
            LD   A,13
            CALL EDITOROU
            LD   A,10
            CALL EDITOROU
            LD   HL,(EDITORRG)
            POP  BC
            DJNZ EDITORRL
            JP   EDITORRM

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORE6:
            LD   HL,(EDITOR17)
            CALL EDITORN8
            LD   (EDITORSS),HL
EDITORE5:
            LD   DE,(EDITORTO)
            OR   A
            SBC  HL,DE
            JR   NC,EDITORE1
            LD   HL,(EDITORSS)
            LD   (EDITORTO),HL
EDITORE1:
            LD   HL,(EDITORTO)
            LD   B,0
EDITORE3:
            LD   DE,(EDITORSS)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   Z,EDITORE4
            CALL EDITORNC
            JR   C,EDITORE4
            INC  B
            LD   A,B
            CP   23
            JR   C,EDITORE3
            LD   HL,(EDITORTO)
            CALL EDITORNC
            JR   C,EDITORE4
            LD   (EDITORTO),HL
            LD   HL,(EDITORSS)
            JR   EDITORE5
EDITORE4:
            LD   A,B
            LD   (EDITOR19),A
            CALL EDITORN6
            LD   DE,80
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,EDITORE2
            LD   DE,79
            OR   A
            SBC  HL,DE
            LD   (EDITORHO),HL
            LD   HL,79
            JR   EDITOREN
EDITORE2:
            LD   DE,0
            LD   (EDITORHO),DE
EDITOREN:
            LD   A,L
            LD   (EDITOR18),A
            RET

; Render one logical line beginning at HL and return the next line's offset or
; logical EOF. RenderColumn is the source visual column; RenderCount is cells.
;@ROUTINE in HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
EDITORR8:
            LD   (EDITORRG),HL
            LD   HL,0
            LD   (EDITORR6),HL
            LD   (EDITORR7),HL
EDITORRC:
            LD   HL,(EDITORRG)
            PUSH HL
            CALL EDITORB4
            POP  HL
            JR   C,EDITORRB
            CP   10
            JR   Z,EDITORRD
            CP   13
            JR   Z,EDITORRA
            CP   9
            JR   Z,EDITORRF
            CALL EDITORR4
            JR   EDITORR9
EDITORRF:
            LD   HL,(EDITORR6)
            CALL EDITORND
            LD   (EDITORST),HL
EDITORRN:
            LD   A,' '
            CALL EDITORR4
            LD   HL,(EDITORR6)
            LD   DE,(EDITORST)
            OR   A
            SBC  HL,DE
            JR   NZ,EDITORRN
EDITORR9:
            LD   HL,(EDITORRG)
            INC  HL
            LD   (EDITORRG),HL
            JR   EDITORRC
EDITORRA:
            INC  HL
            LD   (EDITORRG),HL
            PUSH HL
            CALL EDITORB4
            POP  HL
            JR   C,EDITORRB
            CP   10
            JR   NZ,EDITORRB
EDITORRD:
            INC  HL
            LD   (EDITORRG),HL
EDITORRB:
            LD   HL,(EDITORRG)
            RET

; Render one visual cell in A when it lies in the horizontal viewport.
;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORR4:
            LD   (EDITORSU),A
            LD   HL,(EDITORR6)
            LD   DE,(EDITORHO)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,EDITORR5
            LD   DE,(EDITORR7)
            LD   A,E
            CP   80
            JR   NC,EDITORR5
            LD   A,(EDITORSU)
            CALL EDITOROU
            LD   HL,(EDITORR7)
            INC  HL
            LD   (EDITORR7),HL
EDITORR5:
            LD   HL,(EDITORR6)
            INC  HL
            LD   (EDITORR6),HL
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORRM:
            LD   DE,EDITOR2P
            CALL EDITOR21
            LD   HL,EDITORFC+1
            LD   B,8
EDITOR2J:
            LD   A,(HL)
            PUSH HL
            PUSH BC
            CALL EDITOR23
            POP  BC
            POP  HL
            INC  HL
            DJNZ EDITOR2J
            LD   A,'.'
            CALL EDITOR23
            LD   HL,EDITORFC+9
            LD   B,3
EDITOR27:
            LD   A,(HL)
            PUSH HL
            PUSH BC
            CALL EDITOR23
            POP  BC
            POP  HL
            INC  HL
            DJNZ EDITOR27
            LD   A,' '
            CALL EDITOR23
            LD   A,(EDITORF4)
            AND  EDITORF2
            LD   A,' '
            JR   Z,EDITOR24
            LD   A,'*'
EDITOR24:
            CALL EDITOR23
            LD   A,' '
            CALL EDITOR23
            LD   A,' '
            CALL EDITOR23
            CALL EDITOR2G
            LD   DE,EDITOR2F
            CALL EDITOR32
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR28:
            LD   HL,(EDITORR7)
            LD   A,L
            CP   80
            JR   NC,EDITOR29
            LD   A,' '
            CALL EDITOR23
            JR   EDITOR28
EDITOR29:
            LD   DE,EDITORRQ
            CALL EDITORO5
            JP   EDITORPO

;@ROUTINE in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR21:
            PUSH DE
            LD   DE,EDITOR2O
            CALL EDITORO5
            LD   HL,0
            LD   (EDITORR7),HL
            POP  DE
            JP   EDITOR32

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR2G:
            LD   A,(EDITOR20)
            OR   A
            RET  Z
            ADD  A,A
            JR   C,EDITOR31
            CP   EDITOR2V*2
            LD   DE,EDITOR2W
            JR   Z,EDITOR2I
            CP   EDITOR2C*2
            LD   DE,EDITOR2D
            JR   Z,EDITOR2I
            CP   EDITOR25*2
            LD   DE,EDITOR26
            JR   Z,EDITOR2I
            CP   EDITOR2T*2
            JR   C,EDITOR2H
            LD   DE,EDITOR2X
            CALL EDITOR32
            LD   A,(EDITOR20)
            OR   A
            PUSH AF
            RRCA
            RRCA
            RRCA
            RRCA
            CALL EDITOR2E
            POP  AF
            CALL EDITOR2E
EDITOR2H:
            RET
EDITOR2I:
            JR   EDITOR32
EDITOR31:
            LD   E,A
            LD   D,0
            LD   HL,EDITOR2B
            ADD  HL,DE
            EX   DE,HL
            JR   EDITOR32

;@ROUTINE in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR32:
            LD   A,(DE)
            OR   A
            RET  Z
            INC  DE
            PUSH DE
            CALL EDITOR23
            POP  DE
            JR   EDITOR32

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR23:
            CALL EDITOROU
            LD   HL,(EDITORR7)
            INC  HL
            LD   (EDITORR7),HL
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR2E:
            AND  $0F
            ADD  A,'0'
            CP   '9'+1
            JR   C,EDITOR23
            ADD  A,7
            JR   EDITOR23

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORPO:
            LD   A,(EDITOR19)
            INC  A
            LD   (EDITORSS),A
            LD   A,(EDITOR18)
            INC  A
            LD   (EDITORSS+1),A
            LD   A,(EDITORSS)
            CALL EDITORO1
            LD   A,';'
            CALL EDITOROU
            LD   A,(EDITORSS+1)
            CALL EDITORO1
            LD   A,'H'
            JR   EDITOROU

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORO1:
            LD   B,0
EDITORO2:
            CP   10
            JR   C,EDITORO4
            SUB  10
            INC  B
            JR   EDITORO2
EDITORO4:
            LD   (EDITORSU),A
            LD   A,B
            OR   A
            JR   Z,EDITORO3
            ADD  A,'0'
            CALL EDITOROU
EDITORO3:
            LD   A,(EDITORSU)
            ADD  A,'0'
            JR   EDITOROU

;@ROUTINE in A out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITOROU:
            LD   E,A
            LD   C,6
            JP   EDITORCA

;@ROUTINE in DE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORO5:
            LD   A,(DE)
            CP   '$'
            RET  Z
            INC  DE
            PUSH DE
            CALL EDITOROU
            POP  DE
            JR   EDITORO5

EDITORSV:

; Recoverable save using NAME.$$$ and NAME.BAK.

EDITORS5:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSA:
            XOR  A
            LD   (EDITORSN),A
            CALL EDITORSM
            CALL EDITORSG
            JR   C,EDITORS6
            CALL EDITORSK
            CALL EDITORSG
            JR   NC,EDITORSD
EDITORS6:
            LD   A,EDITOR2T
            JP   EDITORS9
EDITORSD:
            CALL EDITORSM
            LD   C,22
            CALL EDITORTR
            INC  A
            JR   Z,EDITORS8
            LD   A,1
            LD   (EDITORSN),A
            CALL EDITORSP
            JR   C,EDITORSQ
            LD   C,16
            CALL EDITORTR
            INC  A
            JR   Z,EDITORS3
            LD   A,(EDITORF4)
            RLCA
            JR   C,EDITORSB
            CALL EDITORS7
            LD   HL,EDITORT4
            CALL EDITORS2
            LD   HL,$4142
            LD   (EDITORT4+25),HL
            LD   A,'K'
            LD   (EDITORT4+27),A
            LD   C,23
            CALL EDITORTR
            INC  A
            JR   Z,EDITORSF
            LD   A,3
            LD   (EDITORSN),A
EDITORSB:
            CALL EDITORSM
            LD   HL,EDITORFC
            CALL EDITORS2
            LD   C,23
            CALL EDITORTR
            INC  A
            JR   Z,EDITORSF
            LD   A,(EDITORSN)
            DEC  A
            JR   Z,EDITORSO
            LD   A,7
            LD   (EDITORSN),A
            CALL EDITORSK
            LD   C,19
            CALL EDITORTR
            INC  A
            JR   Z,EDITORSF
EDITORSO:
            XOR  A
            LD   (EDITORSN),A
            LD   A,(EDITORF4)
            AND  $74
            LD   (EDITORF4),A
            LD   A,EDITOR2V
            LD   (EDITOR20),A
            OR   A
            RET
EDITORS8:
            LD   A,EDITOR2U
            JR   EDITORS9
EDITORSQ:
            LD   A,EDITOR30
            JR   EDITORS9
EDITORS3:
            LD   A,EDITOR2S
            JR   EDITORS9
EDITORSF:
            LD   A,EDITOR2Y
EDITORS9:
            LD   (EDITOR20),A
            CALL EDITORSH
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSG:
            LD   C,15
            CALL EDITORTR
            INC  A
            JR   Z,EDITORS1
            SCF
            RET
EDITORS1:
            XOR  A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSP:
            LD   HL,EDITORT1
            LD   (EDITORSS),HL
            LD   HL,(EDITORLE)
            LD   (EDITORST),HL
EDITORSE:
            LD   HL,(EDITORST)
            LD   DE,128
            OR   A
            SBC  HL,DE
            JR   C,EDITORSC
            LD   (EDITORST),HL
            LD   DE,(EDITORSS)
            CALL EDITOR1X
            CALL EDITORSR
            RET  C
            LD   HL,(EDITORSS)
            LD   DE,128
            ADD  HL,DE
            LD   (EDITORSS),HL
            JR   EDITORSE
EDITORSC:
            ADD  HL,DE
            LD   A,H
            OR   L
            RET  Z
            LD   (EDITORST),HL
            LD   HL,EDITORDM
            LD   DE,EDITORDM+1
            LD   BC,127
            LD   (HL),$1A
            LDIR
            LD   HL,(EDITORSS)
            LD   DE,EDITORDM
            LD   BC,(EDITORST)
            LDIR
            LD   DE,EDITORDM
            CALL EDITOR1X
            JR   EDITORSR

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSR:
            LD   C,21
            CALL EDITORTR
            OR   A
            RET  Z
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSH:
            LD   A,(EDITORSN)
            OR   A
            RET  Z
            AND  4
            JR   Z,EDITORSJ
            CALL EDITORS7
            LD   C,19
            CALL EDITORTR
EDITORSJ:
            CALL EDITORSM
            LD   C,16
            CALL EDITORTR
            CALL EDITORSM
            LD   C,19
            CALL EDITORTR
            LD   A,(EDITORSN)
            AND  2
            JR   Z,EDITORSI
            CALL EDITORSK
            LD   HL,EDITORFC
            CALL EDITORS2
            LD   C,23
            CALL EDITORTR
            INC  A
            JR   NZ,EDITORSI
            LD   A,EDITOR2Z
            LD   (EDITOR20),A
EDITORSI:
            XOR  A
            LD   (EDITORSN),A
            RET

;@ROUTINE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORS7:
            LD   HL,EDITORFC
            LD   DE,EDITORT4
            JP   EDITORBK

;@ROUTINE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORSM:
            CALL EDITORS7
            LD   HL,$2424
            LD   A,'$'
            JR   EDITORSL

;@ROUTINE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORSK:
            CALL EDITORS7
            LD   HL,$4142
            LD   A,'K'

;@ROUTINE in A,HL out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORSL:
            LD   (EDITORT4+9),HL
            LD   (EDITORT4+11),A
            RET

;@ROUTINE in HL out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORS2:
            LD   DE,EDITORT4+16
            LD   BC,12
            LDIR
            RET
EDITORS4:


; Bounded forward literal search with one committed query per execution.

EDITOR1D:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSZ:
            LD   HL,EDITORQ2
            LD   DE,EDITORDM
            LD   BC,EDITORQ1+1
            LDIR
EDITOR1R:
            CALL EDITORRH
EDITOR1Q:
            CALL EDITORRE
            CP   27
            JR   Z,EDITOR1A
            CP   13
            JR   Z,EDITORSX
            CP   8
            JR   Z,EDITOR1P
            CP   9
            JR   Z,EDITOR1O
            CP   32
            JR   C,EDITOR1S
            CP   127
            JR   C,EDITOR1O
            JR   Z,EDITOR1P
EDITOR1S:
            LD   A,7
            CALL EDITOROU
            JR   EDITOR1Q
EDITOR1P:
            LD   HL,EDITORQ2
            LD   A,(HL)
            OR   A
            JR   Z,EDITOR1S
            DEC  (HL)
            JR   EDITOR1R
EDITOR1O:
            LD   C,A
            LD   HL,EDITORQ2
            LD   A,(HL)
            CP   EDITORQ1
            JR   NC,EDITOR1S
            INC  (HL)
            INC  HL
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   (HL),C
            JR   EDITOR1R
EDITORSX:
            LD   A,(EDITORQ2)
            OR   A
            JR   NZ,EDITOR1G
EDITOR1A:
            LD   HL,EDITORDM
            LD   DE,EDITORQ2
            LD   BC,EDITORQ1+1
            LDIR
            XOR  A
            LD   (EDITOR20),A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORRH:
            LD   DE,EDITOR1N
            CALL EDITOR21
            LD   A,(EDITORQ2)
            OR   A
            JR   Z,EDITORRJ
            LD   B,A
            LD   HL,EDITORQU
EDITORRK:
            LD   A,(HL)
            CP   9
            JR   NZ,EDITORRI
            LD   A,'>'
EDITORRI:
            PUSH HL
            PUSH BC
            CALL EDITOR23
            POP  BC
            POP  HL
            INC  HL
            DJNZ EDITORRK
EDITORRJ:
            LD   HL,(EDITORR7)
            LD   H,L
            LD   L,23
            LD   (EDITOR19),HL
            JP   EDITOR28

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
EDITOR1G:
            LD   HL,(EDITOR17)
            JR   EDITOR1B

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR1T:
            LD   HL,(EDITOR17)
            INC  HL
EDITOR1B:
            LD   A,(EDITORQ2)
            OR   A
            JR   Z,EDITOR1K

EDITOR1U:
            LD   A,EDITOR2A
            LD   (EDITOR20),A
            LD   DE,(EDITORLE)
            LD   (EDITORSS),DE
            JR   EDITOR1L

EDITORSY:
            LD   HL,(EDITORST)
            INC  HL
            LD   DE,(EDITORLE)
EDITOR1L:
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,EDITOR1V
            SBC  HL,HL
            LD   A,EDITOR33
            LD   (EDITOR20),A
EDITOR1V:
            LD   (EDITORST),HL

EDITOR1H:
            LD   HL,(EDITORSS)
            LD   A,H
            OR   L
            JR   Z,EDITOR1M
            DEC  HL
            LD   (EDITORSS),HL
            LD   HL,(EDITORST)
            PUSH HL
            LD   A,(EDITORQ2)
            LD   B,A
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   DE,(EDITORLE)
            INC  DE
            OR   A
            SBC  HL,DE
            POP  HL
            JR   NC,EDITORSY
EDITOR1I:
            LD   DE,EDITORT1
            ADD  HL,DE
            LD   DE,EDITORQU
EDITOR1J:
            LD   A,(DE)
            CP   (HL)
            JR   NZ,EDITORSY
            INC  DE
            INC  HL
            DJNZ EDITOR1J
EDITOR1F:
            LD   HL,(EDITORST)
            LD   (EDITOR17),HL
            LD   HL,EDITORF4
            RES  2,(HL)
            LD   A,(EDITOR20)
            OR   A
            RET

EDITOR1K:
            LD   A,EDITOR2K
            JR   EDITOR1E
EDITOR1M:
            LD   A,EDITOR2M
EDITOR1E:
            LD   (EDITOR20),A
            SCF
            RET
EDITOR1C:

; Transient entry, raw-key dispatcher, and CCP return.

EDITORM1:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EDITORE7:
            LD   (EDITORRP+1),SP
            LD   SP,EDITOR1Z
            CALL EDITORRU
EDITORRP:
            LD   SP,0
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EDITORRU:
            CALL EDITORPR
            JP   C,EDITORRR
            CALL EDITORL7
            JP   C,EDITORRR
            CALL EDITORR3
EDITORM2:
            CALL EDITORRE
            CP   17
            JP   Z,EDITORCW
            PUSH AF
            LD   A,(EDITORF4)
            AND  $FD
            LD   (EDITORF4),A
            POP  AF
            CP   19
            JR   Z,EDITOR10
            CP   6
            JR   Z,EDITOR11
            CP   14
            JR   Z,EDITOR12
            CP   27
            JR   Z,EDITORCC
            CP   13
            JR   Z,EDITORCU
            CP   8
            JR   Z,EDITORC5
            CP   127
            JR   Z,EDITORC9
            CP   9
            JR   Z,EDITORCI
            CP   32
            JR   C,EDITOR15
            CP   127
            JR   NC,EDITOR15
EDITORCI:
            CALL EDITORBH
            JR   EDITORC8
EDITORCU:
            CALL EDITORBI
            JR   EDITORC8
EDITORC5:
            CALL EDITORBU
            JR   EDITORC8
EDITORC9:
            CALL EDITORB9
            JR   EDITORC8
EDITOR10:
            CALL EDITORSA
            JR   EDITORC8
EDITOR11:
            CALL EDITORSZ
            JR   EDITORC8
EDITOR12:
            CALL EDITOR1T
            JR   EDITORC8
EDITORCC:
            CALL EDITORR1
            JR   C,EDITOR15
            CP   '['
            JR   NZ,EDITOR15
            CALL EDITORR1
            JR   C,EDITOR15
            CP   'A'
            JR   Z,EDITOR16
            CP   'B'
            JR   Z,EDITORCB
            CP   'C'
            JR   Z,EDITORCZ
            CP   'D'
            JR   NZ,EDITOR15
            CALL EDITORM3
            JR   EDITORC8
EDITOR16:
            CALL EDITORM7
            JR   EDITORC8
EDITORCB:
            CALL EDITORMO
            JR   EDITORC8
EDITORCZ:
            CALL EDITORM5
            JR   EDITORC8
EDITOR15:
            CALL EDITORB3
EDITORC8:
            JR   NC,EDITORCY
            LD   A,7
            CALL EDITOROU
EDITORCY:
            CALL EDITORR3
            JP   EDITORM2

EDITORCW:
            LD   A,(EDITORF4)
            AND  EDITORF2
            JR   Z,EDITORCD
            LD   A,(EDITORF4)
            AND  EDITORFL
            JR   NZ,EDITORCD
            LD   A,(EDITORF4)
            OR   EDITORFL
            LD   (EDITORF4),A
            LD   A,EDITOR25
            LD   (EDITOR20),A
            CALL EDITORR3
            JP   EDITORM2
EDITORCD:
            LD   DE,EDITORC1
            JP   EDITORO5

EDITORRR:
            PUSH AF
            LD   DE,EDITOREA
            CALL EDITORO5
            POP  AF
            PUSH AF
            RRCA
            RRCA
            RRCA
            RRCA
            CALL EDITORP1
            POP  AF
            CALL EDITORP1
            LD   DE,EDITORNL
            JP   EDITORO5

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORRE:
            LD   DE,$00FF
            LD   C,6
            CALL EDITORCA
            OR   A
            JR   Z,EDITORRE
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORR1:
            LD   HL,256
            LD   (EDITORSS),HL
EDITORR2:
            LD   DE,$00FF
            LD   C,6
            CALL EDITORCA
            OR   A
            RET  NZ
            LD   HL,(EDITORSS)
            DEC  HL
            LD   (EDITORSS),HL
            LD   A,H
            OR   L
            JR   NZ,EDITORR2
            SCF
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORP1:
            AND  $0F
            ADD  A,'0'
            CP   '9'+1
            JP   C,EDITOROU
            ADD  A,7
            JP   EDITOROU
EDITORMA:
















































































































































































































































































































































































































































































































































































































































EDITORC2:

EDITORI1:
EDITORDE:        DB 0,"INPUT   ","NU "
EDITORBA:    DB "BAK"
EDITORTE: DB "$$$"
EDITOREA:        DB 13,10,"EDIT error ","$"
EDITORNL:            DB 13,10,"$"
EDITORC1:          DB 27,"[2J",27,"[H","$"
EDITOR2O:     DB 27,"[24;1H",27,"[7m","$"
EDITORRQ:         DB 27,"[0m",27,"[","$"
EDITOR2P:       DB "EDIT ",0
EDITOR2F:        DB "  ^S Save  ^Q Quit",0
EDITOR2W:    DB "Saved  ",0
EDITOR2D:     DB "Full  ",0
EDITOR26:  DB "Discard changes? ^Q again  ",0
EDITOR2X: DB "Save failed ",0
EDITOR2B:    DB "Found",0
EDITOR34:  DB "Wrapped",0
EDITOR2N: DB "Not found",0
EDITOR2L: DB "No search",0




EDITOR1N:       DB "Find: ",0




EDITORIM:
EDITORRO:
