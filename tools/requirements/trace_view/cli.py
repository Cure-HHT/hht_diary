"""
Command-line interface for trace-view.

Provides the main entry point for the trace-view tool.
"""

import argparse
import sys
from pathlib import Path
from typing import List, Optional

from .git_state import get_elspais_config


def create_parser() -> argparse.ArgumentParser:
    """Create the argument parser for trace-view CLI.

    Returns:
        Configured ArgumentParser instance
    """
    parser = argparse.ArgumentParser(
        description='Generate requirements traceability matrix with test coverage',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Tip: Use --format both to generate both markdown and HTML versions

Examples:
  # Generate matrix for current repo
  python trace_view.py

  # Generate matrix for a different repo
  python trace_view.py --path /path/to/other/repo

  # Generate for sibling repo with HTML output
  python trace_view.py --path ../sibling-repo --format html
'''
    )
    parser.add_argument(
        '--format',
        choices=['markdown', 'html', 'csv', 'both'],
        default='markdown',
        help='Output format (default: markdown). Use "both" for markdown + HTML'
    )
    parser.add_argument(
        '--output',
        type=Path,
        help='Output file path (default: traceability_matrix.{format})'
    )
    parser.add_argument(
        '--sponsor',
        type=str,
        help='Sponsor name for sponsor-specific reports (e.g., "callisto", "titan")'
    )
    parser.add_argument(
        '--mode',
        choices=['core', 'sponsor', 'combined'],
        default='core',
        help='Report mode: "core" (exclude sponsor code), "sponsor" (specific sponsor + core), "combined" (all code)'
    )
    parser.add_argument(
        '--output-dir',
        type=Path,
        help='Output directory path (overrides default based on mode)'
    )
    parser.add_argument(
        '--path',
        type=Path,
        help='Path to repository root (default: auto-detect from script location)'
    )
    parser.add_argument(
        '--embed-content',
        action='store_true',
        help='Embed full requirement content in HTML for portable/offline viewing'
    )
    parser.add_argument(
        '--edit-mode',
        action='store_true',
        help='Enable edit mode UI in HTML output'
    )
    parser.add_argument(
        '--export-planning',
        action='store_true',
        help='Generate planning CSV with actionable requirements'
    )
    parser.add_argument(
        '--coverage-report',
        action='store_true',
        help='Generate coverage report showing implementation status statistics'
    )

    return parser


def get_impl_dirs(
    repo_root: Path,
    mode: str,
    sponsor: Optional[str],
    elspais_config: dict
) -> List[Path]:
    """Get implementation directories based on mode and config.

    Args:
        repo_root: Repository root path
        mode: Report mode ('core', 'sponsor', 'combined')
        sponsor: Sponsor name for sponsor mode
        elspais_config: Elspais configuration dict

    Returns:
        List of implementation directory paths
    """
    directories_config = elspais_config.get('directories', {})
    code_dirs = directories_config.get('code', ['apps', 'packages', 'server', 'tools'])
    database_dir_name = directories_config.get('database', 'database')

    impl_dirs = []

    def add_core_impl_dirs():
        """Add core implementation directories from elspais config"""
        # Add database directory
        database_dir = repo_root / database_dir_name
        if database_dir.exists():
            impl_dirs.append(database_dir)

        # Add code directories
        for code_dir_name in code_dirs:
            code_dir = repo_root / code_dir_name
            if code_dir.exists():
                impl_dirs.append(code_dir)

    if mode == 'core':
        print(f"Mode: CORE - scanning core directories only")
        add_core_impl_dirs()

    elif mode == 'sponsor':
        print(f"Mode: SPONSOR ({sponsor}) - scanning sponsor + core directories")
        sponsor_dir = repo_root / 'sponsor' / sponsor
        if not sponsor_dir.exists():
            print(f"Warning: Sponsor directory not found: {sponsor_dir}")
        else:
            impl_dirs.append(sponsor_dir)
        add_core_impl_dirs()

    elif mode == 'combined':
        print(f"Mode: COMBINED - scanning all directories")
        add_core_impl_dirs()
        sponsor_root = repo_root / 'sponsor'
        if sponsor_root.exists():
            for sponsor_dir in sponsor_root.iterdir():
                if sponsor_dir.is_dir() and not sponsor_dir.name.startswith('.'):
                    impl_dirs.append(sponsor_dir)
                    print(f"   Including sponsor: {sponsor_dir.name}")

    return impl_dirs


def get_output_path(
    args: argparse.Namespace,
    repo_root: Path,
    elspais_config: dict
) -> Path:
    """Determine output path based on arguments and config.

    Args:
        args: Parsed command-line arguments
        repo_root: Repository root path
        elspais_config: Elspais configuration dict

    Returns:
        Output file path
    """
    traceability_config = elspais_config.get('traceability', {})

    if args.output:
        return args.output

    if args.output_dir:
        output_dir = args.output_dir
        output_dir.mkdir(parents=True, exist_ok=True)
        if args.format == 'both':
            return output_dir / 'traceability_matrix.md'
        ext = '.html' if args.format == 'html' else ('.csv' if args.format == 'csv' else '.md')
        return output_dir / f'traceability_matrix{ext}'

    # Use default output path from elspais config
    default_output_dir = traceability_config.get('output_dir', 'build-reports/combined/traceability')
    if args.mode == 'sponsor':
        output_dir = repo_root / 'build-reports' / args.sponsor / 'traceability'
    else:
        output_dir = repo_root / default_output_dir

    output_dir.mkdir(parents=True, exist_ok=True)

    if args.format == 'both':
        return output_dir / 'traceability_matrix.md'
    ext = '.html' if args.format == 'html' else ('.csv' if args.format == 'csv' else '.md')
    return output_dir / f'traceability_matrix{ext}'


def main():
    """Main entry point for trace-view CLI.

    Note: Currently delegates to the original TraceabilityGenerator for
    backward compatibility. Future versions will use TraceViewGenerator.
    """
    # Import here to avoid circular imports during module extraction
    # This will be replaced with TraceViewGenerator once fully migrated
    import sys
    sys.path.insert(0, str(Path(__file__).parent.parent))
    from generate_traceability import TraceabilityGenerator

    parser = create_parser()
    args = parser.parse_args()

    # Validate sponsor argument
    if args.mode == 'sponsor' and not args.sponsor:
        print("Error: --sponsor is required when --mode is 'sponsor'")
        sys.exit(1)

    # Get elspais configuration
    elspais_config = get_elspais_config()
    directories_config = elspais_config.get('directories', {})

    # Find repo root and spec directory
    if args.path:
        repo_root = args.path.resolve()
    else:
        script_dir = Path(__file__).parent
        repo_root = script_dir.parent.parent.parent  # trace_view -> requirements -> tools -> repo

    spec_dir_name = directories_config.get('spec', 'spec')
    spec_dir = repo_root / spec_dir_name

    if not spec_dir.exists():
        print(f"❌ Spec directory not found: {spec_dir}")
        sys.exit(1)

    # Get implementation directories
    impl_dirs = get_impl_dirs(repo_root, args.mode, args.sponsor, elspais_config)

    # Create generator
    generator = TraceabilityGenerator(
        spec_dir,
        impl_dirs=impl_dirs,
        sponsor=args.sponsor,
        mode=args.mode,
        repo_root=repo_root
    )

    # Determine output path
    output_file = get_output_path(args, repo_root, elspais_config)

    # Handle special export options
    if args.export_planning:
        print("📋 Generating planning CSV...")
        generator._parse_requirements()
        if generator.impl_dirs:
            generator._scan_implementation_files()
        planning_csv = generator._generate_planning_csv()
        planning_file = output_file.parent / 'planning_export.csv'
        planning_file.write_text(planning_csv)
        print(f"✅ Planning CSV written to: {planning_file}")

    if args.coverage_report:
        print("📊 Generating coverage report...")
        if not generator.requirements:
            generator._parse_requirements()
            if generator.impl_dirs:
                generator._scan_implementation_files()
        coverage_report = generator._generate_coverage_report()
        report_file = output_file.parent / 'coverage_report.txt'
        report_file.write_text(coverage_report)
        print(f"✅ Coverage report written to: {report_file}")

    # Skip matrix if only special exports
    if args.export_planning or args.coverage_report:
        if not (args.format or args.output):
            return

    # Generate matrix
    if args.format == 'both':
        print("Generating both Markdown and HTML formats...")
        md_output = output_file if output_file.suffix == '.md' else output_file.with_suffix('.md')
        generator.generate(format='markdown', output_file=md_output)
        html_output = md_output.with_suffix('.html')
        generator.generate(format='html', output_file=html_output,
                          embed_content=args.embed_content, edit_mode=args.edit_mode)
    else:
        generator.generate(format=args.format, output_file=output_file,
                          embed_content=args.embed_content, edit_mode=args.edit_mode)


if __name__ == '__main__':
    main()
