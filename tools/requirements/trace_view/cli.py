"""
Command-line interface for trace-view.

Provides the main entry point for the trace-view tool.
"""

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import List, Optional

from .git_state import get_elspais_config


def resolve_associated_repos(repo_root: Path, enabled_only: bool = True) -> list:
    """Resolve associated repos using resolve-sponsors.sh script.

    Args:
        repo_root: Repository root path
        enabled_only: Only include enabled repos

    Returns:
        List of repo dicts with name, code, path, etc.
    """
    script_path = repo_root / 'tools' / 'build' / 'resolve-sponsors.sh'

    if not script_path.exists():
        print(f"Warning: resolve-sponsors.sh not found at {script_path}")
        return []

    cmd = [str(script_path), '--json', '--quiet']
    if enabled_only:
        cmd.append('--enabled-only')

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        return json.loads(result.stdout)
    except subprocess.CalledProcessError as e:
        print(f"Warning: resolve-sponsors.sh failed: {e.stderr}")
        return []
    except json.JSONDecodeError as e:
        print(f"Warning: Failed to parse repo JSON: {e}")
        return []


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
  # Generate matrix using config defaults
  python trace_view.py

  # Generate matrix excluding associated repos
  python trace_view.py --mode core

  # Generate matrix for specific repo only
  python trace_view.py --only-repo callisto

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
        '--only-repo',
        type=str,
        metavar='NAME',
        help='Filter to specific repo only (e.g., "callisto", "titan")'
    )
    parser.add_argument(
        '--mode',
        choices=['core'],
        help='Override mode: "core" excludes associated repos'
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
        '--review-mode',
        action='store_true',
        help='Enable review mode UI in HTML output for collaborative spec reviews'
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
    parser.add_argument(
        '--resolve-repos',
        action='store_true',
        help='Use tools/build/resolve-sponsors.sh to discover associated repos'
    )

    return parser


def get_impl_dirs(
    repo_root: Path,
    elspais_config: dict,
    mode_override: Optional[str] = None,
    only_repo: Optional[str] = None,
    use_resolve_repos: bool = False
) -> List[Path]:
    """Get implementation directories based on config and overrides.

    Args:
        repo_root: Repository root path
        elspais_config: Elspais configuration dict
        mode_override: Optional mode override ('core' to exclude associated)
        only_repo: Filter to specific repo only
        use_resolve_repos: Use resolve-sponsors.sh for discovery

    Returns:
        List of implementation directory paths
    """
    directories_config = elspais_config.get('directories', {})
    traceability_config = elspais_config.get('traceability', {})

    code_dirs = directories_config.get('code', ['apps', 'packages', 'server', 'tools'])
    database_dir_name = directories_config.get('database', 'database')

    # Read default from config
    include_associated = traceability_config.get('include_associated', True)

    # Apply mode override
    if mode_override == 'core':
        include_associated = False

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

    def add_associated_dirs(filter_name: Optional[str] = None):
        """Add associated repo directories"""
        if use_resolve_repos:
            # Use resolve-sponsors.sh for discovery
            repos = resolve_associated_repos(repo_root, enabled_only=True)
            for repo in repos:
                repo_name = repo.get('name')
                repo_path = repo.get('path')

                # Skip if filtering and doesn't match
                if filter_name and repo_name != filter_name:
                    continue

                if repo_path and Path(repo_path).exists():
                    impl_dirs.append(Path(repo_path))
                    print(f"   Including: {repo_name} ({repo.get('code')})")
        else:
            # Fall back to directory scan
            associated_root = repo_root / 'sponsor'
            if associated_root.exists():
                for repo_dir in associated_root.iterdir():
                    if repo_dir.is_dir() and not repo_dir.name.startswith('.'):
                        # Skip if filtering and doesn't match
                        if filter_name and repo_dir.name != filter_name:
                            continue
                        impl_dirs.append(repo_dir)
                        print(f"   Including: {repo_dir.name}")

    # Handle --only-repo: specific repo + core
    if only_repo:
        print(f"Mode: ONLY-REPO ({only_repo}) - scanning specific repo + core")
        add_associated_dirs(filter_name=only_repo)
        add_core_impl_dirs()
    # Handle --mode core: exclude associated
    elif not include_associated:
        print(f"Mode: CORE - scanning core directories only")
        add_core_impl_dirs()
    # Default: include associated repos per config
    else:
        print(f"Mode: DEFAULT - scanning all directories (include_associated=true)")
        add_core_impl_dirs()
        add_associated_dirs()

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
    if args.only_repo:
        output_dir = repo_root / 'build-reports' / args.only_repo / 'traceability'
    else:
        output_dir = repo_root / default_output_dir

    output_dir.mkdir(parents=True, exist_ok=True)

    if args.format == 'both':
        return output_dir / 'traceability_matrix.md'
    ext = '.html' if args.format == 'html' else ('.csv' if args.format == 'csv' else '.md')
    return output_dir / f'traceability_matrix{ext}'


def main():
    """Main entry point for trace-view CLI."""
    from .generators import TraceViewGenerator

    parser = create_parser()
    args = parser.parse_args()

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
    impl_dirs = get_impl_dirs(
        repo_root,
        elspais_config,
        mode_override=args.mode,
        only_repo=args.only_repo,
        use_resolve_repos=args.resolve_repos
    )

    # Determine effective mode for generator (for backwards compatibility)
    if args.only_repo:
        effective_mode = 'sponsor'  # Legacy mode name for generator
    elif args.mode == 'core':
        effective_mode = 'core'
    else:
        effective_mode = 'combined'  # Default includes associated

    # Create generator
    generator = TraceViewGenerator(
        spec_dir,
        impl_dirs=impl_dirs,
        sponsor=args.only_repo,  # Legacy parameter name
        mode=effective_mode,
        repo_root=repo_root
    )

    # Determine output path
    output_file = get_output_path(args, repo_root, elspais_config)

    # Handle special export options
    if args.export_planning:
        print("📋 Generating planning CSV...")
        generator._init_git_state()
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
            generator._init_git_state()
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
                          embed_content=args.embed_content, edit_mode=args.edit_mode,
                          review_mode=args.review_mode)
    else:
        generator.generate(format=args.format, output_file=output_file,
                          embed_content=args.embed_content, edit_mode=args.edit_mode,
                          review_mode=args.review_mode)


if __name__ == '__main__':
    main()
