; Memory partition for the native CP/M editor. The code, workspace, shadow
; screens and text base are fixed. The BDOS address in the word at $0006 is
; the exclusive top of the private stack; the text arena ends where the stack
; begins.

; EditorCodeBase
CODEBASE       EQU $0100
; EditorCodeLimit
CODLIM      EQU $2000
; EditorWorkspaceBase
WORBAS  EQU $2000
; EditorWorkspaceLimit
WORLIM EQU $2200
; EditorStackSize
STASIZ      EQU 256
; EditorTextMinimum
TEXMIN      EQU 1024

; Supported screen sizes. Selected sizes outside them are clamped.
; EditorMinimumColumns
MINCOL      EQU 20
; EditorMaximumColumns
MAXCOL      EQU 80
; EditorMinimumRows
MINROW      EQU 4
; EditorMaximumRows
MAXROW      EQU 24

; The wanted and shown screens, MAXCOL cells a row (the row arithmetic in
; TRMWAD assumes 80), one written-since-flush flag per row, and the shadow
; screen's state, which does not fit the fixed workspace.
; EditorScreenWant
SCRWAN      EQU WORLIM
; EditorScreenDirty
SCRDIR      EQU SCRWAN+2*MAXCOL*MAXROW
; 1 while presentation output goes through the shadow screen.
; EditorTerminalShadow
TRMSHA EQU SCRDIR+MAXROW
; Where the presentation's output cursor is, and its attribute.
; EditorTerminalRow
TRMROW EQU TRMSHA+1
; EditorTerminalColumn
TRMCOL EQU TRMROW+1
; EditorTerminalAttr
TRMATT EQU TRMCOL+1
; EditorTerminalEscape
TRMESC EQU TRMATT+1
; EditorTerminalParameter
TRMPAR EQU TRMESC+1
; EditorTerminalSecond
TRMPA2 EQU TRMPAR+1
; Where the terminal's cursor is, and its attribute.
; EditorPhysicalRow
PHYROW EQU TRMPA2+1
; EditorPhysicalColumn
PHYCOL EQU PHYROW+1
; EditorPhysicalAttribute
PHYATT EQU PHYCOL+1
; Bytes from TerminalRow to PhysicalAttribute, cleared when the shadow starts.
; EditorTerminalStateBytes
TRMSTAN EQU 9
; Row flush scratch: the row, its wanted cells, the first differing cell, one
; past the last, the send limit and one past the last kept cell.
; EditorTerminalFlushRowIndex
TRMFR EQU PHYATT+1
; EditorTerminalWantPointer
TRMWP EQU TRMFR+1
; EditorTerminalFirstCell
TRMFC EQU TRMWP+2
; EditorTerminalLastLimit
TRMLL EQU TRMFC+1
; EditorTerminalSendLimit
TRMKK EQU TRMLL+1
; EditorTerminalKeepLimit
TRMKB EQU TRMKK+1
; 1 when the terminal is TEC-OS's video console, which inserts and deletes
; characters (ESC [ @ and ESC [ P).
; EditorTerminalInsertDelete
TRMICH EQU TRMKB+1
; Registers kept across a direct console write, off the stack, so the flush
; stays within the stack the rest of the editor needs.
; EditorTerminalSave
TRMSAV EQU TRMICH+1
; M or L when the presenter moved the text up or down a line and the flush
; should move the terminal's rows without comparing; 0 otherwise.
; EditorTerminalMoveHint
TRMHINT EQU TRMSAV+6
; EditorTextBase
TEXTBASE       EQU TRMHINT+1
; Lowest BDOS address that leaves the minimum arena below the private stack.
; EditorMinimumTop
MINTOP      EQU TEXTBASE+TEXMIN+STASIZ

; EditorConfigProbe
CFGPRO      EQU 1

; EditorFcb
FCB            EQU WORBAS
; EditorTransactionFcb
TRAFCB EQU FCB+36
; EditorDma
DMA            EQU TRAFCB+36

; EditorLength
LENGTH         EQU DMA+128
; EditorCursor
CURSOR         EQU LENGTH+2
; EditorTop
TOP            EQU CURSOR+2
; EditorHorizontal
HOR     EQU TOP+2
; EditorDesiredColumn
DESCOL  EQU HOR+2
; EditorFlags
FLAGS          EQU DESCOL+2
; EditorStatus
STATUS         EQU FLAGS+1
; Loading and interactive search never overlap. A successful load has already
; reduced the pending-CR state to zero, which also resets the committed query.
; EditorLoadPendingCr
LOAPENCR  EQU STATUS+1
; EditorQueryLength
QUELEN    EQU LOAPENCR
; EditorQueryBuffer
QUEBUF    EQU QUELEN+1
; EditorQueryCapacity
QUECAP  EQU 64
; EditorSaveState
SAVSTA      EQU QUEBUF+QUECAP
; EditorScratchA
SCRATCHA       EQU SAVSTA+1
; EditorScratchB
SCRATCHB       EQU SCRATCHA+2
; EditorScratchC
SCRATCHC       EQU SCRATCHB+2
; EditorRenderPointer
RENPOI  EQU SCRATCHC+2
; EditorRenderColumn
RENCOL   EQU RENPOI+2
; EditorRenderCount
RENCOU    EQU RENCOL+2
; EditorCursorScreenRow
CURSCRRO EQU RENCOU+2
; EditorCursorScreenColumn
CURSCRCO EQU CURSCRRO+1
; Visual columns need 19 bits for a tab-only arena that reaches $FFFF.
; Keep low words in their existing slots; byte offsets remain 16-bit.
; EditorHorizontalHigh
HORHIG EQU CURSCRCO+1
; EditorDesiredColumnHigh
DESCOLHI EQU HORHIG+1
; EditorRenderColumnHigh
RENCOLHI EQU DESCOLHI+1
; EditorColumnHigh
COLHIG     EQU RENCOLHI+1
; EditorTargetColumnHigh
TARCOLHI EQU COLHIG+1
; EditorLegacyWorkspaceEnd
LEGWOREN EQU TARCOLHI+1

; Document-owned request, result and scratch. No session scratch is borrowed.
; EditorDocumentStart
DOCSTA       EQU LEGWOREN
; EditorDocumentRemove
DOCREM      EQU DOCSTA+2
; EditorDocumentInput
DOCINP       EQU DOCREM+2
; EditorDocumentInsert
DOCINS      EQU DOCINP+2
; EditorDocChangeStart
DOCCHAST       EQU DOCINS+2
; EditorDocChangeRemoved
DOCCHARE     EQU DOCCHAST+2
; EditorDocChangeInserted
DOCCHAIN    EQU DOCCHARE+2
; EditorDocChangeFlags
DOCCHAFL       EQU DOCCHAIN+2
; EditorDocumentEnd
DOCEND         EQU DOCCHAFL+1
; EditorDocumentNewLength
DOCNEWLE   EQU DOCEND+2
; EditorDocumentTail
DOCTAI        EQU DOCNEWLE+2
; EditorDocumentWorkFlags
DOCWORFL   EQU DOCTAI+2
; EditorDocumentRangeOffset
DOCRANOF EQU DOCWORFL+1
; EditorDocumentRangeTarget
DOCRANTA EQU DOCRANOF+2
; EditorDocumentRangeCount
DOCRANCO  EQU DOCRANTA+2
; EditorDocumentMatchOffset
DOCMATOF EQU DOCRANCO+2
; EditorDocumentMatchInput
DOCMATIN  EQU DOCMATOF+2
; EditorDocumentMatchCount
DOCMATCO  EQU DOCMATIN+2
; Arena-relative gap bounds: [GapStart, GapEnd) is unused storage.
; EditorDocumentGapStart
DOCGAPST    EQU DOCMATCO+1
; EditorDocumentGapEnd
DOCGAPEN      EQU DOCGAPST+2
; EditorDocumentPendingChanges
DOCPENCH EQU DOCGAPEN+2
; Arena limit and capacity derived from the BDOS address at entry.
; EditorTextLimit
TEXLIM EQU DOCPENCH+1
; EditorTextCapacity
TEXCAP EQU TEXLIM+2
; EditorDocumentWorkspaceEnd
DOCWOREN EQU TEXCAP+2

; EditorDocumentErrorRange
DOCERRRA    EQU 1
; EditorDocumentErrorText
DOCERRTE     EQU 2
; EditorDocumentErrorCapacity
DOCERRCA EQU 3
; EditorDocumentErrorAlias
DOCERRAL    EQU 4

; EditorSessionOpcode
SESOPC EQU DOCWOREN
; EditorSessionByte
SESBYT EQU SESOPC+1
; EditorSessionOldCursor
SESOLDCU EQU SESBYT+1
; EditorSessionOldFlags
SESOLDFL EQU SESOLDCU+2
; EditorSessionOldStatus
SESOLDST EQU SESOLDFL+1
; EditorSessionOutcome
SESOUT EQU SESOLDST+1
; EditorSessionResultFlags
SESRESFL EQU SESOUT+1
; EditorSessionWorkspaceEnd
SESWOREN EQU SESRESFL+1

; Bounded viewport cache. No scratch here is shared with prompts or BDOS.
; EditorLayoutBoundaries
LAYBOU EQU SESWOREN
; EditorLayoutAnchors
LAYANC EQU LAYBOU+48
; Each anchor: word logical offset + phase0..7 relative to OriginHorizontal;
; or word end-column + tag$80|high3; $FF means undiscovered.
; EditorLayoutCursor
LAYCUR EQU LAYANC+69
; EditorLayoutColumn
LAYCOL EQU LAYCUR+2
; EditorLayoutCursorRow
LAYCURRO EQU LAYCOL+3
; EditorLayoutOriginHorizontal
LAYORIHO EQU LAYCURRO+1
; EditorLayoutOriginTop
LAYORITO EQU LAYORIHO+3
; Zero-based number of LF bytes before OriginTop. Bit 2 of LayoutFlags says
; this cached line count is valid. Keeping it separate from the visible-row
; cache lets the status line report an absolute source line without scanning
; the whole document on every ordinary keypress.
; EditorLayoutTopLine
LAYTOPLI EQU LAYORITO+2
; EditorLayoutRowCount
LAYROWCO EQU LAYTOPLI+2
; EditorLayoutFlags
LAYFLA EQU LAYROWCO+1
; EditorLayoutRowEnd
LAYROWEN EQU LAYFLA+1
; EditorLayoutScanPointer
LAYSCAPO EQU LAYROWEN+2
; EditorLayoutScanColumn
LAYSCACO EQU LAYSCAPO+2
; EditorLayoutIndex
LAYIND EQU LAYSCACO+3
; EditorLayoutDamage
LAYDAM EQU LAYIND+1
; EditorLayoutFirst
LAYFIR EQU LAYDAM+1
; EditorLayoutDelta
LAYDEL EQU LAYFIR+1
; EditorLayoutWorkspaceEnd
LAYWOREN EQU LAYDEL+2

; EditorDisplayLastFlags
DISLASFL EQU LAYWOREN
; EditorDisplayLastStatus
DISLASST EQU DISLASFL+1
; EditorDisplayStatusValid
DISSTAVA EQU DISLASST+1
; EditorDisplayLastCursor
DISLASCU EQU DISSTAVA+1
; EditorDisplayRow
DISROW EQU DISLASCU+2
; EditorDisplayEndRow
DISENDRO EQU DISROW+1
; Selected screen width and the number of text rows above the status row.
; EditorColumns
COLUMNS EQU DISENDRO+1
; EditorTextRows
TEXROWS EQU COLUMNS+1
; Cells taken by the pending status message and its separator; zero for none.
; EditorStatusMessageCells
STAMESCE EQU TEXROWS+1
; A one-line scroll found by the viewport check, for Prepare to report:
; 4 when the text moved up, 5 when it moved down, 0 for none.
; EditorLayoutScrollMove
LAYSCRMV EQU STAMESCE+1
; EditorWorkspaceEnd
WOREND EQU LAYSCRMV+1

; EditorOpInsert
OPINSERT EQU 0
; EditorOpNewline
OPNEW EQU 1
; EditorOpBackspace
OPBAC EQU 2
; EditorOpDelete
OPDELETE EQU 3
; EditorOpLeft
OPLEFT EQU 4
; EditorOpRight
OPRIGHT EQU 5
; EditorOpUp
OPUP EQU 6
; EditorOpDown
OPDOWN EQU 7
; EditorOpFind
OPFIND EQU 8
; EditorOpFindNext
OPFINNEX EQU 9
; EditorOpReplace
OPREP EQU 10

; EditorFlagDirty
FLADIR        EQU 1
; EditorFlagConfirmQuit
FLACONQU  EQU 2
; EditorFlagDesiredValid
FLADESVA EQU 4
; EditorFlagNew
FLAGNEW          EQU $80

; EditorStatusReady
STAREA       EQU 0
; EditorStatusSaved
STASAV       EQU 1
; EditorStatusFull
STAFUL        EQU 2
; EditorStatusBoundary
STABOU    EQU 3
; EditorStatusDiscard
STADIS     EQU 4
; EditorStatusUnnamed
STAUNNAM   EQU 5
; Search statuses carry a high-bit tag and half the byte offset of their
; contiguous message. ADD A,A both classifies the tag and recovers the offset.
; EditorStatusFound
STAFOU       EQU $80
; EditorStatusWrapped
STAWRA     EQU $83
; EditorStatusNotFound
STANOTFO    EQU $87
; EditorStatusNoSearch
STANOSEA    EQU $8C
; EditorStatusReplaced
STAREP    EQU $91
; EditorStatusSaveConflict
STASAVCO EQU $10
; EditorStatusSaveCreate
STASAVCR  EQU $11
; EditorStatusSaveWrite
STASAVWR   EQU $12
; EditorStatusSaveClose
STASAVCL   EQU $13
; EditorStatusSaveRename
STASAVRE  EQU $14
; EditorStatusSaveRollback
STASAVRO EQU $15

; EditorErrorCommand
ERRCOM  EQU 1
; EditorErrorNotFound
ERRNOTFO EQU 2
; EditorErrorText
ERRTEX     EQU 3
; EditorErrorCapacity
ERRCAP EQU 4
; EditorErrorStorage
ERRSTO  EQU 5
