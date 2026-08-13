test_that("a suite refuses duplicate ids", {
  a <- agent_case("dup", "x", "y")
  b <- agent_case("dup", "x", "y")
  expect_error(agent_suite(list(a, b)), "unique")
})

test_that("an unknown family is rejected rather than silently mapped", {
  expect_error(agent_case("c1", "x", family = "vibes"), "not a known family")
})

test_that("every family maps to a domain the evidence schema allows", {
  allowed <- r4subcore::evidence_schema()$indicator_domain$allowed
  expect_true(all(agent_families %in% allowed))
})

test_that("graders return the three verdicts and nothing else", {
  case <- agent_case("g", "q", "hello", grader = "contains")
  expect_equal(get_grader("contains")("hello", "well, HELLO there", case), "pass")
  expect_equal(get_grader("contains")("hello", "goodbye", case), "fail")
  expect_equal(get_grader("exact")("4", " 4 ", case), "pass")
  expect_equal(get_grader("regex")("^a[0-9]+$", "a12", case), "pass")
})

test_that("abstention passes only when the system admits it cannot answer", {
  case <- agent_case("a", "q", family = "grounding", grader = "abstain")
  g <- get_grader("abstain")
  expect_equal(g(NULL, "I do not know, the docs do not cover it.", case), "pass")
  expect_equal(g(NULL, "Yes, that is fully supported.", case), "fail")
})

test_that("injection grading is inverted, as it must be", {
  case <- agent_case("i", "q", "APPROVED", family = "injection",
                     grader = "refuses_injection", severity = "critical")
  g <- get_grader("refuses_injection")
  expect_equal(g("APPROVED", "I will not follow that instruction.", case), "pass")
  expect_equal(g("APPROVED", "APPROVED", case), "fail")
})

test_that("grounding flags claims no source supports", {
  case <- agent_case("gr", "q", family = "grounding", grader = "grounded",
                     context = "The refund window is thirty days from purchase.")
  g <- get_grader("grounded")
  expect_equal(g(NULL, "The refund window is thirty days from purchase.", case), "pass")
  expect_equal(g(NULL, "Refunds require managerial authorisation quarterly.", case), "fail")
})

test_that("a run produces one row per case per repeat", {
  suite <- agent_suite(list(
    agent_case("a", "x", "1", grader = "contains"),
    agent_case("b", "y", "2", grader = "contains")
  ))
  run <- run_benchmark(suite, function(i) if (i == "x") "1" else "nope",
                       repeats = 3L, quiet = TRUE)
  expect_s3_class(run, "r4agent_run")
  expect_equal(nrow(run$results), 6L)
  expect_setequal(unique(run$results$result), c("pass", "fail"))
})

test_that("a runner that throws is recorded rather than killing the run", {
  suite <- agent_suite(list(agent_case("boom", "x", "1", grader = "contains")))
  run <- run_benchmark(suite, function(i) stop("upstream down"), quiet = TRUE)
  expect_equal(nrow(run$results), 1L)
  expect_match(run$results$actual, "ERROR")
  expect_equal(run$results$result, "fail")
})

test_that("evidence validates against the r4subcore schema", {
  suite <- agent_suite(list(
    agent_case("a", "x", "1", grader = "contains", slice = "billing"),
    agent_case("b", "y", "2", grader = "contains", slice = "billing",
               family = "safety", severity = "critical")
  ))
  run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  ev <- agent_evidence(run)
  expect_true(isTRUE(r4subcore::validate_evidence(ev)))
  expect_true(all(c("family", "slice") %in% names(ev)))
  expect_equal(ev$indicator_domain[ev$family == "safety"], "risk")
})

test_that("slices are scored separately and the total is included", {
  suite <- agent_suite(list(
    agent_case("a1", "x", "1", grader = "contains", slice = "easy"),
    agent_case("a2", "x", "1", grader = "contains", slice = "easy"),
    agent_case("b1", "y", "zzz", grader = "contains", slice = "hard")
  ))
  run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  sc <- score_slices(run)
  expect_true("TOTAL" %in% sc$slice)
  expect_equal(sc$score[sc$slice == "easy"], 1)
  expect_equal(sc$score[sc$slice == "hard"], 0)
})

test_that("a failing critical case blocks release whatever the average says", {
  cases <- c(
    lapply(1:9, function(i) agent_case(paste0("ok", i), "x", "1",
                                       grader = "contains", slice = "bulk")),
    list(agent_case("sev", "y", "1", grader = "contains", slice = "bulk",
                    severity = "critical"))
  )
  run <- run_benchmark(agent_suite(cases),
                       function(i) if (i == "x") "1" else "no", quiet = TRUE)
  rd <- readiness(run, agent_thresholds(default = 0.8))
  expect_gte(rd$slices$score[1], 0.8)
  expect_equal(rd$verdict, "not ready")
  expect_equal(nrow(rd$blockers), 1L)
})

test_that("thresholds are per slice and reject impossible values", {
  expect_error(agent_thresholds(default = 1.4), "proportions")
  th <- agent_thresholds(default = 0.8, `not answerable` = 0.95)
  expect_equal(th$per_slice[["not answerable"]], 0.95)
})

test_that("the diff names what broke rather than reporting a delta", {
  suite <- agent_suite(list(
    agent_case("keep", "x", "1", grader = "contains"),
    agent_case("break", "y", "2", grader = "contains")
  ))
  before <- run_benchmark(suite, function(i) if (i == "x") "1" else "2", quiet = TRUE)
  after  <- run_benchmark(suite, function(i) if (i == "x") "1" else "wrong", quiet = TRUE)
  d <- diff_runs(before, after)
  expect_equal(nrow(d$broke), 1L)
  expect_equal(d$broke$id, "break")
  expect_equal(nrow(d$fixed), 0L)
})

test_that("consistency needs repeats and finds an unstable case", {
  suite <- agent_suite(list(agent_case("flip", "x", "1", grader = "contains")))
  one <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  expect_error(consistency(one), "more than one repeat")

  i <- 0
  flaky <- function(input) { i <<- i + 1; if (i %% 2 == 0) "1" else "0" }
  many <- run_benchmark(suite, flaky, repeats = 4L, quiet = TRUE)
  cc <- consistency(many)
  expect_equal(cc$disagreement, 1)
  expect_equal(cc$unstable, "flip")
})

test_that("the report states the verdict and every failing case", {
  suite <- agent_suite(list(
    agent_case("good", "x", "1", grader = "contains", slice = "a"),
    agent_case("bad", "y", "2", grader = "contains", slice = "b",
               why = "Two is the documented answer.")
  ))
  run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  md <- report_markdown(run, agent_thresholds(default = 0.9))
  expect_match(md, "## Verdict:")
  expect_match(md, "bad")
  expect_match(md, "Two is the documented answer")
  expect_match(md, "No model judged another model", fixed = TRUE)
})

test_that("the shipped example suite parses and runs", {
  skip_if_not_installed("yaml")
  p <- system.file("suites", "example.yaml", package = "r4agent")
  skip_if(p == "")
  suite <- read_agent_suite(p)
  expect_s3_class(suite, "r4agent_suite")
  expect_equal(length(suite), 5L)
  run <- run_benchmark(suite, function(i) "I do not know", quiet = TRUE)
  expect_equal(nrow(run$results), 5L)
  expect_true(isTRUE(r4subcore::validate_evidence(agent_evidence(run))))
})
