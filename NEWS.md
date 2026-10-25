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
