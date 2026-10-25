# Define one benchmark case

A case is an input, an answer somebody is prepared to defend, and the
grader that decides whether the two agree. The \`why\` field is not
decoration: a case whose expected answer nobody can justify is the
single most common defect in an evaluation set, and being asked to write
the justification is what surfaces it.

## Usage

``` r
agent_case(
  id,
  input,
  expect = NULL,
  family = "task",
  slice = "default",
  severity = "medium",
  grader = "exact",
  why = NA_character_,
  context = character(0)
)
```

## Arguments

- id:

  Character. Stable identifier. Used to match a case across runs, so
  renaming one breaks the regression diff for that case by design.

- input:

  Character. What is sent to the system under test.

- expect:

  The expected answer, interpreted by \`grader\`.

- family:

  One of \`names(agent_families)\`.

- slice:

  Character. The kind of input this case represents, for example
  "billing" or "not answerable". Reported separately, because an average
  over slices hides the one that is failing.

- severity:

  One of "info", "low", "medium", "high", "critical".

- grader:

  Character name of a registered grader, or a function taking \`(expect,
  actual, case)\` and returning "pass", "fail" or "warn".

- why:

  Character. Why the expected answer is the right one.

- context:

  Optional character vector of source passages, for grounding and
  citation graders.

## Value

An object of class \`r4agent_case\`.

## Examples

``` r
agent_case(
  id = "billing-01",
  input = "When is my next invoice due?",
  expect = "the 1st",
  family = "task",
  slice = "billing",
  grader = "contains",
  why = "Billing runs on the first of the month for monthly plans."
)
#> $id
#> [1] "billing-01"
#> 
#> $input
#> [1] "When is my next invoice due?"
#> 
#> $expect
#> [1] "the 1st"
#> 
#> $family
#> [1] "task"
#> 
#> $slice
#> [1] "billing"
#> 
#> $severity
#> [1] "medium"
#> 
#> $grader
#> [1] "contains"
#> 
#> $why
#> [1] "Billing runs on the first of the month for monthly plans."
#> 
#> $context
#> character(0)
#> 
#> attr(,"class")
#> [1] "r4agent_case"
```
