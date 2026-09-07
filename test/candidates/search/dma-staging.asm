; Native ATOM historical experiment: search/dma-staging
; Historical debugger names are recorded in dma-staging.asm.symbols.json.
; Existing DMA storage stages edits; one dedicated buffer retains the query.

CANDID1V EQU $2000
CANDID1W EQU $1EC8
CANDIDAD EQU $1ECA
CANDID1O EQU $1ED3
CANDID1A EQU $1ED7
CANDID19 EQU $1ED9
CANDID18 EQU $1EDB
CANDIDAF EQU $1E48
CANDIDA4 EQU $F000
CANDIDAW EQU $F001
CANDIDAY EQU $F010
CANDIDAV EQU $F060

CANDIDAS EQU $1EE4
CANDIDAA EQU CANDIDAS
CANDIDA9 EQU CANDIDAA+1
CANDIDAR EQU CANDIDA9+64
CANDIDAU EQU 65
CANDID1N EQU CANDIDAF
CANDID1M EQU CANDIDAF+1
CANDIDA1 EQU CANDID1N
CANDIDAT EQU CANDID1M

            ORG $0100
CANDIDA7:
CANDID1U:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA3:
            LD   HL,CANDIDAA
            LD   DE,CANDID1N
            JP   CANDIDAC

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA8:
            LD   HL,CANDID1N
            LD   DE,CANDIDAA
            JP   CANDIDAC

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry
CANDIDA5:
            XOR  A
            RET
CANDID1T:

; Representation-independent query editing, prompt rendering, and forward scan.

CANDID10 EQU 64
CANDID1P EQU 1
CANDID1S EQU 2
CANDID1Q EQU 3
CANDID1R EQU 4

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDID14:
            XOR  A
            LD   (CANDIDAA),A
            LD   (CANDID1O),A
            LD   (CANDIDA4),A
            LD   HL,0
            LD   (CANDIDAD),HL
            RET

;@ROUTINE in HL,DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAC:
            LD   BC,CANDID10+1
            LDIR
            XOR  A
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA2:
            LD   C,A
            LD   A,(CANDIDA1)
            CP   CANDID10
            JR   NC,CANDIDAZ
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
CANDIDAE:
            LD   A,(CANDIDA1)
            OR   A
            JR   Z,CANDIDAZ
            DEC  A
            LD   (CANDIDA1),A
            OR   A
            RET

CANDIDAZ:
            CALL CANDID15
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDID15:
            LD   HL,CANDIDA4
            INC  (HL)
            RET

; One query-entry key. A successful ordinary edit returns A=0. Accepted Return
; returns A=1, Escape or empty Return returns A=2, and a rejected key returns
; with carry set after ringing once.
;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
CANDIDAI:
            CP   27
            JR   Z,CANDIDAK
            CP   13
            JR   Z,CANDIDAN
            CP   8
            JR   Z,CANDIDAL
            CP   127
            JR   Z,CANDIDAL
            CP   9
            JR   Z,CANDIDAJ
            CP   32
            JR   C,CANDIDAM
            CP   127
            JR   C,CANDIDAJ
CANDIDAM:
            CALL CANDID15
            SCF
            RET
CANDIDAL:
            CALL CANDIDAE
            RET  C
            XOR  A
            RET
CANDIDAJ:
            CALL CANDIDA2
            RET  C
            XOR  A
            RET
CANDIDAN:
            LD   A,(CANDIDA1)
            OR   A
            JR   Z,CANDIDAK
            CALL CANDIDA8
            LD   A,1
            OR   A
            RET
CANDIDAK:
            CALL CANDIDA5
            LD   A,2
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDID11:
            LD   HL,CANDIDAY
            LD   DE,CANDIDAY+1
            LD   BC,79
            LD   (HL),' '
            LDIR
            LD   HL,CANDIDAV
            LD   DE,CANDIDAV+1
            LD   BC,79
            LD   (HL),1
            LDIR
            LD   HL,CANDIDAX
            LD   DE,CANDIDAY
            LD   BC,6
            LDIR
            LD   A,(CANDIDA1)
            LD   B,A
            ADD  A,6
            LD   (CANDIDAW),A
            LD   A,B
            OR   A
            RET  Z
            LD   HL,CANDIDAT
            LD   DE,CANDIDAY+6
CANDID12:
            LD   A,(HL)
            CP   9
            JR   NZ,CANDID13
            LD   A,'>'
CANDID13:
            LD   (DE),A
            INC  HL
            INC  DE
            DJNZ CANDID12
            OR   A
            RET

CANDID17:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
CANDID1E:
            LD   A,(CANDIDAA)
            OR   A
            JR   Z,CANDID1G
            LD   HL,(CANDIDAD)
            JR   CANDID1J

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDID1I:
            LD   A,(CANDIDAA)
            OR   A
            JR   Z,CANDID1G
            LD   HL,(CANDIDAD)
            INC  HL

CANDID1J:
            XOR  A
            LD   (CANDID18),A
            LD   DE,(CANDID1W)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,CANDID1K
            LD   HL,0
            INC  A
            LD   (CANDID18),A
CANDID1K:
            LD   (CANDID19),HL
            LD   (CANDID1A),DE

CANDID1F:
            LD   HL,(CANDID1A)
            LD   A,H
            OR   L
            JR   Z,CANDID1H
            LD   HL,(CANDID19)
            CALL CANDIDAO
            JR   Z,CANDID1D
            LD   HL,(CANDID19)
            INC  HL
            LD   DE,(CANDID1W)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,CANDID1B
            LD   HL,0
            LD   A,1
            LD   (CANDID18),A
CANDID1B:
            LD   (CANDID19),HL
            LD   HL,(CANDID1A)
            DEC  HL
            LD   (CANDID1A),HL
            JR   CANDID1F

CANDID1D:
            LD   HL,(CANDID19)
            LD   (CANDIDAD),HL
            LD   A,(CANDID18)
            OR   A
            LD   A,CANDID1P
            JR   Z,CANDID1L
            LD   A,CANDID1S
CANDID1L:
            LD   (CANDID1O),A
            OR   A
            RET

CANDID1G:
            LD   A,CANDID1R
            JR   CANDID1C
CANDID1H:
            LD   A,CANDID1Q
CANDID1C:
            LD   (CANDID1O),A
            CALL CANDID15
            SCF
            RET

;@ROUTINE in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAO:
            LD   (CANDID19),HL
            LD   A,(CANDIDAA)
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   DE,(CANDID1W)
            OR   A
            SBC  HL,DE
            JR   C,CANDIDAP
            JR   Z,CANDIDAP
            LD   A,1
            OR   A
            RET
CANDIDAP:
            LD   HL,(CANDID19)
            LD   DE,CANDID1V
            ADD  HL,DE
            LD   DE,CANDIDA9
            LD   A,(CANDIDAA)
            LD   B,A
CANDIDAQ:
            LD   A,(DE)
            CP   (HL)
            RET  NZ
            INC  DE
            INC  HL
            DJNZ CANDIDAQ
            XOR  A
            RET
CANDID16:
CANDIDAB:

CANDIDAH:
CANDIDAX: DB "Find: "
CANDIDAG:

CANDIDA6:
