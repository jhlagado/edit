; Transient entry, raw-key dispatcher, and CP/M exit.

; CpmWarmBoot
WARMBOOT    EQU $0000
; CpmBdosVector
BDOSVEC     EQU $0006

; EditorMainCodeStart
MAICODST:
; The private stack ends just below the BDOS address and may overwrite the
; CCP, so every exit after the stack switch is a warm boot. A TPA too small for
; the minimum arena returns to the CCP before any memory is written.
;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
; EditorEntry
ENTRY:
            LD   HL,(BDOSVEC)
            LD   DE,MINTOP
            OR   A
            SBC  HL,DE
            JR   C,ENTMEM
            LD   SP,(BDOSVEC)
            LD   HL,(BDOSVEC)
            LD   DE,STASIZ
            SBC  HL,DE
            CALL DOCSETLI
            CALL RUN
            JP   WARMBOOT
; EditorEntryMemory
ENTMEM:
            LD   DE,ERRPRE
            CALL OUTTEX
            LD   DE,MEMTEX
            JP   OUTTEX

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL,IX,IY
; EditorRun
RUN:
            CALL SELSCR
            CALL PRECOM
            JP   C,RUNERROR
            CALL LOADFILE
            JP   C,RUNERROR
            CALL RENDER
; EditorMainLoop
MAINLOOP:
            CALL READBYTE
            CP   17
            JP   Z,COMQUI
            PUSH AF
            LD   A,(FLAGS)
            AND  $FD
            LD   (FLAGS),A
            POP  AF
            CP   19
            JR   Z,COMSAV
            CP   6
            JR   Z,COMSEA
            CP   14
            JR   Z,COMSEARE
            CP   18
            JR   Z,COMREP
            CP   27
            JR   Z,COMESC
            CP   13
            JR   Z,COMNEW
            CP   8
            JR   Z,COMBAC
            CP   127
            JR   Z,COMDEL
            CP   9
            JR   Z,COMINS
            CP   32
            JR   C,COMUNS
            CP   127
            JR   NC,COMUNS
; EditorCommandInsert
COMINS:
            LD   E,A
            LD   A,OPINSERT
            CALL SESEXE
            JR   COMCOM
; EditorCommandNewline
COMNEW:
            LD   A,OPNEW
            CALL SESEXE
            JR   COMCOM
; EditorCommandBackspace
COMBAC:
            LD   A,OPBAC
            CALL SESEXE
            JR   COMCOM
; EditorCommandDelete
COMDEL:
            LD   A,OPDELETE
            CALL SESEXE
            JR   COMCOM
; EditorCommandSave
COMSAV:
            CALL SAVE
            JR   COMCOM
; EditorCommandSearch
COMSEA:
            CALL SEABEG
            JR   COMCOM
; EditorCommandSearchRepeat
COMSEARE:
            LD   A,OPFINNEX
            CALL SESEXE
            JR   COMCOM
; EditorCommandReplace
COMREP:
            CALL REPBEG
            JR   COMCOM
; EditorCommandEscape
COMESC:
            CALL REAESCBY
            JR   C,COMUNS
            CP   '['
            JR   NZ,COMUNS
            CALL REAESCBY
            JR   C,COMUNS
            CP   'A'
            JR   Z,COMUP
            CP   'B'
            JR   Z,COMDOW
            CP   'C'
            JR   Z,COMRIG
            CP   'D'
            JR   NZ,COMUNS
            LD   A,OPLEFT
            CALL SESEXE
            JR   COMCOM
; EditorCommandUp
COMUP:
            LD   A,OPUP
            CALL SESEXE
            JR   COMCOM
; EditorCommandDown
COMDOW:
            LD   A,OPDOWN
            CALL SESEXE
            JR   COMCOM
; EditorCommandRight
COMRIG:
            LD   A,OPRIGHT
            CALL SESEXE
            JR   COMCOM
; EditorCommandUnsupported
COMUNS:
            CALL BUFBOU
; EditorCommandComplete
COMCOM:
            JR   NC,COMREN
            LD   A,7
            CALL OUTBYT
; EditorCommandRender
COMREN:
            CALL PRESENT
            JP   MAINLOOP

; EditorCommandQuit
COMQUI:
            LD   A,(FLAGS)
            AND  FLADIR
            JR   Z,COMEXI
            LD   A,(FLAGS)
            AND  FLACONQU
            JR   NZ,COMEXI
            LD   A,(FLAGS)
            OR   FLACONQU
            LD   (FLAGS),A
            LD   A,STADIS
            LD   (STATUS),A
            CALL PRESENT
            JP   MAINLOOP
; EditorCommandExit
COMEXI:
            LD   DE,CLEHOM
            JP   OUTTEX

; EditorRunError
RUNERROR:
            PUSH AF
            LD   DE,ERRPRE
            CALL OUTTEX
            POP  AF
            PUSH AF
            RRCA
            RRCA
            RRCA
            RRCA
            CALL PRIHEXNI
            POP  AF
            CALL PRIHEXNI
            LD   DE,NEWLINE
            JP   OUTTEX

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorReadByte
READBYTE:
            LD   DE,$00FF
            LD   C,6
            CALL CALLBDOS
            OR   A
            JR   Z,READBYTE
            RET

;@ROUTINE out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorReadEscapeByte
REAESCBY:
            LD   HL,256
            LD   (SCRATCHA),HL
; EditorReadEscapeLoop
REAESCLO:
            LD   DE,$00FF
            LD   C,6
            CALL CALLBDOS
            OR   A
            RET  NZ
            LD   HL,(SCRATCHA)
            DEC  HL
            LD   (SCRATCHA),HL
            LD   A,H
            OR   L
            JR   NZ,REAESCLO
            SCF
            RET

;@ROUTINE in A out A,carry,zero clobbers sign,parity,halfCarry,BC,DE,HL
; EditorPrintHexNibble
PRIHEXNI:
            AND  $0F
            ADD  A,'0'
            CP   '9'+1
            JP   C,OUTBYT
            ADD  A,7
            JP   OUTBYT
; EditorMainCodeEnd
MAICODEN:
