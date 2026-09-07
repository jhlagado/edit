; Native ATOM historical experiment: search/scan-counted
; Historical debugger names are recorded in scan-counted.asm.symbols.json.
; Counted-ring scan alternative. It tests exactly TextLength candidate starts.

CANDIDAY EQU $2000
CANDIDAZ EQU $1EC8
CANDIDA5 EQU $1ECA
CANDIDAS EQU $1ED3
CANDIDAF EQU $1ED7
CANDIDAG EQU $1ED9
CANDIDAE EQU $1EDB
CANDIDA4 EQU $1EE4
CANDIDA3 EQU CANDIDA4+1
CANDIDAT EQU $F000
CANDIDA9 EQU $F001
CANDIDAU EQU 1
CANDIDAX EQU 2
CANDIDAV EQU 3
CANDIDAW EQU 4

            ORG $0100
CANDIDA2:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDIDAB:
            LD   HL,CANDIDAT
            INC  (HL)
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDIDAA:
            XOR  A
            LD   (CANDIDA4),A
            LD   (CANDIDAS),A
            LD   (CANDIDAT),A
            LD   HL,0
            LD   (CANDIDA5),HL
            RET

CANDIDAD:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
CANDIDAK:
            LD   A,(CANDIDA4)
            OR   A
            JR   Z,CANDIDAM
            LD   HL,(CANDIDA5)
            JR   CANDIDAP

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAO:
            LD   A,(CANDIDA4)
            OR   A
            JR   Z,CANDIDAM
            LD   HL,(CANDIDA5)
            INC  HL

CANDIDAP:
            XOR  A
            LD   (CANDIDAE),A
            LD   DE,(CANDIDAZ)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,CANDIDAQ
            LD   HL,0
            INC  A
            LD   (CANDIDAE),A
CANDIDAQ:
            LD   (CANDIDAG),HL
            LD   (CANDIDAF),DE

CANDIDAL:
            LD   HL,(CANDIDAF)
            LD   A,H
            OR   L
            JR   Z,CANDIDAN
            LD   HL,(CANDIDAG)
            CALL CANDIDA6
            JR   Z,CANDIDAJ
            LD   HL,(CANDIDAG)
            INC  HL
            LD   DE,(CANDIDAZ)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,CANDIDAH
            LD   HL,0
            LD   A,1
            LD   (CANDIDAE),A
CANDIDAH:
            LD   (CANDIDAG),HL
            LD   HL,(CANDIDAF)
            DEC  HL
            LD   (CANDIDAF),HL
            JR   CANDIDAL

CANDIDAJ:
            LD   HL,(CANDIDAG)
            LD   (CANDIDA5),HL
            LD   A,(CANDIDAE)
            OR   A
            LD   A,CANDIDAU
            JR   Z,CANDIDAR
            LD   A,CANDIDAX
CANDIDAR:
            LD   (CANDIDAS),A
            OR   A
            RET

CANDIDAM:
            LD   A,CANDIDAW
            JR   CANDIDAI
CANDIDAN:
            LD   A,CANDIDAV
CANDIDAI:
            LD   (CANDIDAS),A
            CALL CANDIDAB
            SCF
            RET

;@ROUTINE in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA6:
            LD   (CANDIDAG),HL
            LD   A,(CANDIDA4)
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   DE,(CANDIDAZ)
            OR   A
            SBC  HL,DE
            JR   C,CANDIDA7
            JR   Z,CANDIDA7
            LD   A,1
            OR   A
            RET
CANDIDA7:
            LD   HL,(CANDIDAG)
            LD   DE,CANDIDAY
            ADD  HL,DE
            LD   DE,CANDIDA3
            LD   A,(CANDIDA4)
            LD   B,A
CANDIDA8:
            LD   A,(DE)
            CP   (HL)
            RET  NZ
            INC  DE
            INC  HL
            DJNZ CANDIDA8
            XOR  A
            RET
CANDIDAC:
CANDIDA1:
