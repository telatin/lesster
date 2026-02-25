# Package

version       = "0.1.0"
author        = "Andrea Telatin"
description   = "A less-like interactive text pager library for Nim"
license       = "MIT"
srcDir        = "src"
namedBin      = {"lesster_app": "lesster"}.toTable()
binDir        = "bin"

# Dependencies

requires "nim >= 2.0.0"
requires "nimwave"
requires "illwave"
requires "argparse"

task docs, "Generate HTML documentation into docs/":
  exec "nim doc --project --outdir:docs --index:on src/lesster.nim"
  exec "cp docs/theindex.html docs/index.html"
