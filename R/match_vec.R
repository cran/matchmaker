#' Rename values in a vector based on a dictionary
#'
#' This function provides an interface for [forcats::fct_recode()],
#' [forcats::fct_explicit_na()], and [forcats::fct_relevel()] in such a way that
#' a data dictionary can be imported from a data frame.
#'
#' @param x a character or factor vector
#'
#' @param dictionary a matrix or data frame defining mis-spelled words or keys
#' in one column (`from`) and replacement values (`to`) in another
#' column. There are keywords that can be appended to the `from` column for
#' addressing default values and missing data.
#'
#' @param from a column name or position defining words or keys to be replaced
#'
#' @param to a column name or position defining replacement values
#'
#' @param quiet a `logical` indicating if warnings should be issued if no
#'   replacement is made; if `FALSE`, these warnings will be disabled
#'
#' @param warn_default a `logical`. When a `.default` keyword is set and
#'   `warn_default = TRUE`, a warning will be issued listing the variables
#'   that were changed to the default value. This can be used to update your
#'   dictionary.
#'
#' @param anchor_regex a `logical`. When `TRUE` (default), any regex within
#'   the keywork
#'
#'
#' @details
#'
#' \subsection{Keys (`from` column)}{
#'
#' The `from` column of the dictionary will contain the keys that you want to
#' match in your current data set. These are expected to match exactly with
#' the exception of three reserved keywords that start with a full stop:
#'
#'  - `.regex [pattern]`: will replace anything matching `[pattern]`. **This
#'    is executed before any other replacements are made**. The `[pattern]`
#'    should be an unquoted, valid, PERL-flavored regular expression. Any
#'    whitespace padding the regular expression is discarded.
#'  - `.missing`: replaces any missing values (see NOTE)
#'  - `.default`: replaces **ALL** values that are not defined in the dictionary
#'                and are not missing.
#'
#' }
#' \subsection{Values (`to` column)}{
#'
#' The values will replace their respective keys exactly as they are presented.
#'
#' There is currently one recognised keyword that can be placed in the `to`
#' column of your dictionary:
#'
#'  - `.na`: Replace keys with missing data. When used in combination with the
#'    `.missing` keyword (in column 1), it can allow you to differentiate
#'    between explicit and implicit missing data.
#'
#' }
#'
#' @note If there are any missing values in the `from` column (keys), then they
#' are automatically converted to the character "NA" with a warning. If you want
#' to target missing data with your dictionary, use the `.missing` keyword. The
#' `.regex` keyword uses [gsub()] with the `perl = TRUE` option for replacement.
#'
#' @return a vector of the same type as `x` with mis-spelled labels cleaned.
#'   Note that factors will be arranged by the order presented in the data
#'   dictionary; other levels will appear afterwards.
#'
#' @author Zhian N. Kamvar
#'
#' @seealso [match_df()] for an implementation that acts across
#'   multiple variables in a data frame.
#'
#' @export
#'
#' @examples
#'
#' corrections <- data.frame(
#'   bad = c("foubar", "foobr", "fubar", "unknown", ".missing"),
#'   good = c("foobar", "foobar", "foobar", ".na", "missing"),
#'   stringsAsFactors = FALSE
#' )
#' corrections
#'
#' # create some fake data
#' my_data <- c(letters[1:5], sample(corrections$bad[-5], 10, replace = TRUE))
#' my_data[sample(6:15, 2)] <- NA  # with missing elements
#'
#' match_vec(my_data, corrections)
#'
#' # You can use regular expressions to simplify your list
#' corrections <- data.frame(
#'   bad =  c(".regex f[ou][^m].+?r$", "unknown", ".missing"),
#'   good = c("foobar",                ".na",     "missing"),
#'   stringsAsFactors = FALSE
#' )
#'
#' # You can also set a default value
#' corrections_with_default <- rbind(corrections, c(bad = ".default", good = "unknown"))
#' corrections_with_default
#'
#' # a warning will be issued about the data that were converted
#' match_vec(my_data, corrections_with_default)
#'
#' # use the warn_default = FALSE, if you are absolutely sure you don't want it.
#' match_vec(my_data, corrections_with_default, warn_default = FALSE)
#'
#' # The function will give you a warning if the dictionary does not
#' # match the data
#' match_vec(letters, corrections)
#'
#' # The can be used for translating survey output
#'
#' words <- data.frame(
#'   option_code = c(".regex ^[yY][eE]?[sS]?",
#'     ".regex ^[nN][oO]?",
#'     ".regex ^[uU][nN]?[kK]?",
#'     ".missing"),
#'   option_name = c("Yes", "No", ".na", "Missing"),
#'   stringsAsFactors = FALSE
#' )
#' match_vec(c("Y", "Y", NA, "No", "U", "UNK", "N"), words)
#' @importFrom forcats fct_recode fct_explicit_na fct_relevel
#' @importFrom rlang "!!!"

match_vec <- function(x = character(), dictionary = data.frame(),
                      from = 1, to = 2,
                      quiet = FALSE, warn_default = TRUE,
                      anchor_regex = TRUE) {

  if (length(x) == 0 || !is.atomic(x)) {
    stop("x must be coerceable to a character")
  } else if (!is.factor(x)) {
    nx <- names(x)
    x  <- as.character(x)
    names(x) <- nx
  }

  wl_is_data_frame  <- is.data.frame(dictionary)

  wl_is_rectangular <- (wl_is_data_frame || is.matrix(dictionary)) &&
    ncol(dictionary) >= 2

  if (!wl_is_rectangular) {
    stop("dictionary must be a data frame with at least two columns")
  }

  if (!wl_is_data_frame) {
    dictionary <- as.data.frame(dictionary, stringsAsFactors = FALSE)
  }

  from_exists <- i_check_scalar(from) && i_check_column_name(from, names(dictionary))
  to_exists   <- i_check_scalar(to)   && i_check_column_name(to, names(dictionary))

  if (!from_exists || !to_exists) {
    stop("`from` and `to` must refer to columns in the dictionary")
  }

  keys   <- dictionary[[from]]
  values <- dictionary[[to]]

  if (!is.atomic(keys) || !is.atomic(values)) {
    stop("dictionary must have two columns coerceable to a character")
  }

  keys   <- as.character(keys)
  values <- as.character(values)


  x_is_factor <- is.factor(x)

  # replace missing with "NA" if NA is present in data
  na_present <- is.na(keys)
  keys[na_present] <- "NA"

  # replace missing keyword with NA
  missing_kw       <- keys == ".missing" | keys == ""
  keys[missing_kw] <- NA_character_

  # removing duplicated keys
  duplikeys <- duplicated(keys)
  dkeys     <- keys[duplikeys]
  keys      <- keys[!duplikeys]
  values    <- values[!duplikeys]

  if (!quiet) {
    the_call  <- match.call()
    no_regex  <- !any(grepl("^\\.regex ", keys))
    no_keys   <- !any(x %in% keys, na.rm = TRUE)
    no_values <- !any(x %in% values, na.rm = TRUE)
    the_x     <- deparse(the_call[["x"]])
    the_words <- deparse(the_call[["dictionary"]])

    if (no_keys && no_values && no_regex) {
      msg <- "None of the variables in %s were found in %s. Did you use the correct dictionary?"
      msg <- sprintf(msg, the_x, the_words)
      warning(msg, call. = FALSE)
    }

    if (any(na_present)) {
      msg <- "NA was present in the `from` column of %s; replacing with the character 'NA'"
      msg <- paste(msg,
        "If you want to indicate missing data, use the '.missing' keyword.",
        collapse = "\n")
      msg <- sprintf(msg, the_words)
      warning(msg, call. = FALSE)
    }

    if (length(dkeys) > 0) {
      dkeys[is.na(dkeys)] <- ".missing"
      msg <- 'Duplicate keys were found in the `from` column of %s: "%s"\nonly the first instance will be used.'
      msg <- sprintf(msg, the_words, paste(dkeys, collapse = '", "'))
      warning(msg, call. = FALSE)
    }
  }


  dict        <- keys
  names(dict) <- values

  na_posi      <- is.na(dict)
  default_posi <- dict == ".default"

  default <- dict[!na_posi & default_posi]
  nas     <- dict[na_posi]
  dict    <- dict[!na_posi & !default_posi]

  # replacing regex keys first ------------------------------------------------
  reg_keys       <- grepl("^\\.regex ", dict)
  dict[reg_keys] <- trimws(gsub("^\\.regex ", "", dict[reg_keys]))
  # If the user wants us to automatically add regex anchors.
  if (anchor_regex) {
    dict[reg_keys] <- sprintf("^%s$", dict[reg_keys])
  }

  for (i in seq_along(dict[reg_keys])) {
    pattern      <- dict[reg_keys][i]
    replacement  <- names(dict[reg_keys])[i]
    x            <- gsub(pattern, replacement, x, perl = TRUE)
  }

  # replacing the regex keys with their values
  dict[reg_keys] <- names(dict)[reg_keys]

  # Making "" explicitly NA ---------------------------------------------------
  x <- forcats::fct_recode(x, NULL = "")

  # Recode data with forcats --------------------------------------------------
  suppressWarnings(x <- forcats::fct_recode(x, !!!dict))

  # Replace NAs if there are any ----------------------------------------------
  if (length(nas) > 0) {
    x <- forcats::fct_explicit_na(x, na_level = names(nas))
  }

  # Make certain values missing if ".na" is in the values
  x <- forcats::fct_recode(x, NULL = ".na")

  # Replace any untranslated variables if .default is defined -----------------
  if (length(default) > 0) {
    default_vars <- levels(x)[!levels(x) %in% c(names(dict), names(nas))]
    if (warn_default && length(default_vars) > 0) {
      was <- if (length(default_vars) > 1) "were" else "was"
      msg <- "'%s' %s changed to the default value ('%s')"
      warning(sprintf(msg, paste(default_vars, collapse = "', '"), was, names(default)), call. = FALSE)
    }
    suppressWarnings({
      x <- forcats::fct_other(x, keep = c(names(dict), names(nas)), other_level = names(default))
    })
  }

  # Make sure order is preserved if it's a factor -----------------------------
  if (x_is_factor) {
    suppressWarnings(x <- forcats::fct_relevel(x, unique(values)))
  } else {
    nx <- names(x)
    x  <- as.character(x)
    names(x) <- nx
  }

  x
}
