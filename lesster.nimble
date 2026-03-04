# Package

version       = "0.3.0"
author        = "Andrea Telatin"
description   = "A less-like interactive text pager library for Nim"
license       = "MIT"
binDir        = "bin"
srcDir        = "src"
installFiles  = @["lesster.nim"]
skipFiles     = @["parser.nim"]
namedBin      = {"lesster_app": "lesster"}.toTable()

# Dependencies

requires "nim >= 2.0.0"
requires "nimwave"
requires "illwave"
requires "argparse"
requires "regex"

task docs, "Generate HTML documentation into docs/":
  exec "nim doc --project --outdir:docs --index:on src/lesster.nim"
  exec "cp docs/theindex.html docs/index.html"

task test, "Run unit tests":
  exec "nim c -r --nimcache:.nimcache --out:.nimcache/test_parser --path:src tests/test_parser.nim"
