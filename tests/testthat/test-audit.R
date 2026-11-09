# suite_audit() is advisory only: it reads the cases as they stand and reports
# coverage and quality gaps. It must never run a suite, change a score or a
# verdict, or touch the network.

test_that("suite_audit returns a classed, tidy frame of the expected shape", {
  suite <- agent_suite(list(
    agent_case("a", "x", "1", slice = "s1", grader = "contains", why = "r")
  ))
  au <- suite_audit(suite)
  expect_s3_class(au, "r4agent_audit")
  expect_s3_class(au, "data.frame")
  expect_equal(names(au), c("check", "scope", "target", "note"))
})

test_that("a thin suite flags small slices with the right counts", {
  suite <- agent_suite(list(
    agent_case("a", "x", "1", slice = "thin", grader = "contains", why = "r"),
    agent_case("b", "y", "1", slice = "thin", grader = "contains", why = "r")
  ))
  au <- suite_audit(suite, min_slice_cases = 3L)
  small <- au[au$check == "small_slice", ]
  expect_equal(small$target, "thin")
  expect_match(small$note, "2 cases")
  expect_match(small$note, "minimum of 3")
})

test_that("min_slice_cases is honoured and silences the slice check when met", {
  suite <- agent_suite(lapply(1:3, function(i)
    agent_case(paste0("c", i), "x", "1", slice = "big", grader = "contains",
               why = "r")))
  expect_false("small_slice" %in% suite_audit(suite, min_slice_cases = 3L)$check)
  expect_true("small_slice" %in% suite_audit(suite, min_slice_cases = 4L)$check)
})

test_that("cases missing a why are flagged one per case", {
  suite <- agent_suite(list(
    agent_case("has", "x", "1", grader = "contains", why = "stated"),
    agent_case("missing1", "y", "1", grader = "contains"),
    agent_case("missing2", "z", "1", grader = "contains")
  ))
  au <- suite_audit(suite)
  nowhy <- au[au$check == "missing_why", ]
  expect_setequal(nowhy$target, c("missing1", "missing2"))
})

test_that("empty families and severities are reported against the known sets", {
  suite <- agent_suite(list(
    agent_case("a", "x", "1", family = "task", severity = "medium",
               grader = "contains", why = "r")
  ))
  au <- suite_audit(suite)
  fams <- au$target[au$check == "empty_family"]
  sevs <- au$target[au$check == "empty_severity"]
  # task is present, so it is not flagged; every other family is.
  expect_false("task" %in% fams)
  expect_true(all(setdiff(names(agent_families), "task") %in% fams))
  # medium is present; the other four levels are flagged.
  expect_false("medium" %in% sevs)
  expect_setequal(sevs, c("info", "low", "high", "critical"))
})

test_that("absent abstain and injection coverage is flagged, and present is not", {
  bare <- agent_suite(list(
    agent_case("a", "x", "1", grader = "contains", why = "r")
  ))
  au <- suite_audit(bare)
  expect_true("no_abstain" %in% au$check)
  expect_true("no_injection" %in% au$check)

  covered <- agent_suite(list(
    agent_case("ab", "q", family = "grounding", slice = "na",
               grader = "abstain", why = "docs are silent"),
    agent_case("inj", "q", expect = "leaked", family = "injection",
               grader = "refuses_injection", why = "planted order ignored")
  ))
  au2 <- suite_audit(covered)
  expect_false("no_abstain" %in% au2$check)
  expect_false("no_injection" %in% au2$check)
})

test_that("a function grader does not break the abstain or injection check", {
  suite <- agent_suite(list(
    agent_case("fn", "x", grader = function(expect, actual, case) "pass",
               why = "r")
  ))
  expect_silent(au <- suite_audit(suite))
  expect_true("no_abstain" %in% au$check)
})

test_that("suite_audit rejects a bad min_slice_cases", {
  suite <- agent_suite(list(agent_case("a", "x", "1", grader = "contains")))
  expect_error(suite_audit(suite, min_slice_cases = 0), "min_slice_cases")
  expect_error(suite_audit(suite, min_slice_cases = c(2, 3)), "min_slice_cases")
  expect_error(suite_audit(suite, min_slice_cases = NA), "min_slice_cases")
})

test_that("suite_audit is advisory: it leaves scoring and verdicts untouched", {
  suite <- agent_suite(list(
    agent_case("a", "x", "1", slice = "s1", grader = "contains", why = "r"),
    agent_case("b", "y", "1", slice = "s2", grader = "contains", why = "r")
  ))
  run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  before <- score_slices(run)
  verdict_before <- readiness(run)$verdict
  invisible(suite_audit(suite))
  expect_equal(score_slices(run), before)
  expect_equal(readiness(run)$verdict, verdict_before)
})

test_that("a clean suite yields a zero-row frame and a success print", {
  # Every family, every severity, both coverage checks, slices of 3+, all why.
  cases <- list()
  fams <- names(agent_families)
  sevs <- c("info", "low", "medium", "high", "critical")
  k <- 0L
  for (f in fams) {
    for (j in 1:3) {
      k <- k + 1L
      sev <- sevs[((k - 1L) %% length(sevs)) + 1L]
      g <- if (f == "injection") "refuses_injection" else "contains"
      cases[[k]] <- agent_case(paste0("c", k), "x",
                               expect = "1", family = f, slice = f,
                               severity = sev, grader = g, why = "stated")
    }
  }
  # guarantee an abstain case too
  cases[[k + 1L]] <- agent_case("abst", "q", family = "grounding",
                                slice = "task", grader = "abstain",
                                why = "docs silent")
  suite <- agent_suite(cases)
  au <- suite_audit(suite)
  expect_equal(nrow(au), 0L)
  expect_invisible(print(au))
})

test_that("print returns its input invisibly for a non-empty audit", {
  suite <- agent_suite(list(agent_case("a", "x", "1", grader = "contains")))
  expect_invisible(print(suite_audit(suite)))
})
