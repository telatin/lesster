import os
import strutils
import argparse
import lesster

const fullHelpMarkdown = staticRead("assets/help.md")

proc main() =
  var p = newParser("lesster"):
    help("A less-like interactive text pager")
    arg("file", nargs = -1,
        help = "File to view, or '-' to read from stdin")
    option("-t", "--title",   default = some(""),
           help = "Title shown in the title bar (default: filename)")
    option("-s", "--scheme",  default = some("default"),
           help = "Colour theme: default, dark, light, matrix, mono, terminal")
    flag("--full-help",
         help = "Open the bundled full help in the TUI")

  try:
    let opts = p.parse()
    let path      = if opts.file.len > 0: opts.file[0] else: "-"
    let themeName = opts.scheme
    let title     = opts.title
    let markdownMode = path != "-" and path.toLowerAscii().endsWith(".md")

    if opts.fullHelp:
      viewText(
        fullHelpMarkdown.splitLines(),
        title = "lesster Full Help",
        themeName = themeName,
        markdownMode = true
      )
      return

    if path != "-" and not fileExists(path):
      echo "Error: file not found: ", path
      quit(1)

    viewFile(path, title, themeName, markdownMode = markdownMode)

  except ShortCircuit as e:
    if e.flag == "argparse_help":
      echo p.help
      quit(0)
  except UsageError:
    stderr.writeLine getCurrentExceptionMsg()
    echo p.help
    quit(1)

when isMainModule:
  main()
