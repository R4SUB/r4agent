# Run to run consistency

The same input, asked more than once. Reports the share of cases that
did not return the same verdict every time.

## Usage

``` r
consistency(run)
```

## Arguments

- run:

  An \`r4agent_run\` with \`repeats\` greater than one.

## Value

A list with the disagreement rate and the unstable case ids.

## Details

This is the measure most often skipped and it is the one that predicts
support load. A system that is right four times in five looks like a 0.8
in an average and behaves like a coin toss to the person using it.
