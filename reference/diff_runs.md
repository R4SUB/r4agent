# Compare two runs

The most useful thing a benchmark reports is not the average. It is the
list of cases that used to pass and now fail.

## Usage

``` r
diff_runs(before, after, rep = 1L)
```

## Arguments

- before, after:

  Objects of class \`r4agent_run\`.

- rep:

  Which repeat to compare in each.

## Value

An object of class \`r4agent_diff\`.

## Details

Model changes are rarely uniform improvements. A prompt revision fixes a
group of failures and breaks a smaller group of successes; the aggregate
rises and everyone is pleased. The broken group is still broken, and if
it contains something that matters more than average, the release is a
regression wearing an improvement's clothes.
