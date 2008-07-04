

## PostgreSQLSupport.R		Last Modified:

## This package was developed as a part of Summer of Code program organized by Google.
## Thanks to David A. James & Saikat DebRoy, the authors of RMySQL package.
## Code from RMySQL package was reused with the permission from the authors.
## Also Thanks to my GSoC mentor Dirk Eddelbuettel for helping me in the development.



"postgresqlInitDriver" <-
function(max.con=16, fetch.default.rec = 500, force.reload=FALSE)
## create a PostgreSQL database connection manager.  By default we allow
## up to "max.con" connections and single fetches of up to "fetch.default.rec"
## records.  These settings may be changed by re-loading the driver
## using the "force.reload" = T flag (note that this will close all
## currently open connections).
## Returns an object of class "PostgreSQLManger".
## Note: This class is a singleton.
{
   if(fetch.default.rec<=0)
      stop("default num of records per fetch must be positive")
   config.params <- as.integer(c(max.con, fetch.default.rec))
   force <- as.logical(force.reload)
   drvId <- .Call("RS_PostgreSQL_init", config.params, force,
                  PACKAGE = .PostgreSQLPkgName)
   new("PostgreSQLDriver", Id = drvId)
}

"postgresqlCloseDriver"<-
function(drv, ...)
{
   if(!isIdCurrent(drv))
      return(TRUE)
   drvId <- as(drv, "integer")
   .Call("RS_PostgreSQL_closeManager", drvId, PACKAGE = .PostgreSQLPkgName)
}

"postgresqlDescribeDriver" <-
function(obj, verbose = FALSE, ...)
## Print out nicely a brief description of the connection Driver
{
   info <- dbGetInfo(obj)
   print(obj)
   cat("  Driver name: ", info$drvName, "\n")
   cat("  Max  connections:", info$length, "\n")
   cat("  Conn. processed:", info$counter, "\n")
   cat("  Default records per fetch:", info$"fetch_default_rec", "\n")
   if(verbose){
      cat("  DBI API version: ", dbGetDBIVersion(), "\n")

##  cat("  PostgreSQL client version: ", info$clientVersion, "\n")  Feature absent

   }
   cat("  Open connections:", info$"num_con", "\n")
   if(verbose && !is.null(info$connectionIds)){
      for(i in seq(along = info$connectionIds)){
         cat("   ", i, " ")
         print(info$connectionIds[[i]])
      }
   }
   invisible(NULL)
}

"postgresqlDriverInfo" <-
function(obj, what="", ...)
{
   if(!isIdCurrent(obj))
      stop(paste("expired", class(obj)))
   drvId <- as(obj, "integer")
   info <- .Call("RS_PostgreSQL_managerInfo", drvId, PACKAGE = .PostgreSQLPkgName)
   ## replace drv/connection id w. actual drv/connection objects
   conObjs <- vector("list", length = info$"num_con")
   ids <- info$connectionIds
   for(i in seq(along = ids))
      conObjs[[i]] <- new("PostgreSQLConnection", Id = c(drvId, ids[i]))
   info$connectionIds <- conObjs
   info$managerId <- new("PostgreSQLDriver", Id = drvId)
   if(!missing(what))
      info[what]
   else
      info
}

"postgresqlNewConnection" <-
## note that dbname may be a database name, an empty string "", or NULL.
## The distinction between "" and NULL is that "" is interpreted by
## the PostgreSQL API as the default database (PostgreSQL config specific)
## while NULL means "no database".
function(drv, user="",
   password="",  host="",dbname = "",
    port = "", tty ="",options="" )
{
   if(!isIdCurrent(drv))
      stop("expired manager")
   con.params <- as.character(c(user, password, host,
                                dbname, port,
                                tty,options))

   drvId <- as(drv, "integer")
   conId <- .Call("RS_PostgreSQL_newConnection", drvId, con.params,PACKAGE = .PostgreSQLPkgName)
   new("PostgreSQLConnection", Id = conId)
}

"postgresqlCloneConnection" <-
function(con, ...)
{
   if(!isIdCurrent(con))
      stop(paste("expired", class(con)))
   conId <- as(con, "integer")
   newId <- .Call("RS_PostgreSQL_cloneConnection", conId, PACKAGE = .PostgreSQLPkgName)
   new("PostgreSQLConnection", Id = newId)
}

"postgresqlDescribeConnection" <-
function(obj, verbose = FALSE, ...)
{
   info <- dbGetInfo(obj)
   print(obj)
   cat("  User:", info$user, "\n")
   cat("  Host:", info$host, "\n")
   cat("  Dbname:", info$dbname, "\n")

  ## cat("  Connection type:", info$conType, "\n")     function absent

   if(verbose){
      cat("  PostgreSQL server version: ", info$serverVersion, "\n")


##     cat("  PostgreSQL client version: ",
##         dbGetInfo(as(obj, "PostgreSQLDriver"), what="clientVersion")[[1]], "\n")           feature absent


      cat("  PostgreSQL protocol version: ", info$protocolVersion, "\n")
      cat("  PostgreSQL server thread id: ", info$threadId, "\n")
   }
   if(length(info$rsId)>0){
      for(i in seq(along = info$rsId)){
         cat("   ", i, " ")
         print(info$rsId[[i]])
      }
   } else
      cat("  No resultSet available\n")
   invisible(NULL)
}

"postgresqlCloseConnection" <-
function(con, ...)
{
   if(!isIdCurrent(con))
      return(TRUE)
   rs <- dbListResults(con)
   if(length(rs)>0){
      if(dbHasCompleted(rs[[1]]))
         dbClearResult(rs[[1]])
      else
         stop("connection has pending rows (close open results set first)")
   }
   conId <- as(con, "integer")
   .Call("RS_PostgreSQL_closeConnection", conId, PACKAGE = .PostgreSQLPkgName)
}

"postgresqlConnectionInfo" <-
function(obj, what="", ...)
{
   if(!isIdCurrent(obj))
      stop(paste("expired", class(obj), deparse(substitute(obj))))
   id <- as(obj, "integer")
   info <- .Call("RS_PostgreSQL_connectionInfo", id, PACKAGE = .PostgreSQLPkgName)
   rsId <- vector("list", length = length(info$rsId))
   for(i in seq(along = info$rsId))
       rsId[[i]] <- new("PostgreSQLResult", Id = c(id, info$rsId[i]))
   info$rsId <- rsId
   if(!missing(what))
      info[what]
   else
      info
}

"postgresqlExecStatement" <-
function(con, statement)
## submits the sql statement to PostgreSQL and creates a
## dbResult object if the SQL operation does not produce
## output, otherwise it produces a resultSet that can
## be used for fetching rows.
{
   if(!isIdCurrent(con))
      stop(paste("expired", class(con)))
   conId <- as(con, "integer")
   statement <- as(statement, "character")
   rsId <- .Call("RS_PostgreSQL_exec", conId, statement, PACKAGE = .PostgreSQLPkgName)
   new("PostgreSQLResult", Id = rsId)
}

## helper function: it exec's *and* retrieves a statement. It should
## be named somehting else.
"postgresqlQuickSQL" <-
function(con, statement)
{
   if(!isIdCurrent(con))
      stop(paste("expired", class(con)))
   nr <- length(dbListResults(con))
   if(nr>0){                     ## are there resultSets pending on con?
      new.con <- dbConnect(con)   ## yep, create a clone connection
      on.exit(dbDisconnect(new.con))
      rs <- dbSendQuery(new.con, statement)
   } else rs <- dbSendQuery(con, statement)
   if(dbHasCompleted(rs)){
      dbClearResult(rs)            ## no records to fetch, we're done
      invisible()
      return(NULL)
   }
   res <- fetch(rs, n = -1)
   if(dbHasCompleted(rs))
      dbClearResult(rs)
   else
      warning("pending rows")
   res
}

"postgresqlDescribeFields" <-
function(res, ...)
{
   flds <- dbGetInfo(res, "fieldDescription")[[1]][[1]]
   if(!is.null(flds)){
      flds$Sclass <- .Call("RS_DBI_SclassNames", flds$Sclass,
                        PACKAGE = .PostgreSQLPkgName)
      flds$type <- .Call("RS_PostgreSQL_typeNames", as.integer(flds$type),
                        PACKAGE = .PostgreSQLPkgName)
      ## no factors
      structure(flds, row.names = paste(seq(along=flds$type)),
                            class = "data.frame")
   }
   else data.frame(flds)
}

"postgresqlDBApply" <-
function(res, INDEX, FUN = stop("must specify FUN"),
         begin = NULL,
         group.begin =  NULL,
         new.record = NULL,
         end = NULL,
         batchSize = 100, maxBatch = 1e6,
         ..., simplify = TRUE)
## (Experimental)
## This function is meant to handle somewhat gracefully(?) large amounts
## of data from the DBMS by bringing into R manageable chunks (about
## batchSize records at a time, but not more than maxBatch); the idea
## is that the data from individual groups can be handled by R, but
## not all the groups at the same time.
##
## dbApply apply functions to groups of rows coming from a remote
## database resultSet upon the following fetching events:
##   begin         (prior to fetching the first record)
##   group.begin   (the record just fetched begins a new group)
##   new_record    (a new record just fetched)
##   group.end     (the record just fetched ends the current group)
##   end           (the record just fetched is the very last record)
##
## The "begin", "begin.group", etc., specify R functions to be
## invoked upon the corresponding events.  (For compatibility
## with other apply functions the arg FUN is used to specify the
## most common case where we only specify the "group.end" event.)
##
## The following describes the exact order and form of invocation for the
## various callbacks in the underlying  C code.  All callback function
## (except FUN) are optional.
##  begin()
##    group.begin(group.name)
##    new.record(df.record)
##    FUN(df.group, group.name)   (aka group.end)
##  end()
##
## TODO: (1) add argument output=F/T to suppress the creation of
##           an expensive(?) output list.
##       (2) allow INDEX to be a list as in tapply()
##       (3) should we implement a simplify argument, as in sapply()?
##       (4) should report (instead of just warning) when we're forced
##           to handle partial groups (groups larger than maxBatch).
##       (5) extend to the case where even individual groups are too
##           big for R (as in incrementatl quantiles).
##       (6) Highly R-dependent, not sure yet how to port it to S-plus.
{
   if(dbHasCompleted(res))
      stop("result set has completed")
   if(is.character(INDEX)){
      flds <- tolower(as.character(dbColumnInfo(res)$name))
      INDEX <- match(tolower(INDEX[1]), flds, 0)
   }
   if(INDEX<1)
      stop(paste("INDEX field", INDEX, "not in result set"))

   "null.or.fun" <- function(fun) # get fun obj, but a NULL is ok
   {
      if(is.null(fun))
         fun
      else
         match.fun(fun)
   }
   begin <- null.or.fun(begin)
   group.begin <- null.or.fun(group.begin)
   group.end <- null.or.fun(FUN)     ## probably this is the most important
   end <- null.or.fun(end)
   new.record <- null.or.fun(new.record)
   rsId <- as(res, "integer")
   con <- as(res, "PostgreSQLConnection")
   on.exit({
      rc <- dbGetException(con)
      if(!is.null(rc$errorNum) && rc$errorNum!=0)
         cat("dbApply aborted with PostgreSQL error ", rc$errorNum,
             " (", rc$errorMsg, ")\n", sep = "")

      })
   ## BEGIN event handler (re-entrant, only prior to reading first row)
   if(!is.null(begin) && dbGetRowCount(res)==0)
      begin()
   rho <- environment()
   funs <- list(begin = begin, end = end,
                group.begin = group.begin,
                group.end = group.end, new.record = new.record)
   out <- .Call("RS_PostgreSQL_dbApply",
	        rs = rsId,
		INDEX = as.integer(INDEX-1),
		funs, rho, as.integer(batchSize), as.integer(maxBatch),
                PACKAGE = .PostgreSQLPkgName)
   if(!is.null(end) && dbHasCompleted(res))
      end()
   out
}

"postgresqlFetch" <-
function(res, n=0, ...)
## Fetch at most n records from the opened resultSet (n = -1 means
## all records, n=0 means extract as many as "default_fetch_rec",
## as defined by PostgreSQLDriver (see describe(drv, T)).
## The returned object is a data.frame.
## Note: The method dbHasCompleted() on the resultSet tells you whether
## or not there are pending records to be fetched.
##
## TODO: Make sure we don't exhaust all the memory, or generate
## an object whose size exceeds option("object.size").  Also,
## are we sure we want to return a data.frame?
{
   n <- as(n, "integer")
   rsId <- as(res, "integer")
   rel <- .Call("RS_PostgreSQL_fetch", rsId, nrec = n, PACKAGE = .PostgreSQLPkgName)
   if(length(rel)==0 || length(rel[[1]])==0)
      return(NULL)
   ## create running row index as of previous fetch (if any)
   cnt <- dbGetRowCount(res)
   nrec <- length(rel[[1]])
   indx <- seq(from = cnt - nrec + 1, length = nrec)
   attr(rel, "row.names") <- as.character(indx)
   if(usingR())
      class(rel) <- "data.frame"
   else
      oldClass(rel) <- "data.frame"
   rel
}

## Note that originally we had only resultSet both for SELECTs
## and INSERTS, ...  Later on we created a base class dbResult
## for non-Select SQL and a derived class resultSet for SELECTS.

"postgresqlResultInfo" <-
function(obj, what = "", ...)
{
   if(!isIdCurrent(obj))
      stop(paste("expired", class(obj), deparse(substitute(obj))))
   id <- as(obj, "integer")
   info <- .Call("RS_PostgreSQL_resultSetInfo", id, PACKAGE = .PostgreSQLPkgName)
   if(!missing(what))
      info[what]
   else
      info
}

"postgresqlDescribeResult" <-
function(obj, verbose = FALSE, ...)
{

   if(!isIdCurrent(obj)){
      print(obj)
      invisible(return(NULL))
   }
   print(obj)
   cat("  Statement:", dbGetStatement(obj), "\n")
   cat("  Has completed?", if(dbHasCompleted(obj)) "yes" else "no", "\n")
   cat("  Affected rows:", dbGetRowsAffected(obj), "\n")
   cat("  Rows fetched:", dbGetRowCount(obj), "\n")
   flds <- dbColumnInfo(obj)
   if(verbose && !is.null(flds)){
      cat("  Fields:\n")
      out <- print(dbColumnInfo(obj))
   }
   invisible(NULL)
}

"postgresqlCloseResult" <-
function(res, ...)
{
   if(!isIdCurrent(res))
      return(TRUE)
   rsId <- as(res, "integer")
   .Call("RS_PostgreSQL_closeResultSet", rsId, PACKAGE = .PostgreSQLPkgName)
}

"postgresqlReadTable" <-
function(con, name, row.names = "row_names", check.names = TRUE, ...)
## Use NULL, "", or 0 as row.names to prevent using any field as row.names.
{
   out <- dbGetQuery(con, paste("SELECT * from", name))
   if(check.names)
       names(out) <- make.names(names(out), unique = TRUE)
   ## should we set the row.names of the output data.frame?
   nms <- names(out)
   j <- switch(mode(row.names),
           "character" = if(row.names=="") 0 else
               match(tolower(row.names), tolower(nms),
                     nomatch = if(missing(row.names)) 0 else -1),
           "numeric" = row.names,
           "NULL" = 0,
           0)
   if(j==0)
      return(out)
   if(j<0 || j>ncol(out)){
      warning("row.names not set on output data.frame (non-existing field)")
      return(out)
   }
   rnms <- as.character(out[,j])
   if(all(!duplicated(rnms))){
      out <- out[,-j, drop = FALSE]
      row.names(out) <- rnms
   } else warning("row.names not set on output (duplicate elements in field)")
   out
}

"postgresqlImportFile" <-
function(con, name, value, field.types = NULL, overwrite = FALSE,
  append = FALSE, header, row.names, nrows = 50, sep = ",",
  eol="\n", skip = 0, quote = '"', ...)
{
  if(overwrite && append)
    stop("overwrite and append cannot both be TRUE")

  ## Do we need to clone the connection (ie., if it is in use)?
  if(length(dbListResults(con))!=0){
    new.con <- dbConnect(con)              ## there's pending work, so clone
    on.exit(dbDisconnect(new.con))
  }
  else
    new.con <- con

  if(dbExistsTable(con,name)){
    if(overwrite){
      if(!dbRemoveTable(con, name)){
        warning(paste("table", name, "couldn't be overwritten"))
        return(FALSE)
      }
    }
    else if(!append){
      warning(paste("table", name, "exists in database: aborting dbWriteTable"))
      return(FALSE)
    }
  }

  ## compute full path name (have R expand ~, etc)
  fn <- file.path(dirname(value), basename(value))
  if(missing(header) || missing(row.names)){
    f <- file(fn, open="r")
    if(skip>0)
      readLines(f, n=skip)
    flds <- count.fields(textConnection(readLines(f, n=2)), sep)
    close(f)
    nf <- length(unique(flds))
  }
  if(missing(header)){
    header <- nf==2
  }
  if(missing(row.names)){
    if(header)
      row.names <- if(nf==2) TRUE else FALSE
    else
      row.names <- FALSE
  }

  new.table <- !dbExistsTable(con, name)
  if(new.table){
    ## need to init table, say, with the first nrows lines
    d <- read.table(fn, sep=sep, header=header, skip=skip, nrows=nrows, ...)
    sql <-
      dbBuildTableDefinition(new.con, name, obj=d, field.types = field.types,
        row.names = row.names)
    rs <- try(dbSendQuery(new.con, sql))
    if(inherits(rs, ErrorClass)){
      warning("could not create table: aborting sqliteImportFile")
      return(FALSE)
    }
    else
      dbClearResult(rs)
  }
  else if(!append){
    warning(sprintf("table %s already exists -- use append=TRUE?", name))
  }

  fmt <-
     paste("LOAD DATA LOCAL INFILE '%s' INTO TABLE  %s ",
           "FIELDS TERMINATED BY '%s' ",
           if(!is.null(quote)) "OPTIONALLY ENCLOSED BY '%s' " else "",
           "LINES TERMINATED BY '%s' ",
           "IGNORE %d LINES ", sep="")
  if(is.null(quote))
     sql <- sprintf(fmt, fn, name, sep, eol, skip + as.integer(header))
  else
     sql <- sprintf(fmt, fn, name, sep, quote, eol, skip + as.integer(header))

  rs <- try(dbSendQuery(new.con, sql))
  if(inherits(rs, ErrorClass)){
     warning("could not load data into table")
     return(FALSE)
  }
  dbClearResult(rs)
  TRUE
}

"postgresqlWriteTable" <-
function(con, name, value, field.types, row.names = TRUE,
   overwrite = FALSE, append = FALSE, ..., allow.keywords = FALSE)
## Create table "name" (must be an SQL identifier) and populate
## it with the values of the data.frame "value"
## TODO: This function should execute its sql as a single transaction,
##       and allow converter functions.
## TODO: In the unlikely event that value has a field called "row_names"
##       we could inadvertently overwrite it (here the user should set
##       row.names=F)  I'm (very) reluctantly adding the code re: row.names,
##       because I'm not 100% comfortable using data.frames as the basic
##       data for relations.
{
   if(overwrite && append)
      stop("overwrite and append cannot both be TRUE")
   if(!is.data.frame(value))
      value <- as.data.frame(value)
   if(row.names){
      value <- cbind(row.names(value), value)  ## can't use row.names= here
      names(value)[1] <- "row.names"
   }
   if(missing(field.types) || is.null(field.types)){
      ## the following mapping should be coming from some kind of table
      ## also, need to use converter functions (for dates, etc.)
      field.types <- sapply(value, dbDataType, dbObj = con)
   }

   ## Do we need to coerce any field prior to write it out?
   ## TODO: PostgreSQL has boolean data type.
   for(i in seq(along = value)){
      if(is(value[[i]], "logical"))
         value[[i]] <- as(value[[i]], "integer")
   }
   i <- match("row.names", names(field.types), nomatch=0)
   if(i>0) ## did we add a row.names value?  If so, it's a text field.
      field.types[i] <- dbDataType(dbObj=con, field.types$row.names)
   names(field.types) <- make.db.names(con, names(field.types),
                             allow.keywords = allow.keywords)
   ## Do we need to clone the connection (ie., if it is in use)?
   if(length(dbListResults(con))!=0){
      new.con <- dbConnect(con)              ## there's pending work, so clone
      on.exit(dbDisconnect(new.con))
   }
   else {
      new.con <- con
   }

   if(dbExistsTable(con,name)){
      if(overwrite){
         if(!dbRemoveTable(con, name)){
         warning(paste("table", name, "couldn't be overwritten"))
         return(FALSE)
         }
      }
      else if(!append){
         warning(paste("table",name,"exists in database: aborting assignTable"))
         return(FALSE)
      }
   }
   if(!dbExistsTable(con,name)){      ## need to re-test table for existance
      ## need to create a new (empty) table
      sql1 <- paste("create table ", name, "\n(\n\t", sep="")
      sql2 <- paste(paste(names(field.types), field.types), collapse=",\n\t",
                          sep="")
      sql3 <- "\n)\n"
      sql <- paste(sql1, sql2, sql3, sep="")
      rs <- try(dbSendQuery(new.con, sql))
      if(inherits(rs, ErrorClass)){
         warning("could not create table: aborting assignTable")
         return(FALSE)
      }
      else
         dbClearResult(rs)
   }

   ## TODO: here, we should query the PostgreSQL to find out if it supports
   ## LOAD DATA thru pipes; if so, should open the pipe instead of a file.

   fn <- tempfile("rsdbi")
   fn <- gsub("\\\\", "/", fn)  # Since PostgreSQL on Windows wants \ double (BDR)
   safe.write(value, file = fn)
   on.exit(unlink(fn), add = TRUE)
   sql4 <- paste("LOAD DATA LOCAL INFILE '", fn, "'",
                  " INTO TABLE ", name,
                  " LINES TERMINATED BY '\n' ", sep="")
   rs <- try(dbSendQuery(new.con, sql4))
   if(inherits(rs, ErrorClass)){
      warning("could not load data into table")
      return(FALSE)
   }
   else
      dbClearResult(rs)
   TRUE
}

"dbBuildTableDefinition" <-
function(dbObj, name, obj, field.types = NULL, row.names = TRUE, ...)
{
  if(!is.data.frame(obj))
    obj <- as.data.frame(obj)
  if(!is.null(row.names) && row.names){
    obj  <- cbind(row.names(obj), obj)  ## can't use row.names= here
    names(obj)[1] <- "row.names"
  }
  if(is.null(field.types)){
    ## the following mapping should be coming from some kind of table
    ## also, need to use converter functions (for dates, etc.)
    field.types <- sapply(obj, dbDataType, dbObj = dbObj)
  }
  i <- match("row.names", names(field.types), nomatch=0)
  if(i>0) ## did we add a row.names value?  If so, it's a text field.
    field.types[i] <- dbDataType(dbObj, field.types$row.names)
  names(field.types) <-
    make.db.names(dbObj, names(field.types), allow.keywords = FALSE)

  ## need to create a new (empty) table
  flds <- paste(names(field.types), field.types)
  paste("CREATE TABLE", name, "\n(", paste(flds, collapse=",\n\t"), "\n)")
}

## the following is almost exactly from the ROracle driver
"safe.write" <-
function(value, file, batch, ...)
## safe.write makes sure write.table doesn't exceed available memory by batching
## at most batch rows (but it is still slowww)
{
   N <- nrow(value)
   if(N<1){
      warning("no rows in data.frame")
      return(NULL)
   }
   digits <- options(digits = 17)
   on.exit(options(digits))
   if(missing(batch) || is.null(batch))
      batch <- 10000
   else if(batch<=0)
      batch <- N
   from <- 1
   to <- min(batch, N)
   while(from<=N){
      if(usingR())
         write.table(value[from:to,, drop=FALSE], file = file, append = TRUE,
               quote = FALSE, sep="\t", na = .PostgreSQL.NA.string,
               row.names=FALSE, col.names=FALSE, eol = '\n', ...)
      else
         write.table(value[from:to,, drop=FALSE], file = file, append = TRUE,
               #quote.string = FALSE,
               sep="\t", na = .PostgreSQL.NA.string,
               #dimnames.write=FALSE,
               #end.of.row = '\n',
               ...)
      from <- to+1
      to <- min(to+batch, N)
   }
   invisible(NULL)
}

"postgresqlDataType" <-
function(obj, ...)
## find a suitable SQL data type for the R/S object obj
## TODO: Lots and lots!! (this is a very rough first draft)
## need to register converters, abstract out PostgreSQL and generalize
## to Oracle, Informix, etc.  Perhaps this should be table-driven.
## NOTE: PostgreSQL data types differ from the SQL92 (e.g., varchar truncate
## trailing spaces).
{
   rs.class <- data.class(obj)    ## this differs in R 1.4 from older vers
   rs.mode <- storage.mode(obj)
   if(rs.class=="numeric" || rs.class == "integer"){
      sql.type <- if(rs.mode=="integer") "bigint" else  "float8" 
   }
   else {
      sql.type <- switch(rs.class,
                     character = "text",
                     logical = "boolean", 
                     factor = "text",      
                     ordered = "text",
                     "text")
   }
   sql.type
}

## the following reserved words were taken from ["RESERVED" of postgres colomn in ] Table C.1 in Appendix C
## of the PostgreSQL Manual 8.3.1.

".PostgreSQLKeywords" <-
c( "ALL", "ANALYSE", "ANALYZE", "AND", "ANY", "ARRAY", "AS", "ASC", "ASYMMETRIC", "AUTHORIZATION", "BETWEEN", "BINARY", "BOTH", "CASE", "CAST", "CHECK", "COLLATE", "COLUMN", "CONSTRAINT", "CREATE", "CROSS", "CURRENT_DATE", "CURRENT_ROLE", "CURRENT_TIME", "CURRENT_TIMESTAMP", "CURRENT_USER", "DEFAULT", "DEFERRABLE", "DESC", "DISTINCT", "DO", "ELSE", "END", "EXCEPT", "FALSE", "FOR", "FOREIGN", "FREEZE", "FROM", "FULL", "GRANT", "GROUP", "HAVING", "ILIKE", "IN", "INITIALLY", "INNER","INTERSECT", "INTO", "IS", "ISNULL", "JOIN", "LEADING", "LEFT", "LIKE", "LIMIT", "LOCALTIME", "LOCALTIMESTAMP", "NATURAL", "NEW", "NOT", "NULL", "OFF", "OFFSET", "OLD", "ON", "ONLY", "OR", "ORDER", "OUTER", "OVERLAPS", "PLACING", "PRIMARY", "REFERENCES", "RESERVED", "SELECT", "SESSION_USER", "SIMILAR", "SOME", "SYMMETRIC", "TABLE", "THEN", "TO", "TRAILING", "TRUE", "UNION", "UNIQUE", "USER", "USING", "VERBOSE", "WHEN", "WHERE", "WITH"
  )

