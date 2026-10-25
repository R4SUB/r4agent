# Convert a run to R4SUB evidence

Emits one evidence row per case result, so a benchmark can be read by
the same tooling as the rest of the R4SUB ecosystem. The finer grained
family and slice travel in their own columns; \`indicator_domain\`
carries the four values the evidence schema allows, mapped through
\[agent_families\].

## Usage

``` r
agent_evidence(run, rep = 1L)
```

## Arguments

- run:

  An \`r4agent_run\`.

- rep:

  Which repeat to emit. Defaults to the first.

## Value

A validated evidence data frame.
