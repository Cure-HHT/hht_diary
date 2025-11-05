#!/usr/bin/env python3
"""
Visualize current vs proposed documentation structure for refactoring plan.
"""

def print_tree(label: str, structure: dict, indent: int = 0):
    """Print tree structure."""
    prefix = "  " * indent
    print(f"{prefix}{label}")

    for key, value in structure.items():
        if isinstance(value, dict):
            print(f"{prefix}├─ {key}/")
            print_tree("", value, indent + 1)
        elif isinstance(value, list):
            for item in value:
                if isinstance(item, dict):
                    for k, v in item.items():
                        print(f"{prefix}│  ├─ {k}")
                        if v:
                            for line in v:
                                print(f"{prefix}│  │  └─ {line}")
                else:
                    print(f"{prefix}│  ├─ {item}")
        else:
            print(f"{prefix}├─ {key}: {value}")


def main():
    print("\n" + "="*80)
    print("CURRENT STRUCTURE (Diary-Centric)")
    print("="*80 + "\n")

    current = {
        "spec/": {
            "Database PRDs (Mixed Generic + Diary)": [
                {"prd-database.md": [
                    "REQ-p00003: Separate DB Per Sponsor (diary)",
                    "REQ-p00013: Change History (generic-ish)"
                ]},
                {"prd-database-event-sourcing.md": [
                    "REQ-p00004: Event Sourcing Audit Trail (generic)"
                ]},
            ],
            "Database Dev (Heavily Diary-Specific)": [
                {"dev-database.md": [
                    "REQ-d00007: Schema Implementation (mixed)",
                    "REQ-d00011: Multi-Site Schema (diary)",
                    "Lots of diary schema details"
                ]},
                {"dev-database-queries.md": [
                    "Patient queries",
                    "Site queries",
                    "Diary entry queries"
                ]},
                {"dev-database-reference.md": [
                    "Diary-specific schema reference"
                ]},
            ],
            "Database Ops (Heavily Diary-Specific)": [
                {"ops-database-setup.md": [
                    "REQ-o00003: Supabase Per Sponsor (diary)",
                    "REQ-o00004: Schema Deployment (mixed)",
                    "REQ-o00011: Multi-Site Config (diary)"
                ]},
                {"ops-database-migration.md": [
                    "Diary-specific migration procedures"
                ]},
            ],
            "Mobile Client (Already Generic!)": [
                {"prd-flutter-event-sourcing.md": [
                    "REQ-p01000-p01019: All generic!",
                    "22x more generic than diary content"
                ]},
            ],
        }
    }

    print("spec/")
    print("│")
    print("├─ Database PRDs (Mixed Generic + Diary)")
    print("│  ├─ prd-database.md")
    print("│  │  ├─ REQ-p00003: Separate DB Per Sponsor [DIARY]")
    print("│  │  └─ REQ-p00013: Change History [GENERIC-ISH]")
    print("│  └─ prd-database-event-sourcing.md")
    print("│     └─ REQ-p00004: Event Sourcing Audit Trail [GENERIC]")
    print("│")
    print("├─ Database Dev (Heavily Diary-Specific)")
    print("│  ├─ dev-database.md")
    print("│  │  ├─ REQ-d00007: Schema Implementation [MIXED]")
    print("│  │  ├─ REQ-d00011: Multi-Site Schema [DIARY]")
    print("│  │  └─ Diary schema: patients, sites, investigators...")
    print("│  ├─ dev-database-queries.md (patient/site queries)")
    print("│  └─ dev-database-reference.md (diary schema reference)")
    print("│")
    print("├─ Database Ops (Heavily Diary-Specific)")
    print("│  ├─ ops-database-setup.md")
    print("│  │  ├─ REQ-o00003: Supabase Per Sponsor [DIARY]")
    print("│  │  ├─ REQ-o00004: Schema Deployment [MIXED]")
    print("│  │  └─ REQ-o00011: Multi-Site Config [DIARY]")
    print("│  └─ ops-database-migration.md (diary migrations)")
    print("│")
    print("└─ Mobile Client (Already Generic! ✅)")
    print("   └─ prd-flutter-event-sourcing.md")
    print("      └─ REQ-p01000-p01019: All generic event-sourcing")

    print("\n" + "="*80)
    print("PROPOSED STRUCTURE (Layered: Generic + Diary)")
    print("="*80 + "\n")

    print("spec/")
    print("│")
    print("├─ 📦 GENERIC EVENT-SOURCING LAYER (New - Reusable)")
    print("│  │")
    print("│  ├─ prd-event-sourcing-system.md [NEW]")
    print("│  │  ├─ REQ-p02000: Event Store Append-Only Architecture")
    print("│  │  ├─ REQ-p02001: Materialized View Pattern")
    print("│  │  ├─ REQ-p02002: Event Replay Capability")
    print("│  │  ├─ REQ-p02003: Multi-Tenant Data Isolation")
    print("│  │  └─ REQ-p02004-02010: Other generic patterns...")
    print("│  │")
    print("│  ├─ dev-event-sourcing-postgres.md [NEW]")
    print("│  │  ├─ REQ-d02000: Event Store Table Implementation")
    print("│  │  ├─ REQ-d02001: Automatic Read Model Updates")
    print("│  │  ├─ REQ-d02002: Event Replay Queries")
    print("│  │  └─ REQ-d02003-02010: Generic PostgreSQL patterns...")
    print("│  │")
    print("│  └─ ops-event-sourcing-deployment.md [NEW]")
    print("│     ├─ REQ-o02000: Event Store Database Provisioning")
    print("│     ├─ REQ-o02001: Schema Migration Procedures")
    print("│     ├─ REQ-o02002: Multi-Tenant Configuration")
    print("│     └─ REQ-o02003-02010: Generic deployment patterns...")
    print("│")
    print("├─ 📱 MOBILE CLIENT LAYER (Existing - Already Generic! ✅)")
    print("│  │")
    print("│  └─ prd-flutter-event-sourcing.md")
    print("│     └─ REQ-p01000-p01019: Mobile client capabilities")
    print("│")
    print("└─ 📋 DIARY IMPLEMENTATION LAYER (Modified - Now Thin)")
    print("   │")
    print("   ├─ prd-diary-database.md [RENAMED from prd-database.md]")
    print("   │  ├─ REQ-p00003: Separate DB Per Sponsor")
    print("   │  │  └─ Implements: REQ-p02003 [LINK ADDED]")
    print("   │  ├─ REQ-p00013: Complete Data Change History")
    print("   │  │  └─ Implements: REQ-p02000, REQ-p02001 [LINKS ADDED]")
    print("   │  └─ Diary-specific requirements context")
    print("   │")
    print("   ├─ dev-diary-database.md [REFACTORED from dev-database.md]")
    print("   │  ├─ REQ-d00007: Database Schema Implementation")
    print("   │  │  └─ Implements: REQ-d02000, REQ-d02001 [LINKS ADDED]")
    print("   │  ├─ REQ-d00011: Multi-Site Schema Implementation")
    print("   │  │  └─ Implements: REQ-d02002 [LINK ADDED]")
    print("   │  └─ Diary schema: patients, sites, diary_entries...")
    print("   │")
    print("   ├─ dev-diary-database-queries.md [FOCUSED]")
    print("   │  └─ Patient/site/diary queries")
    print("   │")
    print("   └─ ops-diary-database-setup.md [REFACTORED]")
    print("      ├─ REQ-o00003: Supabase Project Per Sponsor")
    print("      │  └─ Implements: REQ-o02000 [LINK ADDED]")
    print("      ├─ REQ-o00004: Database Schema Deployment")
    print("      │  └─ Implements: REQ-o02001 [LINK ADDED]")
    print("      └─ REQ-o00011: Multi-Site Data Configuration")
    print("         └─ Implements: REQ-o02002 [LINK ADDED]")

    print("\n" + "="*80)
    print("KEY CHANGES")
    print("="*80 + "\n")

    print("✅ PRESERVED:")
    print("   - All existing REQ-IDs unchanged (p00003, p00004, p00013, d00007, d00011, o00003, o00004, o00011)")
    print("   - All existing requirement text preserved")
    print("   - All existing files kept (just renamed/refactored)")
    print()
    print("🆕 ADDED:")
    print("   - Generic layer: 3 new files with ~30 new requirements (REQ-p/o/d-02000 range)")
    print("   - 'Implements' links from diary requirements to generic requirements")
    print("   - Cross-references between layers")
    print()
    print("📝 MODIFIED:")
    print("   - Renamed: prd-database.md → prd-diary-database.md (clearer name)")
    print("   - Refactored: dev-database.md → focus on diary schema, reference generic")
    print("   - Updated: All diary files add 'Implements: REQ-02XXX' links")
    print()
    print("🎯 BENEFITS:")
    print("   - Generic layer reusable for other event-sourced apps")
    print("   - Clear separation of reusable vs app-specific concerns")
    print("   - Foundation for extracting 'event-sourcing-core' package")
    print("   - Easier to understand and maintain")
    print()
    print("⚠️  RISKS:")
    print("   - More files to maintain")
    print("   - Team must understand layered structure")
    print("   - Initial time investment")
    print()

    print("\n" + "="*80)
    print("EXAMPLE: How Requirements Connect After Refactoring")
    print("="*80 + "\n")

    print("BEFORE:")
    print("  REQ-p00004: Immutable Audit Trail via Event Sourcing")
    print("  └─ (Stands alone, no generic foundation)")
    print()

    print("AFTER:")
    print("  REQ-p02000: Event Store Append-Only Architecture [GENERIC]")
    print("  └─ REQ-p00004: Immutable Audit Trail via Event Sourcing [DIARY]")
    print("     └─ Implements: REQ-p02000")
    print("     └─ Adds: Clinical trial specific audit requirements")
    print()

    print("Result: Generic pattern reusable, diary adds domain specifics")
    print()


if __name__ == '__main__':
    main()
