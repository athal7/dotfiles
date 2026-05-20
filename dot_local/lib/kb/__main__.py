"""kb — dispatch subcommands for knowledge base tools.

Usage:
    python3 -m kb meeting [/path/to/caption.txt]
    python3 -m kb enrich [--slack] [--linear] [--email] [--since HOURS] [--dry-run]
"""
import sys, traceback


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(0 if sys.argv[1:] == ["--help"] or sys.argv[1:] == ["-h"] else 1)

    subcommand = sys.argv[1]
    remaining = sys.argv[2:]

    if subcommand == "meeting":
        from kb.meeting import main as meeting_main, report_error, log
        try:
            meeting_main(remaining)
        except Exception as e:
            log(f"FATAL: {e}")
            traceback.print_exc(file=sys.stderr)
            report_error("unknown meeting", str(e))
            sys.exit(1)

    elif subcommand == "enrich":
        from kb.enrich import main as enrich_main, log
        try:
            enrich_main(remaining)
        except Exception as e:
            log(f"FATAL: {e}")
            traceback.print_exc(file=sys.stderr)
            sys.exit(1)

    else:
        print(f"Unknown subcommand: {subcommand}", file=sys.stderr)
        print(__doc__.strip(), file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
