# Register a grader

Register a grader

## Usage

``` r
register_grader(name, fn)
```

## Arguments

- name:

  Character name used in \`agent_case(grader = )\`.

- fn:

  Function with arguments \`(expect, actual, case)\` returning "pass",
  "fail" or "warn".

## Value

Invisibly, \`name\`.
