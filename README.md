# ExtractEMEPModelDailyData
This script extracts daily values from [EMEP MSC-W model](https://acp.copernicus.org/articles/12/7825/2012/acp-12-7825-2012.html) results at user-specified point coordinates. This script has been tested for data that can be downloaded by clicking on "2000-2016 (Type2)" at [this website](https://www.emep.int/mscw/mscw_ydata.html) and then selecting files with "day" in the file name. As of 2021-06-27, these are 17 NetCDF-files (one per year in 2000-2016), each approx. 23 GB in size. This script does not change variable names or units. For an explanation of variable names and units see section "Compounds in NetCDF files" at [this website](https://www.emep.int/mscw/mscw_ydata.html).


## How to use
 - Download all files from this repository (e.g. via Code -> Download ZIP above).
 - Create a working directory and a subfolder "Input".
 - Copy the file "ExtractEMEPModelDailyData.R" into the working directory.
 - Copy the file "PointCoords.csv" into the "Input" folder.
 - Install all libraries listed in the beginning of "ExtractEMEPModelDailyData.R"
 - Adjust the variable "WorkDir" in the beginning of "ExtractEMEPModelDailyData.R"
 - Download EMEP data (link see above). Store these files (.nc files of approx. 23 GB size) in the "Input" folder.
 - Run the "ExtractEMEPModelDailyData.R" script. Note that execution can take >30 min per .nc-file.
 - Results will be stored in a subfolder named "Output" in the working directory.

## Validation
The "ExtractEMEPModelDailyData.R" script has been validated against data extracted with the Linux tool [ncview](http://manpages.ubuntu.com/manpages/impish/man1/ncview.1.html) based on
 - one randomly choosen location for variable SURF_ugN_NOX in file EMEP01_L20EC_rv4_33_day.2005met_2005emis_rep2019.nc (2005 data)
 - one randomly choosen location for variable SURF_ug_NH3 in file EMEP01_L20EC_rv4_33_day.2005met_2005emis_rep2019.nc (2005 data)
 - one randomly choosen location for variable SURF_ug_NO in file EMEP01_L20EC_rv4_33_day.2014met_2014emis_rep2019.nc (2014 data)
 - one randomly choosen location for variable SURF_ug_PM10 in file EMEP01_L20EC_rv4_33_day.2014met_2014emis_rep2019.nc (2014 data)

This resulted in 1460 single (daily) values from both "ExtractEMEPModelDailyData.R" and "ncview" with no differences between the two approaches.

Please report any bugs / unexpected behaviour.
