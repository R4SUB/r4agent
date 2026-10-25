# Decide whether the system is ready

Returns one of three verdicts, with the slices that fell short attached.
The middle verdict is the common one and it is the useful one: it names
what to fix rather than passing or failing the whole system.

## Usage

``` r
readiness(run, thresholds = agent_thresholds(), rep = 1L)
```

## Arguments

- run:

  An \`r4agent_run\`.

- thresholds:

  An \`r4agent_thresholds\`.

- rep:

  Which repeat to judge.

## Value

An object of class \`r4agent_readiness\`.
