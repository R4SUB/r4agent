# score_confidence() puts a Wilson interval on each per-slice score. It is an
# opt-in second look: it must change no score and no verdict, and it is a closed
# form, so it is deterministic and offline with every runner a plain stub.

make_run <- function(slice_ns, runner = function(i) "1") {
  # slice_ns is a named integer vector: slice -> number of (passing) cases.
  cases <- list()
  k <- 0L
  for (s in names(slice_ns)) {
    for (j in seq_len(slice_ns[[s]])) {
      k <- k + 1L
      cases[[k]] <- agent_case(paste0(s, "-", j), "x", "1",
                               grader = "contains", slice = s)
    }
  }
  run_benchmark(agent_suite(cases), runner, quiet = TRUE)
}

test_that("score_confidence returns a classed frame with the expected columns", {
  run <- make_run(c(a = 3L))
  ci <- score_confidence(run)
  expect_s3_class(ci, "r4agent_confidence")
  expect_s3_class(ci, "data.frame")
  expect_equal(names(ci), c("slice", "cases", "score", "lower", "upper"))
  expect_true("TOTAL" %in% ci$slice)
})

test_that("the interval brackets the point score and stays within [0, 1]", {
  run <- make_run(c(easy = 4L, hard = 4L),
                  runner = function(i) if (i == "x") "1" else "no")
  # mix passes and fails across cases so scores land away from the edges
  mixed <- run_benchmark(agent_suite(list(
    agent_case("m1", "x", "1", grader = "contains", slice = "mix"),
    agent_case("m2", "x", "1", grader = "contains", slice = "mix"),
    agent_case("m3", "y", "1", grader = "contains", slice = "mix"),
    agent_case("m4", "y", "1", grader = "contains", slice = "mix")
  )), function(i) if (i == "x") "1" else "no", quiet = TRUE)
  ci <- score_confidence(mixed)
  expect_true(all(ci$lower <= ci$score))
  expect_true(all(ci$score <= ci$upper))
  expect_true(all(ci$lower >= 0 & ci$upper <= 1))
})

test_that("a perfect small slice has a wide Wilson interval, not zero width", {
  ci <- score_confidence(make_run(c(small = 3L)))
  row <- ci[ci$slice == "small", ]
  expect_equal(row$score, 1)
  # Wilson lower bound for 3/3 at 95% is ~0.4385, not 1.
  expect_equal(row$lower, 0.4385, tolerance = 1e-3)
  expect_equal(row$upper, 1)
})

test_that("more cases at the same score give a tighter lower bound", {
  few  <- score_confidence(make_run(c(s = 3L)))
  many <- score_confidence(make_run(c(s = 30L)))
  expect_equal(few$score[few$slice == "s"], many$score[many$slice == "s"])
  expect_gt(many$lower[many$slice == "s"], few$lower[few$slice == "s"])
})

test_that("warns count as half, as everywhere else in the package", {
  # grounded with no context warns; paired with a pass the slice scores 0.75
  run <- run_benchmark(agent_suite(list(
    agent_case("w", "q", family = "grounding", grader = "grounded",
               slice = "mix"),
    agent_case("p", "q", "1", grader = "contains", slice = "mix")
  )), function(i) "1", quiet = TRUE)
  ci <- score_confidence(run)
  expect_equal(ci$score[ci$slice == "mix"], 0.75)
})

test_that("thresholds attach the threshold and both clearance decisions", {
  run <- make_run(c(small = 3L))
  ci <- score_confidence(run, agent_thresholds(default = 0.9))
  expect_true(all(c("threshold", "clears_point", "clears_lower") %in% names(ci)))
  row <- ci[ci$slice == "small", ]
  expect_equal(row$threshold, 0.9)
  # 3/3 clears on the point estimate but its lower bound (~0.44) does not.
  expect_true(row$clears_point)
  expect_false(row$clears_lower)
  # the TOTAL row has no threshold of its own
  tot <- ci[ci$slice == "TOTAL", ]
  expect_true(is.na(tot$threshold))
  expect_true(is.na(tot$clears_point))
  expect_true(is.na(tot$clears_lower))
})

test_that("per-slice thresholds are honoured", {
  run <- make_run(c(billing = 3L, adversarial = 3L))
  ci <- score_confidence(run, agent_thresholds(default = 0.8, adversarial = 1.0))
  expect_equal(ci$threshold[ci$slice == "billing"], 0.8)
  expect_equal(ci$threshold[ci$slice == "adversarial"], 1.0)
})

test_that("the result is deterministic across calls", {
  run <- make_run(c(a = 5L, b = 7L),
                  runner = function(i) if (i == "x") "1" else "no")
  expect_equal(score_confidence(run), score_confidence(run))
})

test_that("conf_level widens the interval and is validated", {
  run <- make_run(c(s = 10L), runner = function(i) if (i == "x") "1" else "no")
  wide <- score_confidence(run, conf_level = 0.99)
  narrow <- score_confidence(run, conf_level = 0.80)
  expect_lt(wide$lower[wide$slice == "s"], narrow$lower[narrow$slice == "s"])
  expect_error(score_confidence(run, conf_level = 1), "conf_level")
  expect_error(score_confidence(run, conf_level = 0), "conf_level")
  expect_error(score_confidence(run, conf_level = c(0.9, 0.95)), "conf_level")
})

test_that("score_confidence validates thresholds and the repeat", {
  run <- make_run(c(a = 2L))
  expect_error(score_confidence(run, thresholds = list(default = 0.9)),
               "r4agent_thresholds")
  expect_error(score_confidence(run, rep = 2L), "No results")
})

test_that("score_confidence changes no score or verdict", {
  run <- make_run(c(a = 3L, b = 3L),
                  runner = function(i) if (i == "x") "1" else "no")
  before_score <- score_slices(run)
  before_verdict <- readiness(run)$verdict
  invisible(score_confidence(run, agent_thresholds(default = 0.9)))
  expect_equal(score_slices(run), before_score)
  expect_equal(readiness(run)$verdict, before_verdict)
})

test_that("print returns its input invisibly, with and without thresholds", {
  run <- make_run(c(a = 3L))
  expect_invisible(print(score_confidence(run)))
  expect_invisible(print(score_confidence(run, agent_thresholds(default = 0.9))))
})
