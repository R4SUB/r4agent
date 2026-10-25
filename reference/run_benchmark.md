# Run a benchmark

Sends every case to the system under test, grades the answer, and
records the input, the output, the verdict and the time taken.

## Usage

``` r
run_benchmark(
  suite,
  runner,
  repeats = 1L,
  study_id = "agent",
  environment = "DEV",
  quiet = FALSE
)
```

## Arguments

- suite:

  An \`r4agent_suite\`.

- runner:

  A function taking a single character input and returning the answer as
  a character string. Anything that can be called from R can be put
  behind this: an HTTP endpoint, a local model, a shell command.

- repeats:

  Integer. How many times to run each case.

- study_id:

  Character. Passed to the run context, and named this way because the
  evidence schema comes from the clinical submission side of R4SUB. Use
  the name of the system under test.

- environment:

  One of "DEV", "UAT", "PROD".

- quiet:

  Suppress the progress bar.

## Value

An object of class \`r4agent_run\`.

## Details

\`repeats\` is not a convenience. A system asked the same question five
times and answering differently on the third is a support problem
waiting to happen, and a suite run once per case can never show it. The
default of one keeps a quick run quick; raise it when consistency is
part of the question.

## Examples

``` r
suite <- agent_suite(list(
  agent_case("a1", "2 + 2?", "4", grader = "contains", why = "Arithmetic.")
))
run_benchmark(suite, function(x) "the answer is 4", quiet = TRUE)
#> 
#> ── Benchmark: agent ────────────────────────────────────────────────────────────
#> 1 case, 1 repeat, 1 run
#> First pass: 1 pass, 0 warn, 0 fail
#> Median 0s, p95 0s
```
