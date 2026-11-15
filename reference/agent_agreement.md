# Inter-run agreement and reliability

\[consistency()\] answers whether an agent is stable across repeated
runs with a single disagreement rate, and \[score_confidence()\] puts an
interval on a single run's per-slice score. Neither answers the
reliability question a reviewer actually asks: *how much do the repeated
runs agree beyond what chance alone would produce?* A system that passes
four fifths of its cases on every run looks stable by raw agreement even
when the agreeing verdicts are no better than coin flips. This reports
the chance-corrected agreement that tells the two apart.

It treats each repeat in the run as a rater and each case as a subject
rated once per repeat, with the grader's verdict ("pass", "fail",
"warn", "na") as the nominal category. On that balanced, fully-crossed
design it computes three established statistics and a per-case
breakdown. Nothing here calls a model or the network; the verdicts are
read from the run as it stands, so every figure is reproducible from the
run alone.

## Usage

``` r
agent_agreement(run)
```

## Arguments

- run:

  An \`r4agent_run\` with \`repeats\` greater than one. Every case must
  have been run the same number of times, which \[run_benchmark()\]
  guarantees.

## Value

An object of class \`r4agent_agreement\`: a list with
\`percent_agreement\` (the overall mean pairwise agreement), \`kappa\`,
\`kappa_method\` ("Cohen's kappa" or "Fleiss' kappa"), \`strength\` (the
Landis & Koch label, or \`NA\` when kappa is \`NA\`),
\`expected_agreement\` (\\p_e\\), \`n_items\`, \`n_runs\`,
\`categories\` (the verdict levels seen), and \`by_item\`, a data frame
with one row per case (\`id\`, \`slice\`, \`severity\`, \`n_runs\`,
\`distinct\` verdicts, \`modal\` verdict and per-case \`agreement\`)
ordered with the least-agreeing cases first.

## Details

The statistics are textbook nominal-agreement measures; no weight,
threshold or scoring rule is invented here.

**Overall percent agreement** is the mean across cases of the per-case
pairwise agreement \\P_i\\, the proportion of rater pairs that assigned
case \\i\\ to the same category. With \\m\\ repeats and \\n\_{ij}\\
repeats placing case \\i\\ in category \\j\\, \$\$P_i = \frac{1}{m(m-1)}
\left( \sum_j n\_{ij}^2 - m \right),\$\$ the per-subject agreement of
Fleiss (1971). For two repeats this is simply the fraction of cases that
returned the same verdict both times.

**Cohen's kappa** is reported when there are exactly two repeats (Cohen,
1960). With observed agreement \\p_o\\ (the share of cases whose two
verdicts match) and expected agreement \\p_e = \sum_j p\_{1j} p\_{2j}\\
formed from each repeat's own category marginals \\p\_{1j}, p\_{2j}\\,
\$\$\kappa = \frac{p_o - p_e}{1 - p_e}.\$\$

**Fleiss' kappa** is reported for three or more repeats (Fleiss, 1971).
With mean observed agreement \\\bar P = \frac{1}{n}\sum_i P_i\\ and
expected agreement \\\bar P_e = \sum_j p_j^2\\ from the pooled category
proportions \\p_j = \frac{1}{nm}\sum_i n\_{ij}\\, \$\$\kappa =
\frac{\bar P - \bar P_e}{1 - \bar P_e}.\$\$ Fleiss' form treats the
repeats as interchangeable, which is what repeated runs of one agent
are; Cohen's form, used for two, keeps each repeat's marginals separate.
When every verdict falls in one category the expected agreement is 1,
kappa is \\0/0\\ and is returned as \`NA\`: with no variation to correct
for, a chance-corrected statistic has nothing to say.

The \`strength\` label follows the rule of thumb of Landis & Koch (1977)
(\< 0 "poor", 0–0.20 "slight", 0.21–0.40 "fair", 0.41–0.60 "moderate",
0.61–0.80 "substantial", 0.81–1 "almost perfect"). It is their published
guideline, quoted for orientation only; this package enforces no kappa
threshold and the label changes no score and no verdict.

## References

Cohen, J. (1960). A coefficient of agreement for nominal scales.
*Educational and Psychological Measurement*, 20(1), 37–46.

Fleiss, J. L. (1971). Measuring nominal scale agreement among many
raters. *Psychological Bulletin*, 76(5), 378–382.

Landis, J. R. & Koch, G. G. (1977). The measurement of observer
agreement for categorical data. *Biometrics*, 33(1), 159–174.

## See also

\[consistency()\], \[consistency_strata()\], \[score_confidence()\]

## Examples

``` r
suite <- agent_suite(list(
  agent_case("steady", "ping", "ok", slice = "stable", grader = "contains"),
  agent_case("flaky", "toggle", "ok", slice = "shaky", severity = "high",
             grader = "contains")
))
# A deterministic offline runner that flips one case's answer every other call.
seen <- new.env()
flip <- function(x) {
  n <- if (exists(x, seen, inherits = FALSE)) get(x, seen) else 0L
  assign(x, n + 1L, seen)
  if (x == "toggle" && (n + 1L) %% 2L == 0L) "no" else "ok"
}
run <- run_benchmark(suite, flip, repeats = 4L, quiet = TRUE)
ag <- agent_agreement(run)
ag
#> 
#> ── Inter-run agreement: 2 cases over 4 runs ────────────────────────────────────
#> Categories seen: "fail" and "pass"
#> Percent agreement: 0.6667 (mean pairwise)
#> Fleiss' kappa: 0.1111 (slight), expected 0.6250
#> 
#> ── Cases where runs disagree most 
#> flaky (shaky, high) agreement 0.3333, 2 verdicts
#> 
#> Strength label follows Landis & Koch (1977); it changes no score or verdict.
ag$by_item
#>       id  slice severity n_runs distinct modal agreement
#> 1  flaky  shaky     high      4        2  fail    0.3333
#> 2 steady stable   medium      4        1  pass    1.0000
```
