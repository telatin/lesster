import std/unittest

include ../src/lesster

suite "markdown inline renderer":
  test "underscores inside inline code are not parsed as emphasis":
    let md = buildMarkdownDisplayLine("`R1_1, R2_1, R1_2, R2_2`")

    check md.text == "R1_1, R2_1, R1_2, R2_2"
    check md.spans.len == 1
    check md.spans[0].kind == mikCode
    check md.spans[0].bounds == 0 .. md.text.len - 1

  test "inline code and italic can coexist on one line":
    let md = buildMarkdownDisplayLine("`R1_1` and _paired_")

    check md.text == "R1_1 and paired"
    check md.spans.len == 2
    check md.spans[0].kind == mikCode
    check md.spans[0].bounds == 0 .. 3
    check md.spans[1].kind == mikItalic
    check md.spans[1].bounds == 9 .. 14

suite "markdown table formatting":
  test "isTableSeparator detects valid separators":
    check isTableSeparator("|---|---|")
    check isTableSeparator("|:--|--:|")
    check isTableSeparator("| --- | --- |")
    check not isTableSeparator("| a | b |")
    check not isTableSeparator("not a table")

  test "parseTableRow extracts cells":
    check parseTableRow("| a | b |") == @["a", "b"]
    check parseTableRow("|hello|world|") == @["hello", "world"]
    check parseTableRow("not a table") == newSeq[string]()

  test "formatMarkdownTables aligns columns":
    let input = @[
      "| Name | Age |",
      "|---|---|",
      "| Alice | 30 |",
      "| Bob | 25 |"
    ]
    let formatted = formatMarkdownTables(input)
    check formatted.len == 4
    check formatted[0] == "| Name  | Age |"
    check formatted[1] == "| ----- | --- |"
    check formatted[2] == "| Alice | 30  |"
    check formatted[3] == "| Bob   | 25  |"

  test "formatMarkdownTables preserves non-table content":
    let input = @[
      "Some text",
      "| a | b |",
      "|---|---|",
      "| 1 | 2 |",
      "More text"
    ]
    let formatted = formatMarkdownTables(input)
    check formatted[0] == "Some text"
    check formatted[4] == "More text"

  test "formatMarkdownTables handles uneven rows":
    let input = @[
      "| A | B | C |",
      "|---|---|---|",
      "| x |",
      "| y | z |"
    ]
    let formatted = formatMarkdownTables(input)
    check formatted.len == 4
    # All rows should have same number of columns
    for line in formatted:
      check line.count('|') == 4

  test "formatMarkdownTables handles pipe-less tables":
    let input = @[
      "Table | Item | Description",
      "--|--|--",
      "A1 | Alpha | Something here",
      "A2 | Beta | Something there"
    ]
    let formatted = formatMarkdownTables(input)
    check formatted.len == 4
    check formatted[0] == "| Table | Item  | Description     |"
    check formatted[1] == "| ----- | ----- | --------------- |"
    check formatted[2] == "| A1    | Alpha | Something here  |"
    check formatted[3] == "| A2    | Beta  | Something there |"
