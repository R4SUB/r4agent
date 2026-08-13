#' Set the thresholds a run will be judged against
#'
#' Agreed before the run, not chosen afterwards to suit the result. A
#' benchmark that cannot fail is a marketing exercise, and the only defence
#' against that is writing the numbers down first and putting them in version
#' control with the cases.
#'
#' @param default Numeric in 0 to 1. Applied to any slice not named.
#' @param ... Named thresholds, for example `billing = 0.9`.
#' @return An object of class `r4agent_thresholds`.
#' @export
#' @examples
#' agent_thresholds(default = 0.85, `not answerable` = 0.95)
agent_thresholds <- function(default = 0.9, ...) {
  per <- list(...)
  if (length(per) && is.null(names(per))) {
    cli::cli_abort("Slice thresholds must be named.")
  }
  vals <- c(default, unlist(per))
  if (any(vals < 0 | vals > 1)) cli::cli_abort("Thresholds are proportions between 0 and 1.")
  structure(list(default = default, per_slice = per), class = "r4agent_thresholds")
}

#' Score a run by slice
#'
#' Reports each slice separately. The overall figure is included and is the
#' least useful number here: it is the average of a slice at 0.94 and a slice
#' at 0.42, and only the per slice view shows which is which.
#'
#' A "warn" counts as half, which is what `r4subcore::result_to_score()` does,
#' so a benchmark scores the same way as the rest of the ecosystem.
#'
#' @param run An `r4agent_run`.
#' @param rep Which repeat to score.
#' @return A data frame with one row per slice plus a total row.
#' @export
score_slices <- function(run, rep = 1L) {
  stopifnot(inherits(run, "r4agent_run"))
  r <- run$results[run$results$rep == rep, ]
  sc <- r4subcore::result_to_score(r$result)
  sc[is.na(sc)] <- 0

  by_slice <- lapply(split(seq_len(nrow(r)), r$slice), function(i) {
    data.frame(
      slice = r$slice[i][1],
      cases = length(i),
      passed = sum(r$result[i] == "pass"),
      warned = sum(r$result[i] == "warn"),
      failed = sum(r$result[i] == "fail"),
      score = round(mean(sc[i]), 4),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, by_slice)
  out <- out[order(out$score), , drop = FALSE]
  rownames(out) <- NULL
  rbind(out, data.frame(
    slice = "TOTAL", cases = nrow(r),
    passed = sum(r$result == "pass"), warned = sum(r$result == "warn"),
    failed = sum(r$result == "fail"), score = round(mean(sc), 4),
    stringsAsFactors = FALSE
  ))
}

#' Decide whether the system is ready
#'
#' Returns one of three verdicts, with the slices that fell short attached.
#' The middle verdict is the common one and it is the useful one: it names
#' what to fix rather than passing or failing the whole system.
#'
#' @param run An `r4agent_run`.
#' @param thresholds An `r4agent_thresholds`.
#' @param rep Which repeat to judge.
#' @return An object of class `r4agent_readiness`.
#' @export
readiness <- function(run, thresholds = agent_thresholds(), rep = 1L) {
  stopifnot(inherits(thresholds, "r4agent_thresholds"))
  sc <- score_slices(run, rep = rep)
  sl <- sc[sc$slice != "TOTAL", , drop = FALSE]
  sl$threshold <- vapply(sl$slice, function(s) {
    if (!is.null(thresholds$per_slice[[s]])) thresholds$per_slice[[s]] else thresholds$default
  }, numeric(1))
  sl$clears <- sl$score >= sl$threshold

  short <- sl[!sl$clears, , drop = FALSE]
  # A critical case that failed is not a matter of degree. It blocks release
  # even where its slice average still clears, which an average alone hides.
  r <- run$results[run$results$rep == rep, ]
  blockers <- r[r$severity == "critical" & r$result == "fail", , drop = FALSE]

  verdict <- if (nrow(blockers)) {
    "not ready"
  } else if (!nrow(short)) {
    "ready"
  } else if (nrow(short) <= max(1L, floor(nrow(sl) / 2))) {
    "ready after named fixes"
  } else {
    "not ready"
  }

  structure(list(verdict = verdict, slices = sl, short = short,
                 blockers = blockers, total = sc[sc$slice == "TOTAL", "score"]),
            class = "r4agent_readiness")
}

#' @export
print.r4agent_readiness <- function(x, ...) {
  cli::cli_h1("Verdict: {x$verdict}")
  cli::cli_text("Overall {x$total}. The overall figure is the least useful number here.")
  for (i in seq_len(nrow(x$slices))) {
    s <- x$slices[i, ]
    mark <- if (s$clears) "v" else "x"
    cli::cli_text("  [{mark}] {.strong {s$slice}}  {s$score} against {s$threshold}  ({s$passed}/{s$cases})")
  }
  if (nrow(x$blockers)) {
    cli::cli_alert_danger("{nrow(x$blockers)} critical case{?s} failed: {.val {x$blockers$id}}")
  }
  invisible(x)
}
