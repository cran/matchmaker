## ---- include = FALSE---------------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)

## ----setup--------------------------------------------------------------------
library("matchmaker")

# Read in data set
dat <- read.csv(matchmaker_example("coded-data.csv"),
  stringsAsFactors = FALSE
)
dat$date <- as.Date(dat$date)

# Read in dictionary
dict <- read.csv(matchmaker_example("spelling-dictionary.csv"),
  stringsAsFactors = FALSE
)

## ----show_data, echo = FALSE--------------------------------------------------
knitr::kable(head(dat))

## ----show_dictionary, echo = FALSE--------------------------------------------
knitr::kable(dict)

## ----example------------------------------------------------------------------
# Clean spelling based on dictionary -----------------------------
cleaned <- match_df(dat,
  dictionary = dict,
  from = "options",
  to = "values",
  by = "grp"
)
head(cleaned)

## ----keys-example-------------------------------------------------------------
who <- c("Anakin", "Darth", "R2-D2", "Leia", "C-3PO", "Rey", "Obi-Wan", "Luke", "Chewy", "Owen", "Lando")
icecream <- c(letters[1:3], "NO", "N", "yes", "Y", "n", "n", NA, "")
names(icecream) <- who
icecream

## ----mydict-1, echo = FALSE, results = 'asis'---------------------------------
my_dict1 <- data.frame(
  keys = c("yes", "Y", "n", "N", "NO", ".missing", ".default"),
  values = c("Yes", "Yes", "No", "No", "No", ".na", "(invalid)"),
  stringsAsFactors = FALSE
)
knitr::kable(my_dict1, caption = "my_dict1")

## ----key-value-change---------------------------------------------------------
match_vec(icecream, dictionary = my_dict1, from = "keys", to = "values")

## ----luke-no-like-------------------------------------------------------------
icecream["Luke"] <- "NOOOOOOO"
match_vec(icecream, dictionary = my_dict1, from = "keys", to = "values")

## ----mydict-2, echo = FALSE, results = 'asis'---------------------------------
my_dict2 <- data.frame(
  keys = c(".regex \\^[Yy][Ee]?[Ss]*$", ".regex \\^[Nn][Oo]*$", ".missing", ".default"),
  values = c("Yes", "No", ".na", "(invalid)"),
  stringsAsFactors = FALSE
)

knitr::kable(my_dict2, caption = "my_dict2", escape = TRUE)
my_dict2$keys <- c(".regex ^[Yy][Ee]?[Ss]*$", ".regex ^[Nn][Oo]*$", ".missing", ".default")

## ----luke-match---------------------------------------------------------------
match_vec(icecream, dictionary = my_dict2, from = "keys", to = "values")

## ----regex-df-----------------------------------------------------------------
# view the lab_result columns:
print(labs <- grep("^lab_result_", names(dat), value = TRUE))
str(dat[labs])
# show the lab_result part of the dictionary:
print(dict[grep("^[.]regex", dict$grp), ])
# clean the data and compare the result
cleaned <- match_df(dat, dict, 
  from = "options", 
  to = "values", 
  by = "grp", 
  order = "orders"
) 
str(cleaned[labs])

## ----global-df----------------------------------------------------------------
# show the lab_result part of the dictionary:
print(dict[grep("^[.]regex", dict$grp), ])
# show the original data
str(dat[labs])
# show the modified data
str(cleaned[labs])

## ----global-keys--------------------------------------------------------------
print(dict[grep("^[.](regex|global)", dict$grp), ])

## ----the_warning, message = TRUE----------------------------------------------
cleaned <- match_df(dat, dict, 
  from = "options", 
  to = "values", 
  by = "grp", 
  order = "orders",
  warn = TRUE
) 

