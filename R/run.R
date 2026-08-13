#' Run a benchmark
#'
#' Sends every case to the system under test, grades the answer, and records
#' the input, the output, the verdict and the time taken.
#'
#' `repeats` is not a convenience. A system asked the same question five times
#' and answering differently on the third is a support problem waiting to
#' happen, and a suite run once per case can never show it. The default of one
#' keeps a quick run quick; raise it when consistency is part of the question.
#'
#' @param suite An `r4agent_suite`.
#' @param runner A function taking a single character input and returning the
#'   answer as a character string. Anything that can be called from R can be
#'   put behind this: an HTTP endpoint, a local model, a shell command.
#' @param repeats Integer. How many times to run each case.
#' @param study_id Character. Passed to the run context, and named this way
#'   because the evidence schema comes from the clinical submission side of
#'   R4SUB. Use the name of the system under test.
#' @param environment One of "DEV", "UAT", "PROD".
#' @param quiet Suppress the progress bar.
#'
#' @return An object of class `r4agent_run`.
#' @export
#' @examples
#' suite <- agent_suite(list(
#'   agent_case("a1", "2 + 2?", "4", grader = "contains", why = "Arithmetic.")
#' ))
#' run_benchmark(suite, function(x) "the answer is 4", quiet = TRUE)
run_benchmark <- function(suite, runner, repeats = 1L, study_id = "agent",
                          environment = "DEV", quiet = FALSE) {
  stopifnot(inherits(suite, "r4agent_suite"), is.function(runner))
  repeats <- as.integer(repeats)
  if (is.na(repeats) || repeats < 1L) cli::cli_abort("{.arg repeats} must be >= 1.")

  ctx <- suppressMessages(
    r4subcore::r4sub_run_context(study_id = study_id, environment = environment)
  )

  n <- length(suite) * repeats
  if (!quiet) cli::cli_progress_bar("Running", total = n)
  rows <- vector("list", n)
  k <- 0L

  for (rep in seq_len(repeats)) {
    for (case in suite) {
      k <- k + 1L
      t0 <- Sys.time()
      actual <- tryCatch(as.character(runner(case$input))[1],
                         error = function(e) paste("ERROR:", conditionMessage(e)))
      elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

      verdict <- tryCatch({
        v <- get_grader(case$grader)(case$expect, actual, case)
        if (!v %in% c("pass", "fail", "warn", "na")) "warn" else v
      }, error = function(e) "warn")

      rows[[k]] <- data.frame(
        rep = rep, id = case$id, family = case$family, slice = case$slice,
        severity = case$severity, input = case$input,
        expect = if (is.character(case$expect)) paste(case$expect, collapse = " | ") else NA_character_,
        actual = actual, result = verdict, seconds = elapsed,
        why = case$why, stringsAsFactors = FALSE
      )
      if (!quiet) cli::cli_progress_update()
    }
  }
  if (!quiet) cli::cli_progress_done()

  results <- do.call(rbind, rows)
  structure(
    list(results = results, ctx = ctx, repeats = repeats,
         study_id = study_id, n_cases = length(suite)),
    class = "r4agent_run"
  )
}

#' @export
print.r4agent_run <- function(x, ...) {
  r <- x$results
  first <- r[r$rep == 1L, ]
  cli::cli_h1("Benchmark: {x$study_id}")
  cli::cli_text("{x$n_cases} case{?s}, {x$repeats} repeat{?s}, {nrow(r)} run{?s}")
  tb <- table(factor(first$result, levels = c("pass", "warn", "fail", "na")))
  cli::cli_text("{.strong First pass}: {tb[['pass']]} pass, {tb[['warn']]} warn, {tb[['fail']]} fail")
  cli::cli_text("Median {round(stats::median(r$seconds), 3)}s, p95 {round(stats::quantile(r$seconds, 0.95, names = FALSE), 3)}s")
  invisible(x)
}

#' Convert a run to R4SUB evidence
#'
#' Emits one evidence row per case result, so a benchmark can be read by the
#' same tooling as the rest of the R4SUB ecosystem. The finer grained family
#' and slice travel in their own columns; `indicator_domain` carries the four
#' values the evidence schema allows, mapped through [agent_families].
#'
#' @param run An `r4agent_run`.
#' @param rep Which repeat to emit. Defaults to the first.
#' @return A validated evidence data frame.
#' @export
agent_evidence <- function(run, rep = 1L) {
  stopifnot(inherits(run, "r4agent_run"))
  r <- run$results[run$results$rep == rep, ]
  if (!nrow(r)) cli::cli_abort("No results for repeat {rep}.")

  df <- data.frame(
    asset_type = "other",
    asset_id = run$study_id,
    source_name = "r4agent",
    source_version = as.character(utils::packageVersion("r4agent")),
    indicator_id = paste0("AG-", toupper(substr(r$family, 1, 4)), "-", r$id),
    indicator_name = r$id,
    indicator_domain = unname(agent_families[r$family]),
    severity = r$severity,
    result = r$result,
    metric_value = r$seconds,
    metric_unit = "seconds",
    message = ifelse(r$result == "pass", NA_character_,
                     substr(paste0("expected: ", r$expect, " | got: ", r$actual), 1, 500)),
    location = r$slice,
    stringsAsFactors = FALSE
  )
  df$family <- r$family
  df$slice <- r$slice
  suppressMessages(r4subcore::as_evidence(df, ctx = run$ctx))
}
