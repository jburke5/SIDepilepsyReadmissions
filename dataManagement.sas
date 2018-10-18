libname e 'Q:\Sam';
libname a 'Q:\Sam\AHA\linkage files\my dataset';
libname r 'Q:\Sam\RWJ';
OPTIONS FMTSEARCH=(e);

*https://www.hcup-us.ahrq.gov/db/nation/nis/nisdde.jsp;

/*CCS labels (single level 83, multilevel 6.4.1+6.4.2 = epilepsy
6.4       Epilepsy; convulsions [83.]
6.4.1     Epilepsy
          3450 34500 34501 3451 34510 34511 3452 3453 3454 34540
          34541 3455 34550 34551 3456 34560 34561 3457 34570 34571
          3458 34580 34581 3459 34590 34591
6.4.2     Convulsions
          7803 78031 78032 78033 78039
7802, 245, and 17.1.1 are syncope
300.1 conversion*/

*code to count number of unique visitlinks for all patients with an epi admission, which can be copy/pasted/modified at each exclusion;
*visit_count = # admissions for each visilink. this produces figure 1 flowchart;
proc sql;
	create table count1 as
	select * , count(*) as visit_count
	 from e.epi25 /*enter dataset here*/
	 group by visitlink
	;
quit;
data count1;
	set count1 (keep=visitlink epi_admit tran_out daystoevent visit_count);
	if tran_out=1 then tran_out1=1; else tran_out1=0; run;
proc sort data=count1; by visitlink descending epi_admit tran_out1 daystoevent; run;
data count1;
	set count1;
	by visitlink descending epi_admit tran_out1 daystoevent;
	if first.visitlink and epi_admit and tran_out1 ne 1 then first_epi_admit=1;
		else first_epi_admit=0;
	run;
data count1;
	set count1 (keep=visit_count first_epi_admit);
	where first_epi_admit;
	run;
proc means data=count1 sum; var visit_count; run;
*calculates total number of hospitalizations for people with at least one epi admission;

*flag epi admits (single level CCS 83), remove duplicates, and flag first epi admits used for later sorting to find the first epi admit as long as we are sorting to remove duplicates;
data e.epi21;
	set e.epi2 (drop = ageday agemonth ccsmgn1 -- eccsmgn5 /*these are empty variables, to drop*/);
	if dxccs1 = 83 then epi_admit=1; else epi_admit=0;
	run;
proc sort data=e.epi21 out = e.epi22 nodup;
	by visitlink descending epi_admit daystoevent;
	run;

*remove <18y;
data e.epi24;
	set e.epi22 ;
	where age>17 and atype ne 4;
	run;

*previously at this step, removed tran_in's which was epi23, now gone;

*remove patients with multiple admissions with inconsistent demographic coding, as a data quality check.
	i.e. remove visitlinks if one hospitalization for that person says they have changed 
	sex, or age by over a year during a 1 year timespan;
*examine if all sexes, daystoevent, ages are the same/consistent for a patient;

data e.x;set e.epi24 (keep=visitlink female);run;

proc freq data=e.epi24;
	tables race female;
	run; *race is 1-6 and female 0-1, otherwise missing;
data e.epi_comparedemos;
	set e.epi24 (keep = visitlink daystoevent female age year);
	age_rel=age-year; *age - year, because can be within 1 year old if in same year, but can be within 5 years old if within 4 years, etc;
	days_rel_max=daystoevent-(year-2009)*365; *years are 2009-2012. you can be within 365 * # years apart of each other. this formula sets your daystoevents back 365 for each subsequent
		year, so max acceptable range should be 365;
	run;
proc sort data=e.epi_comparedemos;
	by visitlink;
	run;
*sex;
proc transpose data=e.epi_comparedemos out=e.t_sex prefix=female name=visitlink;
    by visitlink;
    var female;
	run;
data e.same_sex;
	set e.t_sex;
	if range(of female1-female191) in (0,.) then samesex=1; else samesex=0;
	keep visitlink samesex;
	run;
proc freq data=e.same_sex;
	tables samesex;
	run; *1864, 1.5% had inconsistent sex;
*age;
proc transpose data=e.epi_comparedemos out=e.t_age prefix=age_rel name=visitlink;
    by visitlink;
    var age_rel;
run;
data e.same_age;
	set e.t_age;
	if range(of age_rel1-age_rel191)<2 then sameage=1; else sameage=0;
	range_age=range(of age_rel1-age_rel178);
	keep visitlink sameage range_age;
	run;
proc freq data=e.same_age;
	tables range_age sameage;
	run; *10157, 8.0% had inconsistent age;
*a check of main dataset to see people flagged as inconsistent age;
proc print data=e.same_age; var visitlink range_age; where visitlink<355970 and sameage=0;run;
proc print data=e.epi24; var visitlink age year state; where visitlink in (109,175,235,444,701,754,769,773,799,849,915,1083,1126,1136,1166,1186,1208,1244,1298,1346,1453,1558,1572,
1574,1592,1654,1700,1786,1837);run; *print some data with inconsistent ages;
proc print data=e.same_age; var visitlink range_age; where visitlink<35597 and sameage=1;run;
proc print data=e.epi24; var visitlink age year; where visitlink in (22,46,78,82);run; *print some data with consistent ages, just to check;
proc print data=e.same_sex; var visitlink; where visitlink<3559 and samesex=0;run; *print visitlinks with inconsistent sex;
proc print data=e.epi24; var visitlink female; where visitlink in (109,769,773,799,849,1083);run; *print some data with inconsistent sexes;



proc freq data=e.epi21;
	tables year;
	run;
*daystoevent;
proc transpose data=e.epi_comparedemos out=e.t_daystoevent prefix=days_rel_max name=visitlink; *daystoevent;
    by visitlink;
    var days_rel_max;
run;
data e.same_days;
	set e.t_daystoevent;
	if range(of days_rel_max1-days_rel_max191)<=365 then samedays=1; else samedays=0;
	rangedays=range(of days_rel_max1-days_rel_max178);
	keep visitlink samedays rangedays;
	run;
proc freq data=e.same_days;
	tables samedays;
	run; *3737, 2.9% had inconsistent daystoevents, i.e. over 365 days * # years apart separating admissions;
*merge back the 'sameness' data into the final dataset;
proc sort data=e.same_race;
	by visitlink;
	run;
proc sort data=e.same_sex;
	by visitlink;
	run;
proc sort data=e.same_days;
	by visitlink;
	run;
proc sort data=e.same_age;
	by visitlink;
	run;
data e.same_all;
	merge e.same_sex e.same_days e.same_age;
	by visitlink;
	if samesex=1 and samedays=1 and sameage=1 then sameall=1;  else sameall=0;
	drop rangedays range_age;
	run;
proc freq data=e.same_all;
	tables sameall samesex*samedays*sameage/norow nocol nopercent;
	run; *10596, 8.3% had at least one inconsistency;

*merge epi24 with same_all so visitlinks are flagged with consistent demographics, so 
	we can delete people whose demographics are coded inconsistently so i don't have to guees
	what your race/sex/age are;
data e.epi25;
	merge e.epi24 e.same_all;
	by visitlink;
	run;
data e.epi25;
	set e.epi25 (drop = samesex samedays sameage);
	where sameall; *delete inconsistencies;
	run;

*flag the first row for each person which was a nontransfer-out epi admit. 
	those flagged rows will comprise the final dataset;
data e.epi26; set e.epi25; if tran_out=1 then tran_out1=1; else tran_out1=0; run;
proc sort data=e.epi26; by visitlink descending epi_admit tran_out1 daystoevent; run;
data e.epi26;
	set e.epi26;
	by visitlink descending epi_admit tran_out1 daystoevent;
	if first.visitlink and epi_admit and tran_out1 ne 1 then first_epi_admit=1;
		else first_epi_admit=0;
	run;
*see if first_epi_admit worked as intended in a shortened dataset;
data e.epi26_short;
	set e.epi26 (keep = visitlink epi_admit tran_out dxccs1 daystoevent first_epi_admit);
	run;
proc means data=e.epi26_short sum;
	var first_epi_admit epi_admit;
	run;

*perform the excel countif function, to mark how many admissions belong to each visitlink;
proc sql;
	create table e.epi27 as
	select * , count(*) as visit_count
	 from e.epi26
	 group by visitlink
	;
quit;

*2012 AHA linkages, AHAID with dshospid;
*linkage files: https://www.hcup-us.ahrq.gov/ahalinkage/ahalinkage_list.jsp?state=NV&year=2012&db=SID
load programs for these files:https://www.hcup-us.ahrq.gov/sasload/sasload_search.jsp
in epi file, 2012 admissions just have dshospid. need to convert 2012 dshospids into ahaid and merge those ahaids back into main database for 2012, which
	currently doesn't have any ahaid's for 2012. note that AR is all messed up in the ASC file and load, but they 
	just have 2009 data and already have ahaid's so don't care;
proc freq data=e.epi27; tables year*state/nopercent nocol norow; run; 
proc freq data=e.epi27; tables dispub04*state/missing nopercent nocol norow; run; 
*states with completely missing 2012 data include FL, MD, VT, WA;
data a.ar12_2;
	set a.ar12;
	ahaid2 = put(ahaid,8.);
	drop ahaid;
	rename ahaid2=ahaid;
	run;
data a.ar12_2;
	format ahaid $7.;
	format dshospid $17.;
	set a.ar12_2;
	run;
data a.ahalinks;
	set a.fl12 a.md12 a.vt12 a.wa12 ;
	run;
data a.ahalinks2;
*ahalinks dshopsid has length 17. epi27 dshospid has length 10. so, change length in ahalinks to 10;
	length dshospid $10;
	set a.ahalinks;
	drop hospid HFIPSSTCO year hospst;
	run;
data e.epi27_n2012;
	set e.epi27;
	where year ne 2012;
	run; 
data e.epi27_2012;
	set e.epi27 (drop=ahaid);
	where year = 2012;
	run;
*want to merge the ahaid's into _2012 dataset to fill in ahaid's for 2012;
proc sort data=e.epi27_2012; by dshospid; run;
proc sort data=a.ahalinks2; by dshospid; run;
data e.epi27_2012ahaid;
	merge e.epi27_2012 a.ahalinks2;
	by dshospid;
	run;
data e.epi28; *stack datasets to combine all years. more people should have an AHAID now;
	set e.epi27_2012ahaid e.epi27_n2012;
	run;
*still ~3000 missing ahaid which is about 1%;
data e.x;set e.epi28 (keep=ahaid state year dshospid);where ahaid=' ';run;
proc freq data=e.x;	tables dshospid;run;
proc sort data=e.x; by hospid; run;
proc print data=e.epi28;
	var state dshospid;
	where dshospid ne ' ' and ahaid=' ';
	run;
*enter ahaid's manually for those with a dshospid but no ahaid yet. 
	probably should have automated this;
data e.epi28;
	set e.epi28;
	if dshospid='00100129' then ahaid='6390417';
		else if dshospid='00104018' then ahaid='6399248';
		else if dshospid='196403' then ahaid='6930243'; 
		else if dshospid='23960084' then ahaid='6390405'; 
		else if dshospid='23960090' then ahaid='6399246';
		else if dshospid='BLTC' then ahaid='6710159';
		else if dshospid='PHYS' then ahaid='6710239';
		else ahaid=ahaid;
	run;
*missing ahaid's for dshospid's:
00100197 missing 
00110022 missing 
00110044 missing 
00110051 missing 
013687 missing 
014207 missing 
044006 missing 
094002 missing 
104089 missing
124004 missing
154160 missing 
164029 missing 
190150 missing 
194010 missing 
196404 missing 
23960061 missing
23960083 missing 
23960102 missing 
23960106 missing 
244027 missing 
304460 missing 
314024 missing 
314029 missing 
334457 missing 
334589 missing 
344011 missing 
344170 missing 
364188 missing 
370749 missing 
380842 missing 
394003 missing 
404046 missing 
424002 missing 
4460 missing 
484028 missing 
484044 missing
514001 missing 
514030 missing
514033 missing;

*merge epi with AHA dataset, now that 99% of people have an ahaid;
proc sort data=e.epi28; by ahaid; run;
data e.aha2;
	*change ID length in AHA from 8 to 7 (because length is 7 in SID dataset), and rename AHA's ID to AHAID;
	length ahaid $7;
	set e.aha (rename=(id=ahaid los=los_AHA));
	run;
proc sort data=e.aha2; by ahaid; run;
data e.epi28AHA;
	merge e.epi28 e.aha2;
	by ahaid;
	run;
data e.epi28AHA;
	set e.epi28AHA;
	where visitlink > 0; run;

*I observed that patients were missing AHA data despite having an ahaid. I realized that for these people,
	those ahaid's from SID did not correspond to any ahaid in AHA, but that their dshospid's from SID correspond
	to valid ahaid's found in linkage files. thus, I think those ahaid's in SID are erroneous, and if patients
	have an ahaid which does not map to any row in AHA, I will replace their ahaid with that stated in
	the linkage file for each dshospid found in SID. this was relevant to 1299 patients. 
	1) flag ahaids needing replacing (ahaid present, but no AHA data got linked in, and thus need
		to search the linkage file for the correct ahaid via its dshospid). 
		make a dataset consisting only of dshospid, and that flag
	2) merge that dataset (which identifies which dshospids need their ahaid replaced) along with linkage file 
		(which has the good ahaids to replace the bad ones with) by dshospid into epi28.
	3) overwrite bad ahaids with good ahaids, but no change to already goood ahaids
	4) redo the epi28 aha merge by ahaid;

data e.flagbadahaids;
	set e.epi28AHA;
	if ahaid ne ' ' and mapp8=' ' and cbsatype=' ' and cntrl=' '
	then ahaid_bad_ind=1; else ahaid_bad_ind=0;
	keep dshospid ahaid_bad_ind state;
	run;
proc sort data=e.flagbadahaids; by dshospid state; run;
data e.flagbadahaids; set e.flagbadahaids; by dshospid state; if first.dshospid; run;
data a.ahalinksall; *note multiple lengths truncation warning. all dshospids are 17 though.
	maybe that warning is in regards to a different variable;
	length dshospid $10; set a.ar12_2 a.ca11 a.fl12 a.ia10 a.ma12 a.md12 a.nc12 a.ny12 a.vt12 a.wa12;
	if state=' ' then state=hospst; else state=state;
	run;
data a.ahalinksall2; 
*ahalinks dshopsid has length 17. epi27 dshospid has length 10. so, change length in ahalinks to 10;
	set a.ahalinksall; rename ahaid=ahaid_good; run;
data a.ahalinksall2; set a.ahalinksall2; keep ahaid_good dshospid state; run;
proc sort data=e.epi28; by dshospid state; run; *can't sort by ahaid, since some ahaids are erroneous in epi28 and
	thus don't exist in the linkage file. also, note keeping state bc some dshospids are not unique to a state;
proc sort data=a.ahalinksall2; by dshospid state; run;

data e.epi28_overwriteahaids;
	merge e.epi28 e.flagbadahaids a.ahalinksall2; by dshospid state;
	ahaid_old=ahaid;
	if ahaid_bad_ind=1 then ahaid=ahaid_good; else ahaid=ahaid; 
	drop ahaid_old ahaid_bad_ind ahaid_good;
run;

proc sort data=e.epi28_overwriteahaids; by ahaid; run; proc sort data=e.aha2; by ahaid; run;
data e.epi28AHA_overwriteahaids;
	merge e.epi28_overwriteahaids e.aha2;
	by ahaid;
	run;
data e.epi28AHA_overwriteahaids;
	set e.epi28AHA_overwriteahaids;
	where visitlink>0; run;

data e.x; set e.epi28aha_overwriteahaids; keep ahaid dshospid; where ahaid ne ' ' and mapp8=' ';run;
data e.x2; set e.epi28aha; keep ahaid dshospid; where ahaid ne ' ' and mapp8=' ';run;

*AHA variabes:
Here's my short list:
cntrl = control code descriptions, i.e. profit and ownership status
hospbd = Total hospital beds
CBSATYPE = Core Based Statistical Area (Metro, Micro, Division, Rural)
MAPP8 = Member of the Council of Teaching Hospitals (COTH) of the Association of American Medical Colleges.
PHYGP = Is hospital owned in whole or in part by physicians or a physicians group?
nerohos = neurological serv hospital
mrihos = Magnetic resonance imaging (MRI) - hospital
FTRES/LBEDSA = residents&terns / licensed beds, if ratio >0.25, or maybe ftres/hospb?

• MAPP3 — Approval to participate in residency and/or internship training by the
Accreditation Council for Graduate Medical Education (ACGME).1
• MAPP5 — Medical school affliation reported to the American Medical Association (AMA).
• MAPP8 — Member of the Council of Teaching Hospitals (COTH) of the Association of
American Medical Colleges.
• MAPP12 — Internship approved by American Osteopathic Association.
• MAPP13 — Residency approved by American Osteopathic Association.
We consider major teaching hospitals to be all hospitals that have the Council of Teaching
Hospitals designation (MAPP8). We consider minor teaching hospitals to be all hospitals
that have any one or more of the other four MAPP codes identifed above.

*grab the next row's data to provide information regarding the next admission. if only 1 admission for a given person, then will make data missing;
	*first copy the relevant variables into holding variables which will be changed in the next step. the _r stands for readmit, but it really just means the next row's data;
data e.epi28aha1;
	set e.epi28aha_overwriteahaids;
	*some relevant variables are atype daystoevent pay1 died los ahaid dxmccs1 dxmccs2 e_mccs1 e_mccs2 prccs1-prccs25 (ignore pr1-25, prmccs1-25) dx1 dx2 dxccs1 dxcc2 totchg, utilization codes;
	age_r = age;
	race_r = race;
	female_r = female;
	daystoevent_r = daystoevent;
	cm_aids_r=cm_aids; cm_alcohol_r=cm_alcohol; cm_anemdef_r=cm_anemdef; cm_chf_r=cm_chf; cm_chrnlung_r=cm_chrnlung; 
		cm_depress_r=cm_depress; cm_dm_r=cm_dm; cm_dmcx_r=cm_dmcx; cm_drug_r=cm_drug; cm_liver_r=cm_liver; 
		cm_mets_r=cm_mets; cm_neuro_r=cm_neuro; cm_obese_r=cm_obese; cm_psych_r=cm_psych; cm_pulmcirc_r=cm_pulmcirc; 
		cm_renlfail_r=cm_renlfail; cm_tumor_r=cm_tumor; 
	year_r=year;
	aweekend_r=aweekend;
	dispub04_r=dispub04;
	atype_r = atype;
	asource_r = asource;
	visitlink_r = visitlink;
	daystoevent_r = daystoevent;
	pay1_r = pay1;
	died_r = died;
	los_r = los;
	ahaid_r = ahaid;
	dx_r1 = dx1;
	dx_r2 = dx2;
	dxmccs_r1 = dxmccs1;
	dxccs_r1 = dxccs1;
	dxccs_r2 = dxccs2;
	dxccs_r3 = dxccs3;
	dxccs_r4 = dxccs4;
	dxccs_r5 = dxccs5;
	dxccs_r6 = dxccs6;
	dxccs_r7 = dxccs7;
	dxccs_r8 = dxccs8;
	dxccs_r9 = dxccs9;
	dxccs_r10 = dxccs10;
	dxccs_r11 = dxccs11;
	dxccs_r12 = dxccs12;
	dxccs_r13 = dxccs13;
	dxccs_r14 = dxccs14;
	dxccs_r15 = dxccs15;
	dxccs_r16 = dxccs16;
	dxccs_r17 = dxccs17;
	dxccs_r18 = dxccs18;
	dxccs_r19 = dxccs19;
	dxccs_r20 = dxccs20;
	dxccs_r21 = dxccs21;
	dxccs_r22 = dxccs22;
	dxccs_r23 = dxccs23;
	dxccs_r24 = dxccs24;
	dxccs_r25 = dxccs25;
	e_mccs_r1 = e_mccs1;
	e_mccs_r2 = e_mccs2;
	prccs_r1 = prccs1;
	prccs_r2 = prccs2;
	prccs_r3 = prccs3;
	prccs_r4 = prccs4;
	prccs_r5 = prccs5;
	prccs_r6 = prccs6;
	prccs_r7 = prccs7;
	prccs_r8 = prccs8;
	prccs_r9 = prccs9;
	prccs_r10 = prccs10;
	prccs_r11 = prccs11;
	prccs_r12 = prccs12;
	prccs_r13 = prccs13;
	prccs_r14 = prccs14;
	prccs_r15 = prccs15;
	prccs_r16 = prccs16;
	prccs_r17 = prccs17;
	prccs_r18 = prccs18;
	prccs_r19 = prccs19;
	prccs_r20 = prccs20;
	prccs_r21 = prccs21;
	prccs_r22 = prccs22;
	prccs_r23 = prccs23;
	prccs_r24 = prccs24;
	prccs_r25 = prccs25;
	totchg_r = totchg;
	u_icu_r = u_icu;
	u_eeg_r = u_eeg;
	u_ed_r = u_ed;
	u_ctscan_r = u_ctscan;
	u_mrt_r = u_mrt;
	u_dialysis_r = u_dialysis;
	tran_out_r=tran_out;
	tran_in_r=tran_in;
	cntrl_r = cntrl; hospbd_r = hospbd; CBSATYPE_r = CBSATYPE; MAPP8_r = MAPP8; PHYGP_r = PHYGP; nerohos_r = nerohos; 
		mrihos_r = mrihos;
	run;
*sort such that the next row is the relevant readmission (though not really if only 1 admission, or the last admission, but it doesn't matter because those don't have subsequent readmissions);
proc sort data=e.epi28aha1;
	by visitlink daystoevent;
	run;
	*replace existing holder _r value with the next row's actual value;
data e.epi28aha1;
	set e.epi28aha1 nobs=nobs;
	next1 = _n_ + 1;
	if _n_ < nobs then set e.epi28aha1(keep= age_r race_r female_r daystoevent_r
		cm_aids_r cm_alcohol_r cm_anemdef_r cm_chf_r cm_chrnlung_r cm_depress_r cm_dm_r cm_dmcx_r cm_drug_r cm_liver_r 
		cm_mets_r cm_neuro_r cm_obese_r cm_psych_r cm_pulmcirc_r cm_renlfail_r cm_tumor_r year_r aweekend_r 
		dispub04_r atype_r asource_r visitlink_r daystoevent_r pay1_r died_r los_r ahaid_r 
		dx_r1 dx_r2 dxmccs_r1 
		dxccs_r1 dxccs_r2 dxccs_r3 dxccs_r4 dxccs_r5 dxccs_r6 dxccs_r7 dxccs_r8 dxccs_r9 dxccs_r10 dxccs_r11 dxccs_r12 
		dxccs_r13 dxccs_r14 dxccs_r15 dxccs_r16 dxccs_r17 dxccs_r18 dxccs_r19 dxccs_r20 dxccs_r21 dxccs_r22 dxccs_r23 
		dxccs_r24 dxccs_r25
		e_mccs_r1 e_mccs_r2 
		prccs_r1 prccs_r2 prccs_r3 prccs_r4 prccs_r5 prccs_r6 prccs_r7 prccs_r8 prccs_r9 prccs_r10 prccs_r11 
		prccs_r12 prccs_r13 prccs_r14 prccs_r15 prccs_r16 prccs_r17 prccs_r18 
		prccs_r19 prccs_r20 prccs_r21 prccs_r22 prccs_r23 prccs_r24 prccs_r25
		totchg_r u_icu_r u_eeg_r u_ed_r u_ctscan_r u_dialysis_r u_mrt_r
		tran_out_r tran_in_r
		cntrl_r  hospbd_r  CBSATYPE_r  MAPP8_r  PHYGP_r  nerohos_r  mrihos_r)
	point=next1;
	run;

*create an epi volume variable...how many dx1ccs 83's per hospital per year. will merge this into the final dataset;
proc freq data=e.epi28aha1; tables state*year/nocol norow nopercent; run;
*years of data for each state as follows, to use when we divide the summed number of epi admits over all 4 years by number of years
	for yearly average epi volume:
AR 1
CA 3
FL 4
IA 3
MA 1
MD 1
NC 2
NE 1
NY 3
VT 1
WA 4;
data e.epivol; set e.epi28aha1 (keep=ahaid state dxccs1); where dxccs1=83; drop dxccs1; run;
proc sql;
	create table e.epivol2 as
	select * , count(*) as epi_vol
	 from e.epivol
	 group by ahaid;
quit;
proc sort data=e.epivol2; by ahaid; run;
data e.epivol3; set e.epivol2; by ahaid;
	if ahaid=' ' then epi_vol=.; else epi_vol=epi_vol;
	if state in ('AR','MA','MD','NE','VT') then epi_vol_av=epi_vol;
		else if state='NC' then epi_vol_av=epi_vol/2;
		else if state in ('CA','IA','NY') then epi_vol_av=epi_vol/3;
		else epi_vol_av=epi_vol/4;
	if first.ahaid; where ahaid ne ' '; drop state epi_vol; run;

*final dataset with a single row for each individual including both the index admission and readmission, and add some final variables;

proc means data=e.epi28aha1 n nmiss mean std q1 q3 min max; var hospbd FTRES LBEDSA;run;
*lbedsa has alot more missing than hospbd, so will use hospbd for teaching calculation;

*tertiles for age, LOS, beds, epivol;
proc univariate data=e.epi28aha5;var epi_vol_av; histogram epi_vol_av; run;
proc univariate data=e.epi28aha5 noprint;var epi_vol_av; output out=e.tertiles pctlpts=20 30 40 50 60 70 75 80 pctlpre=P;run;proc print data=e.tertiles;run;

data e.epi28aha2;
	set e.epi28aha1;
	*days to next admit = readmit date minus index discharge date, then categorize this;
	daystonextadmit = daystoevent_r - (daystoevent+los);
	if visit_count = 1 then readmit_cat = 'No readmission                   ';
		else if visitlink NE visitlink_r then readmit_cat = 'Mult admissions, but last is epi';
		else if daystonextadmit > 30 then readmit_cat = '>30 day readmission';
		else readmit_cat = '<=30 day readmission';
	if readmit_cat = '<=30 day readm' then readmit30d_bin=1;
		else readmit30d_bin=0;
*secondary etiologies/diagnoses
elan's suggestions:
Ischemic stroke (ICD-9 433.x1, 434.x1, 436)
ICH (ICD-9 431.x), but she was open to using 430 and 432 as well
CNS tumor (ICD-9 191x, 239.6, 198.3)
TBI (ICD-9 800.x-804.x, 850.x)
meningoencephalitis (ICD-9 320.x-323.x)
hyponatremia (ICD-9 276.1)
alcohol withdrawal (ICD-9 291.81)
I added cardiac arrest, single level CCS 107;
	array strokedx[25] dx1-dx25; do i=1 to 25; if strokedx[i] in 
		('43301','43311','43321','43331','43381','43391','43401','43411','43491','436  ') then stroke=1; end; drop i;
		if stroke=. then stroke=0;
	array bleeddx[25] dx1-dx25; do i=1 to 25; if cats(bleeddx[i])=:'430' or
		cats(bleeddx[i])=:'431' or cats(bleeddx[i])=:'432' then bleed=1; end; drop i;
		if bleed=. then bleed=0;
	array tumordx[25] dx1-dx25; do i=1 to 25; if 
		cats(tumordx[i])=:'191' or tumordx[i] in ('2396 ','1983 ') then tumor=1; end; drop i;
		if tumor=. then tumor=0;
	array tbidx[25] dx1-dx25; do i=1 to 25; if cats(tbidx[i])=:'800' or 
cats(tbidx[i])=:'801' or cats(tbidx[i])='802' or cats(tbidx[i])=:'803' or cats(tbidx[i])=:'804' or 
cats(tbidx[i])=:'850' then tbi=1; end; drop i;
		if tbi=. then tbi=0;
	array infxndx[25] dx1-dx25; do i=1 to 25; if 
		cats(infxndx[i])=:'320' or cats(infxndx[i])=:'321' or cats(infxndx[i])=:'322' or cats(infxndx[i])=:'323' 
		then infxn=1; end; drop i;
		if infxn=. then infxn=0;
	array arrestdx[25] dxccs1-dxccs25; do i=1 to 25; if arrestdx[i]=107 then arrest=1; end; drop i;
		if arrest=. then arrest=0;
	array hyposmdx[25] dx1-dx25; do i=1 to 25; if cats(hyposmdx[i])='2761 ' then hyposm=1; end;drop i;
		if hyposm=. then hyposm=0;
	array alcdx[25] dx1-dx25; do i=1 to 25; if cats(alcdx[i])='29181' then alc=1; end;drop i;
		if alc=. then alc=0;
*procedures
Incision and excision of CNS [1.] 
Insertion replacement or removal of extracranial ventricular shunt [2.];
	array tube[25] prccs1-prccs25; do i=1 to 25; if tube[i]=216 then tubed=1; end; drop i;
		if tubed=. then tubed=0;
	array tube_r[25] prccs_r1-prccs_r25; do i=1 to 25; if tube_r[i]=216 then tubed_r=1; end; drop i;
		if tubed_r=. then tubed_r=0;
	array brainsxpr[25] prccs1-prccs25; do i=1 to 25; if brainsxpr[i] in (1,2) then brainsx=1; end; drop i;
		if brainsx=. then brainsx=0;
	array brainsxpr_r[25] prccs1-prccs25; do i=1 to 25; if brainsxpr_r[i] in (1,2) then brainsx_r=1; end; drop i;
		if brainsx_r=. then brainsx_r=0;
	*make some epilepsy diagnosis categories for status and refractory;
	if dx1 in ('3452 ','3453 ') then dx1status=1; else dx1status=0;
	if dx_r1 in ('3452 ','3453 ') then dx1status_r=1; else dx1status_r=0;
	if dx1 in ('34501','34511','34541','34551','34561','34571','34581','34591') then dx1refr=1; else dx1refr=0;
	if dx_r1 in ('34501','34511','34541','34551','34561','34571','34581','34591') then dx1refr_r=1; else dx1refr_r=0;
	*look for a few specific single CCS diagnoses appearing in any readmission diagnosis slot.
		fractures: 226, 228, 229, 230, 231
		intracranial injury (includes concussions): 233
		seizures: 83
		aspiration pneumonitis: 129
		Schizophrenia and other psychotic disorders: 659
		mood disorders: 657
		Suicide and intentional self-inflicted injury: 662
		alcohol or substance: 660 or 661
		poisoning by psychotropic agents or other medications/drugs: 241 or 242;
array fracturedx_r[25] dxccs_r1-dxccs_r25; do i=1 to 25; if fracturedx_r[i] in (226,228,229,230,231) 
	then fracture_r=1; end; drop i; if fracture_r=. then fracture_r=0;
array headinjurydx_r[25] dxccs_r1-dxccs_r25; do i=1 to 25; if headinjurydx_r[i] in (233) 
	then headinjury_r=1; end; drop i; if headinjury_r=. then headinjury_r=0;
array szdx_r[25] dxccs_r1-dxccs_r25; do i=1 to 25; if szdx_r[i] in (83) 
	then sz_r=1; end; drop i; if sz_r=. then sz_r=0;
array asppnadx_r[25] dxccs_r1-dxccs_r25; do i=1 to 25; if asppnadx_r[i] in (129) 
	then asppna_r=1; end; drop i; if asppna_r=. then asppna_r=0;
array schizodx_r[25] dxccs_r1-dxccs_r25; do i=1 to 25; if schizodx_r[i] = 659 
	then schizo_r=1; end; drop i; if schizo_r=. then schizo_r=0;
array mooddx_r[25] dxccs_r1-dxccs_r25; do i=1 to 25; if mooddx_r[i] = 657 
	then mood_r=1; end; drop i; if mood_r=. then mood_r=0;
array suicidedx_r[25] dxccs_r1-dxccs_r25; do i=1 to 25; if suicidedx_r[i] = 662 
	then suicide_r=1; end; drop i; if suicide_r=. then suicide_r=0;
array alcsubdx_r[25] dxccs_r1-dxccs_r25; do i=1 to 25; if alcsubdx_r[i] in (660,661) 
	then alcsub_r=1; end; drop i; if alcsub_r=. then alcsub_r=0;
array poisondrugsdx_r[25] dxccs_r1-dxccs_r25; do i=1 to 25; if poisondrugsdx_r[i] in (241,242) 
	then poisondrugs_r=1; end; drop i; if poisondrugs_r=. then poisondrugs_r=0;
*categorize, age, race, admission type, discharge location, profit status, los;
	if age=. then age_cat = '     ';
		else if age<35 then age_cat = '18-34'; else if age<65 then age_cat = '35-64';
		else age_cat = '65+';
	if age_r=. then age_cat_r = '     ';
		else if age_r<35 then age_cat_r = '18-34'; else if age_r<65 then age_cat_r = '35-64'; 
		else age_cat_r = '65+';
	if race=. then race_cat = ' '; else if race=1 then race_cat='W'; 
		else if race=2 then race_cat = 'B'; 
		else if race=3 then race_cat = 'H'; else race_cat = 'O';
	if race_r=. then race_cat_r = ' '; else if race_r=1 then race_cat_r='W'; 
		else if race_r=2 then race_cat_r = 'B'; 
		else if race_r=3 then race_cat_r = 'H'; else race_cat_r = 'O';
	if atype=. and asource=. then atype_cat= '           '; 
		else if atype in (1,2) or asource=1 then atype_cat='Emergent/urgent'; 
		else atype_cat='Non-emergent';
	if atype_r=. and asource_r=. then atype_cat_r= '           '; 
		else if atype_r in (1,2) or asource_r=1 then atype_cat_r='Emergent/urgent'; 
		else atype_cat_r='Non-emergent';
	if dispub04 in (.,99,7) then dispub04_cat = '       '; else if dispub04=1 then dispub04_cat = 'Home'; 
		else if dispub04 = 2 then dispub04_cat = 'Inpt';
		else if dispub04 in (3,83) then dispub04_cat='SNF'; 
		else if dispub04 in (50,51) then dispub04_cat='Hospice'; 
		else if dispub04 in (20,40,41,42) then dispub04_cat = 'Expired'; 
		else if dispub04 in (62,90) then dispub04_cat = 'IPR'; else dispub04_cat = 'Other';
	if dispub04_r in (.,99,7) then dispub04_cat_r = '        '; else if dispub04_r=1 then dispub04_cat_r = 'Home'; 
		else if dispub04_r=2 then dispub04_cat_r = 'Inpt'; 
		else if dispub04_r in (3,83) then dispub04_cat_r='SNF'; 
		else if dispub04_r in (50,51) then dispub04_cat_r='Hospice'; 
		else if dispub04_r in (20,40,41,42) then dispub04_cat_r = 'Expired'; 
		else if dispub04_r in (62,90) then dispub04_cat_r = 'IPR'; else dispub04_cat_r = 'Other';
	if cntrl = ' ' then cntrl_cat = '            '; 
		else if cntrl in ('31','32','33') then cntrl_cat = 'Investor, FP';
		else cntrl_cat = 'Other';
	if cntrl_r = ' ' then cntr_cat = '           ';
		else if cntrl_r in ('31','32','33') then cntrl_cat_r = 'Investor, FP'; 
		else cntrl_cat = 'Other';
	if los=. then los_cat='       '; else if los<2 then los_cat='1: 0-1'; else if los<8 then los_cat='2: 2-7';
		else los_cat='3: 8+';
	if los_r=. then los_cat_r='       '; else if los_r<2 then los_cat_r='1: 0-1'; else if los_r<8 then los_cat_r='2: 2-7';
		else los_cat_r='3: 8+';
	if u_ctscan=. then u_ctscan_cat=.; else if u_ctscan=0 then u_ctscan_cat=0; else u_ctscan_cat=1;
	if u_mrt=. then u_mrt_cat=.; else if u_mrt=0 then u_mrt_cat=0; else u_mrt_cat=1;
	if u_eeg=. then u_eeg_cat=.; else if u_eeg=0 then u_eeg_cat=0; else u_eeg_cat=1;
	if u_dialysis=. then u_dialysis_cat=.; else if u_dialysis=0 then u_dialysis_cat=0; else u_dialysis_cat=1;
	if u_ctscan_r=. then u_ctscan_cat_r=.; else if u_ctscan_r=0 then u_ctscan_cat_r=0; else u_ctscan_cat_r=1;
	if u_mrt_r=. then u_mrt_cat_r=.; else if u_mrt_r=0 then u_mrt_cat_r=0; else u_mrt_cat_r=1;
	if u_eeg_r=. then u_eeg_cat_r=.; else if u_eeg_r=0 then u_eeg_cat_r=0; else u_eeg_cat_r=1;
	if u_dialysis_r=. then u_dialysis_cat_r=.; else if u_dialysis_r=0 then u_dialysis_cat_r=0; else u_dialysis_cat_r=1;
	if totchg=. then totchg_cat='          '; else if totchg<15000 then totchg_cat='1: <15k';
		else if totchg<30000 then totchg_cat='2: 15-30k'; else if totchg<45000 then totchg_cat='3: 30-45k';
		else totchg_cat='4: >45k';
	if totchg_r=. then totchg_cat_r='          '; else if totchg_r<15000 then totchg_cat_r='1: <15k';
		else if totchg_r<30000 then totchg_cat_r='2: 15-30k'; else if totchg_r<45000 then totchg_cat_r='3: 30-45k';
		else totchg_cat_r='4: >45k';
	if hospbd=. then hospbd_cat='          '; else if hospbd<200 then hospbd_cat='1: <200';
		else if hospbd<600 then hospbd_cat='2: 200-599'; else hospbd_cat='3: 600+';
	if hospbd_r=. then hospbd_cat_r='          '; else if hospbd_r<200 then hospbd_cat_r='1: <200';
		else if hospbd_r<600 then hospbd_cat_r='2: 200-599'; else hospbd_cat_r='3: 600+';
	if cbsatype='Rural' then cbsatype_cat='Rural    '; else if cbsatype=' ' then cbsatype_cat=' ';
		else cbsatype_cat='Non-rural';
	if cbsatype_r='Rural' then cbsatype_cat_r='Rural    '; else if cbsatype_r=' ' then cbsatype_cat_r=' ';
		else cbsatype_cat_r='Non-rural';
	if dxccs_r1 = 83 and readmit30d_bin = 1 then epi_30dreadmit=1; else epi_30dreadmit=0;
	if dx1status_r = 1 and readmit30d_bin = 1 then status_30dreadmit=1; else status_30dreadmit=0;
	if readmit30d_bin then los_diff=los-los_r; else los_diff=.;
	if readmit30d_bin then totchg_diff=totchg-totchg_r; else totchg_diff=.;
	if FTRES/hospbd>0.25 or MAPP8='1' or MAPP3='1' then teaching=1;
		else if hospbd=. and mapp8=' ' and mapp3=' ' then teaching=.;
		else teaching=0;
	where first_epi_admit;
	run;

*exclude those discharged expired, since they don't have an opportunity for readmission;
data e.epi28aha2; set e.epi28aha2; where died ne 1 and dispub04_cat ne 'Expired'; run;
proc means data=e.epi28aha2 sum; var visit_count; run;

*exclude IPR and same-day rehab;
data e.epi28aha3;
	set e.epi28aha2;run;
data e.epi28aha3;set e.epi28aha3;
	excludeIPR=(dispub04_cat='IPR');
	excludesamedayrehab=(readmit30d_bin and daystonextadmit=0 and dxccs_r1=254);run;
data e.epi28aha3;set e.epi28aha3;where excludeIPR ne 1 and excludesamedayrehab ne 1; run;
proc means data=e.epi28aha3 sum; var visit_count; run;

*merge in epi volume;
proc sort data=e.epivol3; by ahaid; run;
proc sort data=e.epi28aha3; by ahaid; run;
data e.epi28aha3wvol;
	merge e.epi28aha3 e.epivol3; by ahaid; run;
data e.epi28aha3wvol; set e.epi28aha3wvol; 
	if epi_vol_av=. then epi_vol_av_cat='          ';
		else if epi_vol_av < 50 then epi_vol_av_cat='1: 1-49';
		else if epi_vol_av < 200 then epi_vol_av_cat='2: 50-199';
		else epi_vol_av_cat='3: 200+';
	where visitlink>0;
	run;

*dataset including only those with 30-day readmissions;
data e.epi28aha3_r;
	set e.epi28aha3wvol;
	where readmit30d_bin;
	run;

*RJW data;
*~1300 people have present ahaid and hospstco but missing fcounty. hospstco (numeric) from epi datset is equivalent 
	to fcounty ($6) from aha dataset. both are contained in epiaha dataset. need to fill in missing fcounty's 
	with hospstco. looks easier to have fcounty be numeric;
data e.epi28aha3wvol_fillinfcounty;
	set e.epi28aha3wvol;
	if fcounty ne ' ' then fcounty2=input(fcounty, 6.); else fcounty2=hospstco;
	drop fcounty; rename fcounty2=fcounty;
	run;

*import RWJ data. save 'selected data' xlsx file (which comes from 2012 CHR sheet) into txt file because of 64/32 bit error with xlsx. error message with this, but the error is brilliantly to
	delete the NR's which I would have wished to delete anyways;
*merge epi with RJW. epi28aha2 variable looks like fcounty which is $6.;
data r.r1;
	set r.r; *remove the final _, which I included in excel to preserve the character format during upload;
	*I previously converted FIPS to character preserving leading 0's using...if substr(var1,length(var1),1) = '_' then var1 = substr(var1,1,length(var1)-1);
	drop var1 var2;
	rename fips=fcounty;
	run;
proc sort data=r.r1; by fcounty; run;
proc sort data=e.epi28aha3wvol_fillinfcounty; by fcounty; run;
data e.epi28aha4;
	merge e.epi28aha3wvol_fillinfcounty r.r1; by fcounty; run;
data e.epi28aha4; set e.epi28aha4; 
	d_fairpoorhealth = p_fairpoorhealth/10;
	d_mentallyunhealthydays=n_mentallyunhealthydays; *...#/month; 
	d_smoker = p_smoker/10;
	d_obese = p_obese/10;
	d_exdrink = p_exdrink/10;
	d_unins = p_unins/10;
	d_pcp = r_pcp/10; *pcps/100k population;
	d_ambsenshosp = r_ambsenshosp/10; *discharges per 1000 medicare enrolles;
	d_college = p_college/10;
	d_unemp = p_unemp/10; 
	d_inadsoc = p_inadsoc/10;
	d_illit = p_illit/10;
	d_nodoccost = p_nodoccost/10;
	d_mentalproviders = r_mentalproviders/10; *providers per 100k population;
	d_income = income/10000;
	where visitlink>0; run;

*make counter so glimmix's are more efficient;
proc sort data=e.epi28aha4; by fcounty ahaid; run;
Data e.x; 
	set e.epi28aha4 (keep=ahaid fcounty); by fcounty ahaid; if first.ahaid; run;
data e.x;
	set e.x;
	by fcounty ahaid;
	if first.fcounty then ahaidcounter = 0;
	ahaidcounter+1;
run;
data e.epi28aha5;
	merge e.epi28aha4 e.x;
	by fcounty ahaid;
	run;
data e.epi28aha5;
	set e.epi28aha5;
	if ahaid=' ' then ahaidcounter=.; else ahaidcounter=ahaidcounter;
	run;

***************************************double checks;
*double check the 30 day readmission indicator;
proc print data=e.epi28aha2; var visitlink daystoevent daystoevent_r visit_count readmit_cat readmit30d_bin;where visitlink<1000;run;
proc print data=e.epi28aha1; var daystoevent daystoevent_r dxccs1 dxccs_r1; where visitlink=894;run;
proc print data=e.epi28aha2; var visitlink daystoevent daystoevent_r los visit_count readmit_cat readmit30d_bin;where visitlink=894;run; *yep;
*double check that next-row of data and readmissions are pulled correctly. relevant variables visitlink, daystoevent, dxccs1, totchg (i.e. should be exact), totchg_r;
proc sort data=e.epi28aha1;by visitlink daystoevent;run;
proc print data=e.epi28aha1;var visitlink daystoevent dxccs1 dxccs_r1 totchg totchg_r first_epi_admit; where visitlink<1000;run; *yep;
*double check correct RWJ;
proc print data=e.epi28aha5; var fcounty; where visitlink<500;run;
proc print data=e.epi28aha5; var visitlink fcounty n_mentallyunhealthydays p_unemp; where fcounty in (5119,12019,12031,12053,37067,53033);run;
proc print data=r.r1; var fcounty n_mentallyunhealthydays p_unemp; where fcounty in (5119,12019,12031,12053,37067,53033);run;
*double check AHA;
proc print data=e.epi28aha5; var ahaid; where visitlink<500;run;
proc print data=e.epi28aha5; var visitlink ahaid ipdtot; where ahaid in ('6710335','6390700','6390082','6390082','6390082','6390082');run;
proc print data=e.aha2; var ahaid ipdtot; where ahaid in ('6710335','6390700','6390082','6390082','6390082','6390082');run;
*double check epivol;
proc means data=e.epi28aha1 sum;var epi_admit;where ahaid='6390700';run;
proc print data=e.aha2;;var cntyname; where ahaid='6390700';run; *362 epi admits for this hopsital in FL;
proc freq data=e.epi28aha1;tables year;where ahaid='6390700';run; *4 years for this hospital. so epi vol should be 362/4=90.5;
proc means data=e.epi28aha5 mean;var epi_vol_av; where ahaid='6390700';run; *YES!!!!!!!!!!!!!!!!!!!!!!!!!!!;
*hospital beds v epilepsy volume, expect to be positively correlated;
proc sgplot data=e.epi28aha5;scatter x=hospbd y=epi_vol_av;run; *yep;