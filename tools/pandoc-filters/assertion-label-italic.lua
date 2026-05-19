-- tools/pandoc-filters/assertion-label-italic.lua
--
-- Render assertion ordered lists with italic labels (A., B., C., …)
-- in LaTeX output. Pandoc emits `\def\labelenumi{\Alph{enumi}.}` inside
-- every alphabetic-upper enumerate; the template can't override that
-- via \renewcommand (the \def wins inside the env scope). This filter
-- rewrites the OrderedList AST to wrap the label macro in \emph.
--
-- Triggers only on lists whose explicit style is UpperAlpha + Period.
-- Other ordered lists (decimal numbering, lower-roman, etc.) pass
-- through unchanged.

local function only_for_latex()
  return FORMAT and FORMAT:match("latex")
end

function OrderedList(elem)
  if not only_for_latex() then
    return elem
  end
  local style = elem.style
  local delim = elem.delimiter
  if style ~= "UpperAlpha" or delim ~= "Period" then
    return elem
  end

  -- Build custom enumerate that uses italic labels.
  local lines = {
    "\\begin{enumerate}",
    "\\def\\labelenumi{\\emph{\\Alph{enumi}.}}",
  }
  if elem.start and elem.start > 1 then
    table.insert(lines, "\\setcounter{enumi}{" .. (elem.start - 1) .. "}")
  end
  for _, item_blocks in ipairs(elem.content) do
    local doc = pandoc.Pandoc(item_blocks)
    local body = pandoc.write(doc, "latex"):gsub("\n+$", "")
    table.insert(lines, "\\item " .. body)
  end
  table.insert(lines, "\\end{enumerate}")
  return pandoc.RawBlock("latex", table.concat(lines, "\n"))
end
