#' Confidence intervals on the per-slice scores
#'
#' A per-slice score is a proportion estimated from a handful of cases, and a
#' proportion from a handful of cases is noise with a decimal point. A slice of
#' three cases that all passed scores 1.0, and a slice of three hundred that all
#' passed also scores 1.0; [readiness()] treats the two identically and
#' [suite_audit()] can only warn that the first is "too thin" without saying how
#' thin. This puts a number on it.
#'
#' For each slice it returns the score from [score_slices()] with a lower and an
#' upper bound at `conf_level`, computed as a Wilson score interval. A "warn"
#' counts as half, exactly as everywhere else in the package, so the score is
#' the mean of per-case scores of 0, 0.5 or 1 and the interval is around that
#' mean. For a slice that contains warns the interval is an approximation (an
#' interval on an effective pass proportion), which is the honest state of
#' affairs for the bounded mean of a few discrete values.
#'
#' The Wilson interval is used rather than the textbook normal approximation
#' because the normal one is useless at the edges, and the edges are where a
#' benchmark lives: a slice that passed every case has a point estimate of 1,
#' where the normal interval has zero width and claims certainty from three
#' observations. Wilson does not, and it is a closed form that needs no
#' resampling and no seed, so the bounds are reproducible from the run alone.
#'
#' When `thresholds` are supplied the slice's threshold is attached together
#' with two decisions: `clears_point`, whether the point score meets it (what
#' [readiness()] uses), and `clears_lower`, whether even the lower bound meets
#' it. A slice that clears on the point estimate but not on the lower bound has
#' not been shown to clear; it simply has too few cases to tell. That
#' distinction is the whole reason this function exists. It changes no score and
#' no verdict: [readiness()] is unchanged and this is an opt-in second look.
#'
#' @param run An `r4agent_run`.
#' @param thresholds Optional `r4agent_thresholds`. When given, each slice's
#'   threshold and the two clearance decisions are attached.
#' @param rep Which repeat to score.
#' @param conf_level Confidence level, a single number strictly between 0 and 1.
#'   Defaults to 0.95.
#' @return A data frame of class `r4agent_confidence`, one row per slice plus a
#'   TOTAL row, with columns `slice`, `cases`, `score`, `lower` and `upper`, and,
#'   when `thresholds` are supplied, `threshold`, `clears_point` and
#'   `clears_lower` (the last two are `NA` on the TOTAL row, which has no
#'   threshold of its own).
#' @seealso [score_slices()], [readiness()], [suite_audit()]
#' @export
#' @examples
#' suite <- agent_suite(list(
#'   agent_case("a1", "x", "1", grader = "contains", slice = "small"),
#'   agent_case("a2", "x", "1", grader = "contains", slice = "small"),
#'   agent_case("a3", "x", "1", grader = "contains", slice = "small")
#' ))
#' run <- run_benchmark(suite, function(i) "1", quiet = TRUE)
#' # Three for three is a perfect point score and a wide interval.
#' score_confidence(run)
#'
#' # With thresholds, the point score clears 0.9 but the lower bound does not:
#' # three cases are not enough to claim the slice is ready.
#' score_confidence(run, agent_thresholds(default = 0.9))
score_confidence <- function(run, thresholds = NULL, rep = 1L,
                             conf_level = 0.95) {
  stopifnot(inherits(run, "r4agent_run"))
  if (!is.null(thresholds) && !inherits(thresholds, "r4agent_thresholds")) {
    cli::cli_abort("{.arg thresholds} must be an {.cls r4agent_thresholds} or NULL.")
  }
  if (!is.numeric(conf_level) || length(conf_level) != 1L || is.na(conf_level) ||
      conf_level <= 0 || conf_level >= 1) {
    cli::cli_abort("{.arg conf_level} must be a single number strictly between 0 and 1.")
  }

  r <- run$results[run$results$rep == rep, ]
  if (!nrow(r)) cli::cli_abort("No results for repeat {rep}.")
  sc <- r4subcore::result_to_score(r$result)
  sc[is.na(sc)] <- 0

  z <- stats::qnorm(1 - (1 - conf_level) / 2)
  wilson <- function(scores) {
    n <- length(scores)
    phat <- mean(scores)
    denom <- 1 + z^2 / n
    centre <- (phat + z^2 / (2 * n)) / denom
    half <- (z / denom) * sqrt(phat * (1 - phat) / n + z^2 / (4 * n^2))
    c(lower = max(0, centre - half), upper = min(1, centre + half))
  }

  row_for <- function(slice, i) {
    ci <- wilson(sc[i])
    data.frame(slice = slice, cases = length(i), score = round(mean(sc[i]), 4),
               lower = round(unname(ci[["lower"]]), 4),
               upper = round(unname(ci[["upper"]]), 4),
               stringsAsFactors = FALSE)
  }

  idx <- split(seq_len(nrow(r)), r$slice)
  out <- do.call(rbind, lapply(names(idx), function(s) row_for(s, idx[[s]])))
  out <- out[order(out$score, out$lower), , drop = FALSE]
  out <- rbind(out, row_for("TOTAL", seq_len(nrow(r))))
  rownames(out) <- NULL

  if (!is.null(thresholds)) {
    thr <- vapply(out$slice, function(s) {
      if (identical(s, "TOTAL")) return(NA_real_)
      if (!is.null(thresholds$per_slice[[s]])) thresholds$per_slice[[s]]
      else thresholds$default
    }, numeric(1))
    out$threshold <- unname(thr)
    out$clears_point <- ifelse(is.na(out$threshold), NA, out$score >= out$threshold)
    out$clears_lower <- ifelse(is.na(out$threshold), NA, out$lower >= out$threshold)
  }

  attr(out, "conf_level") <- conf_level
  structure(out, class = c("r4agent_confidence", "data.frame"))
}

#' @export
print.r4agent_confidence <- function(x, ...) {
  cl <- attr(x, "conf_level")
  cli::cli_h1("Per-slice score with {round(cl * 100)}% confidence interval")
  has_thr <- "threshold" %in% names(x)
  for (i in seq_len(nrow(x))) {
    s <- x[i, ]
    band <- sprintf("%.4f [%.4f, %.4f]", s$score, s$lower, s$upper)
    if (has_thr && !is.na(s$threshold)) {
      mark <- if (isTRUE(s$clears_lower)) "v" else if (isTRUE(s$clears_point)) "~" else "x"
      cli::cli_text("  [{mark}] {.strong {s$slice}}  {band}  vs {s$threshold}  (n = {s$cases})")
    } else {
      cli::cli_text("  {.strong {s$slice}}  {band}  (n = {s$cases})")
    }
  }
  if (has_thr) {
    cli::cli_text("")
    cli::cli_text("[v] lower bound clears  [~] only the point estimate clears  [x] neither")
  }
  invisible(x)
}
