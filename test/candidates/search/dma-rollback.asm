; Native ATOM historical experiment: search/dma-rollback
; Historical debugger names are recorded in dma-rollback.asm.symbols.json.
; One active query buffer; existing DMA storage holds its cancellation snapshot.

CANDID1V EQU $2000
CANDID1W EQU $1EC8
CANDIDAF EQU $1ECA
CANDID1O EQU $1ED3
CANDID1C EQU $1ED7
CANDID1B EQU $1ED9
CANDID1A EQU $1EDB
CANDIDAH EQU $1E48
CANDIDA6 EQU $F000
CANDIDAY EQU $F001
CANDID10 EQU $F010
CANDIDAX EQU $F060

CANDIDAV EQU $1EE4
CANDIDAC EQU CANDIDAV
CANDIDAB EQU CANDIDAC+1
CANDIDAU EQU CANDIDAB+64
CANDIDAW EQU 65
CANDIDA4 EQU CANDIDAH
CANDIDA3 EQU CANDIDAH+1
CANDIDA1 EQU CANDIDAC
CANDIDAT EQU CANDIDAB

            ORG $0100
CANDIDA9:
CANDID1U:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA5:
            LD   HL,CANDIDAC
            LD   DE,CANDIDA4
            JP   CANDIDAE

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry
CANDIDAA:
            XOR  A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA7:
            LD   HL,CANDIDA4
            LD   DE,CANDIDAC
            JP   CANDIDAE
CANDID1T:

; Representation-independent query editing, prompt rendering, and forward scan.

CANDID12 EQU 64
CANDID1P EQU 1
CANDID1S EQU 2
CANDID1Q EQU 3
CANDID1R EQU 4

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDID16:
            XOR  A
            LD   (CANDIDAC),A
            LD   (CANDID1O),A
            LD   (CANDIDA6),A
            LD   HL,0
            LD   (CANDIDAF),HL
            RET

;@ROUTINE in HL,DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAE:
            LD   BC,CANDID12+1
            LDIR
            XOR  A
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA2:
            LD   C,A
            LD   A,(CANDIDA1)
            CP   CANDID12
            JR   NC,CANDID11
            LD   E,A
            LD   D,0
            LD   HL,CANDIDAT
            ADD  HL,DE
            LD   (HL),C
            LD   A,E
            INC  A
            LD   (CANDIDA1),A
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDIDAG:
            LD   A,(CANDIDA1)
            OR   A
            JR   Z,CANDID11
            DEC  A
            LD   (CANDIDA1),A
            OR   A
            RET

CANDID11:
            CALL CANDID17
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDID17:
            LD   HL,CANDIDA6
            INC  (HL)
            RET

; One query-entry key. A successful ordinary edit returns A=0. Accepted Return
; returns A=1, Escape or empty Return returns A=2, and a rejected key returns
; with carry set after ringing once.
;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
CANDIDAK:
            CP   27
            JR   Z,CANDIDAM
            CP   13
            JR   Z,CANDIDAP
            CP   8
            JR   Z,CANDIDAN
            CP   127
            JR   Z,CANDIDAN
            CP   9
            JR   Z,CANDIDAL
            CP   32
            JR   C,CANDIDAO
            CP   127
            JR   C,CANDIDAL
CANDIDAO:
            CALL CANDID17
            SCF
            RET
CANDIDAN:
            CALL CANDIDAG
            RET  C
            XOR  A
            RET
CANDIDAL:
            CALL CANDIDA2
            RET  C
            XOR  A
            RET
CANDIDAP:
            LD   A,(CANDIDA1)
            OR   A
            JR   Z,CANDIDAM
            CALL CANDIDAA
            LD   A,1
            OR   A
            RET
CANDIDAM:
            CALL CANDIDA7
            LD   A,2
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDID13:
            LD   HL,CANDID10
            LD   DE,CANDID10+1
            LD   BC,79
            LD   (HL),' '
            LDIR
            LD   HL,CANDIDAX
            LD   DE,CANDIDAX+1
            LD   BC,79
            LD   (HL),1
            LDIR
            LD   HL,CANDIDAZ
            LD   DE,CANDID10
            LD   BC,6
            LDIR
            LD   A,(CANDIDA1)
            LD   B,A
            ADD  A,6
            LD   (CANDIDAY),A
            LD   A,B
            OR   A
            RET  Z
            LD   HL,CANDIDAT
            LD   DE,CANDID10+6
CANDID14:
            LD   A,(HL)
            CP   9
            JR   NZ,CANDID15
            LD   A,'>'
CANDID15:
            LD   (DE),A
            INC  HL
            INC  DE
            DJNZ CANDID14
            OR   A
            RET

CANDID19:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
CANDID1G:
            LD   A,(CANDIDAC)
            OR   A
            JR   Z,CANDID1I
            LD   HL,(CANDIDAF)
            JR   CANDID1L

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDID1K:
            LD   A,(CANDIDAC)
            OR   A
            JR   Z,CANDID1I
            LD   HL,(CANDIDAF)
            INC  HL

CANDID1L:
            XOR  A
            LD   (CANDID1A),A
            LD   DE,(CANDID1W)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,CANDID1M
            LD   HL,0
            INC  A
            LD   (CANDID1A),A
CANDID1M:
            LD   (CANDID1B),HL
            LD   (CANDID1C),DE

CANDID1H:
            LD   HL,(CANDID1C)
            LD   A,H
            OR   L
            JR   Z,CANDID1J
            LD   HL,(CANDID1B)
            CALL CANDIDAQ
            JR   Z,CANDID1F
            LD   HL,(CANDID1B)
            INC  HL
            LD   DE,(CANDID1W)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,CANDID1D
            LD   HL,0
            LD   A,1
            LD   (CANDID1A),A
CANDID1D:
            LD   (CANDID1B),HL
            LD   HL,(CANDID1C)
            DEC  HL
            LD   (CANDID1C),HL
            JR   CANDID1H

CANDID1F:
            LD   HL,(CANDID1B)
            LD   (CANDIDAF),HL
            LD   A,(CANDID1A)
            OR   A
            LD   A,CANDID1P
            JR   Z,CANDID1N
            LD   A,CANDID1S
CANDID1N:
            LD   (CANDID1O),A
            OR   A
            RET

CANDID1I:
            LD   A,CANDID1R
            JR   CANDID1E
CANDID1J:
            LD   A,CANDID1Q
CANDID1E:
            LD   (CANDID1O),A
            CALL CANDID17
            SCF
            RET

;@ROUTINE in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAQ:
            LD   (CANDID1B),HL
            LD   A,(CANDIDAC)
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   DE,(CANDID1W)
            OR   A
            SBC  HL,DE
            JR   C,CANDIDAR
            JR   Z,CANDIDAR
            LD   A,1
            OR   A
            RET
CANDIDAR:
            LD   HL,(CANDID1B)
            LD   DE,CANDID1V
            ADD  HL,DE
            LD   DE,CANDIDAB
            LD   A,(CANDIDAC)
            LD   B,A
CANDIDAS:
            LD   A,(DE)
            CP   (HL)
            RET  NZ
            INC  DE
            INC  HL
            DJNZ CANDIDAS
            XOR  A
            RET
CANDID18:
CANDIDAD:

CANDIDAJ:
CANDIDAZ: DB "Find: "
CANDIDAI:

CANDIDA8:
