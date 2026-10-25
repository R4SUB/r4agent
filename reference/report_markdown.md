# Write the report

Markdown, so it can be committed next to the results it describes and
read in a pull request without a viewer.

## Usage

``` r
report_markdown(run, thresholds = agent_thresholds(), file = NULL, rep = 1L)
```

## Arguments

- run:

  An \`r4agent_run\`.

- thresholds:

  An \`r4agent_thresholds\`.

- file:

  Path to write to, or NULL to return the text.

- rep:

  Which repeat to report.

## Value

The markdown, invisibly if written to a file.
