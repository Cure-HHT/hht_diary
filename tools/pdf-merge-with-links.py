#!/usr/bin/env python3
# pdf-merge-with-links.py — concatenate PDFs while preserving named
# destinations, internal hyperlinks, and outline bookmarks.
#
# `pdfunite` (poppler-utils) and `gs` (ghostscript) both strip named
# destinations during concatenation, leaving the merged PDF with
# clickable-looking blue ToC entries that jump nowhere. pypdf's
# PdfWriter.append() preserves destinations and remaps page references
# correctly across the merge boundary.
#
# Usage:
#   pdf-merge-with-links.py output.pdf input1.pdf input2.pdf [...]
import sys

# Prefer /usr/bin/python3 (Python 3.10 with pypdf installed in
# /home/metagamer/.local/lib/python3.10/site-packages) over
# /home/metagamer/.local/bin/python3 (Python 3.11 without pypdf).
# See "/usr/bin/env python3" shebang above for the normal invocation
# path; this script is also runnable as `/usr/bin/python3 tools/pdf-merge-with-links.py ...`.

from pypdf import PdfWriter


def main(argv: list[str]) -> int:
    if len(argv) < 4:
        print(
            "usage: pdf-merge-with-links.py output.pdf input1.pdf input2.pdf [...]",
            file=sys.stderr,
        )
        return 2

    output_path = argv[1]
    inputs = argv[2:]

    writer = PdfWriter()
    for inp in inputs:
        writer.append(inp)

    with open(output_path, "wb") as f:
        writer.write(f)

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
