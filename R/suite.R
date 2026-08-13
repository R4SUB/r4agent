#' Families of measurement, and how they map onto the R4SUB evidence schema
#'
#' The evidence schema in 'r4subcore' allows four indicator domains: quality,
#' trace, risk and usability. A benchmark has more families than that, so each
#' family is mapped onto the domain it genuinely belongs to and the finer grain
#' is kept in the `family` and `slice` columns that travel alongside.
#'
#' The mapping is stated here rather than inferred, because it decides how
#' `aggregate_indicator_score()` will group results and getting it wrong would
#' quietly file a safety failure under quality.
#'
#' @format A named character vector: family to domain.
#' @export
agent_families <- c(
  task        = "quality",
  grounding   = "quality",
  format      = "quality",
  tool        = "quality",
  consistency = "quality",
  retrieval   = "trace",
  citation    = "trace",
  robustness  = "risk",
  injection   = "risk",
  safety      = "risk",
  cost        = "usability",
  latency     = "usability"
)

#' Define one benchmark case
#'
#' A case is an input, an answer somebody is prepared to defend, and the
#' grader that decides whether the two agree. The `why` field is not
#' decoration: a case whose expected answer nobody can justify is the single
#' most common defect in an evaluation set, and being asked to write the
#' justification is what surfaces it.
#'
#' @param id Character. Stable identifier. Used to match a case across runs,
#'   so renaming one breaks the regression diff for that case by design.
#' @param input Character. What is sent to the system under test.
#' @param expect The expected answer, interpreted by `grader`.
#' @param family One of `names(agent_families)`.
#' @param slice Character. The kind of input this case represents, for example
#'   "billing" or "not answerable". Reported separately, because an average
#'   over slices hides the one that is failing.
#' @param severity One of "info", "low", "medium", "high", "critical".
#' @param grader Character name of a registered grader, or a function taking
#'   `(expect, actual, case)` and returning "pass", "fail" or "warn".
#' @param why Character. Why the expected answer is the right one.
#' @param context Optional character vector of source passages, for grounding
#'   and citation graders.
#'
#' @return An object of class `r4agent_case`.
#' @export
#' @examples
#' agent_case(
#'   id = "billing-01",
#'   input = "When is my next invoice due?",
#'   expect = "the 1st",
#'   family = "task",
#'   slice = "billing",
#'   grader = "contains",
#'   why = "Billing runs on the first of the month for monthly plans."
#' )
agent_case <- function(id, input, expect = NULL, family = "task",
                       slice = "default", severity = "medium",
                       grader = "exact", why = NA_character_,
                       context = character(0)) {
  stopifnot(is.character(id), length(id) == 1L, nzchar(id))
  stopifnot(is.character(input), length(input) == 1L)
  if (!family %in% names(agent_families)) {
    cli::cli_abort(c(
      "{.val {family}} is not a known family.",
      i = "One of: {.val {names(agent_families)}}."
    ))
  }
  sev <- c("info", "low", "medium", "high", "critical")
  if (!severity %in% sev) {
    cli::cli_abort("{.arg severity} must be one of {.val {sev}}.")
  }
  structure(
    list(id = id, input = input, expect = expect, family = family,
         slice = slice, severity = severity, grader = grader,
         why = why, context = context),
    class = "r4agent_case"
  )
}

#' Collect cases into a suite
#'
#' @param ... Objects of class `r4agent_case`, or lists of them.
#' @return An object of class `r4agent_suite`.
#' @export
agent_suite <- function(...) {
  cases <- unlist(list(...), recursive = FALSE, use.names = FALSE)
  ok <- vapply(cases, inherits, logical(1), "r4agent_case")
  if (!all(ok)) {
    cli::cli_abort("Every element must be an {.cls r4agent_case}.")
  }
  ids <- vapply(cases, function(x) x$id, character(1))
  dup <- unique(ids[duplicated(ids)])
  if (length(dup)) {
    cli::cli_abort(c(
      "Case ids must be unique.",
      x = "Repeated: {.val {dup}}.",
      i = "Ids match a case across runs, so a duplicate silently breaks the diff."
    ))
  }
  structure(cases, class = "r4agent_suite")
}

#' @export
print.r4agent_suite <- function(x, ...) {
  fam <- table(vapply(x, function(c) c$family, character(1)))
  sl  <- table(vapply(x, function(c) c$slice, character(1)))
  cli::cli_h1("Benchmark suite: {length(x)} case{?s}")
  cli::cli_text("{.strong Families}: {paste(names(fam), unname(fam), sep = ' ', collapse = ', ')}")
  cli::cli_text("{.strong Slices}: {paste(names(sl), unname(sl), sep = ' ', collapse = ', ')}")
  nowhy <- sum(is.na(vapply(x, function(c) c$why, character(1))))
  if (nowhy) {
    cli::cli_alert_warning(
      "{nowhy} case{?s} ha{?s/ve} no stated reason for the expected answer."
    )
  }
  invisible(x)
}

#' Read a suite from YAML
#'
#' Cases belong in version control next to the code they test, which is why
#' the file format is plain YAML rather than anything this package invents.
#'
#' @param path Path to a YAML file holding a list of cases.
#' @return An `r4agent_suite`.
#' @export
read_agent_suite <- function(path) {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    cli::cli_abort("The {.pkg yaml} package is needed to read a suite file.")
  }
  raw <- yaml::read_yaml(path)
  cases <- lapply(raw$cases, function(x) {
    do.call(agent_case, x[intersect(names(x), names(formals(agent_case)))])
  })
  do.call(agent_suite, list(cases))
}

#' Turn a suite into a data frame
#'
#' @param x An `r4agent_suite`.
#' @param ... Ignored.
#' @return A data frame, one row per case.
#' @export
as.data.frame.r4agent_suite <- function(x, ...) {
  do.call(rbind, lapply(x, function(c) data.frame(
    id = c$id, input = c$input,
    expect = if (is.character(c$expect)) c$expect else NA_character_,
    family = c$family, slice = c$slice, severity = c$severity,
    grader = if (is.character(c$grader)) c$grader else "custom",
    why = c$why, stringsAsFactors = FALSE
  )))
}
