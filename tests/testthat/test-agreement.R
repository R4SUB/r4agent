# agent_agreement() reports chance-corrected reliability across the repeats in a
# run. Every runner here is a deterministic offline stub; no model is called.
# The kappa values asserted below are worked by hand from the textbook formulas
# (Cohen 1960, Fleiss 1971).

# A runner that returns a scripted answer per (input, call number). run_benchmark
# calls each case once per repeat in repeat order, so script[[id]][k] is the
# answer on repeat k. The "exact" grader passes when the answer is "GOOD".
scripted <- function(script) {
  calls <- new.env(parent = emptyenv())
  function(x) {
    n <- if (exists(x, calls, inherits = FALSE)) get(x, calls) else 0L
    n <- n + 1L
    assign(x, n, calls)
    script[[x]][n]
  }
}

run_from_script <- function(script, repeats, slices = NULL, sevs = NULL) {
  ids <- names(script)
  cases <- lapply(ids, function(id) agent_case(
    id, id, "GOOD", grader = "exact",
    slice = if (is.null(slices)) "default" else slices[[id]],
    severity = if (is.null(sevs)) "medium" else sevs[[id]]
  ))
  run_benchmark(agent_suite(cases), scripted(script), repeats = repeats,
                quiet = TRUE)
}

test_that("needs more than one repeat", {
  run <- run_from_script(list(a = "GOOD"), repeats = 1L)
  expect_error(agent_agreement(run), "more than one repeat")
})

test_that("returns a classed object with the documented shape", {
  run <- run_from_script(list(a = c("GOOD", "GOOD"), b = c("BAD", "BAD")),
                         repeats = 2L)
  ag <- agent_agreement(run)
  expect_s3_class(ag, "r4agent_agreement")
  expect_equal(ag$n_items, 2L)
  expect_equal(ag$n_runs, 2L)
  expect_named(ag$by_item,
               c("id", "slice", "severity", "n_runs", "distinct", "modal",
                 "agreement"))
  expect_equal(nrow(ag$by_item), 2L)
})

test_that("Cohen's kappa for two runs matches the hand-worked value", {
  # 10 cases: 4 pass/pass, 1 pass/fail, 1 fail/pass, 4 fail/fail.
  # p_o = 0.8, p_e = 0.5, kappa = (0.8 - 0.5) / (1 - 0.5) = 0.6.
  script <- list(
    pp1 = c("GOOD", "GOOD"), pp2 = c("GOOD", "GOOD"),
    pp3 = c("GOOD", "GOOD"), pp4 = c("GOOD", "GOOD"),
    pf1 = c("GOOD", "BAD"),
    fp1 = c("BAD", "GOOD"),
    ff1 = c("BAD", "BAD"), ff2 = c("BAD", "BAD"),
    ff3 = c("BAD", "BAD"), ff4 = c("BAD", "BAD")
  )
  ag <- agent_agreement(run_from_script(script, repeats = 2L))
  expect_equal(ag$kappa_method, "Cohen's kappa")
  expect_equal(ag$percent_agreement, 0.8)
  expect_equal(ag$kappa, 0.6)
  expect_equal(ag$strength, "moderate")
  expect_setequal(ag$categories, c("fail", "pass"))
})

test_that("Fleiss' kappa for three or more runs matches the hand-worked value", {
  # case A: pass,pass,pass  (P = 1); case B: pass,pass,fail (P = 1/3).
  # Pbar = 2/3; pooled p_pass = 5/6, p_fail = 1/6; Pe = 26/36;
  # kappa = (2/3 - 26/36) / (1 - 26/36) = -0.2.
  script <- list(A = c("GOOD", "GOOD", "GOOD"),
                 B = c("GOOD", "GOOD", "BAD"))
  ag <- agent_agreement(run_from_script(script, repeats = 3L))
  expect_equal(ag$kappa_method, "Fleiss' kappa")
  expect_equal(ag$percent_agreement, round(2 / 3, 4))
  expect_equal(ag$kappa, -0.2)
  expect_equal(ag$strength, "poor")
})

test_that("perfect agreement across two balanced categories gives kappa 1", {
  script <- list(p = c("GOOD", "GOOD", "GOOD"),
                 f = c("BAD", "BAD", "BAD"))
  ag <- agent_agreement(run_from_script(script, repeats = 3L))
  expect_equal(ag$percent_agreement, 1)
  expect_equal(ag$kappa, 1)
  expect_equal(ag$strength, "almost perfect")
})

test_that("one category throughout leaves kappa undefined (NA)", {
  script <- list(a = c("GOOD", "GOOD", "GOOD"),
                 b = c("GOOD", "GOOD", "GOOD"))
  ag <- agent_agreement(run_from_script(script, repeats = 3L))
  expect_equal(ag$percent_agreement, 1)
  expect_true(is.na(ag$kappa))
  expect_true(is.na(ag$strength))
  expect_equal(ag$expected_agreement, 1)
})

test_that("by_item puts the least-agreeing case first with its modal verdict", {
  script <- list(A = c("GOOD", "GOOD", "GOOD"),   # always pass
                 B = c("GOOD", "GOOD", "BAD"))     # mostly pass, one fail
  ag <- agent_agreement(run_from_script(script, repeats = 3L))
  bi <- ag$by_item
  expect_equal(bi$id[1], "B")                      # lowest agreement first
  expect_equal(bi$distinct[bi$id == "B"], 2L)
  expect_equal(bi$distinct[bi$id == "A"], 1L)
  expect_equal(bi$modal[bi$id == "B"], "pass")     # 2 of 3 are pass
  expect_lt(bi$agreement[bi$id == "B"], bi$agreement[bi$id == "A"])
})

test_that("the breakdown carries slice and severity from the cases", {
  script <- list(x = c("GOOD", "BAD"))
  run <- run_from_script(script, repeats = 2L,
                         slices = list(x = "billing"),
                         sevs = list(x = "high"))
  ag <- agent_agreement(run)
  expect_equal(ag$by_item$slice, "billing")
  expect_equal(ag$by_item$severity, "high")
})

test_that("an unbalanced design is rejected", {
  # Hand-build a run whose case 'b' was only run once; run_benchmark never
  # produces this, but the guard must still catch it.
  results <- data.frame(
    rep = c(1L, 2L, 1L), id = c("a", "a", "b"),
    family = "task", slice = "default", severity = "medium",
    input = "x", expect = "1", actual = "1", result = c("pass", "fail", "pass"),
    seconds = 0, why = NA_character_, stringsAsFactors = FALSE
  )
  run <- structure(list(results = results, repeats = 2L, study_id = "x",
                        n_cases = 2L), class = "r4agent_run")
  expect_error(agent_agreement(run), "exactly 2 run")
})

test_that("per-case full agreement matches consistency()'s stable cases", {
  # A case returns the same verdict on every run (per-case agreement 1) exactly
  # when consistency() does not mark it unstable: the two functions describe the
  # same stability from different angles.
  script <- list(s1 = c("GOOD", "GOOD", "GOOD"),
                 s2 = c("BAD", "BAD", "BAD"),
                 u1 = c("GOOD", "BAD", "GOOD"))
  run <- run_from_script(script, repeats = 3L)
  ag <- agent_agreement(run)
  cc <- consistency(run)
  unstable_ids <- ag$by_item$id[ag$by_item$agreement < 1]
  stable_ids <- ag$by_item$id[ag$by_item$agreement == 1]
  expect_setequal(unstable_ids, cc$unstable)
  expect_setequal(stable_ids, setdiff(ag$by_item$id, cc$unstable))
})
