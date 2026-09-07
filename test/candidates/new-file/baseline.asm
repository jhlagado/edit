; Native ATOM historical experiment: new-file/baseline
; Historical debugger names are recorded in baseline.asm.symbols.json.
EDITORRP EQU $0000
EDITORRQ EQU $0000
; Frozen 2,840-byte production editor baseline at a3d70577. The current
; production buffer module is byte-identical at its resident boundary.

CANDIDA1 EQU 0
CANDIDA2 EQU 0
CANDIDA3 EQU 0
CANDIDAT EQU 1

; Complete production editor boundary with candidate command, load, and save
; modules. All unrelated modules and immutable bytes come directly from the
; frozen pre-engine production snapshot so historical deltas remain comparable.

; Fixed memory partition for the native CP/M editor.

EDITORCO EQU $0100
EDITORC3 EQU $1E00
EDITORWO EQU $1E00
EDITORW2 EQU $2000
EDITORT1 EQU $2000
EDITORT3 EQU $D800
EDITORT2 EQU EDITORT3-EDITORT1
EDITOR1P EQU $D800
EDITOR1Q EQU $E400

EDITORFC EQU EDITORWO
EDITORT4 EQU EDITORFC+36
EDITORDM EQU EDITORT4+36

EDITORLE EQU EDITORDM+128
EDITOR18 EQU EDITORLE+2
EDITORTO EQU EDITOR18+2
EDITORHO EQU EDITORTO+2
EDITORD1 EQU EDITORHO+2
EDITORF4 EQU EDITORD1+2
EDITOR1R EQU EDITORF4+1
; Loading and interactive search never overlap. A successful load has already
; reduced the pending-CR state to zero, which also resets the committed query.
EDITORLG EQU EDITOR1R+1
EDITORQ2 EQU EDITORLG
EDITORQU EQU EDITORQ2+1
EDITORQ1 EQU 64
EDITORSL EQU EDITORQU+EDITORQ1
EDITORSQ EQU EDITORSL+1
EDITORSR EQU EDITORSQ+2
EDITORSS EQU EDITORSR+2
EDITORRL EQU EDITORSS+2
EDITORR7 EQU EDITORRL+2
EDITORR8 EQU EDITORR7+2
EDITOR1A EQU EDITORR8+2
EDITOR19 EQU EDITOR1A+1
EDITORW1 EQU EDITOR19+1

EDITORF2 EQU 1
EDITORFL EQU 2
EDITORF1 EQU 4
EDITORF3 EQU $80

EDITOR2H EQU 0
EDITOR2M EQU 1
EDITOR23 EQU 2
EDITOR1T EQU 3
EDITOR1W EQU 4
; Search statuses carry a high-bit tag and half the byte offset of their
; contiguous message. ADD A,A both classifies the tag and recovers the offset.
EDITOR21 EQU $80
EDITOR2U EQU $83
EDITOR2D EQU $87
EDITOR2B EQU $8C
EDITOR2I EQU $91
EDITOR2K EQU $10
EDITOR2L EQU $11
EDITOR2R EQU $12
EDITOR2J EQU $13
EDITOR2P EQU $14
EDITOR2Q EQU $15

EDITORE8 EQU 1
EDITORE9 EQU 2
EDITOREC EQU 3
EDITORER EQU 4
EDITOREB EQU 5


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
EDITOR1O:
            LD   C,26
            JR   EDITORCA

;@ROUTINE in C out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORTR:
            LD   DE,EDITORT4
            JR   EDITORCA

;@ROUTINE in C out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITOR1N:
            LD   DE,EDITORFC
            JR   EDITORCA
EDITORBD:

; Candidate command-tail parser. EditorSaveState retains only whether the
; selected name was syntactically explicit until EditorLoadFile consumes it.

EDITORCK EQU $0080
EDITOR15 EQU $0081

EDITORC7:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX
EDITORPR:
            LD   HL,EDITORDE
            LD   DE,EDITORFC
            CALL EDITORBK




            LD   A,(EDITORCK)
            LD   B,A
            LD   HL,EDITOR15
            CALL EDITOR14
            JR   Z,EDITORCX




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
            CALL EDITOR14
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
EDITOR14:
            LD   A,B
            OR   A
            RET  Z
            LD   A,(HL)
            CP   ' '
            RET  NZ
            INC  HL
            DEC  B
            JR   EDITOR14

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

; Candidate sequential loader. Only an explicit missing name becomes a dirty
; empty buffer; malformed or invalid existing files retain production errors.

EDITORLC:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORLD:
            XOR  A
            LD   (EDITORLG),A
            LD   HL,0
            LD   (EDITORLE),HL
            LD   C,15
            CALL EDITOR1N
            INC  A
            JR   Z,EDITORLF
            LD   DE,EDITORDM
            CALL EDITOR1O
EDITORLJ:
            LD   C,20
            CALL EDITOR1N
            OR   A
            JR   Z,EDITORLK
            DEC  A
            JR   Z,EDITORLH
            JR   EDITORLL
EDITORLK:
            LD   HL,EDITORDM
            LD   B,128
EDITORL8:
            LD   A,(HL)
            CP   $1A
            JR   Z,EDITORLM
            CALL EDITORLQ
            JR   C,EDITORLN
            PUSH HL
            CALL EDITORLO
            POP  HL
            JR   C,EDITORL9
            INC  HL
            DJNZ EDITORL8
            JR   EDITORLJ
EDITORLM:
            LD   A,(EDITORLG)
            OR   A
            JR   NZ,EDITORLN
            JR   EDITORLA
EDITORLH:
            LD   A,(EDITORLG)
            OR   A
            JR   NZ,EDITORLN
EDITORLA:
            LD   C,16
            CALL EDITOR1N
            INC  A
            JR   Z,EDITORLL

            LD   HL,0
            LD   (EDITOR18),HL
            LD   (EDITORTO),HL
            LD   (EDITORHO),HL
            LD   (EDITORD1),HL
            XOR  A
            LD   (EDITORF4),HL
            RET
EDITORLF:
            LD   A,EDITORE9
            SCF
            RET


























EDITORLN:
            LD   A,EDITOREC
            SCF
            RET
EDITORL9:
            LD   A,EDITORER
            SCF
            RET
EDITORLL:
            LD   A,EDITOREB
            SCF
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,C
EDITORLQ:
            LD   C,A
            LD   A,(EDITORLG)
            OR   A
            JR   Z,EDITORLT
            LD   A,C
            CP   10
            JR   NZ,EDITORLP
            XOR  A
            LD   (EDITORLG),A
            LD   A,C
            RET
EDITORLT:
            LD   A,C
            CP   13
            JR   Z,EDITORLR
            CP   9
            JR   Z,EDITORLS
            CP   10
            JR   Z,EDITORLS
            CP   32
            JR   C,EDITORLP
            CP   127
            JR   NC,EDITORLP
EDITORLS:
            OR   A
            RET
EDITORLR:
            LD   A,1
            LD   (EDITORLG),A
            LD   A,C
            OR   A
            RET
EDITORLP:
            LD   A,C
            SCF
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
EDITORLO:
            LD   DE,(EDITORLE)
            LD   HL,EDITORT2
            OR   A
            SBC  HL,DE
            JR   Z,EDITORL7
            LD   HL,EDITORT1
            ADD  HL,DE
            LD   (HL),A
            INC  DE
            LD   (EDITORLE),DE
            OR   A
            RET
EDITORL7:
            SCF
            RET
EDITORLB:

; Contiguous text editing primitives. Cursor and length are logical offsets.

EDITORB8:
;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORBH:
            LD   (EDITORSS),A
            LD   A,1
            CALL EDITORBJ
            RET  C
            LD   A,(EDITORSS)
            LD   (HL),A
            LD   HL,(EDITOR18)
            INC  HL
            LD   (EDITOR18),HL
            JP   EDITORB6

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORBI:
            LD   A,2
            CALL EDITORBJ
            RET  C
            LD   (HL),13
            INC  HL
            LD   (HL),10
            LD   HL,(EDITOR18)
            INC  HL
            INC  HL
            LD   (EDITOR18),HL
            JP   EDITORB6

; Open A bytes at the cursor and return their first address in HL. The buffer
; and all state remain unchanged on capacity failure.
;@ROUTINE in A out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
EDITORBJ:
            LD   L,A
            LD   H,0
            LD   (EDITORSQ),HL
            LD   DE,(EDITORLE)
            LD   HL,EDITORT2
            OR   A
            SBC  HL,DE
            LD   DE,(EDITORSQ)
            OR   A
            SBC  HL,DE
            JR   C,EDITORBF
            LD   HL,(EDITORLE)
            LD   DE,(EDITOR18)
            OR   A
            SBC  HL,DE
            LD   B,H
            LD   C,L
            LD   HL,(EDITORLE)
            LD   DE,EDITORT1
            ADD  HL,DE
            DEC  HL
            PUSH HL
            LD   DE,(EDITORSQ)
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
            LD   DE,(EDITORSQ)
            ADD  HL,DE
            LD   (EDITORLE),HL
            LD   HL,(EDITOR18)
            LD   DE,EDITORT1
            ADD  HL,DE
            OR   A
            RET
EDITORBF:
            LD   A,EDITOR23
            LD   (EDITOR1R),A
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORBU:
            LD   HL,(EDITOR18)
            LD   A,H
            OR   L
            JP   Z,EDITORB3
            DEC  HL
            LD   DE,EDITORT1
            ADD  HL,DE
            LD   A,(HL)
            CP   10
            JR   NZ,EDITORB2
            LD   HL,(EDITOR18)
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
            LD   HL,(EDITOR18)
            DEC  HL
            DEC  HL
            LD   (EDITOR18),HL
            LD   A,2
            JR   EDITORBE
EDITORB2:
            LD   HL,(EDITOR18)
            DEC  HL
            LD   (EDITOR18),HL
            LD   A,1
            JR   EDITORBE

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORB9:
            LD   HL,(EDITOR18)
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
            LD   (EDITORSQ),HL
            LD   HL,(EDITORLE)
            LD   DE,(EDITOR18)
            OR   A
            SBC  HL,DE
            LD   DE,(EDITORSQ)
            OR   A
            SBC  HL,DE
            LD   B,H
            LD   C,L
            LD   HL,(EDITOR18)
            LD   DE,EDITORT1
            ADD  HL,DE
            LD   D,H
            LD   E,L
            LD   HL,(EDITORSQ)
            ADD  HL,DE
            LD   A,B
            OR   C
            JR   Z,EDITORBC
            LDIR
EDITORBC:
            LD   HL,(EDITORLE)
            LD   DE,(EDITORSQ)
            OR   A
            SBC  HL,DE
            LD   (EDITORLE),HL
            JR   EDITORB6

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
EDITORB6:
            LD   HL,EDITORF4
            SET  0,(HL)
            XOR  A
            LD   (EDITOR1R),A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry
EDITORB3:
            LD   A,EDITOR1T
            LD   (EDITOR1R),A
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
            LD   HL,(EDITOR18)
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
            LD   (EDITOR18),HL
            JR   EDITORN7

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
EDITORM5:
            LD   HL,(EDITOR18)
            PUSH HL
            CALL EDITORB4
            POP  HL
            JR   C,EDITORB3
            INC  HL
            CP   13
            JR   NZ,EDITORM6
            INC  HL
EDITORM6:
            LD   (EDITOR18),HL
EDITORN7:
            LD   A,(EDITORF4)
            AND  $F9
            LD   (EDITORF4),A
            XOR  A
            LD   (EDITOR1R),A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORM7:
            CALL EDITORNJ
            LD   HL,(EDITOR18)
            CALL EDITORN8
            LD   A,H
            OR   L
            JR   Z,EDITORB3
            DEC  HL
            CALL EDITORN8
            LD   DE,(EDITORD1)
            CALL EDITORNF
            LD   (EDITOR18),HL
            XOR  A
            LD   (EDITOR1R),A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORMO:
            CALL EDITORNJ
            LD   HL,(EDITOR18)
            CALL EDITORN8
            CALL EDITORNC
            JP   C,EDITORB3
            LD   DE,(EDITORD1)
            CALL EDITORNF
            LD   (EDITOR18),HL
            XOR  A
            LD   (EDITOR1R),A
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
            LD   HL,(EDITOR18)
            LD   (EDITORSQ),HL
            CALL EDITORN8
            LD   DE,0
EDITORN3:
            PUSH HL
            LD   BC,(EDITORSQ)
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
            LD   (EDITORSQ),DE
            LD   BC,0
EDITORNG:
            LD   (EDITORSS),HL
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
            LD   DE,(EDITORSQ)
            OR   A
            SBC  HL,DE
            JR   C,EDITORNI
            JR   Z,EDITORNI
            LD   HL,(EDITORSS)
            RET
EDITORNI:
            LD   HL,(EDITORSS)
            INC  HL
            JR   EDITORNG
EDITORNA:

; Full repaint for the 80-by-24 terminal profile.

EDITORSU:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORR4:
            CALL EDITORE6
            LD   DE,EDITORC1
            CALL EDITORO5
            LD   HL,(EDITORTO)
            LD   B,23
EDITORRM:
            PUSH BC
            CALL EDITORR9
            LD   (EDITORRL),HL
            LD   A,13
            CALL EDITOROU
            LD   A,10
            CALL EDITOROU
            LD   HL,(EDITORRL)
            POP  BC
            DJNZ EDITORRM
            JP   EDITORRN

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORE6:
            LD   HL,(EDITOR18)
            CALL EDITORN8
            LD   (EDITORSQ),HL
EDITORE5:
            LD   DE,(EDITORTO)
            OR   A
            SBC  HL,DE
            JR   NC,EDITORE1
            LD   HL,(EDITORSQ)
            LD   (EDITORTO),HL
EDITORE1:
            LD   HL,(EDITORTO)
            LD   B,0
EDITORE3:
            LD   DE,(EDITORSQ)
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
            LD   HL,(EDITORSQ)
            JR   EDITORE5
EDITORE4:
            LD   A,B
            LD   (EDITOR1A),A
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
            LD   (EDITOR19),A
            RET

; Render one logical line beginning at HL and return the next line's offset or
; logical EOF. RenderColumn is the source visual column; RenderCount is cells.
;@ROUTINE in HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
EDITORR9:
            LD   (EDITORRL),HL
            LD   HL,0
            LD   (EDITORR7),HL
            LD   (EDITORR8),HL
EDITORRD:
            LD   HL,(EDITORRL)
            PUSH HL
            CALL EDITORB4
            POP  HL
            JR   C,EDITORRC
            CP   10
            JR   Z,EDITORRF
            CP   13
            JR   Z,EDITORRB
            CP   9
            JR   Z,EDITORRG
            CALL EDITORR5
            JR   EDITORRA
EDITORRG:
            LD   HL,(EDITORR7)
            CALL EDITORND
            LD   (EDITORSR),HL
EDITORRO:
            LD   A,' '
            CALL EDITORR5
            LD   HL,(EDITORR7)
            LD   DE,(EDITORSR)
            OR   A
            SBC  HL,DE
            JR   NZ,EDITORRO
EDITORRA:
            LD   HL,(EDITORRL)
            INC  HL
            LD   (EDITORRL),HL
            JR   EDITORRD
EDITORRB:
            INC  HL
            LD   (EDITORRL),HL
            PUSH HL
            CALL EDITORB4
            POP  HL
            JR   C,EDITORRC
            CP   10
            JR   NZ,EDITORRC
EDITORRF:
            INC  HL
            LD   (EDITORRL),HL
EDITORRC:
            LD   HL,(EDITORRL)
            RET

; Render one visual cell in A when it lies in the horizontal viewport.
;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORR5:
            LD   (EDITORSS),A
            LD   HL,(EDITORR7)
            LD   DE,(EDITORHO)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,EDITORR6
            LD   DE,(EDITORR8)
            LD   A,E
            CP   80
            JR   NC,EDITORR6
            LD   A,(EDITORSS)
            CALL EDITOROU
            LD   HL,(EDITORR8)
            INC  HL
            LD   (EDITORR8),HL
EDITORR6:
            LD   HL,(EDITORR7)
            INC  HL
            LD   (EDITORR7),HL
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORRN:
            LD   DE,EDITOR2G
            CALL EDITOR1S
            LD   HL,EDITORFC+1
            LD   B,8
EDITOR2A:
            LD   A,(HL)
            PUSH HL
            PUSH BC
            CALL EDITOR1U
            POP  BC
            POP  HL
            INC  HL
            DJNZ EDITOR2A
            LD   A,'.'
            CALL EDITOR1U
            LD   HL,EDITORFC+9
            LD   B,3
EDITOR1Y:
            LD   A,(HL)
            PUSH HL
            PUSH BC
            CALL EDITOR1U
            POP  BC
            POP  HL
            INC  HL
            DJNZ EDITOR1Y
            LD   A,' '
            CALL EDITOR1U
            LD   A,(EDITORF4)
            AND  EDITORF2
            LD   A,' '
            JR   Z,EDITOR1V
            LD   A,'*'
EDITOR1V:
            CALL EDITOR1U
            LD   A,' '
            CALL EDITOR1U
            LD   A,' '
            CALL EDITOR1U
            CALL EDITOR27
            LD   DE,EDITOR26
            CALL EDITOR2T
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR1Z:
            LD   HL,(EDITORR8)
            LD   A,L
            CP   80
            JR   NC,EDITOR20
            LD   A,' '
            CALL EDITOR1U
            JR   EDITOR1Z
EDITOR20:
            LD   DE,EDITORRT
            CALL EDITORO5
            JP   EDITORPO

;@ROUTINE in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR1S:
            PUSH DE
            LD   DE,EDITOR2F
            CALL EDITORO5
            LD   HL,0
            LD   (EDITORR8),HL
            POP  DE
            JP   EDITOR2T

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR27:
            LD   A,(EDITOR1R)
            OR   A
            RET  Z
            ADD  A,A
            JR   C,EDITOR2S
            CP   EDITOR2M*2
            LD   DE,EDITOR2N
            JR   Z,EDITOR29
            CP   EDITOR23*2
            LD   DE,EDITOR24
            JR   Z,EDITOR29
            CP   EDITOR1W*2
            LD   DE,EDITOR1X
            JR   Z,EDITOR29
            CP   EDITOR2K*2
            JR   C,EDITOR28
            LD   DE,EDITOR2O
            CALL EDITOR2T
            LD   A,(EDITOR1R)
            OR   A
            PUSH AF
            RRCA
            RRCA
            RRCA
            RRCA
            CALL EDITOR25
            POP  AF
            CALL EDITOR25
EDITOR28:
            RET
EDITOR29:
            JR   EDITOR2T
EDITOR2S:
            LD   E,A
            LD   D,0
            LD   HL,EDITOR22
            ADD  HL,DE
            EX   DE,HL
            JR   EDITOR2T

;@ROUTINE in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR2T:
            LD   A,(DE)
            OR   A
            RET  Z
            INC  DE
            PUSH DE
            CALL EDITOR1U
            POP  DE
            JR   EDITOR2T

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR1U:
            CALL EDITOROU
            LD   HL,(EDITORR8)
            INC  HL
            LD   (EDITORR8),HL
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR25:
            AND  $0F
            ADD  A,'0'
            CP   '9'+1
            JR   C,EDITOR1U
            ADD  A,7
            JR   EDITOR1U

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORPO:
            LD   A,(EDITOR1A)
            INC  A
            LD   (EDITORSQ),A
            LD   A,(EDITOR19)
            INC  A
            LD   (EDITORSQ+1),A
            LD   A,(EDITORSQ)
            CALL EDITORO1
            LD   A,';'
            CALL EDITOROU
            LD   A,(EDITORSQ+1)
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
            LD   (EDITORSS),A
            LD   A,B
            OR   A
            JR   Z,EDITORO3
            ADD  A,'0'
            CALL EDITOROU
EDITORO3:
            LD   A,(EDITORSS)
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

EDITORST:

; Complete candidate save transactions. The production helpers remain shared;
; only first-save recognition and dispatch differ between candidates.

EDITORS5:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EDITORSA:





            XOR  A
            LD   (EDITORSL),A
            CALL EDITORSK
            CALL EDITORSE

            JR   C,EDITORS6



            CALL EDITORSI
            CALL EDITORSE

            JR   C,EDITORS6



















            CALL EDITORSK
            LD   C,22
            CALL EDITORTR
            INC  A

            JR   Z,EDITORS8







            LD   A,1

            LD   (EDITORSL),A
            CALL EDITORSN

            JR   C,EDITORSO



            LD   C,16
            CALL EDITORTR
            INC  A

            JR   Z,EDITORS3













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

            JR   Z,EDITORSD



            LD   A,3
            LD   (EDITORSL),A



            CALL EDITORSK
            LD   HL,EDITORFC
            CALL EDITORS2
            LD   C,23
            CALL EDITORTR
            INC  A

            JR   Z,EDITORSD













            LD   A,7
            LD   (EDITORSL),A
            CALL EDITORSI
            LD   C,19
            CALL EDITORTR
            INC  A

            JR   Z,EDITORSD



EDITORSM:
            XOR  A
            LD   (EDITORSL),A
            LD   A,(EDITORF4)

            AND  $FC



            LD   (EDITORF4),A
            LD   A,EDITOR2M
            LD   (EDITOR1R),A
            OR   A
            RET




































EDITORS6:
            LD   A,EDITOR2K
            JR   EDITORS9
EDITORS8:
            LD   A,EDITOR2L
            JR   EDITORS9
EDITORSO:
            LD   A,EDITOR2R
            JR   EDITORS9
EDITORS3:
            LD   A,EDITOR2J
            JR   EDITORS9
EDITORSD:
            LD   A,EDITOR2P
EDITORS9:
            LD   (EDITOR1R),A
            CALL EDITORSF
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSE:
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
EDITORSN:
            LD   HL,EDITORT1
            LD   (EDITORSQ),HL
            LD   HL,(EDITORLE)
            LD   (EDITORSR),HL
EDITORSC:
            LD   HL,(EDITORSR)
            LD   DE,128
            OR   A
            SBC  HL,DE
            JR   C,EDITORSB
            LD   (EDITORSR),HL
            LD   DE,(EDITORSQ)
            CALL EDITOR1O
            CALL EDITORSP
            RET  C
            LD   HL,(EDITORSQ)
            LD   DE,128
            ADD  HL,DE
            LD   (EDITORSQ),HL
            JR   EDITORSC
EDITORSB:
            ADD  HL,DE
            LD   A,H
            OR   L
            RET  Z
            LD   (EDITORSR),HL
            LD   HL,EDITORDM
            LD   DE,EDITORDM+1
            LD   BC,127
            LD   (HL),$1A
            LDIR
            LD   HL,(EDITORSQ)
            LD   DE,EDITORDM
            LD   BC,(EDITORSR)
            LDIR
            LD   DE,EDITORDM
            CALL EDITOR1O
            JR   EDITORSP

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSP:
            LD   C,21
            CALL EDITORTR
            OR   A
            RET  Z
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSF:
            LD   A,(EDITORSL)
            OR   A
            RET  Z
            AND  4
            JR   Z,EDITORSH
            CALL EDITORS7
            LD   C,19
            CALL EDITORTR
EDITORSH:
            CALL EDITORSK
            LD   C,16
            CALL EDITORTR
            CALL EDITORSK
            LD   C,19
            CALL EDITORTR
            LD   A,(EDITORSL)
            AND  2
            JR   Z,EDITORSG
            CALL EDITORSI
            LD   HL,EDITORFC
            CALL EDITORS2
            LD   C,23
            CALL EDITORTR
            INC  A
            JR   NZ,EDITORSG
            LD   A,EDITOR2Q
            LD   (EDITOR1R),A
EDITORSG:
            XOR  A
            LD   (EDITORSL),A
            RET

;@ROUTINE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORS7:
            LD   HL,EDITORFC
            LD   DE,EDITORT4
            JP   EDITORBK

;@ROUTINE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORSK:
            CALL EDITORS7
            LD   HL,$2424
            LD   A,'$'
            JR   EDITORSJ

;@ROUTINE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORSI:
            CALL EDITORS7
            LD   HL,$4142
            LD   A,'K'

;@ROUTINE in A,HL out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORSJ:
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

EDITOR1B:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
EDITORSW:
            LD   HL,EDITORQ2
            LD   DE,EDITORDM
            LD   BC,EDITORQ1+1
            LDIR
            LD   HL,EDITORQ2
            LD   DE,EDITOR1J
            CALL EDITORLI
            JR   C,EDITORSX
            LD   A,(EDITORQ2)
            OR   A
            JP   NZ,EDITOR1E
EDITORSX:
            LD   HL,EDITORDM
            LD   DE,EDITORQ2
            LD   BC,EDITORQ1+1
            LDIR
EDITORR3:
            XOR  A
            LD   (EDITOR1R),A
            RET

; Read one bounded literal into the length byte and contiguous payload at HL.
; DE selects its reverse-video prompt. Escape returns carry set; Return returns
; carry clear. Unsupported controls ring locally and leave the literal intact.
;@ROUTINE in DE,HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORLI:
            LD   (EDITORRL),HL
            LD   (EDITORR7),DE
EDITORL5:
            LD   DE,(EDITORR7)
            CALL EDITORRH
EDITORL4:
            CALL EDITORRE
            CP   27
            JR   Z,EDITORL2
            CP   13
            RET  Z
            CP   8
            JR   Z,EDITORL3
            CP   9
            JR   Z,EDITORL1
            CP   32
            JR   C,EDITORL6
            CP   127
            JR   C,EDITORL1
            JR   Z,EDITORL3
EDITORL6:
            LD   A,7
            CALL EDITOROU
            JR   EDITORL4
EDITORL3:
            LD   HL,(EDITORRL)
            LD   A,(HL)
            OR   A
            JR   Z,EDITORL6
            DEC  (HL)
            JR   EDITORL5
EDITORL1:
            LD   C,A
            LD   HL,(EDITORRL)
            LD   A,(HL)
            CP   EDITORQ1
            JR   NC,EDITORL6
            INC  (HL)
            INC  HL
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   (HL),C
            JR   EDITORL5
EDITORL2:
            SCF
            RET

;@ROUTINE in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORRH:
            CALL EDITOR1S
            LD   HL,(EDITORRL)
            LD   A,(HL)
            OR   A
            JR   Z,EDITORRJ
            LD   B,A
            INC  HL
EDITORRK:
            LD   A,(HL)
            CP   9
            JR   NZ,EDITORRI
            LD   A,'>'
EDITORRI:
            PUSH HL
            PUSH BC
            CALL EDITOR1U
            POP  BC
            POP  HL
            INC  HL
            DJNZ EDITORRK
EDITORRJ:
            LD   HL,(EDITORR8)
            LD   H,L
            LD   L,23
            LD   (EDITOR1A),HL
            JP   EDITOR1Z

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
EDITOR1E:
            LD   HL,(EDITOR18)
            JR   EDITORSY

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR1K:
            LD   HL,(EDITOR18)
            INC  HL
EDITORSY:
            LD   A,(EDITORQ2)
            OR   A
            JR   Z,EDITOR1G
            LD   C,A

EDITOR1L:
            LD   A,EDITOR21
            LD   (EDITOR1R),A
            LD   DE,(EDITORLE)
            LD   (EDITORSQ),DE
            JR   EDITOR1H

EDITORSV:
            LD   HL,(EDITORSR)
            INC  HL
            LD   DE,(EDITORLE)
EDITOR1H:
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,EDITOR1M
            SBC  HL,HL
            LD   A,EDITOR2U
            LD   (EDITOR1R),A
EDITOR1M:
            LD   (EDITORSR),HL

EDITOR1F:
            LD   HL,(EDITORSQ)
            LD   A,H
            OR   L
            JR   Z,EDITOR1I
            DEC  HL
            LD   (EDITORSQ),HL
            LD   HL,(EDITORSR)
            CALL EDITORRQ
            JR   NZ,EDITORSV
EDITOR1D:
            LD   HL,(EDITORSR)
            LD   (EDITOR18),HL
            LD   HL,EDITORF4
            RES  2,(HL)
            LD   A,(EDITOR1R)
            OR   A
            RET

EDITOR1G:
            LD   A,EDITOR2B
            JR   EDITOR1C
EDITOR1I:
            LD   A,EDITOR2D
EDITOR1C:
            LD   (EDITOR1R),A
            SCF
            RET
EDITORSZ:

; Transient entry, raw-key dispatcher, and CCP return.

EDITORM1:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EDITORE7:
            LD   (EDITORRS+1),SP
            LD   SP,EDITOR1Q
            CALL EDITORRU
EDITORRS:
            LD   SP,0
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EDITORRU:
            CALL EDITORPR
            JP   C,EDITORRV
            CALL EDITORLD
            JP   C,EDITORRV
            CALL EDITORR4
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
            JR   Z,EDITOR11
            CP   6
            JR   Z,EDITOR12
            CP   14
            JR   Z,EDITOR13
            CP   18
            JR   Z,EDITORCZ
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
            JR   C,EDITOR16
            CP   127
            JR   NC,EDITOR16
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
EDITOR11:
            CALL EDITORSA
            JR   EDITORC8
EDITOR12:
            CALL EDITORSW
            JR   EDITORC8
EDITOR13:
            CALL EDITOR1K
            JR   EDITORC8
EDITORCZ:
            CALL EDITORRP
            JR   EDITORC8
EDITORCC:
            CALL EDITORR1
            JR   C,EDITOR16
            CP   '['
            JR   NZ,EDITOR16
            CALL EDITORR1
            JR   C,EDITOR16
            CP   'A'
            JR   Z,EDITOR17
            CP   'B'
            JR   Z,EDITORCB
            CP   'C'
            JR   Z,EDITOR10
            CP   'D'
            JR   NZ,EDITOR16
            CALL EDITORM3
            JR   EDITORC8
EDITOR17:
            CALL EDITORM7
            JR   EDITORC8
EDITORCB:
            CALL EDITORMO
            JR   EDITORC8
EDITOR10:
            CALL EDITORM5
            JR   EDITORC8
EDITOR16:
            CALL EDITORB3
EDITORC8:
            JR   NC,EDITORCY
            LD   A,7
            CALL EDITOROU
EDITORCY:
            CALL EDITORR4
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
            LD   A,EDITOR1W
            LD   (EDITOR1R),A
            CALL EDITORR4
            JP   EDITORM2
EDITORCD:
            LD   DE,EDITORC1
            JP   EDITORO5

EDITORRV:
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
            LD   (EDITORSQ),HL
EDITORR2:
            LD   DE,$00FF
            LD   C,6
            CALL EDITORCA
            OR   A
            RET  NZ
            LD   HL,(EDITORSQ)
            DEC  HL
            LD   (EDITORSQ),HL
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
EDITOR2F:     DB 27,"[24;1H",27,"[7m","$"
EDITORRT:         DB 27,"[0m",27,"[","$"
EDITOR2G:       DB "EDIT ",0
EDITOR26:        DB "  ^S Save  ^Q Quit",0
EDITOR2N:    DB "Saved  ",0
EDITOR24:     DB "Full  ",0
EDITOR1X:  DB "Discard changes? ^Q again  ",0
EDITOR2O: DB "Save failed ",0
EDITOR22:    DB "Found",0
EDITOR2V:  DB "Wrapped",0
EDITOR2E: DB "Not found",0
EDITOR2C: DB "No search",0
EDITOR1J:       DB "Find: ",0
EDITORIM:
EDITORRR:
