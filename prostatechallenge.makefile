SHELL := /bin/bash
WORKDIR=Processed
ROOTDIR=$(ARCHIVE)/github/ProstateChallenge
C3DEXE=/rsrch2/ip/dtfuentes/bin/c3d
ITKSNAP=vglrun /opt/apps/itksnap/itksnap-3.2.0-20141023-Linux-x86_64/bin/itksnap
OTBOFFSET  = 3
OTBRADIUS  = 4
OTBTEXTURE=/opt/apps/ANTsR/dev//ANTsR_src/ANTsR/src/ANTS/ANTS-build//bin//otbScalarImageToTexturesFilter
NMODELS=1
#OTBTEXTURE=/rsrch2/ip/dtfuentes/github/ExLib/otbScalarImageTextures/otbScalarImageToTexturesFilter

################
# Dependencies #
################
-include $(ROOTDIR)/dependencies
dependencies: ./prostatechallenge.sql
	-$(MYSQL) --local-infile < $< 
	$(MYSQL) -sNre "call DFProstateChallenge.RFHCCDeps();"  > $@

config: $(addprefix $(WORKDIR)/,$(addsuffix /config,$(TRAINING)))  
viewdata: $(addprefix $(WORKDIR)/,$(addsuffix /viewdata,$(TRAINING)))  
truth: $(addprefix $(WORKDIR)/,$(addsuffix /TRUTH.nii.gz,$(TRAINING)))  
lmpre: $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.0.txt,$(TRAINING)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.1.txt,$(TRAINING)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.2.txt,$(TRAINING)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.3.txt,$(TRAINING)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.4.txt,$(TRAINING)))    
lm: $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.txt,$(TRAINING)))  
reslice: $(addprefix $(WORKDIR)/,$(addsuffix /T2Sag.reslice.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /ADC.reslice.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /BVAL.reslice.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /KTRANS.reslice.nii.gz,$(TRAINING)))  
sform: $(addprefix $(WORKDIR)/,$(addsuffix /T2Axial.sform.nii.gz,$(TRAINING))) $(addprefix $(WORKDIR)/,$(addsuffix /T2Sag.sform.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /ADC.sform.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /BVAL.sform.nii.gz,$(TRAINING)))  
norm:    $(addprefix $(WORKDIR)/,$(addsuffix /T2Axial.norm.nii.gz,$(TRAINING))) $(addprefix $(WORKDIR)/,$(addsuffix /T2Sag.norm.nii.gz,$(TRAINING)))
texture: $(addprefix $(WORKDIR)/,$(addsuffix /T2Axial.HaralickCorrelation_$(OTBRADIUS).nii.gz,$(TRAINING)))
# compute all RF models
rfggg:  $(addsuffix /ggg/ALL/RF_MOST.nii.gz,      $(addprefix $(WORKDIR)/,$(TRAINING)))  

#https://www.gnu.org/software/make/manual/html_node/Special-Targets.html
# do not delete secondary files
.SECONDARY: 

$(WORKDIR)/%/landmarks.txt: 
	cat $(WORKDIR)/$*/landmarks.?.txt > $@ 
$(WORKDIR)/%/TRUTH.nii.gz: $(WORKDIR)/%/landmarks.txt $(WORKDIR)/%/T2Axial.sform.nii.gz
	$(C3DEXE) $(word 2,$^) -scale 0 -lts $< 5 -o $@

$(WORKDIR)/%.sform.nii.gz: $(WORKDIR)/%.raw.nii.gz $(WORKDIR)/%.world
	sed 's/,/ /g' $(word 2,$^) > $(basename $(word 2,$^)).mat
	$(C3DEXE)  $< -set-sform $(basename $(word 2,$^)).mat -o $@

$(WORKDIR)/%/T2Axial.norm.nii.gz: $(WORKDIR)/%/T2Axial.sform.nii.gz
	$(C3DEXE) $< -stretch 2% 98% 0.0 1.0  -type float -o $@
$(WORKDIR)/%/T2Sag.norm.nii.gz: $(WORKDIR)/%/T2Sag.reslice.nii.gz
	$(C3DEXE) $< -stretch 2% 98% 0.0 1.0  -type float -o $@
$(WORKDIR)/%.HaralickCorrelation_$(OTBRADIUS).nii.gz: $(WORKDIR)/%.norm.nii.gz
	if [ 0 -eq 1  ] ; then $(OTBTEXTURE) $<  $(WORKDIR)/$*.   5 $(OTBRADIUS)     0             0            0     0 1   ;fi

$(WORKDIR)/%/viewdata:
	$(C3DEXE) $(@D)/T2Axial.sform.nii.gz -info
	$(C3DEXE) $(@D)/T2Sag.sform.nii.gz   -info 
	$(C3DEXE) $(@D)/ADC.sform.nii.gz     -info
	$(C3DEXE) $(@D)/BVAL.sform.nii.gz    -info
	$(C3DEXE) $(@D)/KTRANS.raw.nii.gz  -info
	$(ITKSNAP) -g $(@D)/T2Axial.sform.nii.gz -s $(@D)/TRUTH.nii.gz -o $(@D)/T2Sag.reslice.nii.gz   $(@D)/ADC.reslice.nii.gz     $(@D)/BVAL.reslice.nii.gz    $(@D)/KTRANS.reslice.nii.gz  $(@D)/T2Axial.Entropy_4.nii.gz

#####################
# Build data matrix #
#####################
FILELIST = KTRANS.reslice  T2Axial.norm ADC.reslice  T2Sag.norm T2Axial.Entropy_4 T2Axial.HaralickCorrelation_4 BVAL.reslice                                                                                                                  
#LABELFILES = TRUTH LABELSRF
LABELFILES = TRUTH
lstat:   $(foreach idlabel,$(LABELFILES),$(foreach idimage,$(FILELIST),$(addprefix $(WORKDIR)/,$(addsuffix /$(idimage)/$(idlabel)/lstat.csv,$(TRAINING))))) 
sql:     $(foreach idlabel,$(LABELFILES),$(foreach idimage,$(FILELIST),$(addprefix $(WORKDIR)/,$(addsuffix /$(idimage)/$(idlabel).sql,$(TRAINING))))) 
# load lstat data to sql
$(WORKDIR)/%.sql: $(WORKDIR)/%/lstat.csv
	$(MYSQLIMPORT) --replace --fields-terminated-by=',' --lines-terminated-by='\n' --ignore-lines 1 DFProstateChallenge $<

echo: 
	echo $(foreach idlabel,$(LABELFILES),$(foreach idimage,$(FILELIST),$(addprefix $(WORKDIR)/,$(addsuffix /$(idimage)/$(idlabel)/lstat.csv,$(TRAINING))))) 

# build rf  model
$(WORKDIR)/%/SignificantFeatureImage.RFModel:
	mkdir -p  $(@D)
	@echo 'args <- c("3","truthdatamatrix.csv","$(@D)/SignificantFeatureImage.","1", "1","2000","500","3","$(NMODELS)","$(firstword $(subst /, ,$*))","$(word 2,$(subst /, ,$*))","$(lastword $(subst /, ,$*))")'
	Rscript createRFModel.R 3  truthdatamatrix.csv  $(@D)/SignificantFeatureImage.  1    1   2000   500   3   $(NMODELS) $(subst /, ,$*)

# create WHO maps
$(WORKDIR)/%/RF_MOST.nii.gz: $(WORKDIR)/%/SignificantFeatureImage.RFModel 
	mkdir -p  $(WORKDIR)/$*
	Rscript Code/applyRFModel.R   3  $(WORKDIR)/$*/SignificantFeatureImage.  $(WORKDIR)/$*/RF_POSTERIORS.%04d.   1    $(NMODELS) $(subst /, ,$*)
	$(C3DEXE) $(WORKDIR)/$*/RF_POSTERIORS.*.1.nii.gz  -mean -o $(WORKDIR)/$*/RF_MEAN.1.nii.gz
	$(C3DEXE) $(WORKDIR)/$*/RF_POSTERIORS.*.2.nii.gz  -mean -o $(WORKDIR)/$*/RF_MEAN.2.nii.gz
	$(C3DEXE) $(WORKDIR)/$*/RF_POSTERIORS.*.3.nii.gz  -mean -o $(WORKDIR)/$*/RF_MEAN.3.nii.gz
	$(C3DEXE) -verbose $(WORKDIR)/$*/RF_MEAN.1.nii.gz -scale -1. -popas AVG $(WORKDIR)/$*/RF_POSTERIORS.*.1.nii.gz -foreach -push AVG -add -dup -times -endfor -accum -add -endaccum -sqrt -o $(WORKDIR)/$*/RF_STDD.1.nii.gz
	$(C3DEXE) -verbose $(WORKDIR)/$*/RF_MEAN.2.nii.gz -scale -1. -popas AVG $(WORKDIR)/$*/RF_POSTERIORS.*.2.nii.gz -foreach -push AVG -add -dup -times -endfor -accum -add -endaccum -sqrt -o $(WORKDIR)/$*/RF_STDD.2.nii.gz
	$(C3DEXE) -verbose $(WORKDIR)/$*/RF_MEAN.3.nii.gz -scale -1. -popas AVG $(WORKDIR)/$*/RF_POSTERIORS.*.3.nii.gz -foreach -push AVG -add -dup -times -endfor -accum -add -endaccum -sqrt -o $(WORKDIR)/$*/RF_STDD.3.nii.gz
	$(ANTSIMAGEMATHCMD) 3 $(WORKDIR)/$*/RF_WHO.nii.gz MostLikely 0 $(WORKDIR)/$*/RF_MEAN.*.nii.gz  

###########################################################################
.SECONDEXPANSION:
#https://www.gnu.org/software/make/manual/html_node/Secondary-Expansion.html#Secondary-Expansion
###########################################################################
#https://www.gnu.org/software/make/manual/html_node/Automatic-Variables.html

# reslice
$(WORKDIR)/%.reslice.nii.gz: $(WORKDIR)/%.raw.nii.gz $(WORKDIR)/$$(*D)/T2Axial.sform.nii.gz
	$(C3DEXE) $(word 2,$^) $< -reslice-identity -o $@

# load lstat data for each label file
$(WORKDIR)/%/lstat.csv: $(WORKDIR)/$$(firstword $$(subst /, ,$$*))/$$(word 2,$$(subst /, ,$$*)).nii.gz $(WORKDIR)/$$(firstword $$(subst /, ,$$*))/$$(word 3,$$(subst /, ,$$*)).nii.gz 
	echo $(subst /, ,$*)
	mkdir -p $(@D)
	$(C3DEXE) $<  $(word 2,$^) -lstat > $(@D)/lstat.txt &&  sed "s/^\s\+/$(firstword $(subst /, ,$*)),$(word 3 ,$(subst /, ,$*)),$(subst .,,$(word 2 ,$(subst /, ,$*))),/g;s/\s\+/,/g;s/LabelID/InstanceUID,SegmentationID,FeatureID,LabelID/g;s/Vol(mm^3)/Vol.mm.3/g;s/Extent(Vox)/ExtentX,ExtentY,ExtentZ/g" $(@D)/lstat.txt  > $@
