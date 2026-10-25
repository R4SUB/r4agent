# Score a run by slice

Reports each slice separately. The overall figure is included and is the
least useful number here: it is the average of a slice at 0.94 and a
slice at 0.42, and only the per slice view shows which is which.

## Usage

``` r
score_slices(run, rep = 1L)
```

## Arguments

- run:

  An \`r4agent_run\`.

- rep:

  Which repeat to score.

## Value

A data frame with one row per slice plus a total row.

## Details

A "warn" counts as half, which is what \`r4subcore::result_to_score()\`
does, so a benchmark scores the same way as the rest of the ecosystem.
