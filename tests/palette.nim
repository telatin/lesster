import std/strutils
import illwave

const
  allForegroundColors = [fgNone, fgBlack, fgRed, fgGreen, fgYellow, fgBlue, fgMagenta, fgCyan, fgWhite]
  allBackgroundColors = [bgNone, bgBlack, bgRed, bgGreen, bgYellow, bgBlue, bgMagenta, bgCyan, bgWhite]

func ansiFgCode(fg: ForegroundColor): int =
  case fg
  of fgNone:
    39
  else:
    ord(fg)

func ansiBgCode(bg: BackgroundColor): int =
  case bg
  of bgNone:
    49
  else:
    ord(bg)

func swatch(fg: ForegroundColor, bg: BackgroundColor, text: string): string =
  "\e[" & $ansiFgCode(fg) & ";" & $ansiBgCode(bg) & "m" & text & "\e[0m"

func padRight(s: string, width: int): string =
  if s.len >= width:
    s
  else:
    s & " ".repeat(width - s.len)

proc printForegroundPalette() =
  echo "Foreground colors:"
  for fg in allForegroundColors:
    echo "  " & padRight($fg, 12) & " " & swatch(fg, bgNone, " Sample text ")
  echo ""

proc printBackgroundPalette() =
  echo "Background colors:"
  for bg in allBackgroundColors:
    echo "  " & padRight($bg, 12) & " " & swatch(fgWhite, bg, " Sample text ")
  echo ""

proc printMatrix() =
  echo "FG x BG matrix:"
  var header = "  " & padRight("FG\\BG", 12)
  for bg in allBackgroundColors:
    header.add(" " & padRight($bg, 9))
  echo header

  for fg in allForegroundColors:
    var row = "  " & padRight($fg, 12)
    for bg in allBackgroundColors:
      row.add(" " & swatch(fg, bg, " AaBb "))
    echo row
  echo "\e[0m"

when isMainModule:
  printForegroundPalette()
  printBackgroundPalette()
  printMatrix()
