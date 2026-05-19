-- tools/pandoc-filters/table-grid.lua
--
-- Render every pandoc Table as a `longtable` with full horizontal and
-- vertical grid lines and a shaded header row. Only applied when the
-- pandoc target is LaTeX (PDF output); other formats pass through
-- unchanged.
--
-- Column width policy: every body column is a `p{<width>}` block-paragraph
-- column that fills equal share of \linewidth (after subtracting the
-- per-column rule + padding overhead). This wraps long cell content
-- instead of letting it run past the right margin, which was the failure
-- mode for the Behavior / Description / Trigger columns in the URS PDF
-- (`l` content-sized columns had no upper bound and overflowed the page).
--
-- The shaded header colour is `tableHeaderShade`, defined in
-- tools/urs-template.latex header-includes.
--
-- Targets pandoc 3.x Table schema: {caption, colspecs, head, bodies,
-- foot, attr}. head/foot are TableHead/TableFoot with .rows; each body
-- is a TableBody with .body (a list of rows); each row has .cells, and
-- each cell has .contents (a list of Blocks).

local function only_for_latex()
  return FORMAT and FORMAT:match("latex")
end

-- Render a cell's Blocks as LaTeX via pandoc.write (3.x). A single
-- outer Para/Plain is unwrapped so cells don't introduce paragraph
-- breaks inside longtable rows.
local function cell_latex(cell)
  local blocks = cell.contents
  if #blocks == 1 and (blocks[1].t == "Para" or blocks[1].t == "Plain") then
    blocks = {pandoc.Plain(blocks[1].content)}
  end
  local doc = pandoc.Pandoc(blocks)
  local latex = pandoc.write(doc, "latex")
  return (latex:gsub("\n+$", ""))
end

function Table(tbl)
  if not only_for_latex() then
    return tbl
  end

  local ncols = #tbl.colspecs
  if ncols == 0 then return tbl end

  -- Equal-share `p{...}` columns. Each column gets the same width derived
  -- from \linewidth minus the per-column rule + padding overhead
  -- (\tabcolsep * 2 per column, plus the trailing rule). Using
  -- \dimexpr lets LaTeX evaluate the arithmetic at typeset time.
  local col_width = string.format(
    "\\dimexpr(\\linewidth-%d\\tabcolsep-\\arrayrulewidth)/%d\\relax",
    2 * ncols, ncols
  )
  local single = "|>{\\raggedright\\arraybackslash}p{" .. col_width .. "}"
  local colspec = string.rep(single, ncols) .. "|"

  local lines = {
    "\\begin{longtable}{" .. colspec .. "}",
    "\\hline",
  }

  -- Header rows (shaded). \endhead makes the header repeat across page
  -- breaks for multi-page tables.
  local head_rows = (tbl.head and tbl.head.rows) or {}
  local header_has_content = false
  for _, row in ipairs(head_rows) do
    for _, cell in ipairs(row.cells) do
      if #cell.contents > 0 then
        header_has_content = true
        break
      end
    end
    if header_has_content then break end
  end
  if header_has_content then
    for _, row in ipairs(head_rows) do
      local cells = {}
      for _, cell in ipairs(row.cells) do
        table.insert(cells, cell_latex(cell))
      end
      table.insert(lines,
        "\\rowcolor{tableHeaderShade} " .. table.concat(cells, " & ") .. " \\\\")
      table.insert(lines, "\\hline")
    end
    table.insert(lines, "\\endhead")
  end

  -- Body rows (\hline between every pair for the horizontal grid).
  for _, body in ipairs(tbl.bodies) do
    for _, row in ipairs(body.body) do
      local cells = {}
      for _, cell in ipairs(row.cells) do
        table.insert(cells, cell_latex(cell))
      end
      table.insert(lines, table.concat(cells, " & ") .. " \\\\")
      table.insert(lines, "\\hline")
    end
  end

  table.insert(lines, "\\end{longtable}")
  return pandoc.RawBlock("latex", table.concat(lines, "\n"))
end
