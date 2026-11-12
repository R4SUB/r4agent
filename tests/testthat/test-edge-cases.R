# Edge cases and malformed input for existing behaviour. These assert the
# package as it stands; none of them changes scoring or grading semantics.

test_that("agent_case rejects malformed id and input", {
  expect_error(agent_case("", "x"))
  expect_error(agent_case(c("a", "b"), "x"))
  expect_error(agent_case("ok", c("x", "y")))
  expect_error(agent_case("ok", 42))
})

test_that("agent_case rejects an unknown severity", {
  expect_error(agent_case("c", "x", severity = "catastrophic"), "severity")
})

test_that("agent_case defaults are the documented ones", {
  cs <- agent_case("d", "ask me")
  expect_equal(cs$family, "task")
  expect_equal(cs$slice, "default")
  expect_equal(cs$severity, "medium")
  expect_equal(cs$grader, "exact")
  expect_true(is.na(cs$why))
  expect_null(cs$expect)
})

test_that("agent_suite requires every element to be a case", {
  expect_error(agent_suite(list(agent_case("a", "x"), "not a case")),
               "r4agent_case")
})

test_that("agent_suite accepts bare cases and lists of cases alike", {
  bare <- agent_suite(agent_case("a", "x"), agent_case("b", "y"))
  listed <- agent_suite(list(agent_case("a", "x"), agent_case("b", "y")))
  expect_length(bare, 2L)
  expect_length(listed, 2L)
})

test_that("as.data.frame renders one row per case with stable columns", {
  suite <- agent_suite(list(
    agent_case("a", "ask", "ans", slice = "s1"),
    agent_case("b", "ask2", grader = function(expect, actual, case) "pass")
  ))
  df <- as.data.frame(suite)
  expect_equal(nrow(df), 2L)
  expect_equal(names(df),
               c("id", "input", "expect", "family", "slice", "severity",
                 "grader", "why"))
  # a function grader is reported as "custom", a missing expect as NA
  expect_equal(df$grader[2], "custom")
  expect_true(is.na(df$expect[2]))
})

test_that("thresholds reject unnamed slice values and out-of-range numbers", {
  expect_error(agent_thresholds(0.9, 0.8), "named")
  expect_error(agent_thresholds(default = -0.1), "proportions")
  expect_error(agent_thresholds(default = 0.9, billing = 2), "proportions")
  expect_silent(agent_thresholds(default = 0, billing = 1))
})

test_that("a warn scores as a half in score_slices", {
  # grounded with no context returns warn, which must count as 0.5
  suite <- agent_suite(list(
    agent_case("w1", "q", family = "grounding", grader = "grounded",
               slice = "ungrounded"),
    agent_case("p1", "q", "1", grader = "contains", slice = "ungrounded")
  ))
  run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  sc <- score_slices(run)
  # one pass (1) and one warn (0.5) -> mean 0.75
  expect_equal(sc$score[sc$slice == "ungrounded"], 0.75)
  expect_equal(sc$warned[sc$slice == "ungrounded"], 1L)
})

test_that("the total row aggregates every case in the repeat", {
  suite <- agent_suite(list(
    agent_case("a", "x", "1", grader = "contains", slice = "s1"),
    agent_case("b", "y", "1", grader = "contains", slice = "s2")
  ))
  run <- run_benchmark(suite, function(i) if (i == "x") "1" else "no",
                       quiet = TRUE)
  sc <- score_slices(run)
  tot <- sc[sc$slice == "TOTAL", ]
  expect_equal(tot$cases, 2L)
  expect_equal(tot$passed, 1L)
  expect_equal(tot$failed, 1L)
  expect_equal(tot$score, 0.5)
})

test_that("readiness returns 'ready' when every slice clears", {
  suite <- agent_suite(lapply(1:3, function(i)
    agent_case(paste0("s", i), "x", "1", grader = "contains",
               slice = paste0("sl", i))))
  run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  rd <- readiness(run, agent_thresholds(default = 0.9))
  expect_equal(rd$verdict, "ready")
  expect_equal(nrow(rd$short), 0L)
})

test_that("a small number of short slices yields 'ready after named fixes'", {
  # four slices, one short -> floor(4/2) = 2, one short clears the bar
  suite <- agent_suite(c(
    lapply(1:3, function(i) agent_case(paste0("ok", i), "x", "1",
                                       grader = "contains",
                                       slice = paste0("good", i))),
    list(agent_case("bad", "y", "1", grader = "contains", slice = "weak"))
  ))
  run <- run_benchmark(suite, function(i) if (i == "x") "1" else "no",
                       quiet = TRUE)
  rd <- readiness(run, agent_thresholds(default = 0.9))
  expect_equal(rd$verdict, "ready after named fixes")
  expect_equal(rd$short$slice, "weak")
})

test_that("many short slices yield 'not ready'", {
  suite <- agent_suite(lapply(1:4, function(i)
    agent_case(paste0("s", i), "y", "1", grader = "contains",
               slice = paste0("sl", i))))
  run <- run_benchmark(suite, function(i) "no", quiet = TRUE)
  rd <- readiness(run, agent_thresholds(default = 0.9))
  expect_equal(rd$verdict, "not ready")
})

test_that("the json grader validates structure and required fields", {
  g <- get_grader("json")
  case <- agent_case("j", "q", grader = "json")
  expect_equal(g(NULL, '{"a":1}', case), "pass")
  expect_equal(g(character(0), '{"a":1}', case), "pass")
  expect_equal(g("status", '{"status":"ok"}', case), "pass")
  expect_equal(g("status", '{"other":1}', case), "fail")
  expect_equal(g("status", "plainly not json", case), "fail")
})

test_that("the grounded grader warns when it cannot judge", {
  g <- get_grader("grounded")
  no_ctx <- agent_case("g", "q", family = "grounding", grader = "grounded")
  expect_equal(g(NULL, "some unverifiable claim", no_ctx), "warn")
  # an answer with no scorable content words also warns
  empty <- agent_case("g", "q", family = "grounding", grader = "grounded",
                      context = "anything")
  expect_equal(g(NULL, "a an to of", empty), "warn")
})

test_that("an unknown grader name is a clear error", {
  expect_error(get_grader("does-not-exist"), "No grader named")
})

test_that("register_grader rejects a function with too few arguments", {
  expect_error(register_grader("bad", function(expect, actual) "pass"),
               "grader takes")
  expect_true("exact" %in% graders_available())
})

test_that("a registered custom grader is usable in a run", {
  register_grader("always_pass", function(expect, actual, case) "pass")
  expect_true("always_pass" %in% graders_available())
  suite <- agent_suite(list(agent_case("c", "x", grader = "always_pass")))
  run <- run_benchmark(suite, function(i) "whatever", quiet = TRUE)
  expect_equal(run$results$result, "pass")
})

test_that("a grader returning a nonsense verdict is coerced to warn", {
  register_grader("nonsense", function(expect, actual, case) "banana")
  suite <- agent_suite(list(agent_case("n", "x", grader = "nonsense")))
  run <- run_benchmark(suite, function(i) "x", quiet = TRUE)
  expect_equal(run$results$result, "warn")
})

test_that("run_benchmark rejects a non-positive repeats", {
  suite <- agent_suite(list(agent_case("a", "x", "1", grader = "contains")))
  expect_error(run_benchmark(suite, function(i) "1", repeats = 0L,
                             quiet = TRUE), "repeats")
})

test_that("agent_evidence errors for a repeat that was not run", {
  suite <- agent_suite(list(agent_case("a", "x", "1", grader = "contains")))
  run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  expect_error(agent_evidence(run, rep = 2L), "No results")
})

test_that("evidence messages are populated only for non-passing cases", {
  suite <- agent_suite(list(
    agent_case("ok", "x", "1", grader = "contains"),
    agent_case("no", "y", "2", grader = "contains")
  ))
  run <- run_benchmark(suite, function(i) if (i == "x") "1" else "wrong",
                       quiet = TRUE)
  ev <- agent_evidence(run)
  expect_true(is.na(ev$message[ev$indicator_name == "ok"]))
  expect_match(ev$message[ev$indicator_name == "no"], "expected")
})

test_that("diff_runs lists regressions most-severe first", {
  suite <- agent_suite(list(
    agent_case("low-reg", "a", "1", grader = "contains", severity = "low"),
    agent_case("crit-reg", "b", "1", grader = "contains", severity = "critical"),
    agent_case("med-reg", "c", "1", grader = "contains", severity = "medium")
  ))
  before <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  after  <- run_benchmark(suite, function(i) "no", quiet = TRUE)
  d <- diff_runs(before, after)
  expect_equal(nrow(d$broke), 3L)
  # critical must come first, not sort alphabetically to the bottom
  expect_equal(d$broke$severity, c("critical", "medium", "low"))
  expect_equal(d$broke$id[1], "crit-reg")
})

test_that("diff_runs reports cases gone from and added to the new run", {
  before <- run_benchmark(
    agent_suite(list(agent_case("keep", "x", "1", grader = "contains"),
                     agent_case("old", "y", "1", grader = "contains"))),
    function(i) "1", quiet = TRUE)
  after <- run_benchmark(
    agent_suite(list(agent_case("keep", "x", "1", grader = "contains"),
                     agent_case("new", "z", "1", grader = "contains"))),
    function(i) "1", quiet = TRUE)
  d <- diff_runs(before, after)
  expect_equal(d$gone, "old")
  expect_equal(d$added, "new")
})

test_that("consistency reports zero disagreement for a stable runner", {
  suite <- agent_suite(list(agent_case("steady", "x", "1", grader = "contains")))
  run <- run_benchmark(suite, function(i) "1", repeats = 3L, quiet = TRUE)
  cc <- consistency(run)
  expect_equal(cc$disagreement, 0)
  expect_length(cc$unstable, 0L)
  expect_equal(cc$repeats, 3L)
})

test_that("report_markdown writes to a file and reports no failures cleanly", {
  suite <- agent_suite(list(
    agent_case("good", "x", "1", grader = "contains", slice = "a")
  ))
  run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  f <- tempfile(fileext = ".md")
  res <- report_markdown(run, agent_thresholds(default = 0.5), file = f)
  expect_true(file.exists(f))
  txt <- paste(readLines(f), collapse = "\n")
  expect_match(txt, "## Failing cases \\(0\\)")
  expect_match(txt, "None.", fixed = TRUE)
  expect_identical(res, txt)
})

test_that("print methods return their input invisibly", {
  suite <- agent_suite(list(agent_case("a", "x", "1", grader = "contains")))
  expect_invisible(print(suite))
  run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
  expect_invisible(print(run))
  expect_invisible(print(readiness(run)))
})
