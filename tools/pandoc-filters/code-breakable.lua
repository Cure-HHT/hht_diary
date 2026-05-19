-- tools/pandoc-filters/code-breakable.lua
--
-- Make inline `code` spans wrap at hyphens. By default pandoc emits an
-- inline Code element as `\texttt{...}`, and `\texttt` doesn't allow
-- line breaks at hyphens — the long-kebab REQ identifiers used
-- throughout the URS (`DIARY-PRD-linking-code-lifecycle` etc.) then
-- overflow the right margin on dense pages.
--
-- Inject `\allowbreak{}` after every hyphen so LaTeX is permitted to
-- break the line at any hyphen if needed; if the identifier fits on one
-- line it still renders unbroken because `\allowbreak` only offers an
-- opportunity, it doesn't force a break.
--
-- LaTeX-only; other formats pass through unchanged.

local function only_for_latex()
  return FORMAT and FORMAT:match("latex")
end

local function latex_escape_text(text)
  -- Inline code is verbatim by convention. The only characters LaTeX
  -- treats specially inside `\texttt` are the backslash, the curly
  -- braces, and the percent sign. Escape them so identifiers containing
  -- those characters (rare in REQ ids but possible in code samples)
  -- still render literally.
  text = text:gsub("\\", "\\textbackslash{}")
  text = text:gsub("{", "\\{")
  text = text:gsub("}", "\\}")
  text = text:gsub("%%", "\\%%")
  text = text:gsub("%$", "\\$")
  text = text:gsub("&", "\\&")
  text = text:gsub("#", "\\#")
  text = text:gsub("_", "\\_")
  text = text:gsub("%^", "\\textasciicircum{}")
  text = text:gsub("~", "\\textasciitilde{}")
  return text
end

function Code(elem)
  if not only_for_latex() then
    return elem
  end
  local escaped = latex_escape_text(elem.text)
  -- Offer a line-break opportunity after every hyphen.
  local broken = escaped:gsub("%-", "-\\allowbreak{}")
  return pandoc.RawInline("latex", "\\texttt{" .. broken .. "}")
end
