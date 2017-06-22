#  Usage:
#   > source('applyRFModel.R')
library( ANTsR )
library( randomForest )
library( snowfall )

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
      #           1                              2                                           3                                            4     5        6        7      8
    args <- c("3","Processed/ProstateX-0203/ggg/ALL/SignificantFeatureImage.","Processed/ProstateX-0203/ggg/ALL/RF_POSTERIORS.%04d.","1","1","ProstateX-0203","ggg","ALL")
  } else if( length( args ) < 3 ) {
  cat( "Usage: Rscript applyModel.R dimension inputModel inputCSVFile ",
       "outputProbabilityImagePrefix <numberOfThreads=4>", sep = "" )
  stopQuietly()
  }

dimension      <- as.numeric( args[1] )
inputModelBase <- args[2]
csvfilename    <-  paste0(inputModelBase ,"csv")
fileList       <- read.csv(csvfilename )
ptid           <- as.character( args[6] )
probImageBase  <- args[3]

numberOfThreads <- 1
if( length( args ) >= 4 )
  {
  numberOfThreads <- as.numeric( args[4] )
  }

Nmodels = 10
if( length( args ) >= 5 )
  {
  Nmodels <- as.numeric( args[5] )
  }

ModelOutput = 'ggg'
RFModelType = "prob"
LinearModelType = "response"
if( length( args ) >= 7 )
  {
  ModelOutput <-  args[7] 
  }

if( ModelOutput != 'ggg' & ModelOutput != 'Tumor' )
  {
  RFModelType = "response"
  }


cat( "Model Setup: ", ModelOutput ,LinearModelType , RFModelType ," seconds.\n", sep = " " )
###############################################
#
# Put the image data into a data frame (modelData)
#
###############################################

maskName <- sprintf( as.character(fileList[1,1]),ptid)
featureImages <- fileList[1,2:ncol( fileList )]
featureNames <- colnames( featureImages )

## Create the model data frame

maskImage <- antsImageRead( maskName , dimension = dimension, pixeltype = 'unsigned int' )
mask <- as.array( maskImage )

maskIndices <- which( mask != 0 )

subjectData <- matrix( NA, nrow = length( maskIndices ), ncol = length( featureNames ) )
for( j in 1:length( featureNames ) )
  {
  cat( "  Reading feature image ", featureNames[j], ".\n", sep = "" )
  featureImageName = sprintf(as.character( featureImages[1,j] ), ptid)
  featureImage <- as.array( antsImageRead( featureImageName , dimension = dimension, pixeltype = 'float' ) )

  values <- featureImage[maskIndices]
  subjectData[, j] <- values
  }

colnames( subjectData ) <- c( featureNames )
subjectData <- as.data.frame( subjectData )

# If the subject data has NA's, we need to get rid of them
# since predict.randomForest will return NA's otherwise.
# Setting NA's to 0 is a complete hack.
subjectData[is.na( subjectData )] <- 0


# prediction for all models
for (iii in 1:Nmodels ) # ignore Labels
{
  inputModelName   <- paste0(inputModelBase , sprintf('%04d.RFModel', iii) )
  linearModelName  <- paste0(inputModelBase , sprintf('%04d.Linear', iii) )
  probImagePrefix  <- sprintf(probImageBase, iii)
  # Load model:  contained in the variable "modelForest"
  load( inputModelName )
  # Load model:  contained in the variable "modelLinear"
  load( linearModelName )
  
  ###############################################
  #
  # Predict using the model (in parallel)
  #
  ###############################################
  
  # Start the clock!
  ptm <- proc.time()
  
  # the function each thread calls
  parallelPredict <- function( i ) {
    numberOfSamplesPerThread <- as.integer( nrow( subjectData ) / numberOfThreads )
    threadIndexRange <- ( ( i - 1 ) * numberOfSamplesPerThread + 1 ):( i * numberOfSamplesPerThread )
    if( i == numberOfThreads )
      {
      threadIndexRange <- ( ( i - 1 ) * numberOfSamplesPerThread + 1 ):( nrow( subjectData ) )
      }
    return( predict( modelForest, subjectData[threadIndexRange,], type = RFModelType  ) )
  }
  
  if( numberOfThreads == 1 )
    {
  
    subjectProbabilities <- predict( modelForest, subjectData, type = RFModelType      )
    linearPrediction     <- predict( modelLinear, subjectData, type = LinearModelType  ,se.fit = TRUE)
  
    # Stop the clock
    elapsedTime <- proc.time() - ptm
    cat( "Prediction took ", as.numeric( elapsedTime[3] ), " seconds.\n", sep = "" )
  
    ###############################################
    #
    # Write the probability images to disk
    #
    ###############################################
    if (RFModelType == "prob")
      {
       for( i in 1:ncol( subjectProbabilities ) )
         {
         probImage <- antsImageClone( maskImage, "float" )
         probImage[maskImage != 0] <- subjectProbabilities[,i];
         probFileName <- paste( probImagePrefix, i, ".nii.gz", sep = "" )
         cat( "Writing ", probFileName, ".\n" )
         antsImageWrite( probImage, probFileName )
         }
      } else {
         responseImage <- antsImageClone( maskImage, "float" )
         responseImage[maskImage != 0] <- subjectProbabilities;
         responseFileName <- paste0( probImagePrefix,  "nii.gz" )
         cat( "Writing ", responseFileName, ".\n" )
         antsImageWrite( responseImage, responseFileName )
      } 
    # Write the linear model images to disk
    linearImage <- antsImageClone( maskImage, "float" )
    linearImage[maskImage != 0] <- linearPrediction$fit;
    linearFileName <- paste0( sub("RF_","GLMfit",probImagePrefix) ,  "nii.gz" )
    cat( "Writing ", linearFileName, ".\n" )
    antsImageWrite( linearImage, linearFileName )

    stddevImage <- antsImageClone( maskImage, "float" )
    stddevImage[maskImage != 0] <- linearPrediction$se.fit;
    stddevFileName <- paste0( sub("RF_","GLMstd",probImagePrefix) ,  "nii.gz" )
    cat( "Writing ", stddevFileName, ".\n" )
    antsImageWrite( stddevImage, stddevFileName )
  } else {
    # Initialize the cluster
    sfInit( parallel = TRUE, cpus = numberOfThreads, type = 'SOCK' )
  
    # Make data available to each R instance / node
    sfExport( list = c( "modelForest", "subjectData", "numberOfThreads" ) )
  
    # Load library on each R instance / node
    sfClusterEval( library( randomForest ) )
  
    # Use a parallel random number generator to avoid correlated random numbers
    # this requires rlecuyer (which is default)
    sfClusterSetupRNG()
  
    # build the random forests
    parallelProbabilities <- sfClusterApply( 1:numberOfThreads, parallelPredict )
  
    sfStop()
  
    # everything finished so merge all forests into one
    subjectProbabilities <- parallelProbabilities[[1]]
    for( i in 2:numberOfThreads )
      {
      subjectProbabilities <- rbind( subjectProbabilities, parallelProbabilities[[i]] )
      }
  
    # Stop the clock
    elapsedTime <- proc.time() - ptm
    cat( "Prediction took ", as.numeric( elapsedTime[3] ), " seconds.\n", sep = "" )
  
    ###############################################
    #
    # Write the probability images to disk
    #
    ###############################################
  
    for( i in 1:ncol( subjectProbabilities ) )
      {
      probImage <- antsImageClone( maskImage, "float" )
      probImage[maskImage != 0] <- subjectProbabilities[,i];
      probFileName <- paste( probImagePrefix, i, ".nii.gz", sep = "" )
      cat( "Writing ", probFileName, ".\n" )
      antsImageWrite( probImage, probFileName )
      }
    }
  
}
