#' @export
identify_rows.tbl_sql <- function(data, vars, match = c("in", "start", "regex", "like", "between", "glue_sql"), vals, if_all = FALSE, verbose = TRUE, query_only = TRUE, ...) {
  # input checks
  rlang::arg_match0(match, c("in", "start", "regex", "between", "like", "glue_sql"))

  # get variable names as text with tidyselect and NSE
  db_head <- data %>%
    dplyr::select({{ vars }}) %>%
    utils::head(n = 1) %>%
    dplyr::collect()
  vars <- names(db_head)

  if (match %in% c("in", "between")) {
    var_class <- purrr::map_chr(db_head %>% dplyr::select(dplyr::all_of(vars)), class)
    if (!any(class(vals) %in% var_class)) warning("`match_vals` (", class(vals), ") is not the same type as the `from_var` columns (", paste(var_class, collapse = ", "), ").")
  }

  # make match_str/msg for verbose
  switch(match,
    "start" = {
      match_str <- paste0(vals, "%", collapse = " OR ")
      match_msg <- "satisfied SQL LIKE pattern:"
      vals <- paste0(vals, "%")
    },
    "like" = {
      match_str <- paste0(vals, collapse = " OR ")
      match_msg <- "satisfied SQL LIKE pattern:"
    },
    "regex" = {
      match_str <- paste0(vals, collapse = "|")
      match_msg <- "satisfied regular expression:"
    },
    "in" = {
      match_str <- deparse(substitute(vals))
      match_msg <- "exactly matched values in set:"
    },
    "between" = {
      match_str <- deparse(substitute(vals))
      match_msg <- "between range (bounds included):"
    },
    "glue_sql" = {
      match_str <- glue::glue_sql_collapse(glue::glue_sql(vals, ..., .con = dbplyr::remote_con(data)), sep = ifelse(if_all, " AND ", " OR "))
      match_msg <- "satisfied SQL WHERE clause:"
    }
  )

  if (match == "regex") {
    # Note that SQL does not support regular expression. The match is done by collecting all distinct possible values locally then using regex in R. The result is plugged into subseqent query as: WHERE var_nm IN (match_result).
    all_val <- data %>%
      tidyr::pivot_longer(
        cols = vars,
        names_to = "position",
        values_to = "temp_val"
      ) %>%
      dplyr::select(dplyr::all_of("temp_val")) %>%
      dplyr::distinct() %>%
      dplyr::pull("temp_val")
    vals <- all_val[data.table::like(all_val, match_str)]
    if (length(vals) > 1000) warning("More than 1,000 distinct values were matched by the regular expression. The query including such long list may fail to run. Try using SQL LIKE expression with match_type = 'like'.")
  }

  # run different filter by match type
  # the action expressions were captured for replacing if_any if needed
  # altering expression approach is necessary because if_any/all cannot simply be replaced by different name because dbplyr would fail to translate
  switch(match,
    # left start empty so getting action from like
    "start" = ,
    "like" = act_expr <- rlang::expr({
      like_list <- lapply(vals, function(x) data %>% dplyr::filter(dplyr::if_any(vars, ~ stringr::str_like(., dbplyr::sql(dbplyr::escape_ansi(x))))))
      q_match <- Reduce(dplyr::union, like_list)
    }),
    "regex" = ,
    "in" = act_expr <- rlang::expr({
      q_match <- data %>%
        dplyr::filter(dplyr::if_any(vars, ~ . %in% dbplyr::sql(dbplyr::escape_ansi(vals, collapse = ",", parens = TRUE))))
    }),
    "between" = act_expr <- rlang::expr({
      stopifnot(
        length(vals) == 2,
        vals[1] <= vals[2]
      )
      q_match <- data %>% dplyr::filter(dplyr::if_any(vars, ~ dplyr::between(., dbplyr::sql(dbplyr::escape_ansi(vals[1])), dbplyr::sql(dbplyr::escape_ansi(vals[2])))))
    }),
    "glue_sql" = act_expr <- rlang::expr({
      q_match <- data %>% dplyr::filter(dbplyr::sql(match_str))
    })
  )

  if (if_all) {
    act_expr <- rlang::expr_text(act_expr) %>%
      stringr::str_replace("if_any", "if_all") %>%
      rlang::parse_expr()
  }

  eval(act_expr)

  # explain the configuration in plain language to prompt user thinking
  if (verbose) {
    # get all values in data
    matched_vals <- lapply(vars, function(x) {
      dplyr::select(q_match, dplyr::all_of(x)) %>%
        dplyr::distinct() %>%
        dplyr::pull()
    })
    # if ("Date" %in% var_class)
    matched_vals <- Reduce(dplyr::union, matched_vals)

    cat(
      "\nIdentify records with condition(s):",
      "\n - where", ifelse(if_all & length(vars) > 1, "all of the", ifelse(length(vars) > 1, "at least one of the", "the")), paste0(vars, collapse = ", "), "column(s) in each record",
      "\n   - contains a value", match_msg, match_str, "\n"
    )

    cat(ifelse(is.numeric(matched_vals), "\nRange of values in the result", "\nAll unique value(s) in the result"), ifelse(!if_all & length(vars) > 1, "(as the conditions require just one of the columns containing target values; irrelevant values may come from other columns):", ":"), "\n")

    switch(match,
      "between" = print(range(matched_vals)),
      if (is.numeric(matched_vals)) print(range(matched_vals)) else print(matched_vals, max = 100)
    )
  }

  # job done

  if (!query_only) {
    q_match <- q_match %>% dplyr::collect(cte = TRUE)
    # convert dates
  } else if (verbose) {
    cat(
      "\nTo see the final query generated by 'dbplyr', use dplyr::show_query() on the output.",
      "\nTo extract the SQL string, use dbplyr::remote_query().\n"
    )
  }

  return(q_match)
}