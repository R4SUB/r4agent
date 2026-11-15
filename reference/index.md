# Package index

## Suite definition

- [`agent_suite()`](https://r4sub.github.io/r4agent/reference/agent_suite.md)
  : Collect cases into a suite
- [`agent_case()`](https://r4sub.github.io/r4agent/reference/agent_case.md)
  : Define one benchmark case
- [`agent_thresholds()`](https://r4sub.github.io/r4agent/reference/agent_thresholds.md)
  : Set the thresholds a run will be judged against
- [`agent_families`](https://r4sub.github.io/r4agent/reference/agent_families.md)
  : Families of measurement, and how they map onto the R4SUB evidence
  schema
- [`read_agent_suite()`](https://r4sub.github.io/r4agent/reference/read_agent_suite.md)
  : Read a suite from YAML
- [`write_agent_suite()`](https://r4sub.github.io/r4agent/reference/write_agent_suite.md)
  : Write a suite to YAML

## Running and scoring

- [`run_benchmark()`](https://r4sub.github.io/r4agent/reference/run_benchmark.md)
  : Run a benchmark
- [`score_slices()`](https://r4sub.github.io/r4agent/reference/score_slices.md)
  : Score a run by slice
- [`score_confidence()`](https://r4sub.github.io/r4agent/reference/score_confidence.md)
  : Confidence intervals on the per-slice scores
- [`readiness()`](https://r4sub.github.io/r4agent/reference/readiness.md)
  : Decide whether the system is ready
- [`consistency()`](https://r4sub.github.io/r4agent/reference/consistency.md)
  : Run to run consistency
- [`consistency_strata()`](https://r4sub.github.io/r4agent/reference/consistency_strata.md)
  : Run to run consistency, broken down by slice and severity
- [`agent_evidence()`](https://r4sub.github.io/r4agent/reference/agent_evidence.md)
  : Convert a run to R4SUB evidence

## Comparison and reporting

- [`diff_runs()`](https://r4sub.github.io/r4agent/reference/diff_runs.md)
  : Compare two runs
- [`report_markdown()`](https://r4sub.github.io/r4agent/reference/report_markdown.md)
  : Write the report
- [`agent_agreement()`](https://r4sub.github.io/r4agent/reference/agent_agreement.md)
  : Inter-run agreement and reliability
- [`suite_audit()`](https://r4sub.github.io/r4agent/reference/suite_audit.md)
  : Audit a suite for coverage and quality gaps

## Graders

- [`graders`](https://r4sub.github.io/r4agent/reference/graders.md) :
  Graders
- [`graders_available()`](https://r4sub.github.io/r4agent/reference/graders_available.md)
  : List registered graders
- [`register_grader()`](https://r4sub.github.io/r4agent/reference/register_grader.md)
  : Register a grader

## Methods

- [`as.data.frame(`*`<r4agent_suite>`*`)`](https://r4sub.github.io/r4agent/reference/as.data.frame.r4agent_suite.md)
  : Turn a suite into a data frame
