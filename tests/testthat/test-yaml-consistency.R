# Round-trip serialisation and stratified consistency. Additive features;
# nothing here changes scoring or grading semantics, and every runner is a
# deterministic offline stub.

test_that("write_agent_suite round-trips a suite of built-in graders", {
  skip_if_not_installed("yaml")
  suite <- agent_suite(list(
    agent_case("billing", "When is my invoice due?", "first",
               slice = "billing", grader = "contains",
               why = "Monthly plans bill on the first."),
    agent_case("abstain", "Does X support Y on the old portal?",
               family = "grounding", slice = "not answerable",
               severity = "high", grader = "abstain",
               why = "The docs do not say."),
    agent_case("structured", "Return JSON with a status field.",
               expect = c("status", "code"), family = "format",
               slice = "structured output", grader = "json",
               context = c("passage one", "passage two"))
  ))
  f <- tempfile(fileext = ".yaml")
  on.exit(unlink(f))
  write_agent_suite(suite, f)
  back <- read_agent_suite(f)
  expect_equal(back, suite)
})

test_that("read -> write -> read reproduces the shipped example suite", {
  skip_if_not_installed("yaml")
  path <- system.file("suites", "example.yaml", package = "r4agent")
  skip_if(!nzchar(path))
  s1 <- read_agent_suite(path)
  f <- tempfile(fileext = ".yaml")
  on.exit(unlink(f))
  write_agent_suite(s1, f)
  s2 <- read_agent_suite(f)
  expect_equal(s2, s1)
})

test_that("write_agent_suite returns YAML text when no path is given", {
  skip_if_not_installed("yaml")
  suite <- agent_suite(list(
    agent_case("a", "x", "1", slice = "s1", grader = "contains")
  ))
  txt <- write_agent_suite(suite)
  expect_type(txt, "character")
  expect_match(txt, "cases:")
  expect_match(txt, "grader: contains")
})

test_that("a function grader is skipped with a warning but its case is kept", {
  skip_if_not_installed("yaml")
  suite <- agent_suite(list(
    agent_case("named", "x", "1", slice = "s1", grader = "contains",
               why = "keep me"),
    agent_case("fn", "y", "2", slice = "s2", severity = "high",
               grader = function(expect, actual, case) "pass",
               why = "also keep me")
  ))
  expect_warning(txt <- write_agent_suite(suite), "function grader")

  back <- read_agent_suite(local({
    f <- tempfile(fileext = ".yaml")
    writeLines(suppressWarnings(write_agent_suite(suite)), f)
    f
  }))
  # Both cases survive; the function case kept its metadata and fell to default.
  expect_length(back, 2L)
  fn <- back[[2]]
  expect_equal(fn$id, "fn")
  expect_equal(fn$slice, "s2")
  expect_equal(fn$severity, "high")
  expect_equal(fn$expect, "2")
  expect_equal(fn$why, "also keep me")
  expect_equal(fn$grader, "exact")  # the default grader after re-read
})

test_that("consistency_strata overall figures match consistency()", {
  suite <- agent_suite(list(
    agent_case("steady", "ping", "ok", slice = "stable", grader = "contains")
  ))
  run <- run_benchmark(suite, function(i) "ok", repeats = 3L, quiet = TRUE)
  flat <- consistency(run)
  strat <- consistency_strata(run)
  expect_equal(strat$disagreement, flat$disagreement)
  expect_equal(strat$unstable, flat$unstable)
  expect_equal(strat$n_cases, flat$n_cases)
  expect_equal(strat$repeats, flat$repeats)
})

test_that("consistency_strata breaks instability down by slice and severity", {
  suite <- agent_suite(list(
    agent_case("flaky", "toggle", "ok", slice = "shaky", severity = "high",
               grader = "contains"),
    agent_case("firm-lo", "steady-a", "ok", slice = "stable", severity = "low",
               grader = "contains"),
    agent_case("firm-hi", "steady-b", "ok", slice = "stable", severity = "high",
               grader = "contains")
  ))
  seen <- new.env()
  flip <- function(x) {
    n <- if (exists(x, seen, inherits = FALSE)) get(x, seen) else 0L
    assign(x, n + 1L, seen)
    if (x == "toggle" && (n + 1L) %% 2L == 0L) "no" else "ok"
  }
  run <- run_benchmark(suite, flip, repeats = 4L, quiet = TRUE)
  strat <- consistency_strata(run)

  # Only the flaky case is unstable.
  expect_equal(strat$unstable, "flaky")

  bs <- strat$by_slice
  expect_equal(bs$disagreement[bs$slice == "shaky"], 1)
  expect_equal(bs$disagreement[bs$slice == "stable"], 0)

  bsev <- strat$by_severity
  # severity rows come back in the canonical order
  expect_equal(bsev$severity, c("low", "high"))
  # high holds the flaky case and one firm case -> 1 of 2 unstable
  expect_equal(bsev$unstable[bsev$severity == "high"], 1)
  expect_equal(bsev$n_cases[bsev$severity == "high"], 2)
  expect_equal(bsev$disagreement[bsev$severity == "high"], 0.5)
  expect_equal(bsev$disagreement[bsev$severity == "low"], 0)
})

test_that("consistency_strata needs more than one repeat", {
  suite <- agent_suite(list(agent_case("a", "x", "1", grader = "contains")))
  run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  expect_error(consistency_strata(run), "more than one repeat")
})
