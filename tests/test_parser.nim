import std/[os, streams, unittest]

import parser

suite "parser":
  test "parseDelimitedStream auto-detects delimiter and column types":
    let input = "id,ratio,name\n1,3.14,alpha\n2,2.0,beta\n"
    let stream = newStringStream(input)
    let table = parseDelimitedStream(stream)

    check table.headers == @["id", "ratio", "name"]
    check table.rows.len == 2
    check table.columnTypes == @[ctInt, ctFloat, ctString]
    check table.hiddenColumns == @[false, false, false]
    check table.columnWidths.len == 3

  test "parseDelimitedStream supports skipPrefix with generated headers":
    let input = "# metadata\n# source: demo\n10,20\n30,40\n"
    let stream = newStringStream(input)
    let table = parseDelimitedStream(
      stream,
      delimiter = ',',
      skipPrefix = "#",
      hasHeader = false
    )

    check table.headers == @["Col1", "Col2"]
    check table.rows == @[@["10", "20"], @["30", "40"]]
    check table.columnTypes == @[ctInt, ctInt]

  test "parseDelimitedFile enforces maxColWidth":
    let path = getTempDir() / "lesster_parser_widths.csv"
    defer:
      if fileExists(path):
        removeFile(path)

    writeFile(path, "name,description\nshort,averyveryverylongvalue\n")
    let table = parseDelimitedFile(path, delimiter = ',', maxColWidth = 6)

    check table.columnWidths.len == 2
    check table.columnWidths == @[5, 6]

  test "detectDelimiter chooses comma when comma count ties with tab":
    let path = getTempDir() / "lesster_parser_delimiter.csv"
    defer:
      if fileExists(path):
        removeFile(path)

    writeFile(path, "a,b\tc\n")
    check detectDelimiter(path) == ','

  test "parseDelimitedFile handles skipLines before header":
    let path = getTempDir() / "lesster_parser_skip.tsv"
    defer:
      if fileExists(path):
        removeFile(path)

    writeFile(path, "ignore me\nid\tvalue\n1\t100\n2\t200\n")
    let table = parseDelimitedFile(path, delimiter = '\t', skipLines = 1)

    check table.headers == @["id", "value"]
    check table.rows == @[@["1", "100"], @["2", "200"]]
    check table.columnTypes == @[ctInt, ctInt]
