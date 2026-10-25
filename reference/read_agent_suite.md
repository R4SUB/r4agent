# Read a suite from YAML

Cases belong in version control next to the code they test, which is why
the file format is plain YAML rather than anything this package invents.

## Usage

``` r
read_agent_suite(path)
```

## Arguments

- path:

  Path to a YAML file holding a list of cases.

## Value

An \`r4agent_suite\`.
