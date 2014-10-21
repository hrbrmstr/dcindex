library(rvest)      # super-easy scraping! devtools::install_github("hadley/rvest")
library(pbapply)    # free progress bars for everyone!
library(data.table) # use latest CRAN or higher so you get the 'fill' version of rbindlist

# retrieve primary DC index
pg <- html("http://www.dcindexes.com/features/indexes.php?site=dc")

# save ids; we don't use the names like I orignally thought I would
superhero_ids <- pg %>%
  html_nodes("select[name='selection'] option") %>%
  html_attr("value") %>% .[-1]

#superhero_names <- pg %>% html_nodes("select[name='selection'] option") %>% html_text() %>% .[-1]

s_ids <- sort(as.numeric(superhero_ids)) # not tecnically necessary, but, hey :-)

# we'll be sprintf'ing this
base_url <- "http://www.dcindexes.com/features/indexes.php?selection=%s"

# for future reference all possible fields are:
# fields <- c("Name", "Alter Ego", "Occupation", "Marital Status",
#             "Known Relatives", "Group Affiliation", "Base of Operations",
#             "Height", "Weight", "Hair", "Eyes", "First Appearance")

# iterate over our extracted super ids with a progress bar
# each iteration returns a one-row data.table with all of the extracted fields from the page
# the 'fill' parameter means we don't have to do any work to bind them all together

dc <- rbindlist(pblapply(s_ids, function(x) {

  pg_2 <- html(sprintf(base_url, x))

  # ugly XPaths == some 'spainin to do:

  # this one looks for a paragraph with a "bodytext" class, then looks for the
  # very next sibling paragraph and grabs the text between <b> tags
  fields <- pg_2 %>%
    html_nodes(xpath="//p[contains(@class,'bodytext')]/following-sibling::p[1]/b/text()") %>%
    html_text()

  # this one looks for a paragraph with a "bodytext" class, then looks for the
  # very next sibling paragraph and grabs the text outside the <b> tags OR
  # looks for a sibling <a> to the sibling <p> and grabs the text from it
  # and it leavs a blank line, so nuke it before continuing
  values <- pg_2 %>% html_nodes(xpath="//p[contains(@class,'bodytext')]/following-sibling::p[1]/b/following-sibling::text() |
                                       //p[contains(@class,'bodytext')]/following-sibling::p[1]/b/following-sibling::a/text()") %>%
    html_text() %>%
    grep("^\ +$", ., invert=TRUE, value=TRUE)


  fields <- fields %>% gsub(":", "", .) # don't need the ":" part of the field

  # i've got a `trim` function somewhere, but hey...
  values <- values %>% gsub("^[[:space:]]+|[[:space:]]+$", "", .)

  # make our data.table
  deets <- data.table(t(values))
  setnames(deets, fields)

  deets

}), fill=TRUE)

# speedy R format export
save(dc, file = "data/dc.rda")

# compatible CSV export
write.csv(dc, file = "data/dc.csv")
