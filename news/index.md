# Changelog

## r4agent 0.1.0

- Initial release.
- [`agent_suite()`](https://r4sub.github.io/r4agent/reference/agent_suite.md),
  [`agent_case()`](https://r4sub.github.io/r4agent/reference/agent_case.md),
  [`agent_thresholds()`](https://r4sub.github.io/r4agent/reference/agent_thresholds.md)
  and
  [`read_agent_suite()`](https://r4sub.github.io/r4agent/reference/read_agent_suite.md)
  define a benchmark suite: cases with an expected answer, a slice and a
  severity, plus the slice thresholds agreed before a run.
- [`run_benchmark()`](https://r4sub.github.io/r4agent/reference/run_benchmark.md)
  runs an agent or language model against the suite and
  [`score_slices()`](https://r4sub.github.io/r4agent/reference/score_slices.md)
  grades the results locally and deterministically, with no model called
  to judge another model.
- [`readiness()`](https://r4sub.github.io/r4agent/reference/readiness.md)
  returns a production readiness answer,
  [`consistency()`](https://r4sub.github.io/r4agent/reference/consistency.md)
  checks run-to-run stability, and
  [`diff_runs()`](https://r4sub.github.io/r4agent/reference/diff_runs.md)
  surfaces a case that used to pass and now fails instead of averaging
  it away.
- [`agent_evidence()`](https://r4sub.github.io/r4agent/reference/agent_evidence.md)
  emits the results as R4SUB evidence rows via ‘r4subcore’, and
  [`report_markdown()`](https://r4sub.github.io/r4agent/reference/report_markdown.md)
  writes a shareable report.
- [`register_grader()`](https://r4sub.github.io/r4agent/reference/register_grader.md)
  and
  [`graders_available()`](https://r4sub.github.io/r4agent/reference/graders_available.md)
  expose the pluggable, offline grader interface.
