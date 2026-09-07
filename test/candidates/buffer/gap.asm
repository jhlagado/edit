; Native ATOM historical experiment: buffer/gap
; Historical debugger names are recorded in gap.asm.symbols.json.
; Movable-gap editor text arena candidate. The cursor is always at the gap.

EDITORBU EQU $2000
EDITORB2 EQU $D800
EDITORB1 EQU EDITORB2-EDITORBU
CANDIDAF EQU $1E00
CANDIDAE EQU $1E02
CANDIDA4 EQU $1E04
CANDIDAI EQU $1E05

            ORG $0100
CANDIDA6:
CANDIDAK:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDIDAL:
            LD   HL,EDITORBU
            LD   (CANDIDAF),HL
            LD   HL,EDITORB2
            LD   (CANDIDAE),HL
            XOR  A
            RET

; Input bytes occupy EditorBufferBase..EditorBufferBase+HL. Move them to the
; post-gap span so the initial cursor is byte zero.
;@ROUTINE in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAN:
            LD   (CANDIDAI),HL
            LD   B,H
            LD   C,L
            LD   A,H
            OR   L
            JR   Z,CANDIDAL
            LD   DE,EDITORBU-1
            ADD  HL,DE
            LD   DE,EDITORB2-1
            LDDR
            LD   HL,EDITORBU
            LD   (CANDIDAF),HL
            LD   HL,EDITORB2
            LD   DE,(CANDIDAI)
            OR   A
            SBC  HL,DE
            LD   (CANDIDAE),HL
            XOR  A
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
CANDIDAG:
            LD   HL,(CANDIDAF)
            LD   DE,(CANDIDAE)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   Z,CANDIDA9
            LD   (HL),A
            INC  HL
            LD   (CANDIDAF),HL
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
CANDIDAT:
            LD   HL,(CANDIDAF)
            LD   DE,EDITORBU
            OR   A
            SBC  HL,DE
            JR   Z,CANDIDA9
            ADD  HL,DE
            DEC  HL
            LD   (CANDIDAF),HL
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
CANDIDA8:
            LD   HL,(CANDIDAE)
            LD   DE,EDITORB2
            OR   A
            SBC  HL,DE
            JR   Z,CANDIDA9
            ADD  HL,DE
            INC  HL
            LD   (CANDIDAE),HL
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
CANDIDAH:
            LD   HL,(CANDIDAF)
            LD   DE,EDITORBU
            OR   A
            SBC  HL,DE
            JR   Z,CANDIDA9
            ADD  HL,DE
            DEC  HL
            LD   (CANDIDAF),HL
            LD   A,(HL)
            LD   HL,(CANDIDAE)
            DEC  HL
            LD   (HL),A
            LD   (CANDIDAE),HL
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,DE,HL
CANDIDAM:
            LD   HL,(CANDIDAE)
            LD   DE,EDITORB2
            OR   A
            SBC  HL,DE
            JR   Z,CANDIDA9
            ADD  HL,DE
            LD   A,(HL)
            INC  HL
            LD   (CANDIDAE),HL
            LD   HL,(CANDIDAF)
            LD   (HL),A
            INC  HL
            LD   (CANDIDAF),HL
            OR   A
            RET

CANDIDA9:
            SCF
            RET

;@ROUTINE in HL out A,HL,carry,zero clobbers sign,parity,halfCarry,BC,DE
CANDIDA1:
            PUSH HL
            LD   HL,EDITORB2
            LD   DE,(CANDIDAE)
            OR   A
            SBC  HL,DE
            EX   DE,HL
            LD   HL,(CANDIDAF)
            LD   BC,EDITORBU
            OR   A
            SBC  HL,BC
            ADD  HL,DE
            EX   DE,HL
            POP  HL
            OR   A
            SBC  HL,DE
            JR   NC,CANDIDA2
            ADD  HL,DE
            LD   DE,EDITORBU
            ADD  HL,DE
            LD   DE,(CANDIDAF)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,CANDIDA3
            PUSH HL
            LD   HL,(CANDIDAE)
            LD   DE,(CANDIDAF)
            OR   A
            SBC  HL,DE
            EX   DE,HL
            POP  HL
            ADD  HL,DE
CANDIDA3:
            LD   A,(HL)
            OR   A
            RET
CANDIDA2:
            SCF
            RET
CANDIDAJ:

; Representation-independent cursor scans used by both editor buffer candidates.
; CandidateByteAt accepts a logical byte offset in HL and returns the byte in A,
; with carry set at or beyond logical EOF.

;@ROUTINE in HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
CANDIDAA:
            LD   A,H
            OR   L
            RET  Z
CANDIDAC:
            DEC  HL
            PUSH HL
            CALL CANDIDA1
            POP  HL
            CP   10
            JR   NZ,CANDIDAB
            INC  HL
            RET
CANDIDAB:
            LD   A,H
            OR   L
            JR   NZ,CANDIDAC
            RET

;@ROUTINE in HL out HL,carry,zero clobbers sign,parity,halfCarry,A,BC,DE
CANDIDAD:
            PUSH HL
            CALL CANDIDA1
            POP  HL
            RET  C
            INC  HL
            CP   10
            JR   NZ,CANDIDAD
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAO:
            XOR  A
            LD   (CANDIDA4),A
            LD   HL,0
CANDIDAQ:
            PUSH HL
            CALL CANDIDA1
            JR   C,CANDIDAP
            LD   B,A
            LD   A,(CANDIDA4)
            ADD  A,B
            LD   (CANDIDA4),A
            POP  HL
            INC  HL
            JR   CANDIDAQ
CANDIDAP:
            POP  HL
            LD   A,(CANDIDA4)
            RET

CANDIDA7:

CANDIDA5:
