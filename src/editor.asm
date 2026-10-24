; Portable full-screen editor for CP/M-compatible Z80 systems.

            .include "editor-memory.asmi"

            .org EditorCodeBase
EditorTransientStart:
            JP   EditorEntry

; Patchable configuration at $0103: tag, layout version, columns, rows, and
; flags. The probe flag selects the TEC-OS console geometry when it is present.
EditorConfig:             .db "ECFG",1
EditorConfigColumns:      .db 80
EditorConfigRows:         .db 24
EditorConfigFlags:        .db EditorConfigProbe

EditorCodeStart:
            .include "editor-bdos.asm"
            .include "editor-command.asm"
            .include "editor-load.asm"
            .include "editor-buffer.asm"
            .include "editor-navigation.asm"
            .include "editor-screen.asm"
            .include "editor-save.asm"
            .include "editor-search.asm"
            .include "editor-replace.asm"
            .include "editor-main.asm"
EditorCodeEnd:

EditorImmutableStart:
EditorBackupExtension:    .db "BAK"
EditorTemporaryExtension: .db "$$$"
EditorErrorPrefix:        .db 13,10,"EDIT error ","$"
EditorMemoryText:         .db "06 TPA too small",13,10,"$"
EditorAbiTag:             .db "TNA"
EditorNewline:            .db 13,10,"$"
EditorClearHome:          .db 27,"[2J",27,"[H","$"
EditorStatusPosition:     .db ";1H",27,"[7m","$"
EditorReverseOff:         .db 27,"[0m",27,"[","$"
EditorStatusPrefix:       .db "EDIT ",0
EditorStatusHints:        .db "  ^S Save  ^Q Quit",0
EditorStatusHintsLength   .equ 18
EditorStatusSavedText:    .db "Saved  ",0
EditorStatusFullText:     .db "Full  ",0
EditorStatusDiscardText:  .db "Discard changes? ^Q again  ",0
EditorStatusSaveFailedText: .db "Save failed ",0
EditorStatusFoundText:    .db "Found",0
EditorStatusWrappedText:  .db "Wrapped",0
EditorStatusNotFoundText: .db "Not found",0
EditorStatusNoSearchText: .db "No search",0
; The default FCB's leading drive byte also terminates the replacement status.
EditorStatusReplacedText: .db "Replaced"
EditorDefaultName:        .db 0,"INPUT   ","NU "
EditorSearchPrompt:       .db "Find: ",0
EditorReplacePrompt:      .db "Replace: ",0
EditorImmutableEnd:
EditorResidentEnd:
            .end
