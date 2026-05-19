-- tools/pandoc-filters/image-normalize.lua
--
-- Force every Image that pandoc wraps in a figure to use `[H]` placement
-- (the `float` package's "here, and only here" specifier) so figures
-- can't migrate forward to a different page, stranding the introducing
-- "Screen reference / See:" caption text behind on the previous page.
--
-- Width normalisation is handled separately by the LaTeX template's
-- `\setkeys{Gin}{width=0.5\textwidth,...}` default (every
-- `\includegraphics` without explicit width picks up that default),
-- which is more reliable than attempting to mutate per-Image attributes
-- through pandoc 3.x's `\pandocbounded` wrapper.
--
-- LaTeX-only; other formats pass through unchanged.

local function only_for_latex()
  return FORMAT and FORMAT:match("latex")
end

function Figure(elem)
  if not only_for_latex() then
    return elem
  end
  -- pandoc 3.x reads attr.attributes["fig-pos"] when emitting the
  -- `\begin{figure}[<pos>]` opener. Set it to H so float can't escape.
  elem.attr.attributes["fig-pos"] = "H"
  return elem
end
