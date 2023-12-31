% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/pool_case.R
\name{pool_case}
\alias{pool_case}
\title{Pooling qualified clients from multiple sources}
\usage{
pool_case(
  data,
  def,
  output_lvl = c("raw", "clnt"),
  include_src = c("all", "has_valid", "n_per_clnt"),
  ...
)
}
\arguments{
\item{data}{A list of data.frame or remote table which should be output from [execute_def()].}

\item{def}{A tibble of case definition generated by [build_def()].}

\item{output_lvl}{Either "raw" - output all records (default), or "clnt" - output one record per client with summarized date of first valid record (`first_valid_date`), date of the latest record (`last_entry_date`), and sources that contain valid records.}

\item{include_src}{Character, one of "all" - records from all sources are included; "has_valid" - for each client, records from sources that contain at least one valid record are included; "n_per_clnt" - for each client, if they had fewer than `n_per_clnt` records in a source (see [restrict_n()]), then records from that source are removed. This option will not impact the number of client that would be identified but has impact on the number of records and the latest entry date.}

\item{...}{Additional arguments passing to [bind_sources()]}
}
\value{
A data.frame or remote table with clients that satisfied the predefined case definition.
}
\description{
Pooling qualified clients from multiple sources
}
\examples{
# toy data
sample_size <- 30
df <- data.frame(
  clnt_id = rep(1:3, each = 10),
  service_dt = sample(seq(as.Date("2020-01-01"), as.Date("2020-01-31"), by = 1),
    size = sample_size, replace = TRUE
  ),
  diagx = sample(letters, size = sample_size, replace = TRUE),
  diagx_1 = sample(c(NA, letters), size = sample_size, replace = TRUE),
  diagx_2 = sample(c(NA, letters), size = sample_size, replace = TRUE)
)

# make df a database table
db <- dbplyr::tbl_memdb(df)

# use build_def to make a toy definition
sud_def <- build_def("SUD", # usually a disease name
  src_lab = c("src1", "src2"), # identify from multiple sources, e.g., hospitalization, ED visits.
  # functions that filter the data with some criteria
  def_fn = define_case,
  fn_args = list(
    vars = starts_with("diagx"),
    match = "start", # "start" will be applied to all sources as length = 1
    vals = list(c("304"), c("305")),
    clnt_id = "clnt_id", # list()/c() could be omitted for single element
    # c() can be used in place of list
    # if this argument only takes one value for each source
    n_per_clnt = c(2, 3)
  )
)

# save the definition for re-use
# saveRDS(sud_def, file = some_path)

# execute definition
sud_by_src <- sud_def \%>\% execute_def(with_data = list(src1 = db, src2 = db))

# pool results from src1 and src2 together at client level
sud_pooled <- pool_case(sud_by_src, sud_def, output_lvl = "clnt")
}
