
# code to allow queries at the manager node of the form, e.g. d[,c(2,4)]
# for a distributed data frame d; needs a fake object of the same name,
# e.g. d, at the manager node, of class 'ddf'; one can construct such an
# object via makeddf()

# convert vector, e.g. c(1,3), to string form
numstr <- function(j){
  if (length(j) == 1){
    strr <- as.character(j)
  } else {
    ### clusterEvalQ(cls, dotoexec())
    strr <- paste("c(", paste(j, sep="", collapse = ","), ")")
  }
}

# determine where virtual row i is in the distributed data frame
# objname; 2-tuple is returned, consisting of the row number within
# worker, and the worker number 
findrow <- function(cls, i, objname){
  # get number of rows per worker
  cmd <- paste0("dim(", objname, ")[1]")
  # nr <- distribgetrows2(cls, cmd) #DEBUG
  nr <- doclscmd(cls, cmd) 
  last <- cumsum(nr)
  frst <- c(0, last[1:length(last)-1]) + 1
  here <- i >= frst & i <= last
  iwrk <- 1:length(last)
  df <- data.frame(iwrk, frst, last, here, stringsAsFactors = FALSE)
  df$irow <- 1 + i - df$frst
  # calculate row to request and worker on which it exists
  irow <- df$irow[df$here == TRUE]
  iwrk <- df$iwrk[df$here == TRUE]
  c(irow, iwrk)
}

# make object of class 'ddf', representing the distributed data frame
# named 'dname' on cluster 'cls'
makeddf <- function(dname,cls) {
   tmp <- 0
   class(tmp) <- 'ddf'
   attr(tmp,'dname') <- dname
   attr(tmp,'cluster') <- cls
   eval(parse(text =
      paste0('assign("',dname,'",tmp,envir=.GlobalEnv)')))
}

"[.ddf" <- function(obj, i=NULL, j=NULL){
  objname <- deparse(substitute(obj))
  cls <- attr(obj,'cluster')
  # e.g. user called d[,]
  if (is.null(i) & is.null(j)){
    dr <- distribcat(cls, objname)
  }
  else if (is.null(i)){
    if (length(j) == 1){
      #cmd  <- paste0(objname, "[,", j, "]")
      #dr <- distribgetcols(cls, cmd)
      # cmd  <- paste0(objname, "[,c(", j, ",", j, ")]")
      # dr <- distribgetrows2(cls, cmd)[,1]
      cmd  <- paste0(objname, "[,", j, ",drop=FALSE]")
      dr <- distribgetrows(cls, cmd)
    } else {
      cmd  <- paste0(objname, "[,", numstr(j), "]")
      # dr <- distribgetrows2(cls, cmd)
      dr <- distribgetrows(cls, cmd)
    }
  }
  else if (is.null(j)){
    if (length(i) == 1){ # could be done in else loop
      irow <- findrow(cls, i, objname)
      cmd <- paste0(objname, "[", irow[1], ",]")
      # dr <- distribgetrows2(cls, cmd)[irow[2],]
      dr <- distribgetrows(cls, cmd,irow[2])
    } else {
      dr <- NULL
      for (k in 1:length(i)){
        irow <- findrow(cls, i[k], objname)
        cmd <- paste0(objname, "[", irow[1], ",]")
        # dr1 <- distribgetrows2(cls, cmd)[irow[2],]
        dr1 <- distribgetrows(cls, cmd,irow[2])
        dr <- rbind(dr, dr1)
      }
    }
  }
  else{
    if (length(i) == 1){
      irow <- findrow(cls, i, objname)
      cmd <- paste0(objname, "[", irow[1], ",", numstr(j), "]")
      # dr <- distribgetrows2(cls, cmd)[irow[2]]
      dr <- distribgetrows(cls, cmd,irow[2])
    } else {
      dr <- NULL
      for (k in 1:length(i)){
        irow <- findrow(cls, i[k], objname)
        cmd <- paste0(objname, "[", irow[1], ",", numstr(j), "]")
        # dr1 <- distribgetrows(cls, cmd,irow[2])
        dr1 <- distribgetrows(cls, cmd,irow[2])
        dr <- rbind(dr, dr1)
      }
    }
  }
  dr
}

# test

### nrows <- 9
### ncols <- 4 # cannot be changed
### cl <- makeCluster(4) # from 'parallel' library
### setclsinfo(cl) # from 'partools'
### 
### col1 <- seq(11, nrows*10 + 1, by = 10)
### col2 <- seq(12, nrows*10 + 2, by = 10)
### col3 <- seq(13, nrows*10 + 3, by = 10)
### col4 <- seq(14, nrows*10 + 4, by = 10)
### d <- data.frame(col1,col2,col3,col4)
### rownames(d) <- c(nrows:1) # should have no effect
### 
### # TO WORK AS EXPECTED, THE FOLLOWING ARE REQUIRED:
### # 1) cls must be defined
### # 2) the distributed variable must have a local definition
### # 3) the local definition must have ddf as its first class
### # There is a problem with single variables such as d[2,3] returning any of the following three:
### # 1) [1] 23
### # 2) init
### #      23
### # 3) <0 x 0 matrix>
### # Warning message:
### # In f(init, x[[i]]) :
### #   number of columns of result is not a multiple of vector length (arg 2)
### 
### distribsplit(cl, "d", scramble = FALSE)
### # print(clusterEvalQ(cl, { print(d) }))
### clusterEvalQ(cl, {d})
### dd <- d
### rm(d)
### d <- 123
### class(d) <- append("ddf", class(d))
### attr(d,'cluster') <- cl
### attr(d,'dname') <- 'd'
### print("********** d **********")
### d
### print("********** d[,] **********")
### print(d[,])
### print("********** d[i,] **********")
### for (i in 1:nrows){
###   print(d[i,]) 
### }
### print("********** d[,j] **********")
### for (j in 1:4){
###   print(d[,j]) 
### }
### for (i in 1:nrows){
###   print(paste0("********** d[",i,",] **********"))
###   for (j in 1:4){
###     #print(paste0("********** d[",i,",",j,"] **********"))
###     print(d[i,j])
###   }
### }
### print(paste0("********** d[2:4,] **********"))
### print(d[2:4,])
### print(paste0("********** d[,2:4] **********"))
### print(d[,2:4])
### print(paste0("********** d[5:8,1:3] **********"))
### print(d[5:8,1:3])
### print(paste0("********** d[c(2,4),] **********"))
### print(d[c(2,4),])
### print(paste0("********** d[,c(2,4)] **********"))
### print(d[,c(2,4)])
### print(paste0("********** d[c(1,2,4,8),2:3] **********"))
### print(d[c(1,2,4,8),2:3])
### 
### readline("Press enter to stopCluster, escape to exit")
### stopCluster(cl)
### 
