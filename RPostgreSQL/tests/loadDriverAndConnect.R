

## First rough version of a test script
##
## Assumes that 
##  a) PostgreSQL is running, and
##  b) the current user can connect
## both of which are not viable for release bui suitable while we test
##
## Dirk Eddelbuettel, 02 July 2008

## try to load our module and abort if this fails
stopifnot(require(RPostgreSQL))

## load the PostgresSQL driver
drv <- dbDriver("PostgreSQL")
# can't print result as it contains process id which changes  print(summary(drv))

## connect to the default db
con <- dbConnect(drv, dbname="template1")
# -- idem  print(con)

## run a simple query and show the top of the query
res <- dbGetQuery(con, "select * from pg_tables")
print(head(res))

## and disconnect
dbDisconnect(con)