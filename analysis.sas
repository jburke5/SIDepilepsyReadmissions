libname e 'Q:\Sam';
libname r 'Q:\Sam\RWJ';
OPTIONS FMTSEARCH=(e);

*state/year;
proc freq data=e.epi28aha5;tables state*year/norow nocol nopercent;run;

*% missing;
proc freq data=e.epi28aha5;
	tables age_cat race_cat female 
		cm_alcohol cm_chf cm_chrnlung cm_depress cm_dm cm_drug cm_psych
		year aweekend tran_in atype_cat dx1status dx1refr tubed 
		stroke bleed tumor tbi infxn arrest hyposm alc brainsx 
		pay1 los_cat tran_out tran_out*dispub04_cat totchg_cat 
		cntrl_cat hospbd_cat cbsatype teaching epi_vol_av_cat/missing;
		format tran_in tran_in. pay1 payer.; run;

*nmissing, continuous;
proc means data=e.epi28aha5 nmiss n;
	var d_fairpoorhealth 
		n_mentallyunhealthydays d_smoker d_obese d_exdrink d_unins d_pcp d_mentalproviders 
		d_ambsenshosp d_college d_unemp d_inadsoc d_illit d_income d_nodoccost; run;

*% of non-missing;
proc freq data=e.epi28aha5;
	tables age_cat race_cat female 
		cm_alcohol cm_chf cm_chrnlung cm_depress cm_dm cm_drug cm_psych
		year aweekend tran_in atype_cat dx1status dx1refr tubed 
		stroke bleed tumor tbi infxn arrest tbi alc brainsx 
		pay1 los_cat tran_out tran_out*dispub04_cat totchg_cat 
		cntrl_cat hospbd_cat cbsatype_cat teaching epi_vol_av_cat;
		format tran_in tran_in. pay1 payer.;
run;

proc univariate data=e.epi28aha5; histogram los;run;
proc freq data=e.epi28aha5;tables los;run;

*median IQR of non-missing;
proc means data=e.epi28aha5 p50 p25 p75;
	var age los totchg hospbd epi_vol_av
	p_fairpoorhealth n_mentallyunhealthydays p_smoker p_obese p_exdrink p_unins r_pcp r_mentalproviders 
	r_ambsenshosp p_college p_unemp p_inadsoc p_illit income p_nodoccost;
	run;

*rural analysis;
proc freq data=e.aha2;
	tables cbsatype;
	run; *% hospitals in country which are rural;
proc freq data=e.epi28aha5;
	tables cbsatype_cat;
	run; *% hospitals in our sample which are rural;
proc freq data=e.epi28aha2_r;
	tables cbsatype_cat_r;
	run; *% readmitting hospitals which are rural;
proc means data=e.aha2 sum;	var hospbd; where cbsatype='Rural'; run;
proc means data=e.aha2 sum;	var hospbd; where cbsatype ne 'Rural'; run;
proc sort data=e.epi28aha5; by cbsatype_cat;
proc means data=e.epi28aha5 sum; var hospbd; by cbsatype_cat; run;
proc sort data=e.epi28aha2_r; by cbsatype_cat_r;
proc means data=e.epi28aha2_r sum; var hospbd; by cbsatype_cat_r; run;

*% of each strata which were readmitted;
proc freq data=e.epi28aha5;
	tables (age_cat race_cat female 
		cm_alcohol cm_chf cm_chrnlung cm_depress cm_dm cm_drug cm_psych
		year aweekend tran_in atype_cat dx1status dx1refr tubed 
		stroke bleed tumor tbi infxn arrest tbi alc brainsx 
		pay1 los_cat tran_out totchg_cat 
		cntrl_cat hospbd_cat cbsatype_cat teaching epi_vol_av_cat)
	*readmit30d_bin/nopercent nocol;
	format tran_in tran_in. pay1 payer.;
	run;

proc freq data=e.epi28aha5;
	tables (age_cat race_cat female 
		cm_alcohol cm_chf cm_chrnlung cm_depress cm_dm cm_drug cm_psych
		year aweekend tran_in atype_cat dx1status dx1refr tubed 
		stroke bleed tumor tbi infxn arrest hyposm alc brainsx 
		pay1 los_cat tran_out totchg_cat 
		cntrl_cat hospbd_cat cbsatype teaching epi_vol_av_cat)
	*status_30dreadmit/nopercent nocol norow;
	format tran_in tran_in. pay1 payer.;
	run; *note the separation of values for TBI, bleed;

*median IQR for continuous variables by readmission category;
proc sort data=e.epi28aha5; by readmit30d_bin; run;
proc means data=e.epi28aha5 p50 p25 p75;
	var age los totchg hospbd epi_vol_av
	p_fairpoorhealth n_mentallyunhealthydays p_smoker p_obese p_exdrink p_unins r_pcp r_mentalproviders 
	r_ambsenshosp p_college p_unemp p_inadsoc p_illit income p_nodoccost;
	by readmit30d_bin;
	run;

*readmit by state;
proc freq data=e.epi28aha5;
	tables state*readmit30d_bin/nopercent nocol chisq;
	run;

*describe index v readmission for those readmitted for selected variable;
proc means data=e.epi28aha3_r p50 p25 p75;
	var los los_r totchg totchg_r; run;
proc univariate data=e.epi28aha3_r;
	var los_diff totchg_diff;
	histogram; qqplot; run;
proc ttest data=e.epi28aha3_r; paired los*los_r totchg*totchg_r; run;
proc freq data=e.epi28aha3_r;
	tables atype_cat*atype_cat_r dx1status*dx1status_r tubed*tubed_r dispub04_cat*dispub04_cat_r died_r
		/nocol nopercent norow agree; 
	run;

*multi-level CCS macro readmit diagnoses;

*single-level CCS readmit diagnoses;
proc freq data=e.epi28aha3_r;
	tables dxccs_r1; 
	format dxccs_r1 ccs.;
	run;

*epi specific readmit diagnoses;
proc freq data=e.epi28aha3_r;
	tables dx1status_r dx1refr_r;
	run;
proc means data=e.epi28aha3_r n nmiss; var visitlink; where dxccs_r1=83;run;
proc means data=e.epi28aha3_r n nmiss; var visitlink; where dxccs_r1 ne 83;run;
proc freq data=e.epi28aha2_r;
	tables dx_r1;
	format dx_r1 $I9DXF.; where dxccs_r1=83;
	run;

*if a diagnosis appears in any diagnosis, dx_r1-dx_r25;
proc freq data=e.epi28aha2_r;
	tables fracture_r headinjury_r sz_r asppna_r psych_r alcsub_r poisondrugs_r;
	run;

*models;
*unadjusted logistic regressions;
%macro l(var,ref);
   proc logistic data=e.epi28aha5 noprint;
   class &var (ref=&ref);	
   model readmit30d_bin (event='1') = &var;
   output out=e.x pred=yhat;
   run;
   proc ttest data=e.x; class readmit30d_bin; var yhat; run;
%mend l;
%macro lc(var);
   proc logistic data=e.epi28aha5;
   model readmit30d_bin (event='1') = &var;
   output out=e.x pred=yhat;
   run;
   proc ttest data=e.x; class readmit30d_bin; var yhat; run;
%mend lc;
%l(age_cat,'18-34');
%l(race_cat,'W');
%l(female,'0');
%l(cm_alcohol,'0');
%l(cm_chf,'0');
%l(cm_depress,'0');
%l(cm_drug,'0');
%l(cm_psych,'0');
%l(year,'2009');
%l(aweekend,'0');
%l(tran_in,'0');
%l(atype_cat,'Non-emergen');
%l(dx1status,'0');
%l(dx1refr,'0');
%l(tubed,'0');
%l(stroke,'0');
%l(bleed,'0');
%l(tumor,'0');
%l(tbi,'0');
%l(infxn,'0');
%l(arrest,'0');
%l(hyposm,'0');
%l(alc,'0');
%l(brainsx,'0');
 proc logistic data=e.epi28aha5;
   class pay1 (ref='Medicare');	
   model readmit30d_bin (event='1') = pay1; format pay1 payer.;
   run;
%l(los_cat,'1: 0-1');
%l(tran_out,'0');
%l(cntrl_cat,'Other');
%l(hospbd_cat,'1: <200');
%l(cbsatype_cat,'Non-rural');
%l(teaching,'0');
%l(epi_vol_av_cat,'1: 1-49');
%lc(d_fairpoorhealth);
%lc(d_mentallyunhealthydays);
%lc(d_smoker);
%lc(d_obese);
%lc(d_exdrink);
%lc(d_unins);
%lc(d_pcp);
%lc(d_mentalproviders);
%lc(d_ambsenshosp);
%lc(d_college);
%lc(d_unemp);
%lc(d_inadsoc);
%lc(d_illit);
%lc(d_income);
%lc(d_nodoccost);

*adjusted logistic;
   proc logistic data=e.epi28aha5;
   class age_cat (ref='18-34') race_cat (ref='W') female (ref='0')
	cm_alcohol (ref='0') cm_chf (ref='0') cm_depress (ref='0') cm_drug (ref='0') cm_psych (ref='0') 
	tran_in (ref='Not transferred in') atype_cat (ref='Non-emergen') dx1status (ref='0') tubed (ref='0') 
	pay1 (ref='Medicare') los_cat (ref='1: 0-1') tran_out (ref='Not a transfer') 
	cntrl_cat (ref='Other') hospbd_cat (ref='1: <200') cbsatype_cat (ref='Non-rural') epi_vol_av_cat (ref='1: 1-49');
   model readmit30d_bin (event='1') = age_cat race_cat female 
	cm_alcohol  cm_chf  cm_depress cm_drug cm_psych tran_in
	atype_cat dx1status tubed 
	stroke bleed tumor infxn arrest alc tbi brainsx 
	pay1 los_cat tran_out cntrl_cat
	hospbd_cat cbsatype_cat teaching epi_vol_av_cat
	d_fairpoorhealth n_mentallyunhealthydays d_smoker d_obese d_exdrink d_unins d_pcp d_mentalproviders d_ambsenshosp 
	d_college d_unemp d_inadsoc d_illit d_income d_nodoccost/ lackfit rsquare; *Hosmer, and cox snellen rsquared;
   format pay1 payer. tran_in tran_in. tran_out tran_out.;
   output out=e.x pred=yhat;
   run;
proc ttest data=e.x; class readmit30d_bin; var yhat; run; *tjur r-squared;

*adjusted logistic, excluding 78039;
   proc logistic data=e.epi28aha5;
   class age_cat (ref='18-34') race_cat (ref='B') female (ref='0')
	cm_alcohol (ref='0') cm_chf (ref='0') cm_chrnlung (ref='0') cm_depress (ref='0') cm_dm (ref='0')
	cm_drug (ref='0') cm_psych (ref='0') year (ref='2009') aweekend (ref='0') tran_in (ref='Not transferred in')
	atype_cat (ref='Non-emergen') dx1status (ref='0') dx1refr (ref='0') tubed (ref='0') 
	pay1 (ref='Medicare') los_cat (ref='0-1') tran_out (ref='Not a transfer') totchg_cat (ref='1: <15k') 
	cntrl_cat (ref='Gvt, Nonfed') hospbd_cat (ref='1: <200') 
	cbsatype_cat (ref='Non-rural') epi_vol_av_cat (ref='1: 1-40');
   model readmit30d_bin (event='1') = age_cat race_cat female 
	cm_alcohol  cm_chf  cm_chrnlung cm_depress cm_dm
	cm_drug cm_psych year aweekend tran_in
	atype_cat dx1status dx1refr tubed 
	stroke bleed tumor tbi infxn arrest hyposm alc brainsx 
	pay1 los_cat tran_out totchg_cat cntrl_cat 
	hospbd_cat cbsatype_cat teaching epi_vol_av_cat
	d_fairpoorhealth n_mentallyunhealthydays d_smoker d_obese d_exdrink d_unins d_pcp d_mentalproviders d_ambsenshosp 
	d_college d_unemp d_inadsoc d_illit d_income d_nodoccost/ lackfit rsquare; *Hosmer, and cox snellen rsquared;
   format pay1 payer. tran_in tran_in. tran_out tran_out.;
   where dx1 ne '78039';
   output out=e.x pred=yhat;
   run;
proc ttest data=e.x; class readmit30d_bin; var yhat; run; *tjur r-squared;

*adjusted logistic, outcome is status readmit;
   proc logistic data=e.epi28aha5;
   class age_cat (ref='18-34') race_cat (ref='W') female (ref='0')
	cm_alcohol (ref='0') cm_chf (ref='0') cm_depress (ref='0')	cm_drug (ref='0') cm_psych (ref='0') 
	tran_in (ref='Not transferred in') atype_cat (ref='Non-emergen') dx1status (ref='0') tubed (ref='0') 
	pay1 (ref='Medicare') los_cat (ref='1: 0-1') tran_out (ref='Not a transfer') 
	cntrl_cat (ref='Other') hospbd_cat (ref='1: <200') 
	cbsatype_cat (ref='Non-rural') epi_vol_av_cat (ref='1: 1-49');
   model status_30dreadmit (event='1') = age_cat race_cat female 
	cm_alcohol  cm_chf  cm_depress cm_drug cm_psych 
	tran_in atype_cat dx1status tubed 
	stroke bleed tumor tbi infxn arrest alc brainsx 
	pay1 los_cat tran_out cntrl_cat 
	hospbd_cat cbsatype_cat teaching epi_vol_av_cat
	d_fairpoorhealth n_mentallyunhealthydays d_smoker d_obese d_exdrink d_unins d_pcp d_mentalproviders d_ambsenshosp 
	d_college d_unemp d_inadsoc d_illit d_income d_nodoccost/ lackfit rsquare; *Hosmer, and cox snellen rsquared;
	format pay1 payer. tran_in tran_in. tran_out tran_out.;
	output out=e.x pred=yhat;
   run;
proc ttest data=e.x; class status_30dreadmit; var yhat; run; *tjur r-squared;

*intercept only mixed intercept;
proc glimmix data=e.epi28aha5; 
	class ahaidcounter fcounty;
	model readmit30d_bin (event='1') = / 
		dist=binary link=logit ddfm=satterth oddsratio;
	random intercept / subject=fcounty;
	random intercept / subject=ahaidcounter(fcounty);
	*covtest 'var(fcounty) = 0' 0 .;
	*covtest 'var(ahaid(fcounty)) = 0' . 0;
	output out=e.cstats_intonly pred=xbeta pred(ilink)=predprob;
	run;
*c-statistic;
proc logistic data=e.cstats_intonly plots(only)=roc  PLOTS(MAXPOINTS=NONE);
	model readmit30d_bin (event='1') = predprob; 
	run;
*r-squared;
proc ttest data=e.cstats_intonly; class readmit30d_bin; var predprob; run;

*fully adjusted mixed model;
proc glimmix data=e.epi28aha5;
	class 
		ahaidcounter fcounty
    age_cat (ref='18-34') race_cat (ref='W') female (ref='0')
	cm_alcohol (ref='0') cm_chf (ref='0') cm_depress (ref='0')
	cm_drug (ref='0') cm_psych (ref='0') tran_in (ref='Not transferred in')
	atype_cat (ref='Non-emergen') dx1status (ref='0') tubed (ref='0') 
	pay1 (ref='Medicare') los_cat (ref='1: 0-1') tran_out (ref='Not a transfer')
	cntrl_cat (ref='Other') hospbd_cat (ref='1: <200') 
	cbsatype_cat (ref='Non-rural') epi_vol_av_cat (ref='1: 1-49');
	model readmit30d_bin (event='1') =
	age_cat race_cat female 
	cm_alcohol  cm_chf  cm_depress
	cm_drug cm_psych tran_in
	atype_cat dx1status tubed 
	stroke bleed tumor tbi infxn arrest alc brainsx 
	pay1 los_cat tran_out cntrl_cat 
	hospbd_cat cbsatype_cat teaching epi_vol_av_cat
	d_fairpoorhealth n_mentallyunhealthydays d_smoker d_obese d_exdrink d_unins d_pcp d_mentalproviders d_ambsenshosp 
	d_college d_unemp d_inadsoc d_illit d_income d_nodoccost/ 
	dist=binary link=logit ddfm=satterth oddsratio;
	random intercept / subject=fcounty;
	random intercept / subject=ahaidcounter(fcounty);
	output out=e.cstats pred=xbeta pred(ilink)=predprob;
	format pay1 payer. tran_in tran_in. tran_out tran_out.;
	run;
*c-statistic;
proc logistic data=e.cstats plots(only)=roc  PLOTS(MAXPOINTS=NONE);
	model readmit30d_bin (event='1') = predprob; 
	run;
*r-squared;
proc ttest data=e.cstats; class readmit30d_bin; var predprob; run;

*calibration. dataset is the output from adjusted logistic;
proc rank data=e.x groups=10 out=e.deciles;
var yhat; ranks decile; run; 
data e.deciles; set e.deciles(keep=readmit30d_bin yhat decile);where yhat ne .;run;
proc sort data=e.deciles;by decile;run;
proc means data=e.deciles mean std n; var readmit30d_bin yhat; by decile;output out=e.deciles2;run;
data e.decilesobs; set e.deciles2;where _stat_='MEAN';decile=decile+1;keep decile readmit30d_bin;run;
proc transpose data=e.deciles2 out=e.deciles3 prefix=predicted;
    by decile; id _stat_; var yhat; run; data e.deciles3; set e.deciles3;decile=decile+1;
	drop predictedMIN predictedMAX _LABEL_ _NAME_; run;
data e.deciles4; merge e.deciles3 e.decilesobs; by decile;run;
	data e.deciles4;set e.deciles4;
	readmit30d_bin_std=sqrt(readmit30d_bin*(1-readmit30d_bin)/predictedN);run;
proc export data=e.deciles4 dbms=xlsx outfile="Q:\Sam\calibration.xlsx" replace; run;

******************more detailed missing analysis;

*variables names
demographics: age_cat race_cat female
comorbidities: cm_alcohol cm_chf cm_chrnlung cm_depress cm_dm cm_drug cm_neuro cm_psych
hospitalization: year aweekend tran_out atype_cat dx1status dx1refr u_icu pay1 tubed u_ctscan 
	u_mrt u_eeg u_dialysis los dispub04_cat totchg
hospital: cntrl_cat hospbd cbsatype teaching phygp nerohos mrihos;

*missing;
data e.missing; set e.epi28aha5 /*(keep=
	ahaid hospid dshospid hospstco stcd hospn mcntycd fcounty fstcd fcntycd 
	readmit30d_bin year ahaid age_cat race_cat female  cm_alcohol state year 
	cntrl_cat hospbd_cat cbsatype_cat teaching epi_vol_av_cat 
	cm_chf cm_chrnlung cm_depress cm_dm cm_drug cm_psych year aweekend tran_in 
	atype_cat dx1status dx1refr tubed pay1 los_cat dispub04_cat totchg_cat
	d_fairpoorhealth 
	n_mentallyunhealthydays d_smoker d_obese d_exdrink d_unins d_pcp d_mentalproviders 
	d_ambsenshosp d_college d_unemp d_inadsoc d_illit d_income d_nodoccost state fcounty)*/;
readmit30d_bin_m=(readmit30d_bin=.);
ahaid_m=(ahaid=' ');
age_cat_m=(age_cat=' ');
race_cat_m=(race_cat=' ');
female_m=(female=.);
cm_alcohol_m=(cm_alcohol=.);
cm_chf_m=(cm_chf=.);
cm_chrnlung_m=(cm_chrnlung=.);
cm_depress_m=(cm_depress=.);
cm_dm_m=(cm_dm=.);
cm_drug_m=(cm_drug=.);
cm_psych_m=(cm_psych=.);
year_m=(year=.);
aweekend_m=(aweekend=.);
tran_in_m=(tran_in=.);
atype_cat_m=(atype_cat=' ');
dx1status_m=(dx1status=.);
dx1refr_m=(dx1refr=.);
tubed_m=(tubed=.);
pay1_m=(pay1=.);
los_cat_m=(los_cat=' ');
tran_out_m=(tran_out=.);
totchg_cat_m=(totchg_cat=' ');
cntrl_cat_m=(cntrl_cat=' ');
hospbd_cat_m=(hospbd_cat=' ');
cbsatype_cat_m=(cbsatype_cat=' ');
teaching_m=(teaching=.);
epi_vol_av_cat_m=(epi_vol_av_cat=' ');
d_fairpoorhealth_m=(d_fairpoorhealth=.);
n_mentallyunhealthydays_m=(n_mentallyunhealthydays=.); 
d_smoker_m=(d_smoker=.); 
d_obese_m=(d_obese=.); 
d_exdrink_m=(d_exdrink=.); 
d_unins_m=(d_unins=.); 
d_pcp_m=(d_pcp=.); 
d_mentalproviders_m=(d_mentalproviders=.); 
d_ambsenshosp_m=(d_ambsenshosp=.); 
d_college_m=(d_college=.); 
d_unemp_m=(d_unemp=.); 
d_inadsoc_m=(d_inadsoc=.); 
d_illit_m=(d_illit=.); 
d_income_m=(d_income=.); 
d_nodoccost_m=(d_nodoccost=.);
fcounty_m=(fcounty=.);
sum_m=sum(of readmit30d_bin_m -- fcounty_m);
miss=(sum_m>0);
if ahaid ne ' ' and fcounty ne . and teaching=. and cbsatype_cat=' ' and cntrl_cat=' '
	then AHAIDbutnotinAHA=1; else AHAIDbutnotinAHA=0;
*drop age_cat race_cat female  cm_alcohol 
		cm_chf cm_chrnlung cm_depress cm_dm cm_drug cm_psych aweekend tran_in 
		atype_cat dx1status dx1refr tubed pay1 los_cat dispub04_cat totchg_cat
		d_fairpoorhealth;
run;

proc freq data=e.missing;tables miss;run;
proc freq data=e.missing; tables miss;
	where state not in ('NE','MA') and (state='NC' and year=2009)=0; run;

proc freq data=e.missing; tables (
readmit30d_bin_m
age_cat_m
race_cat_m
female_m
cm_alcohol_m
cm_chf_m
cm_chrnlung_m
cm_depress_m
cm_dm_m
cm_drug_m
cm_psych_m
year_m
aweekend_m
tran_in_m
atype_cat_m
dx1status_m
dx1refr_m
tubed_m
pay1_m
los_cat_m
tran_out_m
totchg_cat_m
ahaid_m
cntrl_cat_m
hospbd_cat_m
cbsatype_cat_m
teaching_m
epi_vol_av_cat_m
fcounty_m
d_fairpoorhealth_m
n_mentallyunhealthydays_m
d_smoker_m
d_obese_m
d_exdrink_m
d_unins_m
d_pcp_m
d_mentalproviders_m
d_ambsenshosp_m
d_college_m
d_unemp_m
d_inadsoc_m 
d_illit_m
d_income_m
d_nodoccost_m)*state / nopercent norow nocol; 
	where miss>0 and state not in ('NE','MA') and (state='NC' and year=2009)=0; 
run;

proc freq data=e.missing; tables state*race_cat_m*year/nocol norow nopercent;run;

proc freq data=e.missing; tables (
readmit30d_bin_m
age_cat_m
race_cat_m
female_m
cm_alcohol_m
cm_chf_m
cm_chrnlung_m
cm_depress_m
cm_dm_m
cm_drug_m
cm_psych_m
year_m
aweekend_m
tran_in_m
atype_cat_m
dx1status_m
dx1refr_m
tubed_m
pay1_m
los_cat_m
tran_out_m
totchg_cat_m
ahaid_m
cntrl_cat_m
hospbd_cat_m
cbsatype_cat_m
teaching_m
epi_vol_av_cat_m
fcounty_m
d_fairpoorhealth_m
n_mentallyunhealthydays_m
d_smoker_m
d_obese_m
d_exdrink_m
d_unins_m
d_pcp_m
d_mentalproviders_m
d_ambsenshosp_m
d_college_m
d_unemp_m
d_inadsoc_m 
d_illit_m
d_income_m
d_nodoccost_m)*readmit30d_bin / nopercent norow nocol chisq; 
	where miss>0 and state not in ('NE','MA') and (state='NC' and year=2009)=0; 
run;

proc freq data=e.missing; tables
readmit30d_bin_m
age_cat_m
race_cat_m
female_m
cm_alcohol_m
cm_chf_m
cm_chrnlung_m
cm_depress_m
cm_drug_m
cm_psych_m
tran_in_m
atype_cat_m
dx1status_m
tubed_m
pay1_m
los_cat_m
tran_out_m
ahaid_m
cntrl_cat_m
hospbd_cat_m
cbsatype_cat_m
teaching_m
epi_vol_av_cat_m
fcounty_m
d_fairpoorhealth_m
n_mentallyunhealthydays_m
d_smoker_m
d_obese_m
d_exdrink_m
d_unins_m
d_pcp_m
d_mentalproviders_m
d_ambsenshosp_m
d_college_m
d_unemp_m
d_inadsoc_m 
d_illit_m
d_income_m
d_nodoccost_m; 
run;