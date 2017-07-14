# Load data

dataset <- read.csv("file:///home/gpauloski/Downloads/PC/truthadcdatamatrix.csv", na.strings=c(".", "NA", "", "?"))

# Model Parameters

seed <- 42		# RF seed
partition <- 0.6	# % of data to be used in test set
trees <- 200		# Num trees for RF
trys <- 2		# Num variables for RF
split <- 4		# if 4; Z = 1 for ggg = 1,2,3
			# elseif 3; Z = 1 for ggg = 1,2

# Create Z vector based on value of ggg

Z <- as.factor(ifelse(dataset$ggg < split, 1, 2))

# Bind Z to dataset

dataset <- cbind(dataset, Z)

# Sample and separate training observations from testing

train <- sample(nrow(dataset), partition*nrow(dataset))
test <- setdiff(seq_len(nrow(dataset)), train)
cat("\nTrain and test set created\n\n")

# Define input/target/ignore variables

input <- c("KTRANS.reslice", "T2Axial.norm", "ADC.reslice", "T2Sag.norm", "T2Axial.Entropy_4", "T2Axial.HaralickCorrelation_4", "BVAL.reslice")
target <- "Z"

# Build RF Model

library(randomForest, quietly=TRUE)
set.seed(seed)
rf <- randomForest::randomForest(dataset$Z[train]~., 
	data=dataset[train,c(input, target)],
	ntree=trees, 
	mtry=trys)
print(rf)

# Apply RF Model on testing data to predict Z

Z2 <- as.numeric(predict(rf, dataset[test,c(input,target)], type="response"))
cat("\nPredicting Z for test set using RF model\n")

# Create new dataset with test data and predicted Z

cat("\nBuilding new data set with Z predictions\n")
dataset2 <- cbind(dataset[test,], Z2)
input2 <- c(input, "Z2")
target2 <- "ggg"
dataset2$ggg <- as.factor(dataset2$ggg)

# Build and Apply RF Model on new dataset to predict ggg

rf2 <- randomForest::randomForest(dataset2$ggg~., 
	data=dataset2[,cbind(input2,target2)], 
	ntree=trees, 
	mtry=trys)
print(rf2)

