#' Inter-run agreement and reliability
#'
#' [consistency()] answers whether an agent is stable across repeated runs with
#' a single disagreement rate, and [score_confidence()] puts an interval on a
#' single run's per-slice score. Neither answers the reliability question a
#' reviewer actually asks: *how much do the repeated runs agree beyond what
#' chance alone would produce?* A system that passes four fifths of its cases on
#' every run looks stable by raw agreement even when the agreeing verdicts are
#' no better than coin flips. This reports the chance-corrected agreement that
#' tells the two apart.
#'
#' It treats each repeat in the run as a rater and each case as a subject rated
#' once per repeat, with the grader's verdict ("pass", "fail", "warn", "na") as
#' the nominal category. On that balanced, fully-crossed design it computes
#' three established statistics and a per-case breakdown. Nothing here calls a
#' model or the network; the verdicts are read from the run as it stands, so
#' every figure is reproducible from the run alone.
#'
#' @details
#' The statistics are textbook nominal-agreement measures; no weight, threshold
#' or scoring rule is invented here.
#'
#' \strong{Overall percent agreement} is the mean across cases of the per-case
#' pairwise agreement \eqn{P_i}, the proportion of rater pairs that assigned
#' case \eqn{i} to the same category. With \eqn{m} repeats and \eqn{n_{ij}}
#' repeats placing case \eqn{i} in category \eqn{j},
#' \deqn{P_i = \frac{1}{m(m-1)} \left( \sum_j n_{ij}^2 - m \right),}
#' the per-subject agreement of Fleiss (1971). For two repeats this is simply
#' the fraction of cases that returned the same verdict both times.
#'
#' \strong{Cohen's kappa} is reported when there are exactly two repeats
#' (Cohen, 1960). With observed agreement \eqn{p_o} (the share of cases whose
#' two verdicts match) and expected agreement
#' \eqn{p_e = \sum_j p_{1j} p_{2j}} formed from each repeat's own category
#' marginals \eqn{p_{1j}, p_{2j}},
#' \deqn{\kappa = \frac{p_o - p_e}{1 - p_e}.}
#'
#' \strong{Fleiss' kappa} is reported for three or more repeats (Fleiss, 1971).
#' With mean observed agreement \eqn{\bar P = \frac{1}{n}\sum_i P_i} and expected
#' agreement \eqn{\bar P_e = \sum_j p_j^2} from the pooled category proportions
#' \eqn{p_j = \frac{1}{nm}\sum_i n_{ij}},
#' \deqn{\kappa = \frac{\bar P - \bar P_e}{1 - \bar P_e}.}
#' Fleiss' form treats the repeats as interchangeable, which is what repeated
#' runs of one agent are; Cohen's form, used for two, keeps each repeat's
#' marginals separate. When every verdict falls in one category the expected
#' agreement is 1, kappa is \eqn{0/0} and is returned as `NA`: with no variation
#' to correct for, a chance-corrected statistic has nothing to say.
#'
#' The `strength` label follows the rule of thumb of Landis & Koch (1977)
#' (< 0 "poor", 0--0.20 "slight", 0.21--0.40 "fair", 0.41--0.60 "moderate",
#' 0.61--0.80 "substantial", 0.81--1 "almost perfect"). It is their published
#' guideline, quoted for orientation only; this package enforces no kappa
#' threshold and the label changes no score and no verdict.
#'
#' @param run An `r4agent_run` with `repeats` greater than one. Every case must
#'   have been run the same number of times, which [run_benchmark()] guarantees.
#'
#' @return An object of class `r4agent_agreement`: a list with
#'   `percent_agreement` (the overall mean pairwise agreement), `kappa`,
#'   `kappa_method` ("Cohen's kappa" or "Fleiss' kappa"), `strength` (the
#'   Landis & Koch label, or `NA` when kappa is `NA`), `expected_agreement`
#'   (\eqn{p_e}), `n_items`, `n_runs`, `categories` (the verdict levels seen),
#'   and `by_item`, a data frame with one row per case (`id`, `slice`,
#'   `severity`, `n_runs`, `distinct` verdicts, `modal` verdict and per-case
#'   `agreement`) ordered with the least-agreeing cases first.
#'
#' @references
#' Cohen, J. (1960). A coefficient of agreement for nominal scales.
#' \emph{Educational and Psychological Measurement}, 20(1), 37--46.
#'
#' Fleiss, J. L. (1971). Measuring nominal scale agreement among many raters.
#' \emph{Psychological Bulletin}, 76(5), 378--382.
#'
#' Landis, J. R. & Koch, G. G. (1977). The measurement of observer agreement
#' for categorical data. \emph{Biometrics}, 33(1), 159--174.
#'
#' @seealso [consistency()], [consistency_strata()], [score_confidence()]
#' @export
#' @examples
#' suite <- agent_suite(list(
#'   agent_case("steady", "ping", "ok", slice = "stable", grader = "contains"),
#'   agent_case("flaky", "toggle", "ok", slice = "shaky", severity = "high",
#'              grader = "contains")
#' ))
#' # A deterministic offline runner that flips one case's answer every other call.
#' seen <- new.env()
#' flip <- function(x) {
#'   n <- if (exists(x, seen, inherits = FALSE)) get(x, seen) else 0L
#'   assign(x, n + 1L, seen)
#'   if (x == "toggle" && (n + 1L) %% 2L == 0L) "no" else "ok"
#' }
#' run <- run_benchmark(suite, flip, repeats = 4L, quiet = TRUE)
#' ag <- agent_agreement(run)
#' ag
#' ag$by_item
agent_agreement <- function(run) {
  stopifnot(inherits(run, "r4agent_run"))
  m <- run$repeats
  if (m < 2L) {
    cli::cli_abort(c("Agreement needs more than one repeat.",
                     i = "Re-run with {.code repeats = 5}."))
  }

  res <- run$results
  res <- res[order(res$id, res$rep), , drop = FALSE]
  by_id <- split(res$result, res$id)

  nr <- vapply(by_id, length, integer(1))
  if (any(nr != m)) {
    bad <- names(by_id)[nr != m]
    cli::cli_abort(c(
      "Every case must have exactly {m} run{?s} to compare across repeats.",
      x = "These do not: {.val {bad}}.",
      i = "Agreement is defined on a balanced design, one verdict per repeat per case."
    ))
  }

  ids <- names(by_id)
  ratings <- do.call(rbind, by_id)          # n items x m repeats, char
  categories <- sort(unique(as.vector(ratings)))
  k <- length(categories)
  n <- length(ids)

  # n_ij: how many repeats placed case i in category j.
  counts <- t(vapply(seq_len(n), function(i)
    tabulate(match(ratings[i, ], categories), nbins = k), integer(k)))
  if (k == 1L) counts <- matrix(counts, nrow = n)  # vapply drops to vector when k == 1

  # Per-case pairwise agreement P_i (Fleiss, 1971), well defined for any m >= 2.
  p_i <- (rowSums(counts^2) - m) / (m * (m - 1))
  percent_agreement <- mean(p_i)

  if (m == 2L) {
    method <- "Cohen's kappa"
    r1 <- ratings[, 1]
    r2 <- ratings[, 2]
    p_o <- mean(r1 == r2)
    p1 <- vapply(categories, function(c) mean(r1 == c), numeric(1))
    p2 <- vapply(categories, function(c) mean(r2 == c), numeric(1))
    p_e <- sum(p1 * p2)
  } else {
    method <- "Fleiss' kappa"
    p_o <- percent_agreement            # Pbar, mean observed agreement
    p_j <- colSums(counts) / (n * m)
    p_e <- sum(p_j^2)
  }

  kappa <- if (isTRUE(all.equal(p_e, 1))) NA_real_ else (p_o - p_e) / (1 - p_e)
  # Round before labelling so the Landis & Koch band is read off the reported
  # figure and does not flip across a boundary on floating-point noise.
  kappa <- if (is.na(kappa)) NA_real_ else round(kappa, 4)

  modal <- categories[max.col(counts, ties.method = "first")]
  distinct <- rowSums(counts > 0L)
  meta <- res[!duplicated(res$id), c("id", "slice", "severity")]
  meta <- meta[match(ids, meta$id), , drop = FALSE]

  by_item <- data.frame(
    id = ids, slice = meta$slice, severity = meta$severity,
    n_runs = as.integer(nr), distinct = as.integer(distinct),
    modal = modal, agreement = round(p_i, 4),
    stringsAsFactors = FALSE
  )
  by_item <- by_item[order(by_item$agreement, by_item$id), , drop = FALSE]
  rownames(by_item) <- NULL

  structure(list(
    percent_agreement = round(percent_agreement, 4),
    kappa = kappa,
    kappa_method = method,
    strength = kappa_strength(kappa),
    expected_agreement = round(p_e, 4),
    n_items = n,
    n_runs = m,
    categories = categories,
    by_item = by_item
  ), class = "r4agent_agreement")
}

# Landis & Koch (1977) rule-of-thumb label. Orientation only; enforces nothing.
kappa_strength <- function(kappa) {
  if (is.na(kappa)) return(NA_character_)
  if (kappa < 0.0)  return("poor")
  if (kappa <= 0.20) return("slight")
  if (kappa <= 0.40) return("fair")
  if (kappa <= 0.60) return("moderate")
  if (kappa <= 0.80) return("substantial")
  "almost perfect"
}

#' @export
print.r4agent_agreement <- function(x, ...) {
  cli::cli_h1("Inter-run agreement: {x$n_items} case{?s} over {x$n_runs} run{?s}")
  cli::cli_text("Categories seen: {.val {x$categories}}")
  cli::cli_text("Percent agreement: {sprintf('%.4f', x$percent_agreement)} (mean pairwise)")
  if (is.na(x$kappa)) {
    cli::cli_text("{x$kappa_method}: NA (every verdict in one category; nothing for chance to correct)")
  } else {
    cli::cli_text("{x$kappa_method}: {sprintf('%.4f', x$kappa)} ({x$strength}), expected {sprintf('%.4f', x$expected_agreement)}")
  }
  disagree <- x$by_item[x$by_item$agreement < 1, , drop = FALSE]
  if (nrow(disagree)) {
    cli::cli_h3("Cases where runs disagree most")
    for (i in seq_len(min(nrow(disagree), 10L))) {
      r <- disagree[i, ]
      cli::cli_text("  {.strong {r$id}} ({r$slice}, {r$severity})  agreement {sprintf('%.4f', r$agreement)}, {r$distinct} verdicts")
    }
    if (nrow(disagree) > 10L) {
      cli::cli_text("  ... and {nrow(disagree) - 10L} more; see {.code $by_item}.")
    }
  } else {
    cli::cli_alert_success("Every case returned the same verdict on every run.")
  }
  cli::cli_text("")
  cli::cli_text("Strength label follows Landis & Koch (1977); it changes no score or verdict.")
  invisible(x)
}
