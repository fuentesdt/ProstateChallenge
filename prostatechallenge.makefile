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

$(WORKDIR)/%/viewdata:
	$(C3DEXE) $(@D)/T2Sag.nii.gz  -info 
	$(C3DEXE) $(@D)/T2Axial.nii.gz -info
	$(C3DEXE) $(@D)/ADC.nii.gz     -info
	$(C3DEXE) $(@D)/BVAL.nii.gz    -info
	$(C3DEXE) $(@D)/KTRANS.nii.gz  -info
	echo $(ITKSNAP) -g $(@D)/T2Sag.nii.gz -o $(@D)/ADC.nii.gz  $(@D)/BVAL.nii.gz  $(@D)/KTRANS.nii.gz  $(@D)/T2Axial.nii.gz  
