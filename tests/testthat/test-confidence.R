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

# ---------------------------------------------------------------------------
# A richer fixture: per-slice (pass, fail, warn) composition, all deterministic.
# A pass is input "x" expecting "1"; a fail is input "y"; a warn is a grounding
# case with no context, which the grounded grader always warns on. The runner is
# a plain stub: "1" for "x", "no" otherwise.
# ---------------------------------------------------------------------------
make_mix <- function(spec) {
  cases <- list(); k <- 0L
  add <- function(id, input, ...) { k <<- k + 1L; cases[[k]] <<- agent_case(id, input, ...) }
  for (s in names(spec)) {
    cnt <- spec[[s]]
    np <- if ("pass" %in% names(cnt)) cnt[["pass"]] else 0L
    nf <- if ("fail" %in% names(cnt)) cnt[["fail"]] else 0L
    nw <- if ("warn" %in% names(cnt)) cnt[["warn"]] else 0L
    for (j in seq_len(np)) add(paste0(s, "-p", j), "x", "1", grader = "contains", slice = s)
    for (j in seq_len(nf)) add(paste0(s, "-f", j), "y", "1", grader = "contains", slice = s)
    for (j in seq_len(nw)) add(paste0(s, "-w", j), "q", family = "grounding",
                               grader = "grounded", slice = s)
  }
  run_benchmark(agent_suite(cases), function(i) if (i == "x") "1" else "no", quiet = TRUE)
}

test_that("Wilson bounds match known textbook values at the edges and the middle", {
  run <- make_mix(list(
    none = c(fail = 5L),            # 0/5
    allp = c(pass = 5L),            # 5/5
    half = c(pass = 5L, fail = 5L)  # 5/10
  ))
  ci <- score_confidence(run)       # 95%
  none <- ci[ci$slice == "none", ]
  expect_equal(none$score, 0)
  expect_equal(none$lower, 0)
  expect_equal(none$upper, 0.4345, tolerance = 1e-4)
  allp <- ci[ci$slice == "allp", ]
  expect_equal(allp$score, 1)
  expect_equal(allp$lower, 0.5655, tolerance = 1e-4)
  expect_equal(allp$upper, 1)
  half <- ci[ci$slice == "half", ]
  expect_equal(half$score, 0.5)
  expect_equal(half$lower, 0.2366, tolerance = 1e-4)
  expect_equal(half$upper, 0.7634, tolerance = 1e-4)
})

test_that("conf_level produces the textbook Wilson width for a 1/2 slice", {
  run <- make_mix(list(s = c(pass = 1L, fail = 1L)))  # phat 0.5, n 2
  r90 <- score_confidence(run, conf_level = 0.90)
  r95 <- score_confidence(run, conf_level = 0.95)
  r99 <- score_confidence(run, conf_level = 0.99)
  lo <- function(x) x$lower[x$slice == "s"]
  up <- function(x) x$upper[x$slice == "s"]
  expect_equal(lo(r90), 0.1209, tolerance = 1e-4)
  expect_equal(lo(r95), 0.0945, tolerance = 1e-4)
  expect_equal(lo(r99), 0.0617, tolerance = 1e-4)
  # phat is exactly 0.5, so the interval is symmetric about the point score
  expect_equal(lo(r95) + up(r95), 1, tolerance = 1e-4)
  # a higher confidence level is a wider interval
  expect_lt(lo(r99), lo(r95))
  expect_lt(lo(r95), lo(r90))
  expect_gt(up(r99), up(r95))
})

test_that("every interval lies within [0, 1] and brackets its point score", {
  run <- make_mix(list(
    perfect  = c(pass = 4L),
    empty    = c(fail = 4L),
    lopsided = c(pass = 8L, fail = 2L),
    warny    = c(warn = 3L),
    mixed    = c(pass = 2L, warn = 2L, fail = 4L)
  ))
  for (cl in c(0.80, 0.90, 0.95, 0.99)) {
    ci <- score_confidence(run, conf_level = cl)
    expect_true(all(ci$lower >= 0 & ci$upper <= 1), info = paste("conf_level", cl))
    expect_true(all(ci$lower <= ci$score & ci$score <= ci$upper),
                info = paste("conf_level", cl))
    expect_true(all(ci$upper - ci$lower >= 0), info = paste("conf_level", cl))
  }
})

test_that("a warn counts as half and the interval is taken on that effective score", {
  run <- make_mix(list(mix = c(pass = 1L, warn = 1L, fail = 2L)))  # (1 + .5)/4
  ci <- score_confidence(run)
  mix <- ci[ci$slice == "mix", ]
  expect_equal(mix$score, 0.375)
  expect_equal(mix$lower, 0.0919, tolerance = 1e-4)  # Wilson on phat = 0.375, n = 4
  expect_equal(mix$upper, 0.7806, tolerance = 1e-4)
  expect_true(mix$lower >= 0 && mix$upper <= 1)
  # an all-warn slice sits at exactly one half
  aw <- score_confidence(make_mix(list(w = c(warn = 3L))))
  expect_equal(aw$score[aw$slice == "w"], 0.5)
  expect_equal(aw$lower[aw$slice == "w"], 0.1253, tolerance = 1e-4)  # Wilson 0.5, n = 3
})

test_that("clears_point and clears_lower separate a thin perfect slice from a thick one", {
  run <- make_mix(list(thin = c(pass = 5L), thick = c(pass = 50L)))
  ci <- score_confidence(run, agent_thresholds(default = 0.9))
  thin <- ci[ci$slice == "thin", ]
  thick <- ci[ci$slice == "thick", ]
  # both score a perfect 1 and both clear on the point estimate
  expect_equal(thin$score, 1); expect_equal(thick$score, 1)
  expect_true(thin$clears_point); expect_true(thick$clears_point)
  # only the thick slice's lower bound clears 0.9 (thin ~0.566, thick ~0.929)
  expect_false(thin$clears_lower)
  expect_true(thick$clears_lower)
  expect_lt(thin$lower, 0.9)
  expect_gt(thick$lower, 0.9)
})

test_that("per-slice thresholds are applied per slice and the TOTAL row carries none", {
  run <- make_mix(list(easy = c(pass = 10L), strict = c(pass = 10L)))
  ci <- score_confidence(run, agent_thresholds(default = 0.5, strict = 0.95))
  easy <- ci[ci$slice == "easy", ]
  strict <- ci[ci$slice == "strict", ]
  expect_equal(easy$threshold, 0.5)
  expect_equal(strict$threshold, 0.95)
  # identical perfect data (lower ~0.7225), opposite lower-bound decisions
  expect_true(easy$clears_lower)
  expect_false(strict$clears_lower)
  tot <- ci[ci$slice == "TOTAL", ]
  expect_true(is.na(tot$threshold))
  expect_true(is.na(tot$clears_point))
  expect_true(is.na(tot$clears_lower))
})

test_that("score_confidence is deterministic, including with thresholds and conf_level", {
  run <- make_mix(list(a = c(pass = 5L, fail = 2L),
                       b = c(pass = 3L, warn = 2L, fail = 1L)))
  th <- agent_thresholds(default = 0.8, a = 0.7)
  expect_identical(score_confidence(run), score_confidence(run))
  expect_identical(score_confidence(run, th), score_confidence(run, th))
  expect_identical(score_confidence(run, th, conf_level = 0.99),
                   score_confidence(run, th, conf_level = 0.99))
})

test_that("conf_level rejects out-of-range, non-scalar and non-numeric values", {
  run <- make_mix(list(a = c(pass = 2L)))
  expect_error(score_confidence(run, conf_level = 0), "conf_level")
  expect_error(score_confidence(run, conf_level = 1), "conf_level")
  expect_error(score_confidence(run, conf_level = -0.1), "conf_level")
  expect_error(score_confidence(run, conf_level = 1.5), "conf_level")
  expect_error(score_confidence(run, conf_level = c(0.9, 0.95)), "conf_level")
  expect_error(score_confidence(run, conf_level = "0.95"), "conf_level")
  expect_error(score_confidence(run, conf_level = NA_real_), "conf_level")
})

test_that("score_confidence leaves score_slices and readiness untouched, even with a blocker", {
  cases <- c(
    lapply(1:8, function(i) agent_case(paste0("ok", i), "x", "1",
                                       grader = "contains", slice = "bulk")),
    list(agent_case("crit", "y", "1", grader = "contains", slice = "bulk",
                    severity = "critical"))
  )
  run <- run_benchmark(agent_suite(cases),
                       function(i) if (i == "x") "1" else "no", quiet = TRUE)
  th <- agent_thresholds(default = 0.8)
  before_scores <- score_slices(run)
  before_rd <- readiness(run, th)
  for (cl in c(0.80, 0.95, 0.99)) invisible(score_confidence(run, th, conf_level = cl))
  expect_equal(score_slices(run), before_scores)
  after_rd <- readiness(run, th)
  expect_equal(after_rd$verdict, before_rd$verdict)
  expect_equal(after_rd$verdict, "not ready")   # the critical fail blocks release
  expect_equal(after_rd$slices, before_rd$slices)
})
