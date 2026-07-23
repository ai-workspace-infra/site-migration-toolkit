#!/usr/bin/env python3
"""Assert that job gating in .github/workflows/*.yaml is falsifiable.

Every check here corresponds to a defect this repository actually shipped, each
of which presented as a permanently `skipped` job rather than as an error. That
is the whole point: a broken gate is invisible in the run summary, so it has to
be caught by an assertion instead of by review.

  C1  folded-scalar `if:` that swallows the expression
  C2  skip propagating past an always() job into a downstream job without one
  C3  always() without a result assertion on each upstream
  C4  needs.<x> referenced in an `if:` but not declared in needs:

Exit 0 = all pass. Non-zero = at least one violation, listed on stderr.
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is required: pip install pyyaml")

WORKFLOW_DIR = Path(__file__).resolve().parents[2] / ".github" / "workflows"

violations = []


def report(wf, job, check, msg):
    violations.append(f"{wf}: job `{job}`: [{check}] {msg}")


def check_workflow(path):
    doc = yaml.safe_load(path.read_text())
    if not isinstance(doc, dict):
        return
    jobs = doc.get("jobs") or {}
    wf = path.name

    for name, cfg in jobs.items():
        if not isinstance(cfg, dict):
            continue
        cond = cfg.get("if")
        needs = cfg.get("needs") or []
        if isinstance(needs, str):
            needs = [needs]
        if cond is None:
            continue
        cond = str(cond)

        # C1 -- A folded scalar (`if: >-`) keeps a newline for every line
        # indented deeper than the first content line. The result is a string
        # containing "${{\n ... \n}}", which GitHub never evaluates as an
        # expression: it is truthy text, or falsy, but never the condition you
        # wrote. Keep every operand at one uniform indent.
        if cond.lstrip().startswith("${{") and "\n" in cond.strip():
            report(wf, name, "C1",
                   "`if:` folded scalar contains newlines inside ${{ }}; "
                   "indent every continuation line to the same column as the first")

        refs = set(re.findall(r"needs\.([A-Za-z0-9_-]+)\.", cond))

        if needs:
            # C2 -- A skipped job propagates its skip down the entire needs
            # chain. always() stops it only for the job carrying it, so a job
            # downstream of an always() job is skipped before its own `if` is
            # ever evaluated -- however correct that `if` may be.
            if "always()" not in cond:
                upstream_always = [
                    u for u in needs
                    if isinstance(jobs.get(u), dict) and "always()" in str(jobs[u].get("if", ""))
                ]
                if upstream_always:
                    report(wf, name, "C2",
                           f"needs {', '.join(upstream_always)} which run(s) under always(), "
                           f"but this job's `if:` has no always() -- it will be skipped "
                           f"without its condition ever being evaluated")

            # C3 -- always() also disables the implicit "upstream succeeded"
            # guard, so each upstream result has to be asserted explicitly or
            # the job runs after a real failure.
            if "always()" in cond:
                unasserted = [u for u in needs if u not in refs]
                if unasserted:
                    report(wf, name, "C3",
                           f"uses always() but never checks needs.<job>.result for: "
                           f"{', '.join(unasserted)} -- it would run after those fail")

        # C4 -- needs.<x> for a job absent from needs: evaluates to empty, so
        # the comparison is false and the job is skipped forever, silently.
        for ref in sorted(refs):
            if ref not in needs:
                report(wf, name, "C4",
                       f"`if:` reads needs.{ref}.* but `{ref}` is not in needs: "
                       f"-- it resolves to empty, making the condition permanently false")
            elif ref not in jobs:
                report(wf, name, "C4",
                       f"`if:` reads needs.{ref}.* but no job `{ref}` is defined")


def main():
    paths = sorted(p for p in WORKFLOW_DIR.iterdir()
                   if p.suffix in (".yaml", ".yml"))
    if not paths:
        sys.exit(f"no workflows found under {WORKFLOW_DIR}")

    for path in paths:
        check_workflow(path)

    if violations:
        print(f"FAIL: {len(violations)} gating violation(s)", file=sys.stderr)
        for v in violations:
            print(f"  {v}", file=sys.stderr)
        return 1

    print(f"OK: job gating verified across {len(paths)} workflow(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
