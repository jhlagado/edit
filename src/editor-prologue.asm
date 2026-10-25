; Entry jump precedes the ordered editor modules.
            ORG CODEBASE
; EditorTransientStart
TRASTA:
            JP   ENTRY

; Patchable configuration at $0103: tag, layout version, columns, rows and
; flags. The probe flag selects the TEC-OS console geometry when present.
; EditorConfig
CONFIG:     DB "ECFG",1
; EditorConfigColumns
CFGCOL:     DB 80
; EditorConfigRows
CFGROW:     DB 24
; EditorConfigFlags
CFGFLA:     DB CFGPRO

; EditorCodeStart
CODSTA:
