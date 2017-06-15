#  Usage:
#   > source('createRFModel.R')
library( ANTsR )
library( randomForest )
options("width"=180)

stopQuietly <- function(...)
  {
  blankMsg <- sprintf( "\r%s\r", paste( rep(" ", getOption( "width" ) - 1L ), collapse = " ") );
  stop( simpleError( blankMsg ) );
  } # stopQuietly()

args <- commandArgs( trailingOnly = TRUE )
             
###############################################
#
# Selected parameters
#
###############################################

if( length( args ) == 0 )
  {
    #           1               2                                       3                             4    5     6     7    8    9          10      11      12
     args <- c("3","truthdatamatrix.csv","Processed/ProstateX-0203/ggg/ALL/SignificantFeatureImage.","1", "1","2000","500","3","1","ProstateX-0203","ggg","ALL")
  } else if( length( args ) < 2 ) {
  cat( "Usage: Rscript createRFModel.R dimension inputFileList outputModelPrefix ",
       "<numberOfThreads=4> <trainingPortion=1.0> <numberOfSamplesPerLabel=1000> ",
       "<numberOfTreesPerThread=1000> <numberOfUniqueLabels=NA>", sep = "" )
  stopQuietly()
  }

dimension       <- as.numeric( args[1] )
datamatrix      <- read.csv(   args[2] )
outputModelBase <- args[3]

numberOfThreads <- 1
if( length( args ) >= 4 )
  {
  numberOfThreads <- as.numeric( args[4] )
  }
trainingPortion <- 1.0
if( length( args ) >= 5 )
  {
  trainingPortion <- as.numeric( args[5] )
  }
numberOfSamplesPerLabel <- 1000
if( length( args ) >= 6 )
  {
  numberOfSamplesPerLabel <- as.numeric( args[6] )
  }
numberOfTreesPerThread <- 1000
if( length( args ) >= 7 )
  {
  numberOfTreesPerThread <- as.numeric( args[7] )
  }
numberOfUniqueLabels <- NA
if( length( args ) >= 8 )
  {
  numberOfUniqueLabels <- as.numeric( args[8] )
  }
Nmodels = 1
if( length( args ) >= 9 )
  {
  Nmodels <- as.numeric( args[9] )
  }

ptid = NA
if( length( args ) >= 10 )
  {
  ptid <-  as.character( args[10]  )
  }

ModelOutput = 'ggg'
LinearFamily = 'binomial'
RFModelType = "classification"
datamatrix$mrn = as.character(datamatrix$mrn )

modelData= subset(datamatrix,  mrn  != ptid  )
print(head(modelData,n=10))

if( length( args ) >= 11 )
  {
  ModelOutput <-  args[11] 
  }
FeatureSelection = 'WRST'
if( length( args ) >= 12 )
  {
  FeatureSelection <-  args[12] 
  }


modelData$ggg <- as.factor( modelData$ggg )

cat( "Model Setup: ", ModelOutput,LinearFamily,RFModelType,FeatureSelection," seconds.\n", sep = " " )

###############################################
#
# Get Subset by Patients
#
###############################################
uniquept = unique(modelData$mrn )
NUnique = length(uniquept)
Nsample = NUnique  

cat( "\nCreating the RF models each with ",Nsample ," patients. \n", sep = "" )
for (iii in 1:Nmodels ) # ignore Labels
{
   # get data subset
   #kfoldsubset = subset(modelData,  mrn %in% ptsubset  )
   kfoldsubset = modelData

   if (FeatureSelection == 'ALL' )
     { colsubset = c( ModelOutput , 'KTRANS.reslice','T2Axial.norm','ADC.reslice','T2Sag.norm','T2Axial.Entropy_4','T2Axial.HaralickCorrelation_4','BVAL.reslice') }
   if (FeatureSelection == 'WRST' )
     { colsubset = c( ModelOutput , 'T2'   , 'FA' , 'AvgDC' , 'eADC',   'T1'  , 'FL'  , 'AUC'   , 'Peak'   , 'T2star','Kep'   , 'K2', 'Ktrans') }
   else if (FeatureSelection == 'UniTmr' )
     { colsubset = c( ModelOutput , 'T2'   ,'eADC', 'T2star', 'Peak', 'AUC'   , 'T1'  , 'FL'    , 'AvgDC'                                     ) }
   else if (FeatureSelection == 'UniKi67' )
     { colsubset = c( ModelOutput , 'AvgDC', 'FA' ,   'T2'  , 'eADC', 'Peak'  , 'T1'  , 'AUC'   , 'WashOut', 'Delay' ,'T2star'                ) }
   else if (FeatureSelection == 'UniERG' )
     { colsubset = c( ModelOutput , 'T2'   , 'FA' , 'Peak'  , 'AUC' , 'AvgDC' , 'T1'  , 'eADC'  , 'T2star' , 'K2'    ,'Ktrans', 'FL'          ) }
   else if (FeatureSelection == 'UniCD' )
     { colsubset = c( ModelOutput , 'T2'   , 'FA' , 'AvgDC' , 'T1'  ,   'AUC' , 'Peak', 'T2star', 'K2'     , 'FL'    ,'eADC'                  ) }

   kfoldsubset =kfoldsubset [colsubset]
   outputModelName  =  paste0(outputModelBase, sprintf('%04d.RFModel', iii) )
   outputLinearName =  paste0(outputModelBase, sprintf('%04d.Linear' , iii) )
   cat ("build new model  ", outputModelName , " total training points ",  nrow(kfoldsubset ), " \n")
   ###############################################
   #
   # Create the random forest model in parallel
   #
   ###############################################
   
   
   # Start the clock!
   ptm <- proc.time()
   
   modelFormula <- as.formula( paste0(ModelOutput, " ~ . ") )
   
   
   print(head(kfoldsubset,n=10))
   #print(kfoldsubset)
   # build each model permutation
   if( numberOfThreads == 1 )
     {
     modelForest <- randomForest( modelFormula, kfoldsubset, ntree = numberOfTreesPerThread, type = RFModelType, importance = TRUE, na.action = randomForest::na.roughfix , replace=FALSE)
     #  http://www.ats.ucla.edu/stat/r/dae/logit.htm
     modelLinear  <- glm(modelFormula, data = kfoldsubset, family = LinearFamily ,control = list(maxit = 100) )
   
     # Stop the clock
     elapsedTime <- proc.time() - ptm
     cat( "Model creation took ", as.numeric( elapsedTime[3] ), " seconds.\n", sep = "" )
   
     ###############################################
     #
     # Save the model
     #
     ###############################################
   
     save( modelForest, file = outputModelName  )
     save( modelLinear, file = outputLinearName )
   
     } 

}
###############################################
#
# write template for applyRFModel 
#
###############################################
featureNames <- attr( modelForest$terms, "term.labels" )
fileNames <- c();

workdirprefix = "Processed/%s/"
for( i in 1:length( featureNames ) )
  {
  fileNames[i] <- paste0(workdirprefix,featureNames[i], ".nii.gz" )
  }

featureNames <- append( featureNames, "MASK", after = 0 )
fileNames <- append( fileNames, paste0(workdirprefix,"MASK.nii.gz" ), after = 0 )

outputCSVName = paste0(outputModelBase, 'csv'  )
write.table( rbind( featureNames, fileNames ), file = outputCSVName ,
  append = FALSE, col.names = FALSE, row.names = FALSE, sep = ",")


warnings()
