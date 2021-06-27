#Extract daily EMEP grid data from files downloaded from
#https://www.emep.int/mscw/mscw_ydata.html


#init-----
rm(list=ls())
graphics.off()
options(
  warnPartialMatchDollar = T,
  stringsAsFactors = F
)
library(data.table) #for fast I/O
library(tidyverse) #for data handling
library(ncdf4) #for NetCDF handling
library(LaF) #for reading large CSV files
library(geosphere) #for calculating spatial distances
library(lubridate) #for date-time handling  

#Set working directory
WorkDir <- "/path/to/your/workdir"

#Define the number of decimal places for the extracted values
#(NetCDF files provide values with lots of decimal places)
ValueDecimalPrecision <- 4



#  --- No changes required below this line ---


#Prepare I/O-----
InDir <- file.path(WorkDir,"Input")
OutDir <- file.path(WorkDir,"Output")
dir.create(OutDir,showWarnings = F)
OutputFile <- file.path(OutDir,"EMEP_data_daily_extracted.csv")


#Prepare coords for points to extract----
StartTime <- Sys.time()
PointCoordsPath <- file.path(InDir,"PointCoords.csv")
if ( !file.exists(PointCoordsPath) ) {
  stop(paste("File not found:", PointCoordsPath))
}
PointCoords <- read.table(
  file = PointCoordsPath,
  header = T,
  sep = ";",
  dec = ".",
  stringsAsFactors = F
) %>%
  select(LocationLabel,Lat_EPSG4326,Lon_EPSG4326) %>%
  mutate(
    LocationLabel = as.character(LocationLabel)
  )
nPointCoords <- nrow(PointCoords)
if ( nPointCoords == 0 ) {
  stop("No rows found in file PointCoords.csv.")
}
if ( any( is.na(PointCoords) ) ) {
  stop("PointCoords.csv must not contain NA.")
}



#List all data files-----
InputFiles <- list.files(
  path = InDir,
  pattern = ".nc",
  recursive = T,
  full.names = T
)
if ( length(InputFiles) == 0 ) {
  stop(paste("No .nc files found in folder",InDir))
}


#Identify grid cells for desired coords---------------------------
#Load the first NetCDF file and for each desired output location
#in PointCoords identify the corresponding grid cell where to extract
#data. This mapping is then used for all input files.
CurrentFile_NC <- InputFiles[1]
NetCDFFileHandle <- nc_open(CurrentFile_NC)
#Extract dimensions from first file
#Variable names
File1_Vars <- names(NetCDFFileHandle$var)
#"degrees_east"
File1_Lon <- NetCDFFileHandle$var[[1]]$dim[[1]]$vals
#"degrees_north"
File1_Lat <- NetCDFFileHandle$var[[1]]$dim[[2]]$vals
nc_close(NetCDFFileHandle)


#Create all combinations of X and Y coords
AllCoords <- as.data.frame(expand.grid(
  Lon = File1_Lon,
  Lat = File1_Lat
))
#For each desired location in PointCoords, identify the corresponding grid cell
PointCoords <- PointCoords %>%
  mutate(
    EMEPGridCellCoordinate_Lat = NA,
    EMEPGridCellCoordinate_Lon = NA,
    EMEPGridCellIndex_Lat = NA,
    EMEPGridCellIndex_Lon = NA
  )
for ( i in 1:nPointCoords ) {
  #For each point in PointCoords, find the grid cell which has the smallest distance
  #from its coordinates to the point.
  CurrentLon <- PointCoords$Lon_EPSG4326[i]
  CurrentLat <- PointCoords$Lat_EPSG4326[i]
  CurrentLabel <- PointCoords$LocationLabel[i]
  #Old calculation without using correct spatial distances
  #DistVec <- sqrt( (AllCoords$Lon - CurrentLon)^2 + (AllCoords$Lat - CurrentLat)^2 )
  #New calculation with geosphere::distm()
  DistVec <- as.vector(geosphere::distm(
    x = matrix(data = c(CurrentLon,CurrentLat), ncol = 2),
    y = as.matrix(AllCoords[,c("Lon","Lat")]),
    fun = distHaversine
  )) / 1000 #Distance in km
  idx_MinDist <-which( DistVec == min(DistVec) )
  if ( length(idx_MinDist) != 1 ) {
    stop(paste("Could not find a single unique EMEP grid cell for point labelled",CurrentLabel,"with coords",CurrentLat,CurrentLon))
  }
  PointCoords$EMEPGridCellCoordinate_Lon[i] <- AllCoords$Lon[idx_MinDist]
  PointCoords$EMEPGridCellCoordinate_Lat[i] <- AllCoords$Lat[idx_MinDist]
  PointCoords$EMEPGridCellIndex_Lon[i] <- which(File1_Lon == PointCoords$EMEPGridCellCoordinate_Lon[i])
  PointCoords$EMEPGridCellIndex_Lat[i] <- which(File1_Lat == PointCoords$EMEPGridCellCoordinate_Lat[i])
}

#_Save mapping of coords to grid cells------
write.table(
  x = PointCoords,
  file = file.path(OutDir,"PointCoordsWithGridCellInfo.csv"),
  sep = ";",
  row.names = F
)



#Extract data------
#_Loop over files-----
for ( iCurrentFile in 1:length(InputFiles) ) {
  print(paste("Working on file",iCurrentFile, "of",length(InputFiles)))
  CurrentFile_NC <- InputFiles[iCurrentFile]
  NetCDFFileHandle <- nc_open(CurrentFile_NC)
  
  #__Consistency check of variables names over files-----
  CurrentFile_Vars <- names(NetCDFFileHandle$var)
  if ( !all(CurrentFile_Vars == File1_Vars) ) {
    stop(paste("File",basename(CurrentFile_NC),"has different variables compared to first file",basename(InputFiles[1])))
  }
  
  #__Loop over variables-----
  ProgressBar <- txtProgressBar(min = 0, max = length(CurrentFile_Vars), style = 3)
  for ( iVar in 1:length(CurrentFile_Vars) ) {
    setTxtProgressBar(ProgressBar, iVar)
    
    CurrentVariable <- CurrentFile_Vars[iVar]
    
    #___Consistency check of coords-------
    #The mapping between coords and grid cell indices has been established with the first variable in file 1.
    #Make sure that all EMEP files and variables use the same grid in order to avoid extracted of data
    #at wrong locations.
    #"degrees_east"
    CurrentFileCurrentVar_Lon <- NetCDFFileHandle$var[[iVar]]$dim[[1]]$vals
    if ( !all(CurrentFileCurrentVar_Lon == File1_Lon) ) {
      stop(paste("File",basename(CurrentFile_NC),"variable",CurrentFile_Vars[iVar],"has different longitude values compared to first variable in first file",basename(InputFiles[1])))
    }
    #"degrees_north"
    CurrentFileCurrentVar_Lat <- NetCDFFileHandle$var[[iVar]]$dim[[2]]$vals
    if ( !all(CurrentFileCurrentVar_Lat == File1_Lat) ) {
      stop(paste("File",basename(CurrentFile_NC),"variable",CurrentFile_Vars[iVar],"has different latitude values compared to first variable in first file",basename(InputFiles[1])))
    }
    
    #___Get timestamps------
    #"days since 1900-1-1 0:0:0"
    CurrentTimeStamps <- NetCDFFileHandle$var[[iVar]]$dim[[3]]$vals
    #Convert to dates
    #Time zone of EMEP data does not matter, because resulting time is alway 18:00 on each day.
    #I.e. no matter what the time zone is, the day will stay the same.
    TimeStamp_Seconds <- as.numeric(CurrentTimeStamps) * 24 * 60 * 60
    Dates <- ymd_hms("1900-01-01 00:00:00", tz = "UTC") + seconds(TimeStamp_Seconds)
    Dates <- as.Date(Dates)

    #___Loop over locations-----
    OutputCurrentFileCurrentVar <- list()
    for ( iPointCoord in 1:nPointCoords ) {
      
      LocationLabel <- PointCoords$LocationLabel[iPointCoord]
      EMEPGridCellIndex_Lon <- PointCoords$EMEPGridCellIndex_Lon[iPointCoord]
      EMEPGridCellIndex_Lat <- PointCoords$EMEPGridCellIndex_Lat[iPointCoord]
    
      #Get values for current grid cell for all dates
      CurrentValues <- ncvar_get(
        nc = NetCDFFileHandle,
        varid = CurrentVariable,
        #Dimenions: lon, lat, day
        start = c(EMEPGridCellIndex_Lon,EMEPGridCellIndex_Lat,1),
        count = c(1,1,-1),
        verbose = F,
        raw_datavals = F
      )
      
      #Insert data into dataframe for current file's results
      tmp <- data.frame(
        LocationLabel = LocationLabel,
        TimeStamp = Dates,
        Variable = CurrentVariable,
        Value = round(CurrentValues,ValueDecimalPrecision)
      )
      OutputCurrentFileCurrentVar[[length(OutputCurrentFileCurrentVar)+1]] <- tmp
      
    } #end of loop over locations
    
    #__Write results for current file x variable-----
    #Convert the output list to a data frame and convert timestamp
    OutputCurrentFileCurrentVarDF <- bind_rows(OutputCurrentFileCurrentVar)
    fwrite(
      x = OutputCurrentFileCurrentVarDF,
      file = OutputFile,
      sep = ";",
      #Write header row only for the first var in first file.
      #Else, just append the data.
      append = ifelse(
        test = ((iCurrentFile == 1) & (iVar == 1)),
        yes = F,
        no = T
      )
    )

  } #end of loop over variables of current file
  
  #_Close file-----
  nc_close(NetCDFFileHandle)
  close(ProgressBar)
  
  
} #end of loop over files



#Split output into one file per LocationLabel----
print("Splitting data into one file per LocationLabel...")
SinglesFilePerLocationLabelDir <- file.path(OutDir,"SinglesFilePerLocationLabel")
dir.create(
  path = SinglesFilePerLocationLabelDir,
  showWarnings = F
)
#Use R package LaF to avoid memory problems with large files
DataModelForReadingLargeFile <- detect_dm_csv(
  filename = OutputFile,
  sep=";",
  header=TRUE,
  stringsAsFactors = F
)
AllData <- laf_open(DataModelForReadingLargeFile)
for ( CurrentLocationLabel in unique(AllData$LocationLabel[]) ) {
  #Use LaF library-style indexing [] to filter for current location
  Sub <- AllData[AllData$LocationLabel[] == CurrentLocationLabel,]
  #Save data for current location as csv
  fwrite(
    x = Sub,
    file = file.path(SinglesFilePerLocationLabelDir,paste0(CurrentLocationLabel,".csv")),
    sep = ";"
  )
  rm(Sub)
}




#Finish----
EndTime <- Sys.time()
TimeElapsed <- difftime(
  time1 = EndTime,
  time2 = StartTime,
  units = "hours"
)
TimeElapsed <- round(as.numeric(TimeElapsed),2)
AverageDurationPerFile = round(TimeElapsed / length(InputFiles),2)
  
print(paste("Start time:",StartTime))
print(paste("End time:",EndTime))
print(paste("Time elapsed:",TimeElapsed,"hours"))
print(paste("Average duration per file:",AverageDurationPerFile,"hours"))
print(paste("Number of files:",length(InputFiles)))
      
