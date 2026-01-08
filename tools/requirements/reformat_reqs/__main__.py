"""
Allow running the package as a module:
    python -m tools.requirements.reformat_reqs
"""

from .cli import main
import sys

if __name__ == '__main__':
    sys.exit(main())
