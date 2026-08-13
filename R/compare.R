#' Run to run consistency
#'
#' The same input, asked more than once. Reports the share of cases that did
#' not return the same verdict every time.
#'
#' This is the measure most often skipped and it is the one that predicts
#' support load. A system that is right four times in five looks like a 0.8
#' in an average and behaves like a coin toss to the person using it.
#'
#' @param run An `r4agent_run` with `repeats` greater than one.
#' @return A list with the disagreement rate and the unstable case ids.
#' @export
consistency <- function(run) {
  stopifnot(inherits(run, "r4agent_run"))
  if (run$repeats < 2L) {
    cli::cli_abort(c("Consistency needs more than one repeat.",
                     i = "Re-run with {.code repeats = 5}."))
  }
  by_case <- split(run$results$result, run$results$id)
  unstable <- names(Filter(function(v) length(unique(v)) > 1L, by_case))
  list(
    disagreement = round(length(unstable) / length(by_case), 4),
    unstable = unstable,
    n_cases = length(by_case),
    repeats = run$repeats
  )
}

#' Compare two runs
#'
#' The most useful thing a benchmark reports is not the average. It is the
#' list of cases that used to pass and now fail.
#'
#' Model changes are rarely uniform improvements. A prompt revision fixes a
#' group of failures and breaks a smaller group of successes; the aggregate
#' rises and everyone is pleased. The broken group is still broken, and if it
#' contains something that matters more than average, the release is a
#' regression wearing an improvement's clothes.
#'
#' @param before,after Objects of class `r4agent_run`.
#' @param rep Which repeat to compare in each.
#' @return An object of class `r4agent_diff`.
#' @export
diff_runs <- function(before, after, rep = 1L) {
  stopifnot(inherits(before, "r4agent_run"), inherits(after, "r4agent_run"))
  b <- before$results[before$results$rep == rep, c("id", "slice", "severity", "result")]
  a <- after$results[after$results$rep == rep, c("id", "result", "actual")]
  m <- merge(b, a, by = "id", suffixes = c("_before", "_after"))

  broke <- m[m$result_before == "pass" & m$result_after != "pass", , drop = FALSE]
  fixed <- m[m$result_before != "pass" & m$result_after == "pass", , drop = FALSE]

  structure(list(
    broke = broke[order(broke$severity, decreasing = TRUE), , drop = FALSE],
    fixed = fixed,
    unchanged = nrow(m) - nrow(broke) - nrow(fixed),
    gone = setdiff(b$id, a$id),
    added = setdiff(a$id, b$id)
  ), class = "r4agent_diff")
}

#' @export
print.r4agent_diff <- function(x, ...) {
  cli::cli_h1("Change since the last run")
  cli::cli_text("{nrow(x$fixed)} newly passing, {.strong {nrow(x$broke)} newly failing}, {x$unchanged} unchanged")
  if (nrow(x$broke)) {
    cli::cli_h3("Used to pass, now fails")
    for (i in seq_len(nrow(x$broke))) {
      r <- x$broke[i, ]
      cli::cli_text("  {.strong {r$id}} ({r$slice}, {r$severity}) -> {r$result_after}")
    }
  }
  if (length(x$gone)) cli::cli_alert_warning("{length(x$gone)} case{?s} missing from the new run: {.val {x$gone}}")
  if (length(x$added)) cli::cli_alert_info("{length(x$added)} new case{?s}: {.val {x$added}}")
  invisible(x)
}

#' Write the report
#'
#' Markdown, so it can be committed next to the results it describes and read
#' in a pull request without a viewer.
#'
#' @param run An `r4agent_run`.
#' @param thresholds An `r4agent_thresholds`.
#' @param file Path to write to, or NULL to return the text.
#' @param rep Which repeat to report.
#' @return The markdown, invisibly if written to a file.
#' @export
report_markdown <- function(run, thresholds = agent_thresholds(), file = NULL,
                            rep = 1L) {
  rd <- readiness(run, thresholds, rep = rep)
  sc <- score_slices(run, rep = rep)
  r <- run$results[run$results$rep == rep, ]
  fails <- r[r$result != "pass", , drop = FALSE]

  ln <- c(
    sprintf("# Benchmark report: %s", run$study_id),
    "",
    sprintf("Run %s, %d cases, %d repeat(s).", run$ctx$run_id, run$n_cases, run$repeats),
    "",
    sprintf("## Verdict: %s", rd$verdict),
    "",
    sprintf("Overall score %.4f. Read the slices, not this number.", rd$total),
    "",
    "## By slice",
    "",
    "| Slice | Cases | Passed | Warned | Failed | Score | Threshold | |",
    "|---|---:|---:|---:|---:|---:|---:|---|"
  )
  for (i in seq_len(nrow(rd$slices))) {
    s <- rd$slices[i, ]
    ln <- c(ln, sprintf("| %s | %d | %d | %d | %d | %.4f | %.2f | %s |",
                        s$slice, s$cases, s$passed, s$warned, s$failed,
                        s$score, s$threshold, if (s$clears) "clear" else "short"))
  }
  tot <- sc[sc$slice == "TOTAL", ]
  ln <- c(ln, sprintf("| **Total** | %d | %d | %d | %d | %.4f | | |",
                      tot$cases, tot$passed, tot$warned, tot$failed, tot$score))

  ln <- c(ln, "", sprintf("## Failing cases (%d)", nrow(fails)), "")
  if (!nrow(fails)) {
    ln <- c(ln, "None.")
  } else {
    for (i in seq_len(nrow(fails))) {
      f <- fails[i, ]
      ln <- c(ln,
              sprintf("### %s  (%s, %s, %s)", f$id, f$slice, f$family, f$severity),
              "",
              sprintf("- **Asked:** %s", f$input),
              sprintf("- **Expected:** %s", ifelse(is.na(f$expect), "n/a", f$expect)),
              sprintf("- **Got:** %s", f$actual),
              sprintf("- **Why that answer is right:** %s", ifelse(is.na(f$why), "not stated", f$why)),
              "")
    }
  }

  ln <- c(ln, "", "## Latency", "",
          sprintf("- median %.3fs", stats::median(r$seconds)),
          sprintf("- p95 %.3fs", stats::quantile(r$seconds, 0.95, names = FALSE)),
          "",
          "Grading was deterministic and offline. No model judged another model,",
          "so every figure here is reproducible from the suite and the runner.")

  out <- paste(ln, collapse = "\n")
  if (is.null(file)) return(out)
  writeLines(out, file)
  invisible(out)
}
