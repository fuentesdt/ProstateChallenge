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
  T2AxialUID          VARCHAR(256)         not NULL  COMMENT 'series UID' ,
  T2SagUID            VARCHAR(256)         not NULL  COMMENT 'series UID' ,
  ADCUID              VARCHAR(256)         not NULL  COMMENT 'series UID' ,
  BVALUID             VARCHAR(256)         not NULL  COMMENT 'series UID' ,
  KTRANSUID           VARCHAR(256)         GENERATED ALWAYS AS (concat(mrn ,'-Ktrans.mhd') ) COMMENT 'ktrans',
  fid                 VARCHAR(256)         not NULL  COMMENT 'findings' ,
  pos                 VARCHAR(256)         not NULL  COMMENT 'findings' ,
  ggg                         int              NULL  COMMENT 'gleason' ,
  PRIMARY KEY (id),
  KEY `UID1` (`mrn`) 
  );
  insert into DFProstateChallenge.metadata( mrn                 , T2AxialUID          , T2SagUID            , ADCUID              , BVALUID             , fid                 , pos                 )
  SELECT JSON_UNQUOTE(eu.data->"$.""ProxID""") "ProxID",
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%t2%tra%" THEN  JSON_UNQUOTE(eu.data->"$.""DCMSerUID""") END ) T2AxialUID, 
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%t2%sag%" THEN  JSON_UNQUOTE(eu.data->"$.""DCMSerUID""") END ) T2SagUID,
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%ADC%"    THEN  JSON_UNQUOTE(eu.data->"$.""DCMSerUID""") END ) ADCUID,
         GROUP_CONCAT( distinct CASE WHEN JSON_UNQUOTE(eu.data->"$.""Name""") like "%BVAL%"   THEN  JSON_UNQUOTE(eu.data->"$.""DCMSerUID""") END ) BVALUID,
         JSON_UNQUOTE(eu.data->"$.""fid""") "fid",
         JSON_UNQUOTE(eu.data->"$.""pos""") "pos" 
  FROM ClinicalStudies.excelUpload eu 
  where eu.uploadID = 48
  group by JSON_UNQUOTE(eu.data->"$.""ProxID""") ;

  update DFProstateChallenge.metadata md
    join ClinicalStudies.excelUpload  eu on eu.uploadID = 49 and  md.mrn= JSON_UNQUOTE(eu.data->"$.""ProxID""")  
     SET md.ggg= JSON_UNQUOTE(eu.data->"$.""ggg""");

END //
DELIMITER ;
show create procedure DFProstateChallenge.LoadDatabase;
call DFProstateChallenge.LoadDatabase();

-- select  iu.mrn, iu.dataID,  iu.truthID, iu.TimeID, iu.StudyUID from  RandomForestHCCResponse.imaginguids iu where iu.truthID=1;
-- show create table RandomForestHCCResponse.imaginguids;

-- verify 77 truth files
insert into Metadata.Singular(id)
(select si.id from Metadata.Singular si join(
   select count( rf.StudyUID) numtruth from RandomForestHCCResponse.imaginguids rf  where rf.TruthID > 0 order by rf.mrn
                                   ) b on b.numtruth !=77 );


DROP PROCEDURE IF EXISTS RandomForestHCCResponse.ResetLabelStats ;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.ResetLabelStats()
BEGIN
  DROP TABLE IF EXISTS  RandomForestHCCResponse.lstat;
  CREATE TABLE RandomForestHCCResponse.lstat  (
   InstanceUID        VARCHAR(255)  NOT NULL COMMENT 'studyuid *OR* seriesUID', 
   SegmentationID     VARCHAR(80)   NOT NULL,  -- UID for segmentation file -- FIXME -- SOPUID NOT WORTH IT???  SegmentationSOPUID VARCHAR(255)   NOT NULL,  
   FeatureID          VARCHAR(80)   NOT NULL,  -- UID for image feature     -- FIXME -- SOPUID NOT WORTH IT???  FeatureSOPUID      VARCHAR(255)   NOT NULL,  
   LabelID            INT           NOT NULL,  -- label id for LabelSOPUID statistics of FeatureSOPUID      
   Mean               REAL              NULL,
   StdD               REAL              NULL,
   Max                REAL              NULL,
   Min                REAL              NULL,
   Count              INT               NULL,
   Volume             REAL              NULL,
   ExtentX            INT               NULL,
   ExtentY            INT               NULL,
   ExtentZ            INT               NULL,
   PRIMARY KEY (InstanceUID,SegmentationID,FeatureID,LabelID) );
END //
DELIMITER ;
show create procedure RandomForestHCCResponse.ResetLabelStats;
-- call RandomForestHCCResponse.ResetLabelStats();
show create table RandomForestHCCResponse.lstat;

DROP TABLE IF EXISTS  RandomForestHCCResponse.liverLabelKey;
CREATE TABLE RandomForestHCCResponse.liverLabelKey(
 labelID        INT        NOT NULL,
 location       CHAR(12)   NOT NULL,
 PRIMARY KEY (labelID) );

INSERT INTO RandomForestHCCResponse.liverLabelKey(labelID,location) VALUES 
   ( 1,  "background"),
   ( 2,  "liver     "),
   ( 3,  "viable    "),
   ( 4,  "necrosis  "),
   ( 5,  "lipiodol  "),
   ( 6,  "I         "),
   ( 7,  "II        "),
   ( 8,  "III       "),
   ( 9,  "IVa       "),
   (10,  "IVb       "),
   (11,  "V         "),
   (12,  "VI        "),
   (13,  "VII       "),
   (14,  "VIII      ");

-- table of image features we are interested in
DROP TABLE IF EXISTS  RandomForestHCCResponse.ImageFeatures;
CREATE TABLE RandomForestHCCResponse.ImageFeatures(
 id    bigint(20) NOT NULL AUTO_INCREMENT,
 FeatureID          VARCHAR(80)   NOT NULL,  -- UID for image feature     -- FIXME -- SOPUID NOT WORTH IT???  FeatureSOPUID      VARCHAR(255)   NOT NULL,  
         KEY (id),
 PRIMARY KEY (FeatureID) );
INSERT INTO RandomForestHCCResponse.ImageFeatures(FeatureID) VALUES 
   ( "Pre_RAWIMAGE"                     ), ( "Art_RAWIMAGE"                     ), ( "Ven_RAWIMAGE"                     ), ( "Del_RAWIMAGE"                     ),
   ( "Pre_DENOISE"                      ), ( "Art_DENOISE"                      ), ( "Ven_DENOISE"                      ), ( "Del_DENOISE"                      ),
   ( "Pre_GRADIENT"                     ), ( "Art_GRADIENT"                     ), ( "Ven_GRADIENT"                     ), ( "Del_GRADIENT"                     ),
   ( "Pre_ATROPOS_GMM_POSTERIORS1"      ), ( "Art_ATROPOS_GMM_POSTERIORS1"      ), ( "Ven_ATROPOS_GMM_POSTERIORS1"      ), ( "Del_ATROPOS_GMM_POSTERIORS1"      ),
   ( "Pre_ATROPOS_GMM_POSTERIORS2"      ), ( "Art_ATROPOS_GMM_POSTERIORS2"      ), ( "Ven_ATROPOS_GMM_POSTERIORS2"      ), ( "Del_ATROPOS_GMM_POSTERIORS2"      ),
   ( "Pre_ATROPOS_GMM_POSTERIORS3"      ), ( "Art_ATROPOS_GMM_POSTERIORS3"      ), ( "Ven_ATROPOS_GMM_POSTERIORS3"      ), ( "Del_ATROPOS_GMM_POSTERIORS3"      ),
   ( "Pre_ATROPOS_GMM_LABEL1_DISTANCE"  ), ( "Art_ATROPOS_GMM_LABEL1_DISTANCE"  ), ( "Ven_ATROPOS_GMM_LABEL1_DISTANCE"  ), ( "Del_ATROPOS_GMM_LABEL1_DISTANCE"  ),
   ( "Pre_MEAN_RADIUS_1"                ), ( "Art_MEAN_RADIUS_1"                ), ( "Ven_MEAN_RADIUS_1"                ), ( "Del_MEAN_RADIUS_1"                ),
   ( "Pre_MEAN_RADIUS_3"                ), ( "Art_MEAN_RADIUS_3"                ), ( "Ven_MEAN_RADIUS_3"                ), ( "Del_MEAN_RADIUS_3"                ),
   ( "Pre_MEAN_RADIUS_5"                ), ( "Art_MEAN_RADIUS_5"                ), ( "Ven_MEAN_RADIUS_5"                ), ( "Del_MEAN_RADIUS_5"                ),
   ( "Pre_SIGMA_RADIUS_1"               ), ( "Art_SIGMA_RADIUS_1"               ), ( "Ven_SIGMA_RADIUS_1"               ), ( "Del_SIGMA_RADIUS_1"               ),
   ( "Pre_SIGMA_RADIUS_3"               ), ( "Art_SIGMA_RADIUS_3"               ), ( "Ven_SIGMA_RADIUS_3"               ), ( "Del_SIGMA_RADIUS_3"               ),
   ( "Pre_SIGMA_RADIUS_5"               ), ( "Art_SIGMA_RADIUS_5"               ), ( "Ven_SIGMA_RADIUS_5"               ), ( "Del_SIGMA_RADIUS_5"               ),
   ( "Pre_SKEWNESS_RADIUS_1"            ), ( "Art_SKEWNESS_RADIUS_1"            ), ( "Ven_SKEWNESS_RADIUS_1"            ), ( "Del_SKEWNESS_RADIUS_1"            ),
   ( "Pre_SKEWNESS_RADIUS_3"            ), ( "Art_SKEWNESS_RADIUS_3"            ), ( "Ven_SKEWNESS_RADIUS_3"            ), ( "Del_SKEWNESS_RADIUS_3"            ),
   ( "Pre_SKEWNESS_RADIUS_5"            ), ( "Art_SKEWNESS_RADIUS_5"            ), ( "Ven_SKEWNESS_RADIUS_5"            ), ( "Del_SKEWNESS_RADIUS_5"            ),
   ( "LEFTLUNGDISTANCE"                 ), ( "RIGHTLUNGDISTANCE"                ), ( "LANDMARKDISTANCE0"                ), ( "LANDMARKDISTANCE1"                ),
   ( "LANDMARKDISTANCE2"                ), ( "HESSOBJ"                          ), ( "NORMALIZEDDISTANCE"               );


DROP PROCEDURE IF EXISTS RandomForestHCCResponse.ResetOverlapStats ;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.ResetOverlapStats()
BEGIN
  DROP TABLE IF EXISTS  RandomForestHCCResponse.overlap;
  CREATE TABLE RandomForestHCCResponse.overlap(
   InstanceUID        VARCHAR(255)  NOT NULL COMMENT 'studyuid *OR* seriesUID',  
   FirstImage         VARCHAR(80)   NOT NULL,  -- UID for  FirstImage  
   SecondImage        VARCHAR(80)   NOT NULL,  -- UID for  SecondImage 
   LabelID            INT           NOT NULL,  -- label id for LabelSOPUID statistics of FeatureSOPUID      
   SegmentationID     VARCHAR(80)   NOT NULL,  -- UID for segmentation file  to join with lstat
   -- output of c3d firstimage.nii.gz secondimage.nii.gz -overlap LabelID
   -- Computing overlap #1 and #2
   -- OVL: 6, 11703, 7362, 4648, 0.487595, 0.322397  
   MatchingFirst      int           DEFAULT NULL,     --   Matching voxels in first image:  11703
   MatchingSecond     int           DEFAULT NULL,     --   Matching voxels in second image: 7362
   SizeOverlap        int           DEFAULT NULL,     --   Size of overlap region:          4648
   DiceSimilarity     real          DEFAULT NULL,     --   Dice similarity coefficient:     0.487595
   IntersectionRatio  real          DEFAULT NULL,     --   Intersection / ratio:            0.322397
   PRIMARY KEY (InstanceUID,FirstImage,SecondImage,LabelID) );
END //
DELIMITER ;
show create procedure RandomForestHCCResponse.ResetOverlapStats;
-- call RandomForestHCCResponse.ResetOverlapStats();
show create table RandomForestHCCResponse.overlap;



-- DEPRACTED Load from ClinicalStudies.excelUpload eu 
-- load hcc imaging data
-- python ./csvtojson.py --csvfile datalocation/ManualHCCUIDs.csv
-- read in multiple times to setup (key,value) pair structure... baseline, followup , baseline2, followup2, ...
-- LOAD DATA LOCAL INFILE './datalocation/ManualHCCUIDs.json'
-- INTO TABLE RandomForestHCCResponse.imaginguids(data) 
-- SET TimeID              ="baseline"                                                  ,
--     StudyUID            =json_unquote(data->'$."BaselineCT_Study UID"')              ,
--     SeriesUIDPre        =json_unquote(data->'$."BaselineCT_SeriesUID-Pre".seriesuid'),
--     SeriesACQPre        =json_unquote(data->'$."BaselineCT_SeriesUID-Pre".acqtime')  ,
--     SeriesUIDArt        =json_unquote(data->'$."BaselineCT_SeriesUID-Art".seriesuid'),
--     SeriesACQArt        =json_unquote(data->'$."BaselineCT_SeriesUID-Art".acqtime')  ,
--     SeriesUIDVen        =json_unquote(data->'$."BaselineCT_SeriesUID-Ven".seriesuid'),
--     SeriesACQVen        =json_unquote(data->'$."BaselineCT_SeriesUID-Ven".acqtime')  ,
--     SeriesUIDDel        =json_unquote(data->'$."BaselineCT_SeriesUID-Del".seriesuid'),
--     SeriesACQDel        =json_unquote(data->'$."BaselineCT_SeriesUID-Del".acqtime')  ;
-- 
-- -- read in multiple times to setup (key,value) pair structure... baseline, followup , baseline2, followup2, ...
-- LOAD DATA LOCAL INFILE './datalocation/ManualHCCUIDs.json'
-- INTO TABLE RandomForestHCCResponse.imaginguids(data) 
-- SET TimeID              ="followup"                                                  ,
--     StudyUID            =json_unquote(data->'$."FollowupCT_Study UID"')              ,
--     SeriesUIDPre        =json_unquote(data->'$."FollowupCT_SeriesUID-Pre".seriesuid'),
--     SeriesACQPre        =json_unquote(data->'$."FollowupCT_SeriesUID-Pre".acqtime')  ,
--     SeriesUIDArt        =json_unquote(data->'$."FollowupCT_SeriesUID-Art".seriesuid'),
--     SeriesACQArt        =json_unquote(data->'$."FollowupCT_SeriesUID-Art".acqtime')  ,
--     SeriesUIDVen        =json_unquote(data->'$."FollowupCT_SeriesUID-Ven".seriesuid'),
--     SeriesACQVen        =json_unquote(data->'$."FollowupCT_SeriesUID-Ven".acqtime')  ,
--     SeriesUIDDel        =json_unquote(data->'$."FollowupCT_SeriesUID-Del".seriesuid'),
--     SeriesACQDel        =json_unquote(data->'$."FollowupCT_SeriesUID-Del".acqtime')  ;

-- treatment history  db
DROP TABLE IF EXISTS  RandomForestHCCResponse.treatmenthistory;
CREATE TABLE RandomForestHCCResponse.treatmenthistory(
id               bigint(20)   NOT NULL AUTO_INCREMENT,
dataID           varchar(64)  NULL     COMMENT 'TACE Cases, MVI data, PNPLA3 data' ,
LesionNumber     int          GENERATED ALWAYS AS (json_unquote(data->'$."Lesion_Number(#)"')             ) COMMENT 'May have multiple lesions per liver... each tracked separately UID' ,
mrn              int          NOT NULL COMMENT 'PT UID'                    ,
Cirrhosis        varchar(64)  GENERATED ALWAYS AS (json_unquote(data->'$."Evidence_of_cirh Y=1 No= 0"'))    COMMENT 'Cirrhosis  '               ,
Pathology        varchar(64)  GENERATED ALWAYS AS (json_unquote(data->'$."Pathology"'))                     COMMENT 'Pathology  '               ,
Vascular         varchar(64)  GENERATED ALWAYS AS (json_unquote(data->'$."Vascular invasion y=1 n=0"'))     COMMENT 'Vascular   '               ,
Metastasis       varchar(64)  GENERATED ALWAYS AS (json_unquote(data->'$."Metastasis y=1 n=0"'))            COMMENT 'Metastasis '               ,
Lymphnodes       varchar(64)  GENERATED ALWAYS AS (json_unquote(data->'$."Lymphnodes y=1 n=0"'))            COMMENT 'Lymphnodes '               ,
Thrombosis       varchar(64)  GENERATED ALWAYS AS (json_unquote(data->'$."Portal Vein Thrombosis y=1 n=0"'))COMMENT 'Thrombosis '               ,
AFP              REAL         GENERATED ALWAYS AS (json_unquote(data->'$."AFP"')                          ) COMMENT 'Alpha feto protein'        ,
FirstLineTherapy varchar(64)  GENERATED ALWAYS AS (json_unquote(data->'$."first_line"')                   ) COMMENT 'First line therapy '       ,
BaselineDate     DATE         NULL                                                                          COMMENT 'Baseline Date '       ,
FollowupDate     DATE         NULL                                                                          COMMENT 'Followup Date '       ,
LobeLocation     varchar(128) GENERATED ALWAYS AS (json_unquote(data->'$."Target_lobe/s _of_Treatment"')  ) COMMENT 'Location information' ,
SegmentLocation  varchar(128) GENERATED ALWAYS AS (json_unquote(data->'$."Target_segment/s of treatment"')) COMMENT 'Location information' ,
BaselineStudyUID varchar(256) NULL COMMENT 'studyuid information if needed...' ,
FollowupStudyUID varchar(256) NULL COMMENT 'studyuid information if needed...' ,
MVIStatus        varchar(64)  NULL COMMENT 'micro vascular invasion data from Qayyum' ,
PNPLA3           varchar(64)  NULL COMMENT 'pnpla3 data',
PNPLA73          int          NULL COMMENT 'pnpla3 data',
pnpl2            int          NULL COMMENT 'pnpla3 data',
LabelTraining    int          GENERATED ALWAYS AS (json_unquote(data->'$."Kareems TACE cases=1 others=0"')) COMMENT 'Kareem Truth labels' ,
TTPTraining      INT          GENERATED ALWAYS AS (json_unquote(data->'$."1 = HCCs with shortest TTP 2 = HCCs with longest TTP"')              ) COMMENT 'Training Data Subset' ,
TTP              REAL         GENERATED ALWAYS AS (json_unquote(data->'$."TTP by week (from first TACE session to date of progression/Censoring)"')  ) COMMENT 'TTP ' ,
data             JSON         NULL ,
PRIMARY KEY (id) 
);

-- load treatment history 
-- python ./csvtojson.py --csvfile datalocation/TreatmentHistory.csv
LOAD DATA LOCAL INFILE './datalocation/TreatmentHistory.json'
INTO TABLE RandomForestHCCResponse.treatmenthistory(data)
set mrn=json_unquote(data->"$.mdacc"),dataID="TACE",BaselineDate=STR_TO_DATE(json_unquote(data->'$."Baseline1CT_date"'),'%m/%d/%Y'),FollowupDate=STR_TO_DATE(json_unquote(data->'$."FollowUpCT_date"'),'%m/%d/%Y');


-- load qayyum microvascular invasion data
insert into RandomForestHCCResponse.treatmenthistory(mrn,dataID,MVIStatus,BaselineDate,data)
SELECT JSON_UNQUOTE(eu.data->"$.""mdacc""") mrn, "MVI" dataID, JSON_UNQUOTE(eu.data->"$.""MVI status (Yes or No)""")  MVIStatus , JSON_UNQUOTE(eu.data->"$.""QayyumCases_Preoperative_CT_Data""") BaselineDate, eu.data
FROM ClinicalStudies.excelUpload eu where eu.uploadID = 30 and JSON_UNQUOTE(eu.data->"$.""I.D.""") is not null; 

-- load pnpla3 data
insert into RandomForestHCCResponse.treatmenthistory(mrn,dataID,BaselineDate,PNPLA3,PNPLA73,pnpl2,data)
SELECT JSON_UNQUOTE(eu.data->"$.""mdacc""") mrn, 
JSON_UNQUOTE(eu.data->"$.""Cases Description""") dataID, 
nullif(JSON_UNQUOTE(eu.data->"$."" First CT study with liver protocol in Clinic station_BL_CT"""),"N/A") BaselineDate, 
JSON_UNQUOTE(eu.data->"$.""rs738409(PNPLA3)""") PNPLA3,
JSON_UNQUOTE(eu.data->"$.""PNPLA_73(rs738409 categories)""") PNPLA73,
JSON_UNQUOTE(eu.data->"$.""pnpl2""") pnpl2,
eu.data
FROM ClinicalStudies.excelUpload eu where eu.uploadID = 29;

-- Update study UIDS... use manual data if available
update RandomForestHCCResponse.treatmenthistory th
  join RandomForestHCCResponse.imaginguids rf on  rf.StudyDate=th.BaselineDate  and rf.mrn=th.mrn
   SET th.BaselineStudyUID = coalesce(json_unquote(th.data->'$."BaselineStudyUID"'),rf.studyUID );
update RandomForestHCCResponse.treatmenthistory th
  join RandomForestHCCResponse.imaginguids rf on  rf.StudyDate=th.FollowupDate  and rf.mrn=th.mrn
   SET th.FollowupStudyUID = coalesce(json_unquote(th.data->'$."FollowupStudyUID"'),rf.studyUID );


-- load qa data
DROP PROCEDURE IF EXISTS RandomForestHCCResponse.DataQA ;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.DataQA
(IN csvfile  varchar(255))
BEGIN
  DROP TABLE IF EXISTS  RandomForestHCCResponse.qadata;
  CREATE TABLE RandomForestHCCResponse.qadata  (
   InstanceUID        VARCHAR(255)  NOT NULL COMMENT 'studyuid *OR* seriesUID', 
   Status             VARCHAR(80)   NOT NULL,  -- Data quality
   PRIMARY KEY (InstanceUID) );
END //
DELIMITER ;
show create procedure RandomForestHCCResponse.DataQA;
-- call RandomForestHCCResponse.ResetLabelStats();
-- select qa.* from  RandomForestHCCResponse.qadata qa where qa.Status='Good' ;
-- show create table RandomForestHCCResponse.qadata;
-- select rf.mrn, rf.TimeID, rf.TruthID,rf.StudyUID from RandomForestHCCResponse.qadata   qa   join RandomForestHCCResponse.imaginguids rf on rf.StudyUID=qa.InstanceUID where  qa.Status='Good'; 

DROP PROCEDURE IF EXISTS RandomForestHCCResponse.RFHCCDeps ;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.RFHCCDeps 
(IN csvfile  varchar(255))
BEGIN
-- FIXME replace csvfile  into  table
    SET SESSION group_concat_max_len = 10000000;
    select 'DCMNIFTISPLIT=/rsrch1/ip/dtfuentes/github/FileConversionScripts/seriesreadwriteall/DicomSeriesReadImageWriteAll';
    -- build all nifti
    select concat("NUMRAWPRE =",count(rf.SeriesACQPre)) from RandomForestHCCResponse.imaginguids rf where rf.SeriesACQPre is not null and rf.StudyDate is not null ;
    select concat("RAWPRE  =", group_concat( distinct
           CONCAT_WS('/','ImageDatabase', rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID, 'Pre.raw.nii.gz ' ) 
                              separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQPre is not null and rf.StudyDate is not null ;

    select concat("NUMRAWART =",count(rf.SeriesACQArt)) from RandomForestHCCResponse.imaginguids rf where rf.SeriesACQArt is not null and rf.StudyDate is not null ;
    select concat("RAWART  =", group_concat( distinct
           CONCAT_WS('/','ImageDatabase', rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID, 'Art.raw.nii.gz ' ) 
                              separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQArt is not null and rf.StudyDate is not null ;

    select concat("NUMRAWVEN =",count(rf.SeriesACQVen)) from RandomForestHCCResponse.imaginguids rf where rf.SeriesACQVen is not null and rf.StudyDate is not null ;
    select concat("RAWVEN  =", group_concat( distinct
           CONCAT_WS('/','ImageDatabase', rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID, 'Ven.raw.nii.gz ' ) 
                              separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQVen is not null and rf.StudyDate is not null ;

    select concat("NUMRAWDEL =",count(rf.SeriesACQDel)) from RandomForestHCCResponse.imaginguids rf where rf.SeriesACQDel is not null and rf.StudyDate is not null ;
    select concat("RAWDEL  =", group_concat( distinct
           CONCAT_WS('/','ImageDatabase', rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID, 'Del.raw.nii.gz ' ) 
                              separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQDel is not null and rf.StudyDate is not null ;

    select 'nifti: $(RAWPRE) $(RAWART) $(RAWVEN) $(RAWDEL)';
 
    -- baseline studies
    select concat("NUMBASELINE  =",count(rf.studyUID)) from RandomForestHCCResponse.imaginguids rf where rf.SeriesACQDel is not null and rf.TimeID = 'baseline' and (rf.truthID not in (1,2,3,4,5,6) or rf.truthID is null);
    select concat("BASELINE  =", group_concat( distinct
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID  ) 
                                separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQDel is not null and rf.TimeID = 'baseline' and (rf.truthID not in (1,2,3,4,5,6) or rf.truthID is null);

    -- followup studies
    select concat("NUMFOLLOWUP  =",count(rf.studyUID)) from RandomForestHCCResponse.imaginguids rf where rf.SeriesACQDel is not null and rf.TimeID = 'followup' and (rf.truthID not in (1,2,3,4,5,6) or rf.truthID is null);
    select concat("FOLLOWUP  =", group_concat( distinct
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID 
                 ) separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQDel is not null and rf.TimeID = 'followup' and (rf.truthID not in (1,2,3,4,5,6) or rf.truthID is null);

    -- separate training data sets
    select concat("NUMLEGACY     =",count(rf.studyUID)) from RandomForestHCCResponse.legacytrain rf ; 
    select concat("TRAININGLEGACY=", group_concat(
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.StudyUID, '-', ''), 'legacytrain'  ) 
                                separator ' ') )
    from RandomForestHCCResponse.legacytrain rf; 

    -- separate training data sets
    select concat("NUMTRAINING1  =",count(rf.studyUID)) from RandomForestHCCResponse.imaginguids rf where  rf.truthID = 1;
    select concat("TRAINING1  =", group_concat(
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID  ) 
                                separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQDel is not null and rf.truthID = 1;

    -- separate training data sets
    select concat("NUMTRAINING2  =",count(rf.studyUID)) from RandomForestHCCResponse.imaginguids rf where  rf.truthID = 2;
    select concat("TRAINING2  =", group_concat(
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID  ) 
                                separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQDel is not null and rf.truthID = 2;

    -- separate training data sets
    select concat("NUMTRAINING3  =",count(rf.studyUID)) from RandomForestHCCResponse.imaginguids rf where  rf.truthID = 3;
    select concat("TRAINING3  =", group_concat(
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID  ) 
                                separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQDel is not null and rf.truthID = 3;

    -- separate training data sets
    select concat("NUMTRAINING4  =",count(rf.studyUID)) from RandomForestHCCResponse.imaginguids rf where  rf.truthID = 4;
    select concat("TRAINING4  =", group_concat(
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID  ) 
                                separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQDel is not null and rf.truthID = 4;

    -- separate training data sets
    select concat("NUMTRAINING5  =",count(rf.studyUID)) from RandomForestHCCResponse.imaginguids rf where  rf.truthID = 5;
    select concat("TRAINING5  =", group_concat(
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID  ) 
                                separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQDel is not null and rf.truthID = 5;

    -- separate training data sets
    select concat("NUMTRAINING6  =",count(rf.studyUID)) from RandomForestHCCResponse.imaginguids rf where  rf.truthID = 6;
    select concat("TRAINING6  =", group_concat(
           CONCAT_WS('/',rf.mrn,  REPLACE(rf.StudyDate, '-', ''), rf.StudyUID  ) 
                                separator ' ') )
    from RandomForestHCCResponse.imaginguids rf
    where rf.SeriesACQDel is not null and rf.truthID = 6;

    -- setup metadata  - string formating pain
    select REPLACE(CONCAT('ImageDatabase/', rf.mrn, '/', REPLACE(rf.StudyDate, '-', ''),'/', rf.StudyUID, '/setup.json:\n\techo [', group_concat(JSON_OBJECT('mrn',rf.mrn,'dataid',rf.dataid, 'truthid', rf.truthid, 'timeid',rf.timeid )), '] > $@' ) , '\"','\\\"')
    from RandomForestHCCResponse.imaginguids rf 
    group by rf.StudyUID;

    -- convert to nifti 
    select CONCAT('ImageDatabase/', a.mrn, '/', REPLACE(sd.StudyDate, '-', ''),'/', a.StudyUID, '/', a.Phase ,'.raw.nii.gz: ImageDatabase/', a.mrn, '/', REPLACE(sd.StudyDate, '-', ''),'/', a.StudyUID, '/',a.SeriesUID, '/raw.xfer \n\tif [ ! -f ImageDatabase/', a.mrn, '/', REPLACE(sd.StudyDate, '-', ''),'/', a.StudyUID, '/',a.SeriesUID,'/',a.SeriesACQ,'.nii.gz   ] ; then mkdir -p ImageDatabase/', a.mrn, '/', REPLACE(sd.StudyDate, '-', ''),'/', a.StudyUID, '/',a.SeriesUID,' ;$(DCMNIFTISPLIT) $(subst ImageDatabase,/FUS4/IPVL_research,$(<D)) $(@D)  \'0008|0032\' ; else echo skipping network filesystem; fi\n\tln -snf ./',a.SeriesUID,'/',a.SeriesACQ,'.nii.gz $@; touch -h -r $(@D)/',a.SeriesUID,'/',a.SeriesACQ,'.nii.gz  $@;\n\tln -snf ./',a.SeriesUID,'/ $(subst .nii.gz,.dir,$@)') 
    from DICOMHeaders.studies             sd   
    join (select rf.mrn,'Pre' as Phase,rf.StudyUID as StudyUID,rf.SeriesUIDPre as SeriesUID,rf.SeriesACQPre as SeriesACQ from RandomForestHCCResponse.imaginguids rf union 
          select rf.mrn,'Art' as Phase,rf.StudyUID as StudyUID,rf.SeriesUIDArt as SeriesUID,rf.SeriesACQArt as SeriesACQ from RandomForestHCCResponse.imaginguids rf union 
          select rf.mrn,'Ven' as Phase,rf.StudyUID as StudyUID,rf.SeriesUIDVen as SeriesUID,rf.SeriesACQVen as SeriesACQ from RandomForestHCCResponse.imaginguids rf union 
          select rf.mrn,'Del' as Phase,rf.StudyUID as StudyUID,rf.SeriesUIDDel as SeriesUID,rf.SeriesACQDel as SeriesACQ from RandomForestHCCResponse.imaginguids rf 
         ) a on a.StudyUID=sd.studyInstanceUID
    where a.SeriesACQ is not null 
    group by a.SeriesUID, a.SeriesACQ;
END //
DELIMITER ;
-- show create procedure RandomForestHCCResponse.RFHCCDeps ;
-- call RandomForestHCCResponse.RFHCCDeps();
-- mysql  -sNre "call RandomForestHCCResponse.RFHCCDeps('test.csv');"

DROP PROCEDURE IF EXISTS RandomForestHCCResponse.LesionCSVMRF;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.LesionCSVMRF()
BEGIN
select  a.mrn, a.TIMEID, a.DataID, a.TruthID,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/Truth.nii.gz'                                            ) TRUTH                                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/LIVERMASK.nii.gz'                                        ) MASKIMAGE                            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LEFTLUNGDISTANCE.nii.gz'                   ) LEFTLUNGDISTANCE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/RIGHTLUNGDISTANCE.nii.gz'                  ) RIGHTLUNGDISTANCE                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LANDMARKDISTANCE0.nii.gz'                  ) LANDMARKDISTANCE0                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LANDMARKDISTANCE1.nii.gz'                  ) LANDMARKDISTANCE1                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LANDMARKDISTANCE2.nii.gz'                  ) LANDMARKDISTANCE2                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/HESSOBJ.nii.gz'                            ) HESSOBJ                              ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/NORMALIZEDDISTANCE.nii.gz'                 ) NORMALIZEDDISTANCE                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/DENOISEArtDelDeriv.nii.gz'                 ) DENOISEArtDelDeriv                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/DENOISEArtVenDeriv.nii.gz'                 ) DENOISEArtVenDeriv                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/DENOISEPreArtDeriv.nii.gz'                 ) DENOISEPreArtDeriv                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/DENOISEVenDelDeriv.nii.gz'                 ) DENOISEVenDelDeriv                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_RAWIMAGE.nii.gz'                       ) Pre_RAWIMAGE                         ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_DENOISE.nii.gz'                        ) Pre_DENOISE                          ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_GRADIENT.nii.gz'                       ) Pre_GRADIENT                         ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ATROPOS_MAP_MRF_POSTERIORS1.nii.gz'    ) Pre_ATROPOS_MAP_MRF_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ATROPOS_MAP_MRF_POSTERIORS2.nii.gz'    ) Pre_ATROPOS_MAP_MRF_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ATROPOS_MAP_MRF_POSTERIORS3.nii.gz'    ) Pre_ATROPOS_MAP_MRF_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ATROPOS_MAP_MRF_LABEL1_DISTANCE.nii.gz') Pre_ATROPOS_MAP_MRF_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_MEAN_RADIUS_1.nii.gz'                  ) Pre_MEAN_RADIUS_1                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_MEAN_RADIUS_3.nii.gz'                  ) Pre_MEAN_RADIUS_3                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_MEAN_RADIUS_5.nii.gz'                  ) Pre_MEAN_RADIUS_5                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SIGMA_RADIUS_1.nii.gz'                 ) Pre_SIGMA_RADIUS_1                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SIGMA_RADIUS_3.nii.gz'                 ) Pre_SIGMA_RADIUS_3                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SIGMA_RADIUS_5.nii.gz'                 ) Pre_SIGMA_RADIUS_5                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SKEWNESS_RADIUS_1.nii.gz'              ) Pre_SKEWNESS_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SKEWNESS_RADIUS_3.nii.gz'              ) Pre_SKEWNESS_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SKEWNESS_RADIUS_5.nii.gz'              ) Pre_SKEWNESS_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ENTROPY_RADIUS_1.nii.gz'               ) Pre_ENTROPY_RADIUS_1                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ENTROPY_RADIUS_3.nii.gz'               ) Pre_ENTROPY_RADIUS_3                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ENTROPY_RADIUS_5.nii.gz'               ) Pre_ENTROPY_RADIUS_5                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_RAWIMAGE.nii.gz'                       ) Art_RAWIMAGE                         ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_DENOISE.nii.gz'                        ) Art_DENOISE                          ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_GRADIENT.nii.gz'                       ) Art_GRADIENT                         ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ATROPOS_MAP_MRF_POSTERIORS1.nii.gz'    ) Art_ATROPOS_MAP_MRF_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ATROPOS_MAP_MRF_POSTERIORS2.nii.gz'    ) Art_ATROPOS_MAP_MRF_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ATROPOS_MAP_MRF_POSTERIORS3.nii.gz'    ) Art_ATROPOS_MAP_MRF_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ATROPOS_MAP_MRF_LABEL1_DISTANCE.nii.gz') Art_ATROPOS_MAP_MRF_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_MEAN_RADIUS_1.nii.gz'                  ) Art_MEAN_RADIUS_1                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_MEAN_RADIUS_3.nii.gz'                  ) Art_MEAN_RADIUS_3                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_MEAN_RADIUS_5.nii.gz'                  ) Art_MEAN_RADIUS_5                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SIGMA_RADIUS_1.nii.gz'                 ) Art_SIGMA_RADIUS_1                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SIGMA_RADIUS_3.nii.gz'                 ) Art_SIGMA_RADIUS_3                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SIGMA_RADIUS_5.nii.gz'                 ) Art_SIGMA_RADIUS_5                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SKEWNESS_RADIUS_1.nii.gz'              ) Art_SKEWNESS_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SKEWNESS_RADIUS_3.nii.gz'              ) Art_SKEWNESS_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SKEWNESS_RADIUS_5.nii.gz'              ) Art_SKEWNESS_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ENTROPY_RADIUS_1.nii.gz'               ) Art_ENTROPY_RADIUS_1                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ENTROPY_RADIUS_3.nii.gz'               ) Art_ENTROPY_RADIUS_3                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ENTROPY_RADIUS_5.nii.gz'               ) Art_ENTROPY_RADIUS_5                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_RAWIMAGE.nii.gz'                       ) Ven_RAWIMAGE                         ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_DENOISE.nii.gz'                        ) Ven_DENOISE                          ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_GRADIENT.nii.gz'                       ) Ven_GRADIENT                         ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ATROPOS_MAP_MRF_POSTERIORS1.nii.gz'    ) Ven_ATROPOS_MAP_MRF_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ATROPOS_MAP_MRF_POSTERIORS2.nii.gz'    ) Ven_ATROPOS_MAP_MRF_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ATROPOS_MAP_MRF_POSTERIORS3.nii.gz'    ) Ven_ATROPOS_MAP_MRF_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ATROPOS_MAP_MRF_LABEL1_DISTANCE.nii.gz') Ven_ATROPOS_MAP_MRF_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_MEAN_RADIUS_1.nii.gz'                  ) Ven_MEAN_RADIUS_1                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_MEAN_RADIUS_3.nii.gz'                  ) Ven_MEAN_RADIUS_3                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_MEAN_RADIUS_5.nii.gz'                  ) Ven_MEAN_RADIUS_5                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SIGMA_RADIUS_1.nii.gz'                 ) Ven_SIGMA_RADIUS_1                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SIGMA_RADIUS_3.nii.gz'                 ) Ven_SIGMA_RADIUS_3                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SIGMA_RADIUS_5.nii.gz'                 ) Ven_SIGMA_RADIUS_5                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SKEWNESS_RADIUS_1.nii.gz'              ) Ven_SKEWNESS_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SKEWNESS_RADIUS_3.nii.gz'              ) Ven_SKEWNESS_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SKEWNESS_RADIUS_5.nii.gz'              ) Ven_SKEWNESS_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ENTROPY_RADIUS_1.nii.gz'               ) Ven_ENTROPY_RADIUS_1                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ENTROPY_RADIUS_3.nii.gz'               ) Ven_ENTROPY_RADIUS_3                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ENTROPY_RADIUS_5.nii.gz'               ) Ven_ENTROPY_RADIUS_5                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_RAWIMAGE.nii.gz'                       ) Del_RAWIMAGE                         ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_DENOISE.nii.gz'                        ) Del_DENOISE                          ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_GRADIENT.nii.gz'                       ) Del_GRADIENT                         ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ATROPOS_MAP_MRF_POSTERIORS1.nii.gz'    ) Del_ATROPOS_MAP_MRF_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ATROPOS_MAP_MRF_POSTERIORS2.nii.gz'    ) Del_ATROPOS_MAP_MRF_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ATROPOS_MAP_MRF_POSTERIORS3.nii.gz'    ) Del_ATROPOS_MAP_MRF_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ATROPOS_MAP_MRF_LABEL1_DISTANCE.nii.gz') Del_ATROPOS_MAP_MRF_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_MEAN_RADIUS_1.nii.gz'                  ) Del_MEAN_RADIUS_1                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_MEAN_RADIUS_3.nii.gz'                  ) Del_MEAN_RADIUS_3                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_MEAN_RADIUS_5.nii.gz'                  ) Del_MEAN_RADIUS_5                    ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SIGMA_RADIUS_1.nii.gz'                 ) Del_SIGMA_RADIUS_1                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SIGMA_RADIUS_3.nii.gz'                 ) Del_SIGMA_RADIUS_3                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SIGMA_RADIUS_5.nii.gz'                 ) Del_SIGMA_RADIUS_5                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SKEWNESS_RADIUS_1.nii.gz'              ) Del_SKEWNESS_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SKEWNESS_RADIUS_3.nii.gz'              ) Del_SKEWNESS_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SKEWNESS_RADIUS_5.nii.gz'              ) Del_SKEWNESS_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ENTROPY_RADIUS_1.nii.gz'               ) Del_ENTROPY_RADIUS_1                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ENTROPY_RADIUS_3.nii.gz'               ) Del_ENTROPY_RADIUS_3                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ENTROPY_RADIUS_5.nii.gz'               ) Del_ENTROPY_RADIUS_5                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/LABELSMRF.nii.gz'                                        ) SOLUTION             
from DICOMHeaders.studies             sd   
join RandomForestHCCResponse.qadata   qa   on sd.studyInstanceUID=qa.InstanceUID   
join (select rf.mrn, rf.TimeID, rf.DataID,rf.TruthID,rf.StudyUID from RandomForestHCCResponse.imaginguids rf  where rf.SeriesACQDel is not null  and rf.TruthID > 0
     ) a on a.StudyUID=qa.InstanceUID
where  qa.Status='Good'; 
END //
DELIMITER ;
-- show create procedure RandomForestHCCResponse.LesionCSVMRF ;
-- call RandomForestHCCResponse.LesionCSVMRF();

DROP PROCEDURE IF EXISTS RandomForestHCCResponse.LesionCSV;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.LesionCSV()
BEGIN
select  a.mrn, a.TIMEID, a.DataID, a.TruthID,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/Truth.nii.gz'                                        ) TRUTH                            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/LIVERMASK.nii.gz'                                    ) MASKIMAGE                        ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LEFTLUNGDISTANCE.nii.gz'               ) LEFTLUNGDISTANCE                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/RIGHTLUNGDISTANCE.nii.gz'              ) RIGHTLUNGDISTANCE                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LANDMARKDISTANCE0.nii.gz'              ) LANDMARKDISTANCE0                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LANDMARKDISTANCE1.nii.gz'              ) LANDMARKDISTANCE1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LANDMARKDISTANCE2.nii.gz'              ) LANDMARKDISTANCE2                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/HESSOBJ.nii.gz'                        ) HESSOBJ                          ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/NORMALIZEDDISTANCE.nii.gz'             ) NORMALIZEDDISTANCE               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/DENOISEArtDelDeriv.nii.gz'             ) DENOISEArtDelDeriv               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/DENOISEArtVenDeriv.nii.gz'             ) DENOISEArtVenDeriv               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/DENOISEPreArtDeriv.nii.gz'             ) DENOISEPreArtDeriv               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/DENOISEVenDelDeriv.nii.gz'             ) DENOISEVenDelDeriv               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_RAWIMAGE.nii.gz'                   ) Pre_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_DENOISE.nii.gz'                    ) Pre_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_GRADIENT.nii.gz'                   ) Pre_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ATROPOS_GMM_POSTERIORS1.nii.gz'    ) Pre_ATROPOS_GMM_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ATROPOS_GMM_POSTERIORS2.nii.gz'    ) Pre_ATROPOS_GMM_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ATROPOS_GMM_POSTERIORS3.nii.gz'    ) Pre_ATROPOS_GMM_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ATROPOS_GMM_LABEL1_DISTANCE.nii.gz') Pre_ATROPOS_GMM_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_MEAN_RADIUS_1.nii.gz'              ) Pre_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_MEAN_RADIUS_3.nii.gz'              ) Pre_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_MEAN_RADIUS_5.nii.gz'              ) Pre_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SIGMA_RADIUS_1.nii.gz'             ) Pre_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SIGMA_RADIUS_3.nii.gz'             ) Pre_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SIGMA_RADIUS_5.nii.gz'             ) Pre_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SKEWNESS_RADIUS_1.nii.gz'          ) Pre_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SKEWNESS_RADIUS_3.nii.gz'          ) Pre_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SKEWNESS_RADIUS_5.nii.gz'          ) Pre_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ENTROPY_RADIUS_1.nii.gz'           ) Pre_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ENTROPY_RADIUS_3.nii.gz'           ) Pre_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ENTROPY_RADIUS_5.nii.gz'           ) Pre_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_RAWIMAGE.nii.gz'                   ) Art_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_DENOISE.nii.gz'                    ) Art_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_GRADIENT.nii.gz'                   ) Art_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ATROPOS_GMM_POSTERIORS1.nii.gz'    ) Art_ATROPOS_GMM_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ATROPOS_GMM_POSTERIORS2.nii.gz'    ) Art_ATROPOS_GMM_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ATROPOS_GMM_POSTERIORS3.nii.gz'    ) Art_ATROPOS_GMM_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ATROPOS_GMM_LABEL1_DISTANCE.nii.gz') Art_ATROPOS_GMM_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_MEAN_RADIUS_1.nii.gz'              ) Art_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_MEAN_RADIUS_3.nii.gz'              ) Art_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_MEAN_RADIUS_5.nii.gz'              ) Art_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SIGMA_RADIUS_1.nii.gz'             ) Art_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SIGMA_RADIUS_3.nii.gz'             ) Art_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SIGMA_RADIUS_5.nii.gz'             ) Art_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SKEWNESS_RADIUS_1.nii.gz'          ) Art_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SKEWNESS_RADIUS_3.nii.gz'          ) Art_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SKEWNESS_RADIUS_5.nii.gz'          ) Art_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ENTROPY_RADIUS_1.nii.gz'           ) Art_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ENTROPY_RADIUS_3.nii.gz'           ) Art_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ENTROPY_RADIUS_5.nii.gz'           ) Art_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_RAWIMAGE.nii.gz'                   ) Ven_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_DENOISE.nii.gz'                    ) Ven_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_GRADIENT.nii.gz'                   ) Ven_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ATROPOS_GMM_POSTERIORS1.nii.gz'    ) Ven_ATROPOS_GMM_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ATROPOS_GMM_POSTERIORS2.nii.gz'    ) Ven_ATROPOS_GMM_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ATROPOS_GMM_POSTERIORS3.nii.gz'    ) Ven_ATROPOS_GMM_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ATROPOS_GMM_LABEL1_DISTANCE.nii.gz') Ven_ATROPOS_GMM_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_MEAN_RADIUS_1.nii.gz'              ) Ven_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_MEAN_RADIUS_3.nii.gz'              ) Ven_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_MEAN_RADIUS_5.nii.gz'              ) Ven_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SIGMA_RADIUS_1.nii.gz'             ) Ven_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SIGMA_RADIUS_3.nii.gz'             ) Ven_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SIGMA_RADIUS_5.nii.gz'             ) Ven_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SKEWNESS_RADIUS_1.nii.gz'          ) Ven_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SKEWNESS_RADIUS_3.nii.gz'          ) Ven_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SKEWNESS_RADIUS_5.nii.gz'          ) Ven_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ENTROPY_RADIUS_1.nii.gz'           ) Ven_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ENTROPY_RADIUS_3.nii.gz'           ) Ven_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ENTROPY_RADIUS_5.nii.gz'           ) Ven_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_RAWIMAGE.nii.gz'                   ) Del_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_DENOISE.nii.gz'                    ) Del_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_GRADIENT.nii.gz'                   ) Del_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ATROPOS_GMM_POSTERIORS1.nii.gz'    ) Del_ATROPOS_GMM_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ATROPOS_GMM_POSTERIORS2.nii.gz'    ) Del_ATROPOS_GMM_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ATROPOS_GMM_POSTERIORS3.nii.gz'    ) Del_ATROPOS_GMM_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ATROPOS_GMM_LABEL1_DISTANCE.nii.gz') Del_ATROPOS_GMM_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_MEAN_RADIUS_1.nii.gz'              ) Del_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_MEAN_RADIUS_3.nii.gz'              ) Del_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_MEAN_RADIUS_5.nii.gz'              ) Del_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SIGMA_RADIUS_1.nii.gz'             ) Del_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SIGMA_RADIUS_3.nii.gz'             ) Del_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SIGMA_RADIUS_5.nii.gz'             ) Del_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SKEWNESS_RADIUS_1.nii.gz'          ) Del_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SKEWNESS_RADIUS_3.nii.gz'          ) Del_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SKEWNESS_RADIUS_5.nii.gz'          ) Del_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ENTROPY_RADIUS_1.nii.gz'           ) Del_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ENTROPY_RADIUS_3.nii.gz'           ) Del_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ENTROPY_RADIUS_5.nii.gz'           ) Del_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/LABELSGMM.nii.gz'                                    ) SOLUTION             
from DICOMHeaders.studies             sd   
join RandomForestHCCResponse.qadata   qa   on sd.studyInstanceUID=qa.InstanceUID   
join (select rf.mrn, rf.TimeID, rf.DataID,rf.TruthID,rf.StudyUID from RandomForestHCCResponse.imaginguids rf  where rf.SeriesACQDel is not null  and rf.TruthID > 0
     ) a on a.StudyUID=qa.InstanceUID
where  qa.Status='Good'; 
END //
DELIMITER ;
-- show create procedure RandomForestHCCResponse.LesionCSV ;
-- call RandomForestHCCResponse.LesionCSV();

DROP PROCEDURE IF EXISTS RandomForestHCCResponse.LiverMaskCSV;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.LiverMaskCSV()
BEGIN
select  a.mrn, a.TIMEID, a.DataID,a.TruthID,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/Truth.nii.gz'                                        ) TRUTH                            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/tissuemask.nii.gz'                                   ) MASKIMAGE                        ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LEFTLUNGDISTANCE.nii.gz'               ) LEFTLUNGDISTANCE                 ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/RIGHTLUNGDISTANCE.nii.gz'              ) RIGHTLUNGDISTANCE                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LANDMARKDISTANCE0.nii.gz'              ) LANDMARKDISTANCE0                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LANDMARKDISTANCE1.nii.gz'              ) LANDMARKDISTANCE1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/LANDMARKDISTANCE2.nii.gz'              ) LANDMARKDISTANCE2                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/HESSOBJ.nii.gz'                        ) HESSOBJ                          ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/TISSUEDISTANCE.nii.gz'                 ) TISSUEDISTANCE                   ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_RAWIMAGE.nii.gz'                   ) Pre_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_DENOISE.nii.gz'                    ) Pre_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_GRADIENT.nii.gz'                   ) Pre_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_MEAN_RADIUS_1.nii.gz'              ) Pre_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_MEAN_RADIUS_3.nii.gz'              ) Pre_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_MEAN_RADIUS_5.nii.gz'              ) Pre_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SIGMA_RADIUS_1.nii.gz'             ) Pre_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SIGMA_RADIUS_3.nii.gz'             ) Pre_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SIGMA_RADIUS_5.nii.gz'             ) Pre_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SKEWNESS_RADIUS_1.nii.gz'          ) Pre_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SKEWNESS_RADIUS_3.nii.gz'          ) Pre_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_SKEWNESS_RADIUS_5.nii.gz'          ) Pre_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ENTROPY_RADIUS_1.nii.gz'           ) Pre_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ENTROPY_RADIUS_3.nii.gz'           ) Pre_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Pre_ENTROPY_RADIUS_5.nii.gz'           ) Pre_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_RAWIMAGE.nii.gz'                   ) Art_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_DENOISE.nii.gz'                    ) Art_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_GRADIENT.nii.gz'                   ) Art_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_MEAN_RADIUS_1.nii.gz'              ) Art_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_MEAN_RADIUS_3.nii.gz'              ) Art_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_MEAN_RADIUS_5.nii.gz'              ) Art_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SIGMA_RADIUS_1.nii.gz'             ) Art_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SIGMA_RADIUS_3.nii.gz'             ) Art_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SIGMA_RADIUS_5.nii.gz'             ) Art_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SKEWNESS_RADIUS_1.nii.gz'          ) Art_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SKEWNESS_RADIUS_3.nii.gz'          ) Art_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_SKEWNESS_RADIUS_5.nii.gz'          ) Art_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ENTROPY_RADIUS_1.nii.gz'           ) Art_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ENTROPY_RADIUS_3.nii.gz'           ) Art_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Art_ENTROPY_RADIUS_5.nii.gz'           ) Art_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_RAWIMAGE.nii.gz'                   ) Ven_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_DENOISE.nii.gz'                    ) Ven_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_GRADIENT.nii.gz'                   ) Ven_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_MEAN_RADIUS_1.nii.gz'              ) Ven_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_MEAN_RADIUS_3.nii.gz'              ) Ven_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_MEAN_RADIUS_5.nii.gz'              ) Ven_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SIGMA_RADIUS_1.nii.gz'             ) Ven_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SIGMA_RADIUS_3.nii.gz'             ) Ven_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SIGMA_RADIUS_5.nii.gz'             ) Ven_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SKEWNESS_RADIUS_1.nii.gz'          ) Ven_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SKEWNESS_RADIUS_3.nii.gz'          ) Ven_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_SKEWNESS_RADIUS_5.nii.gz'          ) Ven_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ENTROPY_RADIUS_1.nii.gz'           ) Ven_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ENTROPY_RADIUS_3.nii.gz'           ) Ven_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Ven_ENTROPY_RADIUS_5.nii.gz'           ) Ven_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_RAWIMAGE.nii.gz'                   ) Del_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_DENOISE.nii.gz'                    ) Del_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_GRADIENT.nii.gz'                   ) Del_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_MEAN_RADIUS_1.nii.gz'              ) Del_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_MEAN_RADIUS_3.nii.gz'              ) Del_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_MEAN_RADIUS_5.nii.gz'              ) Del_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SIGMA_RADIUS_1.nii.gz'             ) Del_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SIGMA_RADIUS_3.nii.gz'             ) Del_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SIGMA_RADIUS_5.nii.gz'             ) Del_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SKEWNESS_RADIUS_1.nii.gz'          ) Del_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SKEWNESS_RADIUS_3.nii.gz'          ) Del_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_SKEWNESS_RADIUS_5.nii.gz'          ) Del_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ENTROPY_RADIUS_1.nii.gz'           ) Del_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ENTROPY_RADIUS_3.nii.gz'           ) Del_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/featureimages/Del_ENTROPY_RADIUS_5.nii.gz'           ) Del_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(sd.StudyDate,'-',''),'/',sd.studyInstanceUID,'/LIVERMASK.nii.gz'                                    ) SOLUTION             
from DICOMHeaders.studies             sd   
join RandomForestHCCResponse.qadata   qa   on sd.studyInstanceUID=qa.InstanceUID   
join (select rf.mrn, rf.TimeID, rf.DataID, rf.TruthID,rf.StudyUID from RandomForestHCCResponse.imaginguids rf  where rf.SeriesACQDel is not null  and rf.TruthID > 0
     ) a on a.StudyUID=qa.InstanceUID
where  qa.Status='Good'; 
END //
DELIMITER ;
-- select rf.mrn, rf.TimeID, rf.StudyUID from RandomForestHCCResponse.imaginguids rf  where rf.TruthID = 1 order by rf.mrn;
-- show create procedure RandomForestHCCResponse.LiverMaskCSV ;
-- call RandomForestHCCResponse.LiverMaskCSV();

DROP PROCEDURE IF EXISTS RandomForestHCCResponse.LegacyCSV;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.LegacyCSV()
BEGIN
select  a.mrn, a.StudyUID as TimeID, CASE WHEN a.dataid = "TACE" THEN 1 WHEN a.dataid="Sorafenib" THEN 2  END  DataID , -1 as TruthID,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/Truth.nii.gz'                                        ) TRUTH                            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/LIVERMASK.nii.gz'                                    ) MASKIMAGE                        ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/NORMALIZEDDISTANCE.nii.gz'             ) NORMALIZEDDISTANCE               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/DENOISEArtDelDeriv.nii.gz'             ) DENOISEArtDelDeriv               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/DENOISEArtVenDeriv.nii.gz'             ) DENOISEArtVenDeriv               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/DENOISEPreArtDeriv.nii.gz'             ) DENOISEPreArtDeriv               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/DENOISEVenDelDeriv.nii.gz'             ) DENOISEVenDelDeriv               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_RAWIMAGE.nii.gz'                   ) Pre_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_DENOISE.nii.gz'                    ) Pre_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_GRADIENT.nii.gz'                   ) Pre_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_ATROPOS_GMM_POSTERIORS1.nii.gz'    ) Pre_ATROPOS_GMM_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_ATROPOS_GMM_POSTERIORS2.nii.gz'    ) Pre_ATROPOS_GMM_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_ATROPOS_GMM_POSTERIORS3.nii.gz'    ) Pre_ATROPOS_GMM_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_ATROPOS_GMM_LABEL1_DISTANCE.nii.gz') Pre_ATROPOS_GMM_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_MEAN_RADIUS_1.nii.gz'              ) Pre_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_MEAN_RADIUS_3.nii.gz'              ) Pre_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_MEAN_RADIUS_5.nii.gz'              ) Pre_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_SIGMA_RADIUS_1.nii.gz'             ) Pre_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_SIGMA_RADIUS_3.nii.gz'             ) Pre_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_SIGMA_RADIUS_5.nii.gz'             ) Pre_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_SKEWNESS_RADIUS_1.nii.gz'          ) Pre_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_SKEWNESS_RADIUS_3.nii.gz'          ) Pre_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_SKEWNESS_RADIUS_5.nii.gz'          ) Pre_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_ENTROPY_RADIUS_1.nii.gz'           ) Pre_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_ENTROPY_RADIUS_3.nii.gz'           ) Pre_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Pre_ENTROPY_RADIUS_5.nii.gz'           ) Pre_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_RAWIMAGE.nii.gz'                   ) Art_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_DENOISE.nii.gz'                    ) Art_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_GRADIENT.nii.gz'                   ) Art_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_ATROPOS_GMM_POSTERIORS1.nii.gz'    ) Art_ATROPOS_GMM_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_ATROPOS_GMM_POSTERIORS2.nii.gz'    ) Art_ATROPOS_GMM_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_ATROPOS_GMM_POSTERIORS3.nii.gz'    ) Art_ATROPOS_GMM_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_ATROPOS_GMM_LABEL1_DISTANCE.nii.gz') Art_ATROPOS_GMM_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_MEAN_RADIUS_1.nii.gz'              ) Art_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_MEAN_RADIUS_3.nii.gz'              ) Art_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_MEAN_RADIUS_5.nii.gz'              ) Art_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_SIGMA_RADIUS_1.nii.gz'             ) Art_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_SIGMA_RADIUS_3.nii.gz'             ) Art_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_SIGMA_RADIUS_5.nii.gz'             ) Art_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_SKEWNESS_RADIUS_1.nii.gz'          ) Art_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_SKEWNESS_RADIUS_3.nii.gz'          ) Art_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_SKEWNESS_RADIUS_5.nii.gz'          ) Art_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_ENTROPY_RADIUS_1.nii.gz'           ) Art_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_ENTROPY_RADIUS_3.nii.gz'           ) Art_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Art_ENTROPY_RADIUS_5.nii.gz'           ) Art_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_RAWIMAGE.nii.gz'                   ) Ven_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_DENOISE.nii.gz'                    ) Ven_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_GRADIENT.nii.gz'                   ) Ven_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_ATROPOS_GMM_POSTERIORS1.nii.gz'    ) Ven_ATROPOS_GMM_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_ATROPOS_GMM_POSTERIORS2.nii.gz'    ) Ven_ATROPOS_GMM_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_ATROPOS_GMM_POSTERIORS3.nii.gz'    ) Ven_ATROPOS_GMM_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_ATROPOS_GMM_LABEL1_DISTANCE.nii.gz') Ven_ATROPOS_GMM_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_MEAN_RADIUS_1.nii.gz'              ) Ven_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_MEAN_RADIUS_3.nii.gz'              ) Ven_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_MEAN_RADIUS_5.nii.gz'              ) Ven_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_SIGMA_RADIUS_1.nii.gz'             ) Ven_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_SIGMA_RADIUS_3.nii.gz'             ) Ven_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_SIGMA_RADIUS_5.nii.gz'             ) Ven_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_SKEWNESS_RADIUS_1.nii.gz'          ) Ven_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_SKEWNESS_RADIUS_3.nii.gz'          ) Ven_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_SKEWNESS_RADIUS_5.nii.gz'          ) Ven_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_ENTROPY_RADIUS_1.nii.gz'           ) Ven_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_ENTROPY_RADIUS_3.nii.gz'           ) Ven_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Ven_ENTROPY_RADIUS_5.nii.gz'           ) Ven_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_RAWIMAGE.nii.gz'                   ) Del_RAWIMAGE                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_DENOISE.nii.gz'                    ) Del_DENOISE                      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_GRADIENT.nii.gz'                   ) Del_GRADIENT                     ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_ATROPOS_GMM_POSTERIORS1.nii.gz'    ) Del_ATROPOS_GMM_POSTERIORS1      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_ATROPOS_GMM_POSTERIORS2.nii.gz'    ) Del_ATROPOS_GMM_POSTERIORS2      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_ATROPOS_GMM_POSTERIORS3.nii.gz'    ) Del_ATROPOS_GMM_POSTERIORS3      ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_ATROPOS_GMM_LABEL1_DISTANCE.nii.gz') Del_ATROPOS_GMM_LABEL1_DISTANCE  ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_MEAN_RADIUS_1.nii.gz'              ) Del_MEAN_RADIUS_1                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_MEAN_RADIUS_3.nii.gz'              ) Del_MEAN_RADIUS_3                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_MEAN_RADIUS_5.nii.gz'              ) Del_MEAN_RADIUS_5                ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_SIGMA_RADIUS_1.nii.gz'             ) Del_SIGMA_RADIUS_1               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_SIGMA_RADIUS_3.nii.gz'             ) Del_SIGMA_RADIUS_3               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_SIGMA_RADIUS_5.nii.gz'             ) Del_SIGMA_RADIUS_5               ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_SKEWNESS_RADIUS_1.nii.gz'          ) Del_SKEWNESS_RADIUS_1            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_SKEWNESS_RADIUS_3.nii.gz'          ) Del_SKEWNESS_RADIUS_3            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_SKEWNESS_RADIUS_5.nii.gz'          ) Del_SKEWNESS_RADIUS_5            ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_ENTROPY_RADIUS_1.nii.gz'           ) Del_ENTROPY_RADIUS_1             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_ENTROPY_RADIUS_3.nii.gz'           ) Del_ENTROPY_RADIUS_3             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/featureimages/Del_ENTROPY_RADIUS_5.nii.gz'           ) Del_ENTROPY_RADIUS_5             ,
  CONCAT('ImageDatabase/',     a.mrn,'/',REPLACE(a.StudyUID,'-',''),'/legacytrain/LABELSGMM.nii.gz'                                    ) SOLUTION             
from RandomForestHCCResponse.legacytrain a; 
END //
DELIMITER ;
-- show create procedure RandomForestHCCResponse.LegacyCSV ;
-- call RandomForestHCCResponse.LegacyCSV();

DROP PROCEDURE IF EXISTS RandomForestHCCResponse.HCCPathOutput ;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.HCCPathOutput 
(IN radius int)
BEGIN
select md.Rat, md.TimePoint, md.PathologyHE, hee.mean as EntropyHE,heh.mean as HaralickHE, hev.mean as DistViableHE, hen.mean as DistNecrosisHE, md.PathologyPimo ,pie.mean as EntropyPimo,pih.mean as HaralickPimo, pio.mean as DistO2Pimo,md.metadata
from        RandomForestHCCResponse.metadata md
left  join  RandomForestHCCResponse.lstat    heh  on (md.Rat=heh.InstanceUID and heh.LabelID = 4 and heh.FeatureID=CONCAT('PathHE000.HaralickCorrelation_',radius ,'.nii.gz'))
left  join  RandomForestHCCResponse.lstat    pih  on (md.Rat=pih.InstanceUID and pih.LabelID = 4 and pih.FeatureID=CONCAT('PathPIMO000.HaralickCorrelation_',radius ,'.nii.gz')) 
left  join  RandomForestHCCResponse.lstat    hev  on (md.Rat=hev.InstanceUID and hev.LabelID = 1 and hev.FeatureID=CONCAT('PathHELMdist.nii.gz'))
left  join  RandomForestHCCResponse.lstat    hen  on (md.Rat=hen.InstanceUID and hen.LabelID = 3 and hen.FeatureID=CONCAT('PathHELMdist.nii.gz'))
left  join  RandomForestHCCResponse.lstat    pio  on (md.Rat=pio.InstanceUID and pio.LabelID = 1 and pio.FeatureID=CONCAT('PathPIMOLMdist.nii.gz'))
left  join  RandomForestHCCResponse.lstat    hee  on (md.Rat=hee.InstanceUID and hee.LabelID = 4 and hee.FeatureID=CONCAT('PathHE000.Entropy_',radius ,'.nii.gz'))
left  join  RandomForestHCCResponse.lstat    pie  on (md.Rat=pie.InstanceUID and pie.LabelID = 4 and pie.FeatureID=CONCAT('PathPIMO000.Entropy_',radius ,'.nii.gz'));
END //
DELIMITER ;
-- show create procedure RandomForestHCCResponse.HCCPathOutput;
-- call RandomForestHCCResponse.HCCPathOutput(20);
-- mysql  -re "call RandomForestHCCResponse.HCCPathOutput(20);" | sed "s/\t/,/g;s/NULL//g" > analysissummary.csv

-- format data for analysis 
-- build transpose command
SET SESSION group_concat_max_len = 10000000;
SET @dynamicsql = NULL;
SELECT
  GROUP_CONCAT(DISTINCT
    CONCAT(
      'group_concat( distinct CASE WHEN fi.id = ',
      fi.id,
      ' THEN vl.mean  END ) as  ',
      fi.featureid
    )
  ) INTO @dynamicsql
FROM RandomForestHCCResponse.ImageFeatures fi;
-- HACK copy paste dynamic code generation below
select  @dynamicsql;

SET @dynamicsql = NULL;
SELECT
  GROUP_CONCAT(DISTINCT
    CONCAT( 'a.', fi.featureid)
  ) INTO @dynamicsql
FROM RandomForestHCCResponse.ImageFeatures fi;
-- HACK copy paste dynamic code generation below
select  @dynamicsql;

-- WIP: @thomas-nguyen-3 @pvtruong-mdacc @wstefan
DROP PROCEDURE IF EXISTS RandomForestHCCResponse.DataMatrix ;
DELIMITER //
CREATE PROCEDURE RandomForestHCCResponse.DataMatrix 
(IN analysisID varchar(255) )
BEGIN
   -- set  @varAnalysis='Truth' collate utf8_unicode_ci;
   set  @varAnalysis=analysisID;
   -- select  a.mrn, a.TIMEID, sd.studyInstanceUID, lk.location,  
   select th.dataID ,th.LesionNumber ,th.TTP, th.LobeLocation, th.SegmentLocation , 
          th.Cirrhosis, th.Pathology, th.Vascular, th.Metastasis, th.Lymphnodes, th.Thrombosis, th.AFP, th.FirstLineTherapy ,
          th.MVIStatus ,th.PNPLA3    ,th.PNPLA73   ,th.pnpl2     ,
          th.TTPTraining, th.LabelTraining , 
          rf.TimeID  ,   qa.Status , rf.StudyUID,
          a.labellocation, a.Volume,
          a.Pre_RAWIMAGE,a.Art_RAWIMAGE,a.Ven_RAWIMAGE,a.Del_RAWIMAGE,a.Pre_DENOISE,a.Art_DENOISE,a.Ven_DENOISE,a.Del_DENOISE,a.Pre_GRADIENT,a.Art_GRADIENT,a.Ven_GRADIENT,a.Del_GRADIENT,a.Pre_ATROPOS_GMM_POSTERIORS1,a.Art_ATROPOS_GMM_POSTERIORS1,a.Ven_ATROPOS_GMM_POSTERIORS1,a.Del_ATROPOS_GMM_POSTERIORS1,a.Pre_ATROPOS_GMM_POSTERIORS2,a.Art_ATROPOS_GMM_POSTERIORS2,a.Ven_ATROPOS_GMM_POSTERIORS2,a.Del_ATROPOS_GMM_POSTERIORS2,a.Pre_ATROPOS_GMM_POSTERIORS3,a.Art_ATROPOS_GMM_POSTERIORS3,a.Ven_ATROPOS_GMM_POSTERIORS3,a.Del_ATROPOS_GMM_POSTERIORS3,a.Pre_ATROPOS_GMM_LABEL1_DISTANCE,a.Art_ATROPOS_GMM_LABEL1_DISTANCE,a.Ven_ATROPOS_GMM_LABEL1_DISTANCE,a.Del_ATROPOS_GMM_LABEL1_DISTANCE,a.Pre_MEAN_RADIUS_1,a.Art_MEAN_RADIUS_1,a.Ven_MEAN_RADIUS_1,a.Del_MEAN_RADIUS_1,a.Pre_MEAN_RADIUS_3,a.Art_MEAN_RADIUS_3,a.Ven_MEAN_RADIUS_3,a.Del_MEAN_RADIUS_3,a.Pre_MEAN_RADIUS_5,a.Art_MEAN_RADIUS_5,a.Ven_MEAN_RADIUS_5,a.Del_MEAN_RADIUS_5,a.Pre_SIGMA_RADIUS_1,a.Art_SIGMA_RADIUS_1,a.Ven_SIGMA_RADIUS_1,a.Del_SIGMA_RADIUS_1,a.Pre_SIGMA_RADIUS_3,a.Art_SIGMA_RADIUS_3,a.Ven_SIGMA_RADIUS_3,a.Del_SIGMA_RADIUS_3,a.Pre_SIGMA_RADIUS_5,a.Art_SIGMA_RADIUS_5,a.Ven_SIGMA_RADIUS_5,a.Del_SIGMA_RADIUS_5,a.Pre_SKEWNESS_RADIUS_1,a.Art_SKEWNESS_RADIUS_1,a.Ven_SKEWNESS_RADIUS_1,a.Del_SKEWNESS_RADIUS_1,a.Pre_SKEWNESS_RADIUS_3,a.Art_SKEWNESS_RADIUS_3,a.Ven_SKEWNESS_RADIUS_3,a.Del_SKEWNESS_RADIUS_3,a.Pre_SKEWNESS_RADIUS_5,a.Art_SKEWNESS_RADIUS_5,a.Ven_SKEWNESS_RADIUS_5,a.Del_SKEWNESS_RADIUS_5,a.LEFTLUNGDISTANCE,a.RIGHTLUNGDISTANCE,a.LANDMARKDISTANCE0,a.LANDMARKDISTANCE1,a.LANDMARKDISTANCE2,a.HESSOBJ,a.NORMALIZEDDISTANCE  
   from      RandomForestHCCResponse.treatmenthistory th
   left join RandomForestHCCResponse.imaginguids      rf on (rf.studyUID=th.BaselineStudyUID or  rf.studyUID=th.FollowupStudyUID )
   left join RandomForestHCCResponse.qadata           qa on  rf.studyUID=qa.InstanceUID   
   left join (  select vl.InstanceUID, lk.location labellocation, group_concat( distinct vl.Volume) Volume,
                       group_concat( distinct CASE WHEN fi.id = 1 THEN vl.mean  END ) as  Pre_RAWIMAGE,group_concat( distinct CASE WHEN fi.id = 2 THEN vl.mean  END ) as  Art_RAWIMAGE,group_concat( distinct CASE WHEN fi.id = 3 THEN vl.mean  END ) as  Ven_RAWIMAGE,group_concat( distinct CASE WHEN fi.id = 4 THEN vl.mean  END ) as  Del_RAWIMAGE,group_concat( distinct CASE WHEN fi.id = 5 THEN vl.mean  END ) as  Pre_DENOISE,group_concat( distinct CASE WHEN fi.id = 6 THEN vl.mean  END ) as  Art_DENOISE,group_concat( distinct CASE WHEN fi.id = 7 THEN vl.mean  END ) as  Ven_DENOISE,group_concat( distinct CASE WHEN fi.id = 8 THEN vl.mean  END ) as  Del_DENOISE,group_concat( distinct CASE WHEN fi.id = 9 THEN vl.mean  END ) as  Pre_GRADIENT,group_concat( distinct CASE WHEN fi.id = 10 THEN vl.mean  END ) as  Art_GRADIENT,group_concat( distinct CASE WHEN fi.id = 11 THEN vl.mean  END ) as  Ven_GRADIENT,group_concat( distinct CASE WHEN fi.id = 12 THEN vl.mean  END ) as  Del_GRADIENT,group_concat( distinct CASE WHEN fi.id = 13 THEN vl.mean  END ) as  Pre_ATROPOS_GMM_POSTERIORS1,group_concat( distinct CASE WHEN fi.id = 14 THEN vl.mean  END ) as  Art_ATROPOS_GMM_POSTERIORS1,group_concat( distinct CASE WHEN fi.id = 15 THEN vl.mean  END ) as  Ven_ATROPOS_GMM_POSTERIORS1,group_concat( distinct CASE WHEN fi.id = 16 THEN vl.mean  END ) as  Del_ATROPOS_GMM_POSTERIORS1,group_concat( distinct CASE WHEN fi.id = 17 THEN vl.mean  END ) as  Pre_ATROPOS_GMM_POSTERIORS2,group_concat( distinct CASE WHEN fi.id = 18 THEN vl.mean  END ) as  Art_ATROPOS_GMM_POSTERIORS2,group_concat( distinct CASE WHEN fi.id = 19 THEN vl.mean  END ) as  Ven_ATROPOS_GMM_POSTERIORS2,group_concat( distinct CASE WHEN fi.id = 20 THEN vl.mean  END ) as  Del_ATROPOS_GMM_POSTERIORS2,group_concat( distinct CASE WHEN fi.id = 21 THEN vl.mean  END ) as  Pre_ATROPOS_GMM_POSTERIORS3,group_concat( distinct CASE WHEN fi.id = 22 THEN vl.mean  END ) as  Art_ATROPOS_GMM_POSTERIORS3,group_concat( distinct CASE WHEN fi.id = 23 THEN vl.mean  END ) as  Ven_ATROPOS_GMM_POSTERIORS3,group_concat( distinct CASE WHEN fi.id = 24 THEN vl.mean  END ) as  Del_ATROPOS_GMM_POSTERIORS3,group_concat( distinct CASE WHEN fi.id = 25 THEN vl.mean  END ) as  Pre_ATROPOS_GMM_LABEL1_DISTANCE,group_concat( distinct CASE WHEN fi.id = 26 THEN vl.mean  END ) as  Art_ATROPOS_GMM_LABEL1_DISTANCE,group_concat( distinct CASE WHEN fi.id = 27 THEN vl.mean  END ) as  Ven_ATROPOS_GMM_LABEL1_DISTANCE,group_concat( distinct CASE WHEN fi.id = 28 THEN vl.mean  END ) as  Del_ATROPOS_GMM_LABEL1_DISTANCE,group_concat( distinct CASE WHEN fi.id = 29 THEN vl.mean  END ) as  Pre_MEAN_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 30 THEN vl.mean  END ) as  Art_MEAN_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 31 THEN vl.mean  END ) as  Ven_MEAN_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 32 THEN vl.mean  END ) as  Del_MEAN_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 33 THEN vl.mean  END ) as  Pre_MEAN_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 34 THEN vl.mean  END ) as  Art_MEAN_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 35 THEN vl.mean  END ) as  Ven_MEAN_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 36 THEN vl.mean  END ) as  Del_MEAN_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 37 THEN vl.mean  END ) as  Pre_MEAN_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 38 THEN vl.mean  END ) as  Art_MEAN_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 39 THEN vl.mean  END ) as  Ven_MEAN_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 40 THEN vl.mean  END ) as  Del_MEAN_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 41 THEN vl.mean  END ) as  Pre_SIGMA_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 42 THEN vl.mean  END ) as  Art_SIGMA_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 43 THEN vl.mean  END ) as  Ven_SIGMA_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 44 THEN vl.mean  END ) as  Del_SIGMA_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 45 THEN vl.mean  END ) as  Pre_SIGMA_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 46 THEN vl.mean  END ) as  Art_SIGMA_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 47 THEN vl.mean  END ) as  Ven_SIGMA_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 48 THEN vl.mean  END ) as  Del_SIGMA_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 49 THEN vl.mean  END ) as  Pre_SIGMA_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 50 THEN vl.mean  END ) as  Art_SIGMA_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 51 THEN vl.mean  END ) as  Ven_SIGMA_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 52 THEN vl.mean  END ) as  Del_SIGMA_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 53 THEN vl.mean  END ) as  Pre_SKEWNESS_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 54 THEN vl.mean  END ) as  Art_SKEWNESS_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 55 THEN vl.mean  END ) as  Ven_SKEWNESS_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 56 THEN vl.mean  END ) as  Del_SKEWNESS_RADIUS_1,group_concat( distinct CASE WHEN fi.id = 57 THEN vl.mean  END ) as  Pre_SKEWNESS_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 58 THEN vl.mean  END ) as  Art_SKEWNESS_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 59 THEN vl.mean  END ) as  Ven_SKEWNESS_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 60 THEN vl.mean  END ) as  Del_SKEWNESS_RADIUS_3,group_concat( distinct CASE WHEN fi.id = 61 THEN vl.mean  END ) as  Pre_SKEWNESS_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 62 THEN vl.mean  END ) as  Art_SKEWNESS_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 63 THEN vl.mean  END ) as  Ven_SKEWNESS_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 64 THEN vl.mean  END ) as  Del_SKEWNESS_RADIUS_5,group_concat( distinct CASE WHEN fi.id = 65 THEN vl.mean  END ) as  LEFTLUNGDISTANCE,group_concat( distinct CASE WHEN fi.id = 66 THEN vl.mean  END ) as  RIGHTLUNGDISTANCE,group_concat( distinct CASE WHEN fi.id = 67 THEN vl.mean  END ) as  LANDMARKDISTANCE0,group_concat( distinct CASE WHEN fi.id = 68 THEN vl.mean  END ) as  LANDMARKDISTANCE1,group_concat( distinct CASE WHEN fi.id = 69 THEN vl.mean  END ) as  LANDMARKDISTANCE2,group_concat( distinct CASE WHEN fi.id = 70 THEN vl.mean  END ) as  HESSOBJ,group_concat( distinct CASE WHEN fi.id = 71 THEN vl.mean  END ) as  NORMALIZEDDISTANCE
                from  RandomForestHCCResponse.ImageFeatures fi 
                join  RandomForestHCCResponse.liverLabelKey lk on lk.labelID = 2 or lk.labelID = 3 or lk.labelID = 4
                join  RandomForestHCCResponse.lstat         vl on vl.FeatureID=fi.FeatureID  and vl.SegmentationID=@varAnalysis and lk.labelID =  vl.labelid 
                group by vl.InstanceUID, lk.labelID
              ) a on a.InstanceUID = rf.StudyUID; 
END //
DELIMITER ;
-- show create procedure RandomForestHCCResponse.DataMatrix ;
-- call RandomForestHCCResponse.DataMatrix ('Truth');
-- mysql  -re "call RandomForestHCCResponse.DataMatrix ('Truth');" | sed "s/\t/,/g;s/NULL//g" > datalocation/datamatrix.csv
-- mysql  -re "call RandomForestHCCResponse.DataMatrix ('LABELSGMM');" | sed "s/\t/,/g;s/NULL//g" > gmmdatamatrix.csv



-- @pvtruong-mdacc: error check  missing MRNs 
insert into Metadata.Singular(id)
(select si.id from Metadata.Singular si join
  (select rf.mrn from RandomForestHCCResponse.imaginguids rf where rf.mrn not in (select pt.mrn from DICOMHeaders.patients pt)) a);

-- BUG: @pvtruong-mdacc error check  missing studyuid 
insert into Metadata.Singular(id)
(select si.id from Metadata.Singular si join(
   select rf.StudyUID  
   from RandomForestHCCResponse.imaginguids rf
   left join DICOMHeaders.studies  sd  on sd.StudyInstanceUID = rf.StudyUID  
   where sd.StudyInstanceUID  is null  
                                   ) b);

