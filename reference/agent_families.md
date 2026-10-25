# Families of measurement, and how they map onto the R4SUB evidence schema

The evidence schema in 'r4subcore' allows four indicator domains:
quality, trace, risk and usability. A benchmark has more families than
that, so each family is mapped onto the domain it genuinely belongs to
and the finer grain is kept in the \`family\` and \`slice\` columns that
travel alongside.

## Usage

``` r
agent_families
```

## Format

A named character vector: family to domain.

## Details

The mapping is stated here rather than inferred, because it decides how
\`aggregate_indicator_score()\` will group results and getting it wrong
would quietly file a safety failure under quality.
