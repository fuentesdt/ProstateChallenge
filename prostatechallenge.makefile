SHELL := /bin/bash
WORKDIR=Processed
ROOTDIR=$(ARCHIVE)/github/ProstateChallenge
C3DEXE=/rsrch2/ip/dtfuentes/bin/c3d
ITKSNAP=vglrun /opt/apps/itksnap/itksnap-3.2.0-20141023-Linux-x86_64/bin/itksnap

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
lmpre: $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.1.txt,$(TRAINING)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.2.txt,$(TRAINING)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.3.txt,$(TRAINING)))   \
       $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.4.txt,$(TRAINING)))    
lm: $(addprefix $(WORKDIR)/,$(addsuffix /landmarks.txt,$(TRAINING)))  
reslice: $(addprefix $(WORKDIR)/,$(addsuffix /T2Sag.reslice.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /ADC.reslice.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /BVAL.reslice.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /KTRANS.reslice.nii.gz,$(TRAINING)))  
sform: $(addprefix $(WORKDIR)/,$(addsuffix /T2Axial.sform.nii.gz,$(TRAINING))) $(addprefix $(WORKDIR)/,$(addsuffix /T2Sag.sform.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /ADC.sform.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /BVAL.sform.nii.gz,$(TRAINING)))  

$(WORKDIR)/%/landmarks.txt: 
	cat $(WORKDIR)/$*/landmarks.?.txt > $@ 
$(WORKDIR)/%/TRUTH.nii.gz: $(WORKDIR)/%/landmarks.txt $(WORKDIR)/%/T2Axial.sform.nii.gz
	$(C3DEXE) $(word 2,$^) -scale 0 -lts $< 5 -o $@

$(WORKDIR)/%.sform.nii.gz: $(WORKDIR)/%.raw.nii.gz $(WORKDIR)/%.world
	sed 's/,/ /g' $(word 2,$^) > $(basename $(word 2,$^)).mat
	$(C3DEXE)  $< -set-sform $(basename $(word 2,$^)).mat -o $@

$(WORKDIR)/%.reslice.nii.gz: $(WORKDIR)/%.raw.nii.gz
	$(C3DEXE) $(@D)/T2Axial.raw.nii.gz  $< -reslice-identity -o $@

$(WORKDIR)/%/viewdata:
	$(C3DEXE) $(@D)/T2Axial.sform.nii.gz -info
	$(C3DEXE) $(@D)/T2Sag.sform.nii.gz   -info 
	$(C3DEXE) $(@D)/ADC.sform.nii.gz     -info
	$(C3DEXE) $(@D)/BVAL.sform.nii.gz    -info
	$(C3DEXE) $(@D)/KTRANS.raw.nii.gz  -info
	$(ITKSNAP) -g $(@D)/T2Axial.sform.nii.gz -s $(@D)/TRUTH.nii.gz -o $(@D)/T2Sag.reslice.nii.gz   $(@D)/ADC.reslice.nii.gz     $(@D)/BVAL.reslice.nii.gz    $(@D)/KTRANS.reslice.nii.gz  
