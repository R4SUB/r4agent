# Set the thresholds a run will be judged against

Agreed before the run, not chosen afterwards to suit the result. A
benchmark that cannot fail is a marketing exercise, and the only defence
against that is writing the numbers down first and putting them in
version control with the cases.

## Usage

``` r
agent_thresholds(default = 0.9, ...)
```

## Arguments

- default:

  Numeric in 0 to 1. Applied to any slice not named.

- ...:

  Named thresholds, for example \`billing = 0.9\`.

## Value

An object of class \`r4agent_thresholds\`.

## Examples

``` r
agent_thresholds(default = 0.85, `not answerable` = 0.95)
#> $default
#> [1] 0.85
#> 
#> $per_slice
#> $per_slice$`not answerable`
#> [1] 0.95
#> 
#> 
#> attr(,"class")
#> [1] "r4agent_thresholds"
```
