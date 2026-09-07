; Native ATOM historical experiment: search/scan-endpoint
; Historical debugger names are recorded in scan-endpoint.asm.symbols.json.
; Two-segment endpoint scan alternative. It stops at the saved start address.

CANDIDAZ EQU $2000
CANDID10 EQU $1EC8
CANDIDA5 EQU $1ECA
CANDIDAU EQU $1ED3
CANDIDAG EQU $1ED7
CANDIDAF EQU $1ED9
CANDIDAE EQU $1EDB
CANDIDA4 EQU $1EE4
CANDIDA3 EQU CANDIDA4+1
CANDIDAT EQU $F000
CANDIDA9 EQU $F001
CANDIDAV EQU 1
CANDIDAY EQU 2
CANDIDAW EQU 3
CANDIDAX EQU 4

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
            LD   (CANDIDAU),A
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
            LD   DE,(CANDID10)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,CANDIDAQ
            LD   (CANDIDAG),DE
            LD   HL,0
            LD   A,1
            LD   (CANDIDAE),A
            JR   CANDIDAL
CANDIDAQ:
            LD   (CANDIDAG),HL

CANDIDAL:
            LD   A,(CANDIDAE)
            OR   A
            JR   Z,CANDIDAH
            LD   DE,(CANDIDAG)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   Z,CANDIDAN
            JR   CANDIDAS
CANDIDAH:
            LD   DE,(CANDID10)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,CANDIDAS
            LD   HL,0
            LD   A,1
            LD   (CANDIDAE),A
            JR   CANDIDAL

CANDIDAS:
            LD   (CANDIDAF),HL
            CALL CANDIDA6
            JR   Z,CANDIDAJ
            LD   HL,(CANDIDAF)
            INC  HL
            JR   CANDIDAL

CANDIDAJ:
            LD   HL,(CANDIDAF)
            LD   (CANDIDA5),HL
            LD   A,(CANDIDAE)
            OR   A
            LD   A,CANDIDAV
            JR   Z,CANDIDAR
            LD   A,CANDIDAY
CANDIDAR:
            LD   (CANDIDAU),A
            OR   A
            RET

CANDIDAM:
            LD   A,CANDIDAX
            JR   CANDIDAI
CANDIDAN:
            LD   A,CANDIDAW
CANDIDAI:
            LD   (CANDIDAU),A
            CALL CANDIDAB
            SCF
            RET

;@ROUTINE in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA6:
            LD   (CANDIDAF),HL
            LD   A,(CANDIDA4)
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   DE,(CANDID10)
            OR   A
            SBC  HL,DE
            JR   C,CANDIDA7
            JR   Z,CANDIDA7
            LD   A,1
            OR   A
            RET
CANDIDA7:
            LD   HL,(CANDIDAF)
            LD   DE,CANDIDAZ
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
