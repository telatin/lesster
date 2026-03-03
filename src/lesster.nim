## lesster – a ``less``-like interactive text pager library for Nim.
##
## Exports the public API for embedding the pager in other Nim programs:
##
## - `viewText <#viewText,seq[string],string,string>`_ – display an in-memory
##   sequence of lines.
## - `viewFile <#viewFile,string,string,string>`_ – display a file path, or
##   ``"-"`` to read from stdin.
##
## **Keybindings**
##
## =========  =============================================
## Key        Action
## =========  =============================================
## ``↑`` / ``↓``      Scroll one line up / down
## ``PgUp`` / ``PgDn``  Scroll one page up / down
## ``Space``  Scroll one page down
## ``g``      Jump to the top
## ``G``      Jump to the bottom
## ``/``      Enter case-insensitive regex search mode
## ``n``      Next search match
## ``N``      Previous search match
## ``m``      Toggle minimal Markdown rendering on / off
## ``s``      Toggle word-wrap on / off
## ``Tab``    Cycle through colour themes
## ``q``      Quit
## =========  =============================================

import os
import terminal
import unicode
import strutils
import tables
import regex
when defined(posix):
  import posix
from illwave as iw import `[]`, `[]=`, `==`
from nimwave as nw import nil

# ── Public types ──────────────────────────────────────────────────────────────

type
  Theme* = object
    ## Colour configuration for every visual element drawn on screen.
    ## Set ``bodyBg`` / ``bodyFg`` to ``bgNone`` / ``fgWhite`` to let the
    ## terminal's own theme shine through (the ``"terminal"`` preset).
    titleBg*:  iw.BackgroundColor  ## Title bar background
    titleFg*:  iw.ForegroundColor  ## Title bar foreground
    bodyBg*:   iw.BackgroundColor  ## Content area background
    bodyFg*:   iw.ForegroundColor  ## Content area foreground
    statusBg*: iw.BackgroundColor  ## Status bar background (normal mode)
    statusFg*: iw.ForegroundColor  ## Status bar foreground (normal mode)
    searchBg*: iw.BackgroundColor  ## Search prompt bar background
    searchFg*: iw.ForegroundColor  ## Search prompt bar foreground
    matchBg*:  iw.BackgroundColor  ## Search-match line highlight background
    matchFg*:  iw.ForegroundColor  ## Search-match line highlight foreground
    mdHeaderBg*: iw.BackgroundColor    ## Markdown header background (same as body background).
    mdHeaderFg*: iw.ForegroundColor    ## Markdown header foreground (bright/accent color).
    mdCodeBg*: iw.BackgroundColor      ## Markdown code-block background (contrasts with body background).
    mdCodeFg*: iw.ForegroundColor      ## Markdown code-block foreground.
    mdEmphasisBg*: iw.BackgroundColor  ## Markdown emphasis background (same as body background).
    mdEmphasisFg*: iw.ForegroundColor  ## Markdown emphasis foreground (same accent as header).

# ── Theme registry ────────────────────────────────────────────────────────────

const ThemeNames* = ["default", "dark", "light", "matrix", "mono", "terminal"]
  ## Ordered list used when cycling themes with ``Tab``.

let ThemesTable* = {
  # Respects the user's terminal colours – nothing is hard-coded.
  "terminal": Theme(
    titleBg:  iw.bgNone,    titleFg:  iw.fgWhite,
    bodyBg:   iw.bgNone,    bodyFg:   iw.fgWhite,
    statusBg: iw.bgNone,    statusFg: iw.fgWhite,
    searchBg: iw.bgNone,    searchFg: iw.fgYellow,
    matchBg:  iw.bgNone,    matchFg:  iw.fgYellow,
    mdHeaderBg: iw.bgNone,  mdHeaderFg: iw.fgYellow,
    mdCodeBg: iw.bgBlack,   mdCodeFg: iw.fgWhite,
    mdEmphasisBg: iw.bgNone, mdEmphasisFg: iw.fgYellow
  ),
  "default": Theme(
    titleBg:  iw.bgBlue,    titleFg:  iw.fgWhite,
    bodyBg:   iw.bgBlack,   bodyFg:   iw.fgWhite,
    statusBg: iw.bgCyan,    statusFg: iw.fgBlack,
    searchBg: iw.bgYellow,  searchFg: iw.fgBlack,
    matchBg:  iw.bgYellow,  matchFg:  iw.fgBlack,
    mdHeaderBg: iw.bgBlack, mdHeaderFg: iw.fgCyan,
    mdCodeBg: iw.bgBlue,    mdCodeFg: iw.fgWhite,
    mdEmphasisBg: iw.bgBlack, mdEmphasisFg: iw.fgCyan
  ),
  "dark": Theme(
    titleBg:  iw.bgBlack,   titleFg:  iw.fgCyan,
    bodyBg:   iw.bgBlack,   bodyFg:   iw.fgWhite,
    statusBg: iw.bgBlue,    statusFg: iw.fgWhite,
    searchBg: iw.bgGreen,   searchFg: iw.fgBlack,
    matchBg:  iw.bgGreen,   matchFg:  iw.fgBlack,
    mdHeaderBg: iw.bgBlack, mdHeaderFg: iw.fgCyan,
    mdCodeBg: iw.bgBlue,    mdCodeFg: iw.fgWhite,
    mdEmphasisBg: iw.bgBlack, mdEmphasisFg: iw.fgCyan
  ),
  "light": Theme(
    titleBg:  iw.bgWhite,   titleFg:  iw.fgBlue,
    bodyBg:   iw.bgWhite,   bodyFg:   iw.fgBlack,
    statusBg: iw.bgBlue,    statusFg: iw.fgWhite,
    searchBg: iw.bgYellow,  searchFg: iw.fgBlack,
    matchBg:  iw.bgYellow,  matchFg:  iw.fgBlack,
    mdHeaderBg: iw.bgWhite, mdHeaderFg: iw.fgBlue,
    mdCodeBg: iw.bgCyan,    mdCodeFg: iw.fgBlack,
    mdEmphasisBg: iw.bgWhite, mdEmphasisFg: iw.fgBlue
  ),
  "matrix": Theme(
    titleBg:  iw.bgBlack,   titleFg:  iw.fgGreen,
    bodyBg:   iw.bgBlack,   bodyFg:   iw.fgGreen,
    statusBg: iw.bgGreen,   statusFg: iw.fgBlack,
    searchBg: iw.bgGreen,   searchFg: iw.fgBlack,
    matchBg:  iw.bgGreen,   matchFg:  iw.fgBlack,
    mdHeaderBg: iw.bgBlack, mdHeaderFg: iw.fgGreen,
    mdCodeBg: iw.bgBlue,    mdCodeFg: iw.fgWhite,
    mdEmphasisBg: iw.bgBlack, mdEmphasisFg: iw.fgGreen
  ),
  "mono": Theme(
    titleBg:  iw.bgWhite,   titleFg:  iw.fgBlack,
    bodyBg:   iw.bgBlack,   bodyFg:   iw.fgWhite,
    statusBg: iw.bgWhite,   statusFg: iw.fgBlack,
    searchBg: iw.bgWhite,   searchFg: iw.fgBlack,
    matchBg:  iw.bgWhite,   matchFg:  iw.fgBlack,
    mdHeaderBg: iw.bgBlack, mdHeaderFg: iw.fgWhite,
    mdCodeBg: iw.bgBlue,    mdCodeFg: iw.fgWhite,
    mdEmphasisBg: iw.bgBlack, mdEmphasisFg: iw.fgWhite
  )
}.toTable

# ── Private state ─────────────────────────────────────────────────────────────

type
  InputMode = enum
    imNormal  ## Regular scrolling / navigation
    imSearch  ## User is typing a search pattern

  MdLineKind = enum
    mlBody
    mlHeader
    mlCode

  MdInlineKind = enum
    mikItalic
    mikBold

  MdSpan = object
    bounds: Slice[int]   ## Byte bounds in the wrapped line.
    kind: MdInlineKind

  State = object
    lines:         seq[string]  ## Original source lines
    wrappedLines:  seq[string]  ## Lines after word-wrap (or == lines when off)
    markdownMode:  bool
    mdLineKinds:   seq[MdLineKind]  ## Per wrapped-line markdown kind.
    mdInlineSpans: Table[int, seq[MdSpan]] ## Optional inline emphasis spans by wrapped-line index.
    wrapWidth:     int          ## Terminal width used when wrapping last ran
    scrollY:       int          ## Index of the top-visible line in wrappedLines
    wordWrap:      bool
    inputMode:     InputMode
    inputBuffer:   string       ## In-progress search text
    searchPattern: string       ## Committed search pattern
    matchLines:    seq[int]     ## wrappedLines indices that contain the pattern
    matchRanges:   Table[int, seq[Slice[int]]] ## Byte ranges for matched substrings per line.
    matchIdx:      int          ## Current position in matchLines (for n / N)
    title:         string
    theme:         Theme
    themeIdx:      int          ## Index into ThemeNames for Tab cycling
    statusMessage: string       ## Transient status message
    statusMessageTTL: int       ## Ticks remaining to show statusMessage

include nimwave/prelude

# ── Word-wrap helpers ─────────────────────────────────────────────────────────

proc wrapOneLine(line: string, width: int): seq[string] =
  ## Word-wrap a single source line into one or more display lines.
  if width <= 0 or line.runeLen <= width:
    return @[line]
  result = @[]
  let words = line.split(' ')
  var cur = ""
  for word in words:
    if cur.len == 0:
      var w = word
      while w.runeLen > width:
        result.add(w.runeSubStr(0, width))
        w = w.runeSubStr(width)
      cur = w
    else:
      let candidate = cur & " " & word
      if candidate.runeLen <= width:
        cur = candidate
      else:
        result.add(cur)
        var w = word
        while w.runeLen > width:
          result.add(w.runeSubStr(0, width))
          w = w.runeSubStr(width)
        cur = w
  result.add(cur)

proc spansOverlap(a, b: Slice[int]): bool =
  not (a.b < b.a or b.b < a.a)

proc hasOverlap(spans: seq[MdSpan], bounds: Slice[int]): bool =
  for span in spans:
    if spansOverlap(span.bounds, bounds):
      return true
  return false

proc parseDoubleDelimitedSpans(line: string, delim: string, kind: MdInlineKind): seq[MdSpan] =
  let delimLen = delim.len
  if delimLen == 0 or line.len < delimLen * 2:
    return
  var i = 0
  while i <= line.len - delimLen:
    if line[i ..< i + delimLen] == delim:
      let startIdx = i + delimLen
      var j = startIdx
      var foundClose = false
      while j <= line.len - delimLen:
        if line[j ..< j + delimLen] == delim:
          if j > startIdx:
            result.add(MdSpan(bounds: startIdx .. j - 1, kind: kind))
          i = j + delimLen
          foundClose = true
          break
        inc j
      if not foundClose:
        inc i
    else:
      inc i

proc parseSingleDelimitedSpans(line: string, delim: char, kind: MdInlineKind,
                               existing: seq[MdSpan]): seq[MdSpan] =
  if line.len < 3:
    return
  var i = 0
  while i < line.len:
    let isOpen = line[i] == delim and
                 (i == 0 or line[i - 1] != delim) and
                 (i + 1 < line.len and line[i + 1] != delim)
    if isOpen:
      let startIdx = i + 1
      var j = startIdx
      var foundClose = false
      while j < line.len:
        let isClose = line[j] == delim and
                      line[j - 1] != delim and
                      (j + 1 == line.len or line[j + 1] != delim)
        if isClose:
          if j > startIdx:
            let bounds = startIdx .. j - 1
            if not hasOverlap(existing, bounds):
              result.add(MdSpan(bounds: bounds, kind: kind))
          i = j + 1
          foundClose = true
          break
        inc j
      if not foundClose:
        inc i
    else:
      inc i

proc collectMarkdownInlineSpans(line: string): seq[MdSpan] =
  result.add(parseDoubleDelimitedSpans(line, "__", mikBold))
  result.add(parseDoubleDelimitedSpans(line, "**", mikBold))
  result.add(parseSingleDelimitedSpans(line, '_', mikItalic, result))
  result.add(parseSingleDelimitedSpans(line, '*', mikItalic, result))
  for i in 1 ..< result.len:
    var j = i
    while j > 0 and result[j - 1].bounds.a > result[j].bounds.a:
      swap(result[j - 1], result[j])
      dec j

proc buildWrappedLines(ctx: var nw.Context[State], width: int) =
  ## Rebuild wrappedLines from lines using *width*; clamp scrollY.
  ctx.data.wrappedLines = @[]
  ctx.data.mdLineKinds = @[]
  ctx.data.mdInlineSpans = initTable[int, seq[MdSpan]]()

  var inCodeBlock = false
  for line in ctx.data.lines:
    var displayLine = line
    var lineKind = mlBody
    if ctx.data.markdownMode:
      let trimmed = strutils.strip(line, leading = true, trailing = false)
      let isFence = trimmed.startsWith("```")
      if inCodeBlock:
        lineKind = mlCode
        if isFence:
          inCodeBlock = false
      else:
        if isFence:
          lineKind = mlCode
          inCodeBlock = true
        elif trimmed.len > 0 and trimmed[0] == '#':
          lineKind = mlHeader
          var hashCount = 0
          while hashCount < trimmed.len and trimmed[hashCount] == '#':
            inc hashCount
          if hashCount == 1:
            displayLine = line.toUpperAscii()

    let wrapped =
      if ctx.data.wordWrap: wrapOneLine(displayLine, width)
      else: @[displayLine]

    for wl in wrapped:
      let idx = ctx.data.wrappedLines.len
      ctx.data.wrappedLines.add(wl)
      ctx.data.mdLineKinds.add(lineKind)
      if ctx.data.markdownMode and lineKind != mlCode:
        let spans = collectMarkdownInlineSpans(wl)
        if spans.len > 0:
          ctx.data.mdInlineSpans[idx] = spans

  ctx.data.wrapWidth = width
  let maxScroll = max(0, ctx.data.wrappedLines.len - 1)
  ctx.data.scrollY = min(ctx.data.scrollY, maxScroll)

# ── Search helpers ────────────────────────────────────────────────────────────

proc buildMatchList(ctx: var nw.Context[State]): tuple[ok: bool, err: string] =
  ## Populate matchLines with all wrappedLines indices matching searchPattern.
  ## Returns `ok = false` when searchPattern is not a valid regex.
  ctx.data.matchLines = @[]
  ctx.data.matchRanges = initTable[int, seq[Slice[int]]]()
  ctx.data.matchIdx = 0
  if ctx.data.searchPattern.len == 0:
    return (true, "")
  try:
    let pat = re2("(?i)" & ctx.data.searchPattern)
    for i, line in ctx.data.wrappedLines:
      var hasMatch = false
      var ranges: seq[Slice[int]] = @[]
      for bounds in findAllBounds(line, pat):
        hasMatch = true
        # Zero-length matches are valid for navigation, but have no visible span.
        if bounds.a <= bounds.b:
          ranges.add(bounds)
      if hasMatch:
        ctx.data.matchLines.add(i)
        if ranges.len > 0:
          ctx.data.matchRanges[i] = ranges
    return (true, "")
  except RegexError:
    return (false, getCurrentExceptionMsg())

proc scrollToCurrentMatch(ctx: var nw.Context[State], contentH: int) =
  ## Scroll so the current match is visible.
  if ctx.data.matchLines.len == 0:
    return
  let lineIdx = ctx.data.matchLines[ctx.data.matchIdx]
  if lineIdx < ctx.data.scrollY:
    ctx.data.scrollY = lineIdx
  elif lineIdx >= ctx.data.scrollY + contentH:
    ctx.data.scrollY = max(0, lineIdx - contentH + 1)

# ── Rendering ─────────────────────────────────────────────────────────────────

proc renderTitleBar(ctx: var nw.Context[State]) =
  let w = iw.width(ctx.tb)
  let theme = ctx.data.theme
  iw.setBackgroundColor(ctx.tb, theme.titleBg)
  iw.setForegroundColor(ctx.tb, theme.titleFg)
  let t = ctx.data.title
  let pad = max(0, (w - t.runeLen) div 2)
  let line = " ".repeat(pad) & t
  let full = line & " ".repeat(max(0, w - line.runeLen))
  iw.write(ctx.tb, 0, 0, full.runeSubStr(0, w))
  iw.resetAttributes(ctx.tb)

proc renderBody(ctx: var nw.Context[State]) =
  let w = iw.width(ctx.tb)
  let h = iw.height(ctx.tb)
  let contentH = h - 2   # rows between title bar and status bar
  let theme = ctx.data.theme

  for row in 0 ..< contentH:
    let lineIdx = ctx.data.scrollY + row
    let y = row + 1  # +1 because y=0 is the title bar

    let text =
      if lineIdx >= 0 and lineIdx < ctx.data.wrappedLines.len:
        ctx.data.wrappedLines[lineIdx]
      else:
        ""
    var baseBg = theme.bodyBg
    var baseFg = theme.bodyFg
    var baseStyle: set[terminal.Style] = {}
    if ctx.data.markdownMode and lineIdx >= 0 and lineIdx < ctx.data.mdLineKinds.len:
      case ctx.data.mdLineKinds[lineIdx]:
      of mlHeader:
        baseBg = theme.mdHeaderBg
        baseFg = theme.mdHeaderFg
        baseStyle = {terminal.styleBright}
      of mlCode:
        baseBg = theme.mdCodeBg
        baseFg = theme.mdCodeFg
      of mlBody:
        discard

    iw.setBackgroundColor(ctx.tb, baseBg)
    iw.setForegroundColor(ctx.tb, baseFg)
    iw.setStyle(ctx.tb, baseStyle)
    let full = text & " ".repeat(max(0, w - text.runeLen))
    iw.write(ctx.tb, 0, y, full.runeSubStr(0, w))
    iw.resetAttributes(ctx.tb)

    if text.len == 0 or w <= 0:
      continue

    if ctx.data.markdownMode and ctx.data.mdInlineSpans.hasKey(lineIdx):
      for span in ctx.data.mdInlineSpans[lineIdx]:
        let bounds = span.bounds
        if bounds.a < 0 or bounds.b < bounds.a or bounds.a >= text.len:
          continue
        let endByte = min(bounds.b, text.len - 1)
        let prefix = if bounds.a > 0: text[0 ..< bounds.a] else: ""
        let spanText = text[bounds.a .. endByte]
        let x = prefix.runeLen
        if x >= w:
          continue
        let remainingWidth = w - x
        var toDraw = spanText
        if toDraw.runeLen > remainingWidth:
          toDraw = toDraw.runeSubStr(0, remainingWidth)
        if toDraw.runeLen == 0:
          continue
        iw.setBackgroundColor(ctx.tb, theme.mdEmphasisBg)
        iw.setForegroundColor(ctx.tb, theme.mdEmphasisFg)
        case span.kind:
        of mikItalic:
          iw.setStyle(ctx.tb, {terminal.styleItalic})
        of mikBold:
          iw.setStyle(ctx.tb, {terminal.styleBright})
        iw.write(ctx.tb, x, y, toDraw)
        iw.resetAttributes(ctx.tb)

    if ctx.data.matchRanges.hasKey(lineIdx):
      for bounds in ctx.data.matchRanges[lineIdx]:
        if bounds.a < 0 or bounds.b < bounds.a or bounds.a >= text.len:
          continue
        let endByte = min(bounds.b, text.len - 1)
        let prefix = if bounds.a > 0: text[0 ..< bounds.a] else: ""
        let matchText = text[bounds.a .. endByte]
        let x = prefix.runeLen
        if x >= w:
          continue
        let remainingWidth = w - x
        var toDraw = matchText
        if toDraw.runeLen > remainingWidth:
          toDraw = toDraw.runeSubStr(0, remainingWidth)
        if toDraw.runeLen == 0:
          continue
        iw.setBackgroundColor(ctx.tb, theme.matchBg)
        iw.setForegroundColor(ctx.tb, theme.matchFg)
        iw.write(ctx.tb, x, y, toDraw)
        iw.resetAttributes(ctx.tb)

proc renderStatusBar(ctx: var nw.Context[State]) =
  let w = iw.width(ctx.tb)
  let h = iw.height(ctx.tb)
  let theme = ctx.data.theme
  let total = ctx.data.wrappedLines.len

  var line: string
  case ctx.data.inputMode:
  of imSearch:
    iw.setBackgroundColor(ctx.tb, theme.searchBg)
    iw.setForegroundColor(ctx.tb, theme.searchFg)
    line = "/" & ctx.data.inputBuffer & "_"
  of imNormal:
    iw.setBackgroundColor(ctx.tb, theme.statusBg)
    iw.setForegroundColor(ctx.tb, theme.statusFg)
    if ctx.data.statusMessageTTL > 0:
      line = ctx.data.statusMessage
    else:
      let contentH = h - 2
      let topLine  = ctx.data.scrollY + 1
      let botLine  = min(ctx.data.scrollY + contentH, total)
      let pct      = if total > 0: min(100, (ctx.data.scrollY + contentH) * 100 div total) else: 100
      let wrap     = if ctx.data.wordWrap: "wrap" else: "nowrap"
      let tname    = ThemeNames[ctx.data.themeIdx mod ThemeNames.len]
      let matchInfo =
        if ctx.data.matchLines.len > 0:
          "  /" & ctx.data.searchPattern &
          " [" & $(ctx.data.matchIdx + 1) & "/" & $ctx.data.matchLines.len & "]"
        else:
          ""
      line = "Lines " & $topLine & "-" & $botLine & "/" & $total &
             "  " & $pct & "%" &
             "  [" & wrap & "]" &
             "  theme:" & tname &
             matchInfo

  line = line & " ".repeat(max(0, w - line.runeLen))
  iw.write(ctx.tb, 0, h - 1, line.runeSubStr(0, w))
  iw.resetAttributes(ctx.tb)

proc renderAll(ctx: var nw.Context[State]) =
  let w = iw.width(ctx.tb)
  # Rewrap whenever the terminal has been resized.
  if w != ctx.data.wrapWidth:
    buildWrappedLines(ctx, w)
    discard buildMatchList(ctx)
  renderTitleBar(ctx)
  renderBody(ctx)
  renderStatusBar(ctx)

# ── Key handling ──────────────────────────────────────────────────────────────

proc handleInput(ctx: var nw.Context[State], key: iw.Key): bool =
  ## Handle a single keypress. Returns ``true`` when the user requests quit.
  let h        = iw.height(ctx.tb)
  let w        = iw.width(ctx.tb)
  let contentH = h - 2
  let total    = ctx.data.wrappedLines.len

  # ── Search input mode ─────────────────────────────────────────────────────
  if ctx.data.inputMode == imSearch:
    case key:
    of iw.Key.Enter:
      let previousPattern = ctx.data.searchPattern
      ctx.data.searchPattern = ctx.data.inputBuffer
      ctx.data.inputBuffer   = ""
      ctx.data.inputMode     = imNormal
      let matchBuild = buildMatchList(ctx)
      if not matchBuild.ok:
        ctx.data.searchPattern = previousPattern
        discard buildMatchList(ctx)
        ctx.data.statusMessage    = "Invalid regex: " & matchBuild.err
        ctx.data.statusMessageTTL = 120
      elif ctx.data.matchLines.len > 0:
        ctx.data.matchIdx = 0
        scrollToCurrentMatch(ctx, contentH)
      else:
        ctx.data.statusMessage    = "Pattern not found: " & ctx.data.searchPattern
        ctx.data.statusMessageTTL = 120
    of iw.Key.Escape:
      ctx.data.inputBuffer = ""
      ctx.data.inputMode   = imNormal
    of iw.Key.Backspace:
      if ctx.data.inputBuffer.len > 0:
        ctx.data.inputBuffer = ctx.data.inputBuffer[0 ..< ctx.data.inputBuffer.len - 1]
    else:
      if key.int >= 32 and key.int <= 126:
        ctx.data.inputBuffer.add(chr(key.int))
    return false

  # ── Normal mode ───────────────────────────────────────────────────────────
  case key:

  of iw.Key.Up:
    if ctx.data.scrollY > 0:
      ctx.data.scrollY -= 1

  of iw.Key.Down:
    if ctx.data.scrollY < total - 1:
      ctx.data.scrollY += 1

  of iw.Key.PageUp:
    ctx.data.scrollY = max(0, ctx.data.scrollY - contentH)

  of iw.Key.PageDown, iw.Key(ord(' ')):
    ctx.data.scrollY = min(max(0, total - 1), ctx.data.scrollY + contentH)

  of iw.Key.Home, iw.Key(ord('g')):
    ctx.data.scrollY = 0

  of iw.Key.End, iw.Key(ord('G')):
    ctx.data.scrollY = max(0, total - contentH)

  of iw.Key(ord('/')):
    ctx.data.inputMode   = imSearch
    ctx.data.inputBuffer = ""

  of iw.Key(ord('n')):
    if ctx.data.matchLines.len > 0:
      ctx.data.matchIdx = (ctx.data.matchIdx + 1) mod ctx.data.matchLines.len
      scrollToCurrentMatch(ctx, contentH)

  of iw.Key(ord('N')):
    if ctx.data.matchLines.len > 0:
      ctx.data.matchIdx = (ctx.data.matchIdx - 1 + ctx.data.matchLines.len) mod
                           ctx.data.matchLines.len
      scrollToCurrentMatch(ctx, contentH)

  of iw.Key(ord('m')):
    ctx.data.markdownMode = not ctx.data.markdownMode
    buildWrappedLines(ctx, w)
    discard buildMatchList(ctx)
    ctx.data.statusMessage    = if ctx.data.markdownMode: "Markdown mode ON" else: "Markdown mode OFF"
    ctx.data.statusMessageTTL = 80

  of iw.Key(ord('s')):
    ctx.data.wordWrap = not ctx.data.wordWrap
    buildWrappedLines(ctx, w)
    discard buildMatchList(ctx)
    ctx.data.statusMessage    = if ctx.data.wordWrap: "Word-wrap ON" else: "Word-wrap OFF"
    ctx.data.statusMessageTTL = 80

  of iw.Key.Tab:
    ctx.data.themeIdx = (ctx.data.themeIdx + 1) mod ThemeNames.len
    let name = ThemeNames[ctx.data.themeIdx]
    ctx.data.theme            = ThemesTable[name]
    ctx.data.statusMessage    = "Theme: " & name
    ctx.data.statusMessageTTL = 80

  of iw.Key(ord('q')), iw.Key(ord('Q')):
    return true

  else:
    discard

  return false

# ── Event loop ────────────────────────────────────────────────────────────────

proc tick(ctx: var nw.Context[State], prevTb: var iw.TerminalBuffer): bool =
  var mouseInfo: iw.MouseInfo
  let key = iw.getKey(mouseInfo)

  case mouseInfo.scrollDir:
  of iw.ScrollDirection.sdUp:
    discard handleInput(ctx, iw.Key.Up)
  of iw.ScrollDirection.sdDown:
    discard handleInput(ctx, iw.Key.Down)
  else:
    discard

  if key != iw.Key.None:
    if handleInput(ctx, key):
      return true

  if ctx.data.statusMessageTTL > 0:
    ctx.data.statusMessageTTL -= 1

  ctx.tb = iw.initTerminalBuffer(terminal.terminalWidth(), terminal.terminalHeight())
  renderAll(ctx)
  iw.display(ctx.tb, prevTb)
  return false

proc deinit() =
  terminal.showCursor()
  iw.deinit()

proc runEventLoop(ctx: var nw.Context[State]) =
  var prevTb: iw.TerminalBuffer
  try:
    while true:
      if tick(ctx, prevTb):
        break
      prevTb = ctx.tb
      os.sleep(5)
  except Exception as ex:
    deinit()
    raise ex
  deinit()

# ── Initialisation ────────────────────────────────────────────────────────────

proc initPager(ctx: var nw.Context[State], lines: seq[string],
               title: string, themeName: string, markdownMode: bool) =
  let name = if ThemesTable.hasKey(themeName): themeName else: "default"
  ctx.data.theme    = ThemesTable[name]
  ctx.data.themeIdx = block:
    var idx = 0
    for i, n in ThemeNames:
      if n == name: idx = i
    idx

  ctx.data.lines        = lines
  ctx.data.title        = if title.len > 0: title else: "lesster"
  ctx.data.markdownMode = markdownMode
  ctx.data.mdLineKinds  = @[]
  ctx.data.mdInlineSpans = initTable[int, seq[MdSpan]]()
  ctx.data.wordWrap     = true
  ctx.data.scrollY      = 0
  ctx.data.inputMode    = imNormal
  ctx.data.inputBuffer  = ""
  ctx.data.searchPattern = ""
  ctx.data.matchLines   = @[]
  ctx.data.matchRanges  = initTable[int, seq[Slice[int]]]()
  ctx.data.matchIdx     = 0
  ctx.data.statusMessage    = ""
  ctx.data.statusMessageTTL = 0

  terminal.enableTrueColors()
  iw.init()
  setControlCHook(
    proc () {.noconv.} =
      iw.deinit()
      quit(0)
  )
  terminal.hideCursor()

  buildWrappedLines(ctx, terminal.terminalWidth())

# ── Public API ────────────────────────────────────────────────────────────────

proc viewText*(lines: seq[string], title: string = "lesster",
               themeName: string = "default", markdownMode: bool = false) =
  ## Launch the interactive pager with an in-memory sequence of text lines.
  ##
  ## `title` is displayed centred in the title bar.
  ## `themeName` must be one of the keys in `ThemesTable <#ThemesTable>`_
  ## (``"default"``, ``"dark"``, ``"light"``, ``"matrix"``, ``"mono"``,
  ## ``"terminal"``); unknown names fall back to ``"default"``.
  var ctx: nw.Context[State]
  initPager(ctx, lines, title, themeName, markdownMode)
  runEventLoop(ctx)

proc viewFile*(path: string, title: string = "",
               themeName: string = "default", markdownMode: bool = false) =
  ## Launch the interactive pager for a file path, or ``"-"`` for stdin.
  ##
  ## When reading from stdin, fd 0 is reconnected to ``/dev/tty`` after
  ## all data has been buffered so that keyboard input still works.
  var lines: seq[string]
  var displayTitle: string

  if path == "-":
    var line: string
    while stdin.readLine(line):
      lines.add(line)
    when defined(posix):
      discard posix.close(0)
      let ttyFd = posix.open("/dev/tty", posix.O_RDWR)
      if ttyFd < 0:
        raise newException(IOError, "Cannot open /dev/tty for terminal input")
      if ttyFd != 0:
        discard posix.dup2(ttyFd, 0)
        discard posix.close(ttyFd)
    displayTitle = if title.len > 0: title else: "<stdin>"
  else:
    for line in lines(path):
      lines.add(line)
    displayTitle = if title.len > 0: title else: path

  var ctx: nw.Context[State]
  initPager(ctx, lines, displayTitle, themeName, markdownMode)
  runEventLoop(ctx)
