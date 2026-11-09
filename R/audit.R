#' Audit a suite for coverage and quality gaps
#'
#' A benchmark is only ever as good as the cases in it, and the cases are the
#' part people skimp on: a slice with one example, a case whose expected answer
#' nobody wrote a reason for, a whole family or severity that was never
#' exercised, no abstention case, no injection case. None of these is wrong
#' enough to fail a run, so an average never shows them. This lists them.
#'
#' The findings are advisory and carry no severity of their own. `suite_audit()`
#' changes no score and no verdict; it is a lint over the suite, read once while
#' the cases are being written, not a gate the suite has to clear. It does not
#' run the suite, call a model or touch the network: it reads the cases as they
#' stand.
#'
#' The checks are:
#' \itemize{
#'   \item \strong{empty_family} -- a family in [agent_families] that no case
#'     uses, so a whole domain of behaviour is unmeasured.
#'   \item \strong{empty_severity} -- a severity level ("info" through
#'     "critical") that no case carries.
#'   \item \strong{small_slice} -- a slice with fewer than `min_slice_cases`
#'     cases, too thin to support the per-slice verdict [readiness()] draws
#'     from it.
#'   \item \strong{missing_why} -- a case with no stated reason for its expected
#'     answer, the single most common defect in an evaluation set.
#'   \item \strong{no_abstain} -- no case uses the `abstain` grader, so the
#'     system's behaviour on a question it cannot answer is untested.
#'   \item \strong{no_injection} -- no case is in the `injection` family or uses
#'     the `refuses_injection` grader, so a planted instruction is never tried.
#' }
#'
#' @param suite An `r4agent_suite`.
#' @param min_slice_cases Integer. A slice with fewer than this many cases is
#'   flagged as too thin. Defaults to 3.
#'
#' @return A data frame of class `r4agent_audit`, one row per finding, with
#'   columns `check`, `scope`, `target` and `note`. A clean suite returns a
#'   zero-row frame of the same shape.
#' @seealso [agent_families], [readiness()]
#' @export
#' @examples
#' suite <- agent_suite(list(
#'   agent_case("billing-01", "When is my next invoice due?", "first",
#'              slice = "billing", grader = "contains",
#'              why = "Monthly plans bill on the first of the month."),
#'   agent_case("billing-02", "What card is on file?", "visa",
#'              slice = "billing", grader = "contains"),
#'   agent_case("edge-01", "Does the old portal support SAML?",
#'              family = "grounding", slice = "not answerable",
#'              grader = "abstain",
#'              why = "The docs do not say, so saying so is the only right answer.")
#' ))
#' suite_audit(suite)
#'
#' # The thin "not answerable" slice and the missing "why" surface as notes.
#' as.data.frame(suite_audit(suite))
suite_audit <- function(suite, min_slice_cases = 3L) {
  stopifnot(inherits(suite, "r4agent_suite"))
  if (!is.numeric(min_slice_cases) || length(min_slice_cases) != 1L ||
      is.na(min_slice_cases) || min_slice_cases < 1) {
    cli::cli_abort("{.arg min_slice_cases} must be a single number of at least 1.")
  }

  ids      <- vapply(suite, function(c) c$id, character(1))
  families <- vapply(suite, function(c) c$family, character(1))
  slices   <- vapply(suite, function(c) c$slice, character(1))
  sevs     <- vapply(suite, function(c) c$severity, character(1))
  whys     <- vapply(suite, function(c) c$why, character(1))
  graders  <- vapply(suite, function(c)
    if (is.character(c$grader)) c$grader else "<function>", character(1))

  findings <- list()
  add <- function(check, scope, target, note) {
    findings[[length(findings) + 1L]] <<- data.frame(
      check = check, scope = scope, target = target, note = note,
      stringsAsFactors = FALSE
    )
  }

  # Families defined in the ecosystem that this suite never exercises.
  for (f in names(agent_families)) {
    if (!f %in% families) {
      add("empty_family", "family", f,
          sprintf("No case exercises the %s family, so that domain is unmeasured.", f))
    }
  }

  # Severity levels no case carries.
  sev_levels <- c("info", "low", "medium", "high", "critical")
  for (s in sev_levels) {
    if (!s %in% sevs) {
      add("empty_severity", "severity", s,
          sprintf("No case carries severity %s.", s))
    }
  }

  # Slices too thin to support a per-slice verdict.
  sl_counts <- table(slices)
  for (s in names(sl_counts)) {
    n <- as.integer(sl_counts[[s]])
    if (n < min_slice_cases) {
      add("small_slice", "slice", s,
          sprintf(
            "Slice %s has %d case%s, below the minimum of %d; a slice this thin cannot support a per-slice verdict.",
            s, n, if (n == 1L) "" else "s", as.integer(min_slice_cases)))
    }
  }

  # Cases with no stated reason for their expected answer.
  for (i in which(is.na(whys) | !nzchar(whys))) {
    add("missing_why", "case", ids[i],
        sprintf("Case %s has no stated reason for its expected answer.", ids[i]))
  }

  # Abstention coverage.
  if (!any(graders == "abstain")) {
    add("no_abstain", "coverage", NA_character_,
        paste("No case uses the abstain grader; the system's behaviour on an",
              "unanswerable question is untested, and that is the one slice an",
              "average hides."))
  }

  # Prompt-injection coverage.
  if (!any(families == "injection") && !any(graders == "refuses_injection")) {
    add("no_injection", "coverage", NA_character_,
        paste("No case covers prompt injection (family \"injection\" or the",
              "refuses_injection grader), so a planted instruction is never tried."))
  }

  out <- if (length(findings)) {
    do.call(rbind, findings)
  } else {
    data.frame(check = character(0), scope = character(0),
               target = character(0), note = character(0),
               stringsAsFactors = FALSE)
  }
  rownames(out) <- NULL
  structure(out, class = c("r4agent_audit", "data.frame"))
}

#' @export
print.r4agent_audit <- function(x, ...) {
  n <- nrow(x)
  if (!n) {
    cli::cli_alert_success("Suite audit: no advisory findings.")
    return(invisible(x))
  }
  cli::cli_h1("Suite audit: {n} advisory note{?s}")
  cli::cli_text("Advisory only. None of these changes a score or a verdict.")
  for (i in seq_len(n)) {
    tgt <- x$target[i]
    where <- if (is.na(tgt)) x$scope[i] else sprintf("%s %s", x$scope[i], tgt)
    cli::cli_text("  {.strong [{x$check[i]}]} ({where}) {x$note[i]}")
  }
  invisible(x)
}
