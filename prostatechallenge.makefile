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
reg: $(addprefix $(WORKDIR)/,$(addsuffix /T2Sag.reg.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /ADC.reg.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /BVAL.reg.nii.gz,$(TRAINING)))  $(addprefix $(WORKDIR)/,$(addsuffix /KTRANS.reg.nii.gz,$(TRAINING)))  

$(WORKDIR)/%/TRUTH.nii.gz: $(WORKDIR)/%/landmarks.txt $(WORKDIR)/%/T2Axial.nii.gz
	$(C3DEXE) $(word 2,$^) -scale 0 -lts $< 5 -o $@

$(WORKDIR)/%.reg.nii.gz: $(WORKDIR)/%.raw.nii.gz
	$(C3DEXE) $(@D)/T2Axial.raw.nii.gz  $< -reslice-identity -o $@

$(WORKDIR)/%/viewdata:
	$(C3DEXE) $(@D)/T2Axial.raw.nii.gz -info
	$(C3DEXE) $(@D)/T2Sag.raw.nii.gz   -info 
	$(C3DEXE) $(@D)/ADC.raw.nii.gz     -info
	$(C3DEXE) $(@D)/BVAL.raw.nii.gz    -info
	$(C3DEXE) $(@D)/KTRANS.raw.nii.gz  -info
	$(ITKSNAP) -g $(@D)/T2Axial.raw.nii.gz -s $(@D)/TRUTH.nii.gz -o $(@D)/T2Sag.reg.nii.gz   $(@D)/ADC.reg.nii.gz     $(@D)/BVAL.reg.nii.gz    $(@D)/KTRANS.reg.nii.gz  
