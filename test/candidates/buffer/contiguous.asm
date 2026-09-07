; Native ATOM historical experiment: buffer/contiguous
; Historical debugger names are recorded in contiguous.asm.symbols.json.
; Contiguous editor text arena candidate.

EDITORBU EQU $2000
EDITORB2 EQU $D800
EDITORB1 EQU EDITORB2-EDITORBU
CANDIDAK EQU $1E00
CANDIDA7 EQU $1E02
CANDIDA3 EQU $1E04
CANDIDAP EQU $1E05

            ORG $0100
CANDIDA5:
CANDIDAM:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDIDAN:
            LD   HL,0
            LD   (CANDIDAK),HL
            LD   (CANDIDA7),HL
            XOR  A
            RET

;@ROUTINE in HL out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDIDAQ:
            LD   (CANDIDAK),HL
            LD   HL,0
            LD   (CANDIDA7),HL
            XOR  A
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAG:
            LD   (CANDIDAP),A
            LD   HL,(CANDIDAK)
            LD   DE,EDITORB1
            OR   A
            SBC  HL,DE
            JR   Z,CANDIDAH
            LD   HL,(CANDIDAK)
            LD   DE,(CANDIDA7)
            OR   A
            SBC  HL,DE
            LD   B,H
            LD   C,L
            LD   HL,(CANDIDAK)
            LD   DE,EDITORBU
            ADD  HL,DE
            LD   D,H
            LD   E,L
            DEC  HL
            LD   A,B
            OR   C
            JR   Z,CANDIDAI
            LDDR
CANDIDAI:
            LD   HL,(CANDIDA7)
            LD   DE,EDITORBU
            ADD  HL,DE
            LD   A,(CANDIDAP)
            LD   (HL),A
            LD   HL,(CANDIDA7)
            INC  HL
            LD   (CANDIDA7),HL
            LD   HL,(CANDIDAK)
            INC  HL
            LD   (CANDIDAK),HL
            OR   A
            RET
CANDIDAH:
            LD   A,(CANDIDAP)
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAT:
            LD   HL,(CANDIDA7)
            LD   A,H
            OR   L
            JR   Z,CANDIDAB
            DEC  HL
            LD   (CANDIDA7),HL
            JP   CANDIDAA

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA8:
            LD   HL,(CANDIDAK)
            LD   DE,(CANDIDA7)
            OR   A
            SBC  HL,DE
            JR   Z,CANDIDAB
            JP   CANDIDAA

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAA:
            LD   HL,(CANDIDAK)
            LD   DE,(CANDIDA7)
            OR   A
            SBC  HL,DE
            DEC  HL
            LD   B,H
            LD   C,L
            LD   HL,(CANDIDA7)
            LD   DE,EDITORBU
            ADD  HL,DE
            LD   D,H
            LD   E,L
            INC  HL
            LD   A,B
            OR   C
            JR   Z,CANDIDA9
            LDIR
CANDIDA9:
            LD   HL,(CANDIDAK)
            DEC  HL
            LD   (CANDIDAK),HL
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDIDAJ:
            LD   HL,(CANDIDA7)
            LD   A,H
            OR   L
            JR   Z,CANDIDAB
            DEC  HL
            LD   (CANDIDA7),HL
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
CANDIDAO:
            LD   HL,(CANDIDA7)
            LD   DE,(CANDIDAK)
            OR   A
            SBC  HL,DE
            JR   Z,CANDIDAB
            ADD  HL,DE
            INC  HL
            LD   (CANDIDA7),HL
            OR   A
            RET

CANDIDAB:
            SCF
            RET

;@ROUTINE in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,DE
CANDIDA1:
            LD   DE,(CANDIDAK)
            OR   A
            SBC  HL,DE
            JR   NC,CANDIDA2
            ADD  HL,DE
            LD   DE,EDITORBU
            ADD  HL,DE
            LD   A,(HL)
            OR   A
            RET
CANDIDA2:
            SCF
            RET
CANDIDAL:

; Representation-independent cursor scans used by both editor buffer candidates.
; CandidateByteAt accepts a logical byte offset in HL and returns the byte in A,
; with carry set at or beyond logical EOF.

;@ROUTINE in HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
CANDIDAC:
            LD   A,H
            OR   L
            RET  Z
CANDIDAE:
            DEC  HL
            PUSH HL
            CALL CANDIDA1
            POP  HL
            CP   10
            JR   NZ,CANDIDAD
            INC  HL
            RET
CANDIDAD:
            LD   A,H
            OR   L
            JR   NZ,CANDIDAE
            RET

;@ROUTINE in HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
CANDIDAF:
            PUSH HL
            CALL CANDIDA1
            POP  HL
            RET  C
            INC  HL
            CP   10
            JR   NZ,CANDIDAF
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAR:
            XOR  A
            LD   (CANDIDA3),A
            LD   HL,0
CANDIDAU:
            PUSH HL
            CALL CANDIDA1
            JR   C,CANDIDAS
            LD   B,A
            LD   A,(CANDIDA3)
            ADD  A,B
            LD   (CANDIDA3),A
            POP  HL
            INC  HL
            JR   CANDIDAU
CANDIDAS:
            POP  HL
            LD   A,(CANDIDA3)
            RET

CANDIDA6:

CANDIDA4:
