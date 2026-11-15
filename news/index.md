# Changelog

## r4agent (development version)

- [`agent_agreement()`](https://r4sub.github.io/r4agent/reference/agent_agreement.md)
  reports inter-run reliability from a run with repeats: overall percent
  agreement (mean pairwise), Cohen’s kappa for two runs or Fleiss’ kappa
  for three or more, and a per-case breakdown ordered with the
  least-agreeing cases first. Where
  [`consistency()`](https://r4sub.github.io/r4agent/reference/consistency.md)
  gives a raw disagreement rate and
  [`score_confidence()`](https://r4sub.github.io/r4agent/reference/score_confidence.md)
  bounds a single run’s score, this is the chance-corrected agreement
  across repeated runs. Textbook formulas (Cohen 1960, Fleiss 1971) with
  the Landis & Koch (1977) strength label cited in the help; it calls no
  model and changes no score or verdict.
- [`score_confidence()`](https://r4sub.github.io/r4agent/reference/score_confidence.md)
  puts a Wilson confidence interval on each per-slice score, so a slice
  of three passing cases (point score 1.0) is no longer read the same as
  a slice of three hundred. Supply `thresholds` and it reports both
  whether the point score clears the bar and whether even the lower
  bound does; a slice that clears on the point estimate but not the
  lower bound has too few cases to claim. The interval is a closed form,
  deterministic and offline, and the function changes no score and no
  verdict:
  [`readiness()`](https://r4sub.github.io/r4agent/reference/readiness.md)
  is unchanged.
- [`diff_runs()`](https://r4sub.github.io/r4agent/reference/diff_runs.md)
  now lists regressions most-severe first. It had ordered them by the
  severity string, which sorts alphabetically and pushed a failed
  critical case to the bottom of the list instead of the top.
- [`suite_audit()`](https://r4sub.github.io/r4agent/reference/suite_audit.md)
  lints an `r4agent_suite` for coverage and quality gaps: families or
  severities with no cases, slices below a minimum case count, cases
  with no stated `why`, and the absence of abstention or injection
  coverage. The findings are advisory, carry no severity and change no
  score or verdict; the audit never runs the suite or calls a model.
- [`write_agent_suite()`](https://r4sub.github.io/r4agent/reference/write_agent_suite.md)
  serialises an `r4agent_suite` back to the YAML that
  [`read_agent_suite()`](https://r4sub.github.io/r4agent/reference/read_agent_suite.md)
  reads, so a suite built in R round-trips through a file. A case whose
  grader is a function cannot be serialised: it is kept with every other
  field and a warning names it, and its grader falls to the default on
  re-read.
- [`consistency_strata()`](https://r4sub.github.io/r4agent/reference/consistency_strata.md)
  reports run-to-run instability broken down by slice and by severity,
  so an unstable slice, or instability concentrated in the critical
  cases, is visible rather than averaged into one flat rate. The
  existing
  [`consistency()`](https://r4sub.github.io/r4agent/reference/consistency.md)
  output is unchanged.
- [`agent_suite()`](https://r4sub.github.io/r4agent/reference/agent_suite.md)
  now accepts bare cases (`agent_suite(case1, case2)`) as well as a list
  of cases, as its documentation already stated; previously a bare case
  was spliced into its fields and rejected.
- Added a “Getting started” vignette walking through a benchmark end to
  end with a deterministic, offline stand-in agent (no network or model
  calls).
- Expanded the test suite with edge cases for case and threshold
  validation, warn-as-half scoring, the readiness verdicts, custom and
  malformed graders, and the evidence, diff, consistency and report
  paths.

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
