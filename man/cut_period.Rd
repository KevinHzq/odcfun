% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/cut_period.R
\name{cut_period}
\alias{cut_period}
\title{Cut the time period in one row into multiple rows by interval}
\usage{
cut_period(
  dat,
  start,
  end,
  len,
  unit = c("day", "week", "month", "quarter", "year"),
  .dt_trans = NULL
)
}
\arguments{
\item{dat}{Input dataframe that each row has start and end dates}

\item{start}{Record start date column (unquoted)}

\item{end}{Record end date column (unquoted)}

\item{len}{An integer, the interval that would be used to divide the record duration}

\item{unit}{One of "day" (default), "week", "month", "quarter, or "year" used in combination of len to specify the time length of the interval.}

\item{.dt_trans}{Function to transform start/end, such as lubridate::ymd. Default is NULL.}
}
\value{
Data frame that each row is now a segment of the period defined by (start, end) in the original row. Original variables are retained and repeated for each segment plus new variables defining the segment interval.
}
\description{
This function is useful for cutting time ranges into levels for overlap joins.
}
\examples{
# toy data
df <- data.frame(sample_id = 1, period_id = 1, start_date = "2015-01-01", end_date = "2019-12-31")

# divide period into segments (multiple rows per period)
df_seg <- cut_period(
  dat = df, start = start_date, end = end_date,
  len = 30, .dt_trans = lubridate::ymd
)

# categorize segment_id as factor
df_seg$segment <- cut(df_seg$segment_id,
  breaks = c(0, 1, 2, Inf),
  labels = c("< 1 month", "1 - 2 months", "Remainder")
)
}
