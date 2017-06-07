-- mysql  --local-infile < ./prostatechallenge.sql
-- CREATE DATABASE `DFProstateChallenge` CHARACTER SET utf8 COLLATE utf8_unicode_ci;
-- select * from DFProstateChallenge.metadata;
-- set db
use DFProstateChallenge;

-- Load Khalaf database data
DROP PROCEDURE IF EXISTS DFProstateChallenge.LoadDatabase ;
DELIMITER //
CREATE PROCEDURE DFProstateChallenge.LoadDatabase 
()
BEGIN

  DROP TABLE IF EXISTS  DFProstateChallenge.metadata;
  CREATE TABLE DFProstateChallenge.metadata(
  id    bigint(20) NOT NULL AUTO_INCREMENT,
  mrn                 VARCHAR(32)          not null COMMENT 'PT UID'     ,
  fid                 VARCHAR(256)         not NULL  COMMENT 'findings' ,
  pos                 VARCHAR(256)         not NULL  COMMENT 'findings' ,
  T2AxialUID          VARCHAR(256)         not NULL  COMMENT 'series UID' ,
  T2SagUID            VARCHAR(256)         not NULL  COMMENT 'series UID' ,
  ADCUID              VARCHAR(256)         not NULL  COMMENT 'series UID' ,
  BVALUID             VARCHAR(256)         not NULL  COMMENT 'series UID' ,
  T2AxialWorld        VARCHAR(256)         not NULL  COMMENT 'world matrix' ,
  T2SagWorld          VARCHAR(256)         not NULL  COMMENT 'world matrix' ,
  ADCWorld            VARCHAR(256)         not NULL  COMMENT 'world matrix' ,
  BVALWorld           VARCHAR(256)         not NULL  COMMENT 'world matrix' ,
  T2AxialIJK          VARCHAR(256)         not NULL  COMMENT 'IJK Coord' ,
  T2SagIJK            VARCHAR(256)         not NULL  COMMENT 'IJK Coord' ,
  ADCIJK              VARCHAR(256)         not NULL  COMMENT 'IJK Coord' ,
  BVALIJK             VARCHAR(256)         not NULL  COMMENT 'IJK Coord' ,
  KTRANSUID           VARCHAR(256)         GENERATED ALWAYS AS (concat(mrn ,'-Ktrans.mhd') ) COMMENT 'ktrans',
  ggg                         int              NULL  COMMENT 'gleason group' ,
  PRIMARY KEY (id),
  KEY `UID1` (`mrn`) 
  );
  insert into DFProstateChallenge.metadata( mrn, T2AxialUID, T2SagUID, ADCUID, BVALUID, T2AxialWorld, T2SagWorld, ADCWorld, BVALWorld, T2AxialIJK, T2SagIJK, ADCIJK, BVALIJK, fid, pos)
  SELECT JSON_UNQUOTE(eu.data->"$.""ProxID""") "ProxID",
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%t2%tra%" THEN  JSON_UNQUOTE(eu.data->"$.""DCMSerUID""") END ) T2AxialUID, 
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%t2%sag%" THEN  JSON_UNQUOTE(eu.data->"$.""DCMSerUID""") END ) T2SagUID,
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%ADC%"    THEN  JSON_UNQUOTE(eu.data->"$.""DCMSerUID""") END ) ADCUID,
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%BVAL%"   THEN  JSON_UNQUOTE(eu.data->"$.""DCMSerUID""") END ) BVALUID,
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%t2%tra%" THEN  JSON_UNQUOTE(eu.data->"$.""WorldMatrix""") END ) T2AxialWorld, 
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%t2%sag%" THEN  JSON_UNQUOTE(eu.data->"$.""WorldMatrix""") END ) T2SagWorld,
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%ADC%"    THEN  JSON_UNQUOTE(eu.data->"$.""WorldMatrix""") END ) ADCWorld,
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%BVAL%"   THEN  JSON_UNQUOTE(eu.data->"$.""WorldMatrix""") END ) BVALWorld,
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%t2%tra%" THEN  JSON_UNQUOTE(eu.data->"$.""ijk""") END ) T2AxialIJK, 
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%t2%sag%" THEN  JSON_UNQUOTE(eu.data->"$.""ijk""") END ) T2SagIJK,
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%ADC%"    THEN  JSON_UNQUOTE(eu.data->"$.""ijk""") END ) ADCIJK,
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%BVAL%"   THEN  JSON_UNQUOTE(eu.data->"$.""ijk""") END ) BVALIJK,
         JSON_UNQUOTE(eu.data->"$.""fid""") "fid",
         JSON_UNQUOTE(eu.data->"$.""pos""") "pos" 
  FROM ClinicalStudies.excelUpload eu 
  where eu.uploadID = 48
  group by JSON_UNQUOTE(eu.data->"$.""ProxID""") , JSON_UNQUOTE(eu.data->"$.""fid""");

  update DFProstateChallenge.metadata md
    join ClinicalStudies.excelUpload  eu on eu.uploadID = 49 and  md.mrn= JSON_UNQUOTE(eu.data->"$.""ProxID""")  
     SET md.ggg= JSON_UNQUOTE(eu.data->"$.""ggg""");

END //
DELIMITER ;
show create procedure DFProstateChallenge.LoadDatabase;
call DFProstateChallenge.LoadDatabase();


DROP PROCEDURE IF EXISTS DFProstateChallenge.RFHCCDeps ;
DELIMITER //
CREATE PROCEDURE DFProstateChallenge.RFHCCDeps 
()
BEGIN
-- FIXME replace csvfile  into  table
    SET SESSION group_concat_max_len = 10000000;
    select 'DCMNIFTISPLIT=/rsrch1/ip/dtfuentes/github/FileConversionScripts/seriesreadwriteall/DicomSeriesReadImageWriteAll';
    -- setup metadata  - string formating pain
    select concat("TRAINING = ",group_concat(  rf.mrn separator '  ') )
    from DFProstateChallenge.metadata rf ;
    
    select CONCAT('Processed/',rf.mrn,'/config:',' Processed/',rf.mrn,'/T2Axial.raw.nii.gz',' Processed/',rf.mrn,'/T2Sag.raw.nii.gz' , ' Processed/', rf.mrn, '/ADC.raw.nii.gz' , ' Processed/', rf.mrn, '/BVAL.raw.nii.gz' , ' Processed/', rf.mrn, '/KTRANS.raw.nii.gz' ) 
    from DFProstateChallenge.metadata rf ;
    select CONCAT('Processed/', rf.mrn, '/T2Axial.raw.nii.gz:\n\tmkdir -p $(@D); DicomSeriesReadImageWrite2  /rsrch1/ip/dtfuentes/PROSTATExChallenge2/ProstateTrain/DOI/', rf.mrn,'/*/', rf.T2AxialUID , ' $@' ) 
    from DFProstateChallenge.metadata rf group by rf.mrn;
    select CONCAT('Processed/', rf.mrn, '/T2Sag.raw.nii.gz:\n\tmkdir -p $(@D); DicomSeriesReadImageWrite2  /rsrch1/ip/dtfuentes/PROSTATExChallenge2/ProstateTrain/DOI/'  , rf.mrn,'/*/', rf.T2SagUID   , ' $@' ) 
    from DFProstateChallenge.metadata rf group by rf.mrn;
    select CONCAT('Processed/', rf.mrn, '/ADC.raw.nii.gz:\n\tmkdir -p $(@D); DicomSeriesReadImageWrite2  /rsrch1/ip/dtfuentes/PROSTATExChallenge2/ProstateTrain/DOI/'    , rf.mrn,'/*/', rf.ADCUID     , ' $@' ) 
    from DFProstateChallenge.metadata rf group by rf.mrn;
    select CONCAT('Processed/', rf.mrn, '/BVAL.raw.nii.gz:\n\tmkdir -p $(@D); DicomSeriesReadImageWrite2  /rsrch1/ip/dtfuentes/PROSTATExChallenge2/ProstateTrain/DOI/'   , rf.mrn,'/*/', rf.BVALUID    , ' $@' ) 
    from DFProstateChallenge.metadata rf group by rf.mrn;
    select CONCAT('Processed/', rf.mrn, '/KTRANS.raw.nii.gz:\n\tmkdir -p $(@D); c3d /rsrch1/ip/dtfuentes/PROSTATExChallenge2/KtransTrain/'   , rf.mrn,'/', rf.KTRANSUID , ' -o $@' ) 
    from DFProstateChallenge.metadata rf group by rf.mrn;
    select CONCAT('Processed/', rf.mrn, '/landmarks.',rf.fid,'.txt:\n\tmkdir -p $(@D); echo '   , rf.pos         ,' ', rf.ggg,'  > $@' ) from DFProstateChallenge.metadata rf ;
    select CONCAT('Processed/', rf.mrn, '/T2Axial.world:\n\tmkdir -p $(@D); echo '   , rf.T2AxialWorld,            '  > $@' ) from DFProstateChallenge.metadata rf group by rf.mrn;
    select CONCAT('Processed/', rf.mrn, '/T2Sag.world:\n\tmkdir   -p $(@D); echo '   , rf.T2SagWorld  ,            '  > $@' ) from DFProstateChallenge.metadata rf group by rf.mrn;
    select CONCAT('Processed/', rf.mrn, '/ADC.world:\n\tmkdir     -p $(@D); echo '   , rf.ADCWorld    ,            '  > $@' ) from DFProstateChallenge.metadata rf group by rf.mrn;
    select CONCAT('Processed/', rf.mrn, '/BVAL.world:\n\tmkdir    -p $(@D); echo '   , rf.BVALWorld   ,            '  > $@' ) from DFProstateChallenge.metadata rf group by rf.mrn;
    select CONCAT('Processed/', rf.mrn, '/T2Axial.',rf.fid,'.ijk:\n\tmkdir   -p $(@D); echo '   , rf.T2AxialIJK  ,' ', rf.ggg,'  > $@' ) from DFProstateChallenge.metadata rf ;
    select CONCAT('Processed/', rf.mrn, '/T2Sag.',rf.fid,'.ijk:\n\tmkdir     -p $(@D); echo '   , rf.T2SagIJK    ,' ', rf.ggg,'  > $@' ) from DFProstateChallenge.metadata rf ;
    select CONCAT('Processed/', rf.mrn, '/ADC.',rf.fid,'.ijk:\n\tmkdir       -p $(@D); echo '   , rf.ADCIJK      ,' ', rf.ggg,'  > $@' ) from DFProstateChallenge.metadata rf ;
    select CONCAT('Processed/', rf.mrn, '/BVAL.',rf.fid,'.ijk:\n\tmkdir      -p $(@D); echo '   , rf.BVALIJK     ,' ', rf.ggg,'  > $@' ) from DFProstateChallenge.metadata rf ;

END //
DELIMITER ;
-- show create procedure DFProstateChallenge.RFHCCDeps ;
-- call DFProstateChallenge.RFHCCDeps();
-- mysql  -sNre "call DFProstateChallenge.RFHCCDeps();"

