# Confidence intervals on the per-slice scores

A per-slice score is a proportion estimated from a handful of cases, and
a proportion from a handful of cases is noise with a decimal point. A
slice of three cases that all passed scores 1.0, and a slice of three
hundred that all passed also scores 1.0; \[readiness()\] treats the two
identically and \[suite_audit()\] can only warn that the first is "too
thin" without saying how thin. This puts a number on it.

## Usage

``` r
score_confidence(run, thresholds = NULL, rep = 1L, conf_level = 0.95)
```

## Arguments

- run:

  An \`r4agent_run\`.

- thresholds:

  Optional \`r4agent_thresholds\`. When given, each slice's threshold
  and the two clearance decisions are attached.

- rep:

  Which repeat to score.

- conf_level:

  Confidence level, a single number strictly between 0 and 1. Defaults
  to 0.95.

## Value

A data frame of class \`r4agent_confidence\`, one row per slice plus a
TOTAL row, with columns \`slice\`, \`cases\`, \`score\`, \`lower\` and
\`upper\`, and, when \`thresholds\` are supplied, \`threshold\`,
\`clears_point\` and \`clears_lower\` (the last two are \`NA\` on the
TOTAL row, which has no threshold of its own).

## Details

For each slice it returns the score from \[score_slices()\] with a lower
and an upper bound at \`conf_level\`, computed as a Wilson score
interval. A "warn" counts as half, exactly as everywhere else in the
package, so the score is the mean of per-case scores of 0, 0.5 or 1 and
the interval is around that mean. For a slice that contains warns the
interval is an approximation (an interval on an effective pass
proportion), which is the honest state of affairs for the bounded mean
of a few discrete values.

The Wilson interval is used rather than the textbook normal
approximation because the normal one is useless at the edges, and the
edges are where a benchmark lives: a slice that passed every case has a
point estimate of 1, where the normal interval has zero width and claims
certainty from three observations. Wilson does not, and it is a closed
form that needs no resampling and no seed, so the bounds are
reproducible from the run alone.

When \`thresholds\` are supplied the slice's threshold is attached
together with two decisions: \`clears_point\`, whether the point score
meets it (what \[readiness()\] uses), and \`clears_lower\`, whether even
the lower bound meets it. A slice that clears on the point estimate but
not on the lower bound has not been shown to clear; it simply has too
few cases to tell. That distinction is the whole reason this function
exists. It changes no score and no verdict: \[readiness()\] is unchanged
and this is an opt-in second look.

## See also

\[score_slices()\], \[readiness()\], \[suite_audit()\]

## Examples

``` r
suite <- agent_suite(list(
  agent_case("a1", "x", "1", grader = "contains", slice = "small"),
  agent_case("a2", "x", "1", grader = "contains", slice = "small"),
  agent_case("a3", "x", "1", grader = "contains", slice = "small")
))
run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
# Three for three is a perfect point score and a wide interval.
score_confidence(run)
#> 
#> ── Per-slice score with 95% confidence interval ────────────────────────────────
#> small 1.0000 [0.4385, 1.0000] (n = 3)
#> TOTAL 1.0000 [0.4385, 1.0000] (n = 3)

# With thresholds, the point score clears 0.9 but the lower bound does not:
# three cases are not enough to claim the slice is ready.
score_confidence(run, agent_thresholds(default = 0.9))
#> 
#> ── Per-slice score with 95% confidence interval ────────────────────────────────
#> [~] small 1.0000 [0.4385, 1.0000] vs 0.9 (n = 3)
#> TOTAL 1.0000 [0.4385, 1.0000] (n = 3)
#> 
#> [v] lower bound clears [~] only the point estimate clears [x] neither
```
