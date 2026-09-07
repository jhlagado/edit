; Native ATOM historical experiment: search/dedicated
; Historical debugger names are recorded in dedicated.asm.symbols.json.
; Dedicated committed and staging query buffers.

CANDID1U EQU $2000
CANDID1V EQU $1EC8
CANDIDAD EQU $1ECA
CANDID1N EQU $1ED3
CANDID19 EQU $1ED7
CANDID18 EQU $1ED9
CANDID17 EQU $1EDB
CANDIDA4 EQU $F000
CANDIDAV EQU $F001
CANDIDAX EQU $F010
CANDIDAU EQU $F060

CANDIDAR EQU $1EE4
CANDIDAA EQU CANDIDAR
CANDIDA9 EQU CANDIDAA+1
CANDID1M EQU CANDIDA9+64
CANDID1L EQU CANDID1M+1
CANDIDAQ EQU CANDID1L+64
CANDIDAS EQU 0
CANDIDA1 EQU CANDID1M
CANDIDAT EQU CANDID1L

            ORG $0100
CANDIDA7:
CANDID1T:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA3:
            LD   HL,CANDIDAA
            LD   DE,CANDID1M
            JP   CANDIDAC

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA8:
            LD   HL,CANDID1M
            LD   DE,CANDIDAA
            JP   CANDIDAC

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry
CANDIDA5:
            XOR  A
            RET
CANDID1S:

; Representation-independent query editing, prompt rendering, and forward scan.

CANDIDAZ EQU 64
CANDID1O EQU 1
CANDID1R EQU 2
CANDID1P EQU 3
CANDID1Q EQU 4

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDID13:
            XOR  A
            LD   (CANDIDAA),A
            LD   (CANDID1N),A
            LD   (CANDIDA4),A
            LD   HL,0
            LD   (CANDIDAD),HL
            RET

;@ROUTINE in HL,DE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAC:
            LD   BC,CANDIDAZ+1
            LDIR
            XOR  A
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDA2:
            LD   C,A
            LD   A,(CANDIDA1)
            CP   CANDIDAZ
            JR   NC,CANDIDAY
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
            JR   Z,CANDIDAY
            DEC  A
            LD   (CANDIDA1),A
            OR   A
            RET

CANDIDAY:
            CALL CANDID14
            SCF
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,HL
CANDID14:
            LD   HL,CANDIDA4
            INC  (HL)
            RET

; One query-entry key. A successful ordinary edit returns A=0. Accepted Return
; returns A=1, Escape or empty Return returns A=2, and a rejected key returns
; with carry set after ringing once.
;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
CANDIDAH:
            CP   27
            JR   Z,CANDIDAJ
            CP   13
            JR   Z,CANDIDAM
            CP   8
            JR   Z,CANDIDAK
            CP   127
            JR   Z,CANDIDAK
            CP   9
            JR   Z,CANDIDAI
            CP   32
            JR   C,CANDIDAL
            CP   127
            JR   C,CANDIDAI
CANDIDAL:
            CALL CANDID14
            SCF
            RET
CANDIDAK:
            CALL CANDIDAE
            RET  C
            XOR  A
            RET
CANDIDAI:
            CALL CANDIDA2
            RET  C
            XOR  A
            RET
CANDIDAM:
            LD   A,(CANDIDA1)
            OR   A
            JR   Z,CANDIDAJ
            CALL CANDIDA8
            LD   A,1
            OR   A
            RET
CANDIDAJ:
            CALL CANDIDA5
            LD   A,2
            OR   A
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDID10:
            LD   HL,CANDIDAX
            LD   DE,CANDIDAX+1
            LD   BC,79
            LD   (HL),' '
            LDIR
            LD   HL,CANDIDAU
            LD   DE,CANDIDAU+1
            LD   BC,79
            LD   (HL),1
            LDIR
            LD   HL,CANDIDAW
            LD   DE,CANDIDAX
            LD   BC,6
            LDIR
            LD   A,(CANDIDA1)
            LD   B,A
            ADD  A,6
            LD   (CANDIDAV),A
            LD   A,B
            OR   A
            RET  Z
            LD   HL,CANDIDAT
            LD   DE,CANDIDAX+6
CANDID11:
            LD   A,(HL)
            CP   9
            JR   NZ,CANDID12
            LD   A,'>'
CANDID12:
            LD   (DE),A
            INC  HL
            INC  DE
            DJNZ CANDID11
            OR   A
            RET

CANDID16:
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IXH,IXL,IYH,IYL
CANDID1D:
            LD   A,(CANDIDAA)
            OR   A
            JR   Z,CANDID1F
            LD   HL,(CANDIDAD)
            JR   CANDID1I

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDID1H:
            LD   A,(CANDIDAA)
            OR   A
            JR   Z,CANDID1F
            LD   HL,(CANDIDAD)
            INC  HL

CANDID1I:
            XOR  A
            LD   (CANDID17),A
            LD   DE,(CANDID1V)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,CANDID1J
            LD   HL,0
            INC  A
            LD   (CANDID17),A
CANDID1J:
            LD   (CANDID18),HL
            LD   (CANDID19),DE

CANDID1E:
            LD   HL,(CANDID19)
            LD   A,H
            OR   L
            JR   Z,CANDID1G
            LD   HL,(CANDID18)
            CALL CANDIDAN
            JR   Z,CANDID1C
            LD   HL,(CANDID18)
            INC  HL
            LD   DE,(CANDID1V)
            PUSH HL
            OR   A
            SBC  HL,DE
            POP  HL
            JR   C,CANDID1A
            LD   HL,0
            LD   A,1
            LD   (CANDID17),A
CANDID1A:
            LD   (CANDID18),HL
            LD   HL,(CANDID19)
            DEC  HL
            LD   (CANDID19),HL
            JR   CANDID1E

CANDID1C:
            LD   HL,(CANDID18)
            LD   (CANDIDAD),HL
            LD   A,(CANDID17)
            OR   A
            LD   A,CANDID1O
            JR   Z,CANDID1K
            LD   A,CANDID1R
CANDID1K:
            LD   (CANDID1N),A
            OR   A
            RET

CANDID1F:
            LD   A,CANDID1Q
            JR   CANDID1B
CANDID1G:
            LD   A,CANDID1P
CANDID1B:
            LD   (CANDID1N),A
            CALL CANDID14
            SCF
            RET

;@ROUTINE in HL out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
CANDIDAN:
            LD   (CANDID18),HL
            LD   A,(CANDIDAA)
            LD   E,A
            LD   D,0
            ADD  HL,DE
            LD   DE,(CANDID1V)
            OR   A
            SBC  HL,DE
            JR   C,CANDIDAO
            JR   Z,CANDIDAO
            LD   A,1
            OR   A
            RET
CANDIDAO:
            LD   HL,(CANDID18)
            LD   DE,CANDID1U
            ADD  HL,DE
            LD   DE,CANDIDA9
            LD   A,(CANDIDAA)
            LD   B,A
CANDIDAP:
            LD   A,(DE)
            CP   (HL)
            RET  NZ
            INC  DE
            INC  HL
            DJNZ CANDIDAP
            XOR  A
            RET
CANDID15:
CANDIDAB:

CANDIDAG:
CANDIDAW: DB "Find: "
CANDIDAF:

CANDIDA6:
