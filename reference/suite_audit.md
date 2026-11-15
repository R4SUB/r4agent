# Audit a suite for coverage and quality gaps

A benchmark is only ever as good as the cases in it, and the cases are
the part people skimp on: a slice with one example, a case whose
expected answer nobody wrote a reason for, a whole family or severity
that was never exercised, no abstention case, no injection case. None of
these is wrong enough to fail a run, so an average never shows them.
This lists them.

## Usage

``` r
suite_audit(suite, min_slice_cases = 3L)
```

## Arguments

- suite:

  An \`r4agent_suite\`.

- min_slice_cases:

  Integer. A slice with fewer than this many cases is flagged as too
  thin. Defaults to 3.

## Value

A data frame of class \`r4agent_audit\`, one row per finding, with
columns \`check\`, \`scope\`, \`target\` and \`note\`. A clean suite
returns a zero-row frame of the same shape.

## Details

The findings are advisory and carry no severity of their own.
\`suite_audit()\` changes no score and no verdict; it is a lint over the
suite, read once while the cases are being written, not a gate the suite
has to clear. It does not run the suite, call a model or touch the
network: it reads the cases as they stand.

The checks are:

- **empty_family** – a family in \[agent_families\] that no case uses,
  so a whole domain of behaviour is unmeasured.

- **empty_severity** – a severity level ("info" through "critical") that
  no case carries.

- **small_slice** – a slice with fewer than \`min_slice_cases\` cases,
  too thin to support the per-slice verdict \[readiness()\] draws from
  it.

- **missing_why** – a case with no stated reason for its expected
  answer, the single most common defect in an evaluation set.

- **no_abstain** – no case uses the \`abstain\` grader, so the system's
  behaviour on a question it cannot answer is untested.

- **no_injection** – no case is in the \`injection\` family or uses the
  \`refuses_injection\` grader, so a planted instruction is never tried.

## See also

\[agent_families\], \[readiness()\]

## Examples

``` r
suite <- agent_suite(list(
  agent_case("billing-01", "When is my next invoice due?", "first",
             slice = "billing", grader = "contains",
             why = "Monthly plans bill on the first of the month."),
  agent_case("billing-02", "What card is on file?", "visa",
             slice = "billing", grader = "contains"),
  agent_case("edge-01", "Does the old portal support SAML?",
             family = "grounding", slice = "not answerable",
             grader = "abstain",
             why = "The docs do not say, so saying so is the only right answer.")
))
suite_audit(suite)
#> 
#> ── Suite audit: 18 advisory notes ──────────────────────────────────────────────
#> Advisory only. None of these changes a score or a verdict.
#> [empty_family] (family format) No case exercises the format family, so that
#> domain is unmeasured.
#> [empty_family] (family tool) No case exercises the tool family, so that domain
#> is unmeasured.
#> [empty_family] (family consistency) No case exercises the consistency family,
#> so that domain is unmeasured.
#> [empty_family] (family retrieval) No case exercises the retrieval family, so
#> that domain is unmeasured.
#> [empty_family] (family citation) No case exercises the citation family, so that
#> domain is unmeasured.
#> [empty_family] (family robustness) No case exercises the robustness family, so
#> that domain is unmeasured.
#> [empty_family] (family injection) No case exercises the injection family, so
#> that domain is unmeasured.
#> [empty_family] (family safety) No case exercises the safety family, so that
#> domain is unmeasured.
#> [empty_family] (family cost) No case exercises the cost family, so that domain
#> is unmeasured.
#> [empty_family] (family latency) No case exercises the latency family, so that
#> domain is unmeasured.
#> [empty_severity] (severity info) No case carries severity info.
#> [empty_severity] (severity low) No case carries severity low.
#> [empty_severity] (severity high) No case carries severity high.
#> [empty_severity] (severity critical) No case carries severity critical.
#> [small_slice] (slice billing) Slice billing has 2 cases, below the minimum of
#> 3; a slice this thin cannot support a per-slice verdict.
#> [small_slice] (slice not answerable) Slice not answerable has 1 case, below the
#> minimum of 3; a slice this thin cannot support a per-slice verdict.
#> [missing_why] (case billing-02) Case billing-02 has no stated reason for its
#> expected answer.
#> [no_injection] (coverage) No case covers prompt injection (family "injection"
#> or the refuses_injection grader), so a planted instruction is never tried.

# The thin "not answerable" slice and the missing "why" surface as notes.
as.data.frame(suite_audit(suite))
#>             check    scope         target
#> 1    empty_family   family         format
#> 2    empty_family   family           tool
#> 3    empty_family   family    consistency
#> 4    empty_family   family      retrieval
#> 5    empty_family   family       citation
#> 6    empty_family   family     robustness
#> 7    empty_family   family      injection
#> 8    empty_family   family         safety
#> 9    empty_family   family           cost
#> 10   empty_family   family        latency
#> 11 empty_severity severity           info
#> 12 empty_severity severity            low
#> 13 empty_severity severity           high
#> 14 empty_severity severity       critical
#> 15    small_slice    slice        billing
#> 16    small_slice    slice not answerable
#> 17    missing_why     case     billing-02
#> 18   no_injection coverage           <NA>
#>                                                                                                                              note
#> 1                                                              No case exercises the format family, so that domain is unmeasured.
#> 2                                                                No case exercises the tool family, so that domain is unmeasured.
#> 3                                                         No case exercises the consistency family, so that domain is unmeasured.
#> 4                                                           No case exercises the retrieval family, so that domain is unmeasured.
#> 5                                                            No case exercises the citation family, so that domain is unmeasured.
#> 6                                                          No case exercises the robustness family, so that domain is unmeasured.
#> 7                                                           No case exercises the injection family, so that domain is unmeasured.
#> 8                                                              No case exercises the safety family, so that domain is unmeasured.
#> 9                                                                No case exercises the cost family, so that domain is unmeasured.
#> 10                                                            No case exercises the latency family, so that domain is unmeasured.
#> 11                                                                                                 No case carries severity info.
#> 12                                                                                                  No case carries severity low.
#> 13                                                                                                 No case carries severity high.
#> 14                                                                                             No case carries severity critical.
#> 15                       Slice billing has 2 cases, below the minimum of 3; a slice this thin cannot support a per-slice verdict.
#> 16                 Slice not answerable has 1 case, below the minimum of 3; a slice this thin cannot support a per-slice verdict.
#> 17                                                                  Case billing-02 has no stated reason for its expected answer.
#> 18 No case covers prompt injection (family "injection" or the refuses_injection grader), so a planted instruction is never tried.
```
