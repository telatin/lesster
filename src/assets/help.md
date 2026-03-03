# lesster TUI quick guide

Welcome to **lesster**.
It is a lightweight terminal pager for logs, text files, and markdown.

## Open files

- `lesster myfile.txt`
- `cat output.txt | lesster -`
- `lesster --full-help`

## Move around

- `Up` / `Down` scroll one line
- `PgUp` / `PgDn` scroll one page
- `Space` scroll one page down
- `g` jump to top
- `G` jump to bottom

## Search

Search is _case-insensitive regex_:

```text
/error|warning
/^2026-.*timeout/
```

- Press `/` to start typing a pattern
- Press `Enter` to search
- Press `n` for next match
- Press `N` for previous match

## Markdown mode

Press `m` to toggle minimal markdown rendering.

Supported markdown styling:

- `#` / `##` / `###` headings use header style
- `#` heading text is shown in **UPPERCASE**
- fenced blocks (``` ... ```) use code style
- inline _italic_ and **bold** are styled

## Display options

- `s` toggle word wrap
- `Tab` cycle theme
- `q` quit

## Tips

- For markdown notes, save files as `.md` to auto-enable markdown mode
- Use concise regex patterns first, then refine
- If search reports an invalid regex, simplify and retry
