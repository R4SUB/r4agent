# r4agent (development version)

- `write_agent_suite()` serialises an `r4agent_suite` back to the YAML that
  `read_agent_suite()` reads, so a suite built in R round-trips through a file.
  A case whose grader is a function cannot be serialised: it is kept with every
  other field and a warning names it, and its grader falls to the default on
  re-read.
- `consistency_strata()` reports run-to-run instability broken down by slice and
  by severity, so an unstable slice, or instability concentrated in the critical
  cases, is visible rather than averaged into one flat rate. The existing
  `consistency()` output is unchanged.
- `agent_suite()` now accepts bare cases (`agent_suite(case1, case2)`) as well
  as a list of cases, as its documentation already stated; previously a bare
  case was spliced into its fields and rejected.
- Added a "Getting started" vignette walking through a benchmark end to end
  with a deterministic, offline stand-in agent (no network or model calls).
- Expanded the test suite with edge cases for case and threshold validation,
  warn-as-half scoring, the readiness verdicts, custom and malformed graders,
  and the evidence, diff, consistency and report paths.

# r4agent 0.1.0

- Initial release.
- `agent_suite()`, `agent_case()`, `agent_thresholds()` and `read_agent_suite()`
  define a benchmark suite: cases with an expected answer, a slice and a
  severity, plus the slice thresholds agreed before a run.
- `run_benchmark()` runs an agent or language model against the suite and
  `score_slices()` grades the results locally and deterministically, with no
  model called to judge another model.
- `readiness()` returns a production readiness answer, `consistency()` checks
  run-to-run stability, and `diff_runs()` surfaces a case that used to pass and
  now fails instead of averaging it away.
- `agent_evidence()` emits the results as R4SUB evidence rows via 'r4subcore',
  and `report_markdown()` writes a shareable report.
- `register_grader()` and `graders_available()` expose the pluggable,
  offline grader interface.
