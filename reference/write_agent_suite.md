# Write a suite to YAML

Serialises an \`r4agent_suite\` back to the YAML that
\[read_agent_suite()\] reads, so a suite assembled in R can be committed
next to the code it tests and read back unchanged. A suite that uses
only built-in or registered graders by name round trips exactly.

## Usage

``` r
write_agent_suite(suite, path = NULL)
```

## Arguments

- suite:

  An \`r4agent_suite\`.

- path:

  Path to write to, or NULL to return the YAML as a string.

## Value

The YAML text. Returned invisibly when written to \`path\`.

## Details

A grader supplied as a function cannot be written: the file names a
grader, it cannot carry the function's code. Such a case is still
written, with every other field kept (\`why\`, \`severity\`, \`slice\`,
\`expect\` and the rest), and a warning names it; on the way back in its
grader falls to the default.

## See also

\[read_agent_suite()\]

## Examples

``` r
suite <- agent_suite(list(
  agent_case("billing-01", "When is my next invoice due?", "first",
             slice = "billing", grader = "contains",
             why = "Monthly plans bill on the first of the month."),
  agent_case("abstain-01", "Does the plan support SAML on the old portal?",
             family = "grounding", slice = "not answerable",
             severity = "high", grader = "abstain",
             why = "The docs do not say, so the only right answer is to say so.")
))
cat(write_agent_suite(suite))
#> cases:
#> - id: billing-01
#>   input: When is my next invoice due?
#>   expect: first
#>   family: task
#>   slice: billing
#>   severity: medium
#>   grader: contains
#>   why: Monthly plans bill on the first of the month.
#> - id: abstain-01
#>   input: Does the plan support SAML on the old portal?
#>   family: grounding
#>   slice: not answerable
#>   severity: high
#>   grader: abstain
#>   why: The docs do not say, so the only right answer is to say so.

# Round-trips through a file
f <- tempfile(fileext = ".yaml")
write_agent_suite(suite, f)
identical(length(read_agent_suite(f)), length(suite))
#> [1] TRUE
unlink(f)
```
