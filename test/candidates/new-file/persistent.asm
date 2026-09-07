; Native ATOM historical experiment: new-file/persistent
; Historical debugger names are recorded in persistent.asm.symbols.json.
EDITORRP EQU $0000
EDITORRQ EQU $0000
; Full native editor candidate: one persistent new-buffer flag and a shared
; first-save branch.

CANDIDA1 EQU 1
CANDIDA2 EQU 0
CANDIDA3 EQU 0
CANDIDAT EQU 0

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
EDITOR1Q EQU $D800
EDITOR1R EQU $E400

EDITORFC EQU EDITORWO
EDITORT4 EQU EDITORFC+36
EDITORDM EQU EDITORT4+36

EDITORLE EQU EDITORDM+128
EDITOR18 EQU EDITORLE+2
EDITORTO EQU EDITOR18+2
EDITORHO EQU EDITORTO+2
EDITORD1 EQU EDITORHO+2
EDITORF4 EQU EDITORD1+2
EDITOR1S EQU EDITORF4+1
; Loading and interactive search never overlap. A successful load has already
; reduced the pending-CR state to zero, which also resets the committed query.
EDITORLH EQU EDITOR1S+1
EDITORQ2 EQU EDITORLH
EDITORQU EQU EDITORQ2+1
EDITORQ1 EQU 64
EDITORSM EQU EDITORQU+EDITORQ1
EDITORSR EQU EDITORSM+1
EDITORSS EQU EDITORSR+2
EDITORST EQU EDITORSS+2
EDITORRL EQU EDITORST+2
EDITORR7 EQU EDITORRL+2
EDITORR8 EQU EDITORR7+2
EDITOR1A EQU EDITORR8+2
EDITOR19 EQU EDITOR1A+1
EDITORW1 EQU EDITOR19+1

EDITORF2 EQU 1
EDITORFL EQU 2
EDITORF1 EQU 4
EDITORF3 EQU $80

EDITOR2I EQU 0
EDITOR2N EQU 1
EDITOR24 EQU 2
EDITOR1U EQU 3
EDITOR1X EQU 4
; Search statuses carry a high-bit tag and half the byte offset of their
; contiguous message. ADD A,A both classifies the tag and recovers the offset.
EDITOR22 EQU $80
EDITOR2V EQU $83
EDITOR2E EQU $87
EDITOR2C EQU $8C
EDITOR2J EQU $91
EDITOR2L EQU $10
EDITOR2M EQU $11
EDITOR2S EQU $12
EDITOR2K EQU $13
EDITOR2Q EQU $14
EDITOR2R EQU $15

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
EDITOR1P:
            LD   C,26
            JR   EDITORCA

;@ROUTINE in C out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORTR:
            LD   DE,EDITORT4
            JR   EDITORCA

;@ROUTINE in C out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITOR1O:
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


            LD   (EDITORSM),A

            LD   A,(EDITORCK)
            LD   B,A
            LD   HL,EDITOR15
            CALL EDITOR14
            JR   Z,EDITORCX


            LD   (EDITORSM),A

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
            LD   (EDITORLH),A
            LD   HL,0
            LD   (EDITORLE),HL
            LD   C,15
            CALL EDITOR1O
            INC  A
            JR   Z,EDITORLG
            LD   DE,EDITORDM
            CALL EDITOR1P
EDITORLK:
            LD   C,20
            CALL EDITOR1O
            OR   A
            JR   Z,EDITORLM
            DEC  A
            JR   Z,EDITORLJ
            JR   EDITORLN
EDITORLM:
            LD   HL,EDITORDM
            LD   B,128
EDITORL8:
            LD   A,(HL)
            CP   $1A
            JR   Z,EDITORLP
            CALL EDITORLS
            JR   C,EDITORLQ
            PUSH HL
            CALL EDITORLO
            POP  HL
            JR   C,EDITORL9
            INC  HL
            DJNZ EDITORL8
            JR   EDITORLK
EDITORLP:
            LD   A,(EDITORLH)
            OR   A
            JR   NZ,EDITORLQ
            JR   EDITORLA
EDITORLJ:
            LD   A,(EDITORLH)
            OR   A
            JR   NZ,EDITORLQ
EDITORLA:
            LD   C,16
            CALL EDITOR1O
            INC  A
            JR   Z,EDITORLN














            XOR  A
EDITORLL:
            LD   HL,0
            LD   (EDITOR18),HL
            LD   (EDITORTO),HL
            LD   (EDITORHO),HL
            LD   (EDITORD1),HL
            LD   L,A
            LD   (EDITORF4),HL
            RET
EDITORLG:
            LD   A,(EDITORSM)
            OR   A
            JR   Z,EDITORLF



            LD   A,EDITORF2|EDITORF3

            JR   EDITORLL
EDITORLF:
            LD   A,EDITORE9
            SCF
            RET

EDITORLQ:
            LD   A,EDITOREC
            SCF
            RET
EDITORL9:
            LD   A,EDITORER
            SCF
            RET
EDITORLN:
            LD   A,EDITOREB
            SCF
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,C
EDITORLS:
            LD   C,A
            LD   A,(EDITORLH)
            OR   A
            JR   Z,EDITORLV
            LD   A,C
            CP   10
            JR   NZ,EDITORLR
            XOR  A
            LD   (EDITORLH),A
            LD   A,C
            RET
EDITORLV:
            LD   A,C
            CP   13
            JR   Z,EDITORLT
            CP   9
            JR   Z,EDITORLU
            CP   10
            JR   Z,EDITORLU
            CP   32
            JR   C,EDITORLR
            CP   127
            JR   NC,EDITORLR
EDITORLU:
            OR   A
            RET
EDITORLT:
            LD   A,1
            LD   (EDITORLH),A
            LD   A,C
            OR   A
            RET
EDITORLR:
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
            LD   (EDITORST),A
            LD   A,1
            CALL EDITORBJ
            RET  C
            LD   A,(EDITORST)
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
            LD   (EDITORSR),HL
            LD   DE,(EDITORLE)
            LD   HL,EDITORT2
            OR   A
            SBC  HL,DE
            LD   DE,(EDITORSR)
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
            LD   DE,(EDITORSR)
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
            LD   DE,(EDITORSR)
            ADD  HL,DE
            LD   (EDITORLE),HL
            LD   HL,(EDITOR18)
            LD   DE,EDITORT1
            ADD  HL,DE
            OR   A
            RET
EDITORBF:
            LD   A,EDITOR24
            LD   (EDITOR1S),A
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
            LD   (EDITORSR),HL
            LD   HL,(EDITORLE)
            LD   DE,(EDITOR18)
            OR   A
            SBC  HL,DE
            LD   DE,(EDITORSR)
            OR   A
            SBC  HL,DE
            LD   B,H
            LD   C,L
            LD   HL,(EDITOR18)
            LD   DE,EDITORT1
            ADD  HL,DE
            LD   D,H
            LD   E,L
            LD   HL,(EDITORSR)
            ADD  HL,DE
            LD   A,B
            OR   C
            JR   Z,EDITORBC
            LDIR
EDITORBC:
            LD   HL,(EDITORLE)
            LD   DE,(EDITORSR)
            OR   A
            SBC  HL,DE
            LD   (EDITORLE),HL
            JR   EDITORB6

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
EDITORB6:
            LD   HL,EDITORF4
            SET  0,(HL)
            XOR  A
            LD   (EDITOR1S),A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry
EDITORB3:
            LD   A,EDITOR1U
            LD   (EDITOR1S),A
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
            LD   (EDITOR1S),A
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
            LD   (EDITOR1S),A
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
            LD   (EDITOR1S),A
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
            LD   (EDITORSR),HL
            CALL EDITORN8
            LD   DE,0
EDITORN3:
            PUSH HL
            LD   BC,(EDITORSR)
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
            LD   (EDITORSR),DE
            LD   BC,0
EDITORNG:
            LD   (EDITORST),HL
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
            LD   DE,(EDITORSR)
            OR   A
            SBC  HL,DE
            JR   C,EDITORNI
            JR   Z,EDITORNI
            LD   HL,(EDITORST)
            RET
EDITORNI:
            LD   HL,(EDITORST)
            INC  HL
            JR   EDITORNG
EDITORNA:

; Full repaint for the 80-by-24 terminal profile.

EDITORSV:
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
            LD   (EDITORSR),HL
EDITORE5:
            LD   DE,(EDITORTO)
            OR   A
            SBC  HL,DE
            JR   NC,EDITORE1
            LD   HL,(EDITORSR)
            LD   (EDITORTO),HL
EDITORE1:
            LD   HL,(EDITORTO)
            LD   B,0
EDITORE3:
            LD   DE,(EDITORSR)
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
            LD   HL,(EDITORSR)
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
            LD   (EDITORSS),HL
EDITORRO:
            LD   A,' '
            CALL EDITORR5
            LD   HL,(EDITORR7)
            LD   DE,(EDITORSS)
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
            LD   (EDITORST),A
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
            LD   A,(EDITORST)
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
            LD   DE,EDITOR2H
            CALL EDITOR1T
            LD   HL,EDITORFC+1
            LD   B,8
EDITOR2B:
            LD   A,(HL)
            PUSH HL
            PUSH BC
            CALL EDITOR1V
            POP  BC
            POP  HL
            INC  HL
            DJNZ EDITOR2B
            LD   A,'.'
            CALL EDITOR1V
            LD   HL,EDITORFC+9
            LD   B,3
EDITOR1Z:
            LD   A,(HL)
            PUSH HL
            PUSH BC
            CALL EDITOR1V
            POP  BC
            POP  HL
            INC  HL
            DJNZ EDITOR1Z
            LD   A,' '
            CALL EDITOR1V
            LD   A,(EDITORF4)
            AND  EDITORF2
            LD   A,' '
            JR   Z,EDITOR1W
            LD   A,'*'
EDITOR1W:
            CALL EDITOR1V
            LD   A,' '
            CALL EDITOR1V
            LD   A,' '
            CALL EDITOR1V
            CALL EDITOR28
            LD   DE,EDITOR27
            CALL EDITOR2U
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR20:
            LD   HL,(EDITORR8)
            LD   A,L
            CP   80
            JR   NC,EDITOR21
            LD   A,' '
            CALL EDITOR1V
            JR   EDITOR20
EDITOR21:
            LD   DE,EDITORRT
            CALL EDITORO5
            JP   EDITORPO

;@ROUTINE in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR1T:
            PUSH DE
            LD   DE,EDITOR2G
            CALL EDITORO5
            LD   HL,0
            LD   (EDITORR8),HL
            POP  DE
            JP   EDITOR2U

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR28:
            LD   A,(EDITOR1S)
            OR   A
            RET  Z
            ADD  A,A
            JR   C,EDITOR2T
            CP   EDITOR2N*2
            LD   DE,EDITOR2O
            JR   Z,EDITOR2A
            CP   EDITOR24*2
            LD   DE,EDITOR25
            JR   Z,EDITOR2A
            CP   EDITOR1X*2
            LD   DE,EDITOR1Y
            JR   Z,EDITOR2A
            CP   EDITOR2L*2
            JR   C,EDITOR29
            LD   DE,EDITOR2P
            CALL EDITOR2U
            LD   A,(EDITOR1S)
            OR   A
            PUSH AF
            RRCA
            RRCA
            RRCA
            RRCA
            CALL EDITOR26
            POP  AF
            CALL EDITOR26
EDITOR29:
            RET
EDITOR2A:
            JR   EDITOR2U
EDITOR2T:
            LD   E,A
            LD   D,0
            LD   HL,EDITOR23
            ADD  HL,DE
            EX   DE,HL
            JR   EDITOR2U

;@ROUTINE in DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR2U:
            LD   A,(DE)
            OR   A
            RET  Z
            INC  DE
            PUSH DE
            CALL EDITOR1V
            POP  DE
            JR   EDITOR2U

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR1V:
            CALL EDITOROU
            LD   HL,(EDITORR8)
            INC  HL
            LD   (EDITORR8),HL
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR26:
            AND  $0F
            ADD  A,'0'
            CP   '9'+1
            JR   C,EDITOR1V
            ADD  A,7
            JR   EDITOR1V

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORPO:
            LD   A,(EDITOR1A)
            INC  A
            LD   (EDITORSR),A
            LD   A,(EDITOR19)
            INC  A
            LD   (EDITORSR+1),A
            LD   A,(EDITORSR)
            CALL EDITORO1
            LD   A,';'
            CALL EDITOROU
            LD   A,(EDITORSR+1)
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
            LD   (EDITORST),A
            LD   A,B
            OR   A
            JR   Z,EDITORO3
            ADD  A,'0'
            CALL EDITOROU
EDITORO3:
            LD   A,(EDITORST)
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

EDITORSU:

; Complete candidate save transactions. The production helpers remain shared;
; only first-save recognition and dispatch differ between candidates.

EDITORS5:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EDITORSA:





            XOR  A
            LD   (EDITORSM),A
            CALL EDITORSL
            CALL EDITORSF



            JP   C,EDITORS6

            CALL EDITORSJ
            CALL EDITORSF



            JP   C,EDITORS6

















            CALL EDITORSL
            LD   C,22
            CALL EDITORTR
            INC  A



            JP   Z,EDITORS8





            LD   A,1

            LD   (EDITORSM),A
            CALL EDITORSO



            JP   C,EDITORSP

            LD   C,16
            CALL EDITORTR
            INC  A



            JP   Z,EDITORS3


            LD   A,(EDITORF4)
            AND  EDITORF3
            JR   NZ,EDITORSB






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



            JP   Z,EDITORSE

            LD   A,3
            LD   (EDITORSM),A

EDITORSB:

            CALL EDITORSL
            LD   HL,EDITORFC
            CALL EDITORS2
            LD   C,23
            CALL EDITORTR
            INC  A



            JP   Z,EDITORSE


            LD   A,(EDITORF4)
            AND  EDITORF3
            JR   NZ,EDITORSN






            LD   A,7
            LD   (EDITORSM),A
            CALL EDITORSJ
            LD   C,19
            CALL EDITORTR
            INC  A



            JP   Z,EDITORSE

EDITORSN:
            XOR  A
            LD   (EDITORSM),A
            LD   A,(EDITORF4)



            AND  $74

            LD   (EDITORF4),A
            LD   A,EDITOR2N
            LD   (EDITOR1S),A
            OR   A
            RET




































EDITORS6:
            LD   A,EDITOR2L
            JR   EDITORS9
EDITORS8:
            LD   A,EDITOR2M
            JR   EDITORS9
EDITORSP:
            LD   A,EDITOR2S
            JR   EDITORS9
EDITORS3:
            LD   A,EDITOR2K
            JR   EDITORS9
EDITORSE:
            LD   A,EDITOR2Q
EDITORS9:
            LD   (EDITOR1S),A
            CALL EDITORSG
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSF:
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
EDITORSO:
            LD   HL,EDITORT1
            LD   (EDITORSR),HL
            LD   HL,(EDITORLE)
            LD   (EDITORSS),HL
EDITORSD:
            LD   HL,(EDITORSS)
            LD   DE,128
            OR   A
            SBC  HL,DE
            JR   C,EDITORSC
            LD   (EDITORSS),HL
            LD   DE,(EDITORSR)
            CALL EDITOR1P
            CALL EDITORSQ
            RET  C
            LD   HL,(EDITORSR)
            LD   DE,128
            ADD  HL,DE
            LD   (EDITORSR),HL
            JR   EDITORSD
EDITORSC:
            ADD  HL,DE
            LD   A,H
            OR   L
            RET  Z
            LD   (EDITORSS),HL
            LD   HL,EDITORDM
            LD   DE,EDITORDM+1
            LD   BC,127
            LD   (HL),$1A
            LDIR
            LD   HL,(EDITORSR)
            LD   DE,EDITORDM
            LD   BC,(EDITORSS)
            LDIR
            LD   DE,EDITORDM
            CALL EDITOR1P
            JR   EDITORSQ

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSQ:
            LD   C,21
            CALL EDITORTR
            OR   A
            RET  Z
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITORSG:
            LD   A,(EDITORSM)
            OR   A
            RET  Z
            AND  4
            JR   Z,EDITORSI
            CALL EDITORS7
            LD   C,19
            CALL EDITORTR
EDITORSI:
            CALL EDITORSL
            LD   C,16
            CALL EDITORTR
            CALL EDITORSL
            LD   C,19
            CALL EDITORTR
            LD   A,(EDITORSM)
            AND  2
            JR   Z,EDITORSH
            CALL EDITORSJ
            LD   HL,EDITORFC
            CALL EDITORS2
            LD   C,23
            CALL EDITORTR
            INC  A
            JR   NZ,EDITORSH
            LD   A,EDITOR2R
            LD   (EDITOR1S),A
EDITORSH:
            XOR  A
            LD   (EDITORSM),A
            RET

;@ROUTINE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORS7:
            LD   HL,EDITORFC
            LD   DE,EDITORT4
            JP   EDITORBK

;@ROUTINE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORSL:
            CALL EDITORS7
            LD   HL,$2424
            LD   A,'$'
            JR   EDITORSK

;@ROUTINE out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORSJ:
            CALL EDITORS7
            LD   HL,$4142
            LD   A,'K'

;@ROUTINE in A,HL out A clobbers carry,zero,sign,parity,halfCarry,BC,DE,HL
EDITORSK:
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

EDITOR1C:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
EDITORSX:
            LD   HL,EDITORQ2
            LD   DE,EDITORDM
            LD   BC,EDITORQ1+1
            LDIR
            LD   HL,EDITORQ2
            LD   DE,EDITOR1K
            CALL EDITORLI
            JR   C,EDITORSY
            LD   A,(EDITORQ2)
            OR   A
            JP   NZ,EDITOR1F
EDITORSY:
            LD   HL,EDITORDM
            LD   DE,EDITORQ2
            LD   BC,EDITORQ1+1
            LDIR
EDITORR3:
            XOR  A
            LD   (EDITOR1S),A
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
            CALL EDITOR1T
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
            CALL EDITOR1V
            POP  BC
            POP  HL
            INC  HL
            DJNZ EDITORRK
EDITORRJ:
            LD   HL,(EDITORR8)
            LD   H,L
            LD   L,23
            LD   (EDITOR1A),HL
            JP   EDITOR20

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
EDITOR1F:
            LD   HL,(EDITOR18)
            JR   EDITORSZ

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
EDITOR1L:
            LD   HL,(EDITOR18)
            INC  HL
EDITORSZ:
            LD   A,(EDITORQ2)
            OR   A
            JR   Z,EDITOR1H
            LD   C,A

EDITOR1M:
            LD   A,EDITOR22
            LD   (EDITOR1S),A
            LD   DE,(EDITORLE)
            LD   (EDITORSR),DE
            JR   EDITOR1I

EDITORSW:
            LD   HL,(EDITORSS)
            INC  HL
            LD   DE,(EDITORLE)
EDITOR1I:
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,EDITOR1N
            SBC  HL,HL
            LD   A,EDITOR2V
            LD   (EDITOR1S),A
EDITOR1N:
            LD   (EDITORSS),HL

EDITOR1G:
            LD   HL,(EDITORSR)
            LD   A,H
            OR   L
            JR   Z,EDITOR1J
            DEC  HL
            LD   (EDITORSR),HL
            LD   HL,(EDITORSS)
            CALL EDITORRQ
            JR   NZ,EDITORSW
EDITOR1E:
            LD   HL,(EDITORSS)
            LD   (EDITOR18),HL
            LD   HL,EDITORF4
            RES  2,(HL)
            LD   A,(EDITOR1S)
            OR   A
            RET

EDITOR1H:
            LD   A,EDITOR2C
            JR   EDITOR1D
EDITOR1J:
            LD   A,EDITOR2E
EDITOR1D:
            LD   (EDITOR1S),A
            SCF
            RET
EDITOR1B:

; Transient entry, raw-key dispatcher, and CCP return.

EDITORM1:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
EDITORE7:
            LD   (EDITORRS+1),SP
            LD   SP,EDITOR1R
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
            CALL EDITORSX
            JR   EDITORC8
EDITOR13:
            CALL EDITOR1L
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
            LD   A,EDITOR1X
            LD   (EDITOR1S),A
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
            LD   (EDITORSR),HL
EDITORR2:
            LD   DE,$00FF
            LD   C,6
            CALL EDITORCA
            OR   A
            RET  NZ
            LD   HL,(EDITORSR)
            DEC  HL
            LD   (EDITORSR),HL
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
EDITOR2G:     DB 27,"[24;1H",27,"[7m","$"
EDITORRT:         DB 27,"[0m",27,"[","$"
EDITOR2H:       DB "EDIT ",0
EDITOR27:        DB "  ^S Save  ^Q Quit",0
EDITOR2O:    DB "Saved  ",0
EDITOR25:     DB "Full  ",0
EDITOR1Y:  DB "Discard changes? ^Q again  ",0
EDITOR2P: DB "Save failed ",0
EDITOR23:    DB "Found",0
EDITOR2W:  DB "Wrapped",0
EDITOR2F: DB "Not found",0
EDITOR2D: DB "No search",0
EDITOR1K:       DB "Find: ",0
EDITORIM:
EDITORRR:
