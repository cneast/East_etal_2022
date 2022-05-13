/***********************************************************************
PROGRAM:	1_EHLMV_results_emp_FINAL.do 
PURPOSE:    Convert the Control Variable Data Set from County Level to CZ level
			Convert the ACS Employment Data Set from PUMA Level to CZ level and Merge in Controls
			Conduct Main Analysis on Population, Employment, Unemployment and Out of the Labor Force Variables 
CREATES: 	Figures: 1, 2A, 2C, 3A, 3B, 3C
			Tables: 2, 3 (col 1-3), 4 (col 1-3), 5, 6 (panel A), 7, 9 (panel A), 10 (column 1)
			A1 (1st two panels), A2 (col 1-2), A3, A4, A5 (panel A)
************************************************************************/


*******************************************************
clear all
drop _all
matrix drop _all
scalar drop _all 
set more off
set matsize 11000 
capture clear
capture log close
capture estimates clear
set seed 10101
pause off

*set directory
cd "$user"

global data 
global resultsfolder 


set more off
set scheme modern


* readin sanctuary city info
preserve
import excel using "$data/ice_policies/ice_policies.xlsx", firstrow clear
keep county state fips month year policy_any
	replace county=strtrim(county)
	replace state=strtrim(state)
	rename month sanctuary_month
	rename year sanctuary_year
	rename policy_any sanctuary_policy

	drop if sanctuary_policy==. 
	drop if fips=="n/a"
	drop if county=="California (state)" | county=="Connecticut (state)"
	destring fips sanctuary*, replace
	rename fips countyfip 
	
	duplicates report countyfip
		* keep earliest year within a county
		collapse (min) sanctuary_month sanctuary_year (mean) sanctuary_policy, by(countyfip)
		duplicates report countyfip
		
	save "$data/ice_policies.dta", replace 
restore 


* Build CZ to CPUMA Concordance:
use "$data/crosswalks/PUMA_CPUMA_CW.dta", clear
replace puma00 = substr(trim(puma00),2,4)
gen puma2000 = state00+puma00
keep puma2000 cpuma10
duplicates drop
destring puma2000, replace
merge m:m puma2000 using "$data/crosswalks/cw_puma2000_czone/cw_puma2000_czone.dta"
keep if _merge ==3
drop puma2000
collapse (sum) af , by( cpuma cz)
duplicates drop
bysort cpuma : egen revwtg =sum(af)
rename cpuma10 cpuma0010
sort cpuma
replace af = af/revwtg
drop revwtg
save "$data/crosswalks/cw_cpuma2010_czone.dta", replace

* Readin Housing Start Data
preserve
forvalues y = 2000/2014 {
import excel using "$data/housing_starts.xlsx", sheet("`y'") clear first
gen n = _n
drop if n<3
rename Survey year
rename FIPS statefip
rename C countyfip
destring, replace
egen total_bldg=rowtotal(G J M P)
keep year statefip countyfip total_bldg
sum
save "$data/housing_starts`y'.dta", replace
}
forvalues y = 2000/2013 {
append using "$data/housing_starts`y'.dta"
}

tostring statefip , replace
gen countyfip2=string(countyfip,"%03.0f") 

egen cty_fips = concat(statefip countyfip2)
drop if cty_fips==".."
destring, replace

rename countyfip countyfips
merge m:1 statefip countyfips using "$data/County Level/county_population.dta"
tab year _merge
drop if _merge==2
drop _merge

*Merge CZ codes
merge m:m cty_fips using "$data/xw/cw_cty_czone_mod.dta"

 
collapse  (mean) total_bldg [aweight = pop2000], ///
				by(czone  year )
sum		
foreach var in total_bldg {
gen `var'00 = `var' if year==2000
gen `var'05 = `var' if year==2005
gen `var'06 = `var' if year==2006
gen `var'07 = `var' if year==2007
bysort czone: egen mx_`var'00=max(`var'00)
bysort czone: egen mx_`var'05=max(`var'05)
bysort czone: egen mx_`var'06=max(`var'06)
bysort czone: egen mx_`var'07=max(`var'07)
gen d_`var'_0006=(mx_`var'06-mx_`var'00)/mx_`var'00 
gen d_`var'_0507=(mx_`var'07-mx_`var'05)/mx_`var'05 
}
	

save "$data/housing_starts.dta", replace
restore


* Use policy variables constructed at the County and aggregate to the CZ  level
use "$data/County Level/287g_SC_EVerify_5_13_22.dta", clear

drop everify_all everify_public
// Add E-Verify Information from RAND Report and "State Actions Regarding E-Verify" and NCSL report
// used the NCSL report to classify types of laws and to find year, then used "State Actions Regarding E-Verify" 
// to find implementation dates
// if policy phased in over multiple months or years, pick the first date
gen everify_all = 0
replace everify_all = 1 if ((year>=2012) ) & statefip==1 //AL, in 2012 mad contractors not liable for subcontractors but don't include for now
replace everify_all = 1 if ((year>2008) ) & statefip==4 // AZ, 
replace everify_all = 1 if ((year>2011) ) & statefip==13 // GA, Requires private employers with more than 10 employees to use E-Verify
replace everify_all = 1 if ((year>=2012) ) & statefip==22 // LA, Private employers must either use E-Verify or retain work authorization documents. Protects employers from liability if they unknowingly hire illegal aliens while participating in E-Verify
replace everify_all = 1 if ((year>2008) ) & statefip==28 // MS, All employers, contractors, and subcontractors must use E-Verify
replace everify_all = 1 if ((year>2012) ) & statefip==37 // NC, All employers, counties, and municipalities must use E-Verify
replace everify_all = 1 if ((year>=2012) ) & statefip==45 // SC, All employers required to use E-Verify
replace everify_all = 1 if ((year>=2012) ) & statefip==47 // TN, All employers with 6 or more employees required to use E-Verify or request new employees provide valid state ID
replace everify_all = 1 if ((year>2010) ) & statefip==49 // UT, Private employers with more than 15 employees required to use status verification system such as E-Verify


gen everify_public=0 
replace everify_public =1 if ((year>=2008) ) & statefip==4 // AZ, all contractors, subcontractors, required also
replace everify_public =1 if ((year>2006) ) & statefip==8 // CO, State agencies, contractors required to use E-Verify
replace everify_public =1 if ((year>2011) ) & statefip==12 // FL, State agencies, contractors, subcontractors, also "encourage" other employers to use it
replace everify_public =1 if ((year>2007) ) & statefip==13 // GA, Public employers, contractors, subcontractors with 500+ employees, later pass penalties too
replace everify_public =1 if ((year>2009) ) & statefip==16 // ID, 	Requires all state agencies to verify work eligibility status of new employees; requires public contractors and subcontractors that receive state or federal funds to verify work eligibility status
replace everify_public =1 if ((year>=2012)) & statefip==18 // IN, 	State/local agencies and contractors required to use E-Verify and in 2015 Public works contractors required to use E-Verify
replace everify_public =1 if ((year>=2012) ) & statefip==22 // LA, 	All state contractors must participate in E-Verify under penalty of contract cancellation and ineligibility for 3 years
replace everify_public =1 if ((year>2012) ) & statefip==26 // MI, 	Contractors, subcontractors of the Department of Human Services and Department of Transportation required to use E-Verify
replace everify_public =1 if ((year>=2008) ) & statefip==27 // MN, 	Contracts in excess of $50,000 require vendors and subcontractors to use E-Verify
replace everify_public =0 if ((year>2011) ) & statefip==27 // MN, 	in "State Actions Regarding E-Verify": Governor Mark Dayton let the order expire in 2011.
replace everify_public =1 if ((year>=2009) ) & statefip==29 // MO, 	Public employers, contractors, subcontractors must use E-Verify
replace everify_public =1 if ((year>2009) ) & statefip==31 // NB, 	Public employers, contractors, and businesses qualifying for state tax incentives must use E-Verify
replace everify_public =1 if ((year>=2007) ) & statefip==37 // NC, 	All state agencies and institutions, including universities, must use E-Verify
replace everify_public =1 if ((year>2007) ) & statefip==40 // OK, 	Public employers, contractors, subcontractors must use E-Verify
replace everify_public =1 if ((year>=2013) ) & statefip==42 // PA, 	Public works contractors and subcontractors must use E-Verify
replace everify_public =1 if ((year>=2009) ) & statefip==45 // SC, 	Public employers and contractors required to use E-Verify
replace everify_public =1 if ((year>2015) ) & statefip==48 // TX, 	State agencies required to use E-Verify, implementation date: https://www.texastribune.org/2015/08/27/e-verify-mandate-becomes-law/
replace everify_public =1 if ((year>=2009) ) & statefip==49 // UT, 	Public employers, contractors, subcontractors required to use E-Verify
replace everify_public =1 if ((year>2012) ) & statefip==51 // VA, 	State agencies required to use E-Verify and in 2011, Public contractors, subcontractors with more than 50 employees required to use E-Verify
replace everify_public =1 if ((year>2012) ) & statefip==54 // WV,   Public employers and contractors required to use E-Verify



* merge in sanctuary city info created above
merge m:1 countyfip using "$data/ice_policies.dta"
	drop _merge
	

for any state287g jail287g task287g SC: gen X_jan = X if month==1
for any state287g jail287g task287g SC: gen X_march = X if month==3
for any state287g jail287g task287g SC: gen X_frac = X 

* generate policy variable =1 if sanctuary policy in place when SC started * 
bys countyfip: egen aux = min(year) if SC_frac>0 & SC_frac~=.
	bys countyfip: egen sc_firstyear = mean(aux)
	drop aux
	
gen sanctuary_on = 1 if sanctuary_year<=sc_firstyear & sanctuary_policy==1 // county-level indicator for a sanctuary policy that started before SC 
	* note - only 8 counties with policies in place when SC starts (only 12 total policies before 2013)
	* dropped CA and CT state policies, these are both 2014 anyway
	* This is equivalent to Alsan and Yang definition
	replace sanctuary_on =0 if sanctuary_on ==. 
		
	
label var sanctuary_on "Sanctuary before SC"

*Merge in annual housing price controls
rename countyfip countyfips
merge m:1 statefip countyfips year using "$data/County Level/hpi_ACS_countyfips.dta"
tab year _merge // nothing not matched in 2005-2011
drop _merge

*Merge in county pop
merge m:1 statefip countyfips using "$data/County Level/county_population.dta"
tab year _merge // nothing not matched in 2005-2011
keep if _merge==3
drop _merge
destring fips , gen (cty_fips)
sort cty_fips

*Merge CZ codes
merge m:m cty_fips using "$data/xw/cw_cty_czone_mod.dta"

 
collapse (rawsum) pop* (max) sanctuary_on (mean) region   HPIwith2000base  ///
				everify_* jail287g_march task287g_march state287g_march SC_march jail287g_jan ///
				task287g_jan state287g_jan SC_jan jail287g_frac task287g_frac state287g_frac SC_frac  [aweight = pop2000], ///
				by(czone  year )
				
merge 1:1 czone year using "$data/housing_starts.dta"
tab year _merge
gen trend = year-2004
gen hstboom_trend=d_total_bldg_0006*trend
gen hstboom_trend2=(d_total_bldg_0006^2)*trend
gen hstboom_trend3=(d_total_bldg_0006^3)*trend
				
* Add in Housing Boom Trend Control
preserve
	foreach y in 2000 2006 {
		gen HPIwith2000base`y'=HPIwith2000base if year==`y'
		bysort czone  : egen m_HPIwith2000base`y'=max(HPIwith2000base`y')
		}
	gen d_mhpi_0006 =(m_HPIwith2000base2006-m_HPIwith2000base2000)/m_HPIwith2000base2000
	collapse d_mhpi_0006, by(czone  )
	keep d_mhpi_0006  czone  
	duplicates drop
	sum 
	tempfile boomhouse
	save "`boomhouse'", replace
restore

cap drop _merge
merge m:1 czone   using "`boomhouse'"
gen hpiboom_trend2=(d_mhpi_0006^2)*trend	 			
gen hpiboom_trend3=(d_mhpi_0006^3)*trend	

cap drop _merge
gen hpiboom_trend=d_mhpi_0006*trend	 			
save	"$data/County Level/policy_pop_cz_5_13_22.dta"	, replace		
			



******************************
* Use PUMA-Industry-Year Level ACS Data with Control Variables Merged in
* Collapse to PUMA by Year Level
* Then merge in PUMA to CZ condorance and re-collapse
******************************
use  "$user/$data/acs_aggregate_emp.dta", clear


	gen sector =0

		replace sector =1 if ind1990 <=32                  		/* AGRICULTURE, FORESTRY, AND FISHERIES */
		replace sector =2 if ind1990 <=50 & sector ==0			/* MINING */
		replace sector =3 if ind1990 <=60 & sector ==0			/* CONSTRUCTION */
		replace sector =4 if ind1990 <=392 & sector ==0			/* MANUFACTURING */
		replace sector =5 if ind1990 <=472 & sector ==0			/* Transportation & Utilites */
		replace sector =6 if ind1990 <=691 & sector ==0			/* WHOLESALE, RETAIL */
		replace sector =7 if ind1990 <=712 & sector ==0			/* FINANCE, INSURANCE, AND REAL ESTATE */
		replace sector =8 if ind1990 <=760 & sector ==0			/* BUSINESS AND REPAIR SERVICES */
		replace sector =9 if ind1990 <=810 & sector ==0			/* PERSONAL, ENTERTAINMENT AND RECREATION SERVICES */
		replace sector =10 if ind1990 <=893 & sector ==0		/* Education and Health & Other Services */
		replace sector =11 if ind1990 <=932 & sector ==0		/* PUBLIC ADMINISTRATION */
		replace sector =12 if ind1990 <=940 & sector ==0		/* ACTIVE DUTY MILITARY */
		
		*drop mil and pub admin
		drop if sector ==11 |  sector ==12


// collpase to PUMA*year level, get rid of industry level variation	
collapse (sum) un_* nlf_* emp_* 	(max) statefip  ///
				(mean) pop_*   d_* ///
				HPIwith2000base  deportations detainers ///
				 	cpuma0010_pop  state287g_frac jail287g_frac task287g_frac SC_frac ///
					, by( year  cpuma0010   )
					
sum emp_* pop_*


saveold "$data/acs_aggregate_emp_040422.dta" , replace


******************************************* *******************************************
******************************************* *******************************************
* ******************  USE COUNTY LEVEL POLICY AND POP DATA   * ************************ 
******************************************* *******************************************
******************************************* *******************************************/

*merge to ACS employment Data:		
use "$data/acs_aggregate_emp_040422.dta" , clear

* MERGE IN NEW BARTIKS W SPLITS BY COUNTRY OF BIRTH
merge m:1 statefip cpuma0010 year using $data/final_bartik_acs_cpuma0010_updated.dta
sum year
tab year _merge
keep if _merge==3 // everything merged except 2015
drop _merge  

// merge in CZ to PUMA crosswalk
joinby cpuma0010 using  "$data/crosswalks/cw_cpuma2010_czone.dta"

// gen region variable
recode statefip (9 23 25 33 44 50 34 36 42 =1) (17 18 26 39 55 19 20 27 29 31 38 46=2) ///
(10 11 12 13 24 37 45 51 54 1 21 28 47 5 22 40 48 =3) (4 8 16 30 32 35 49 56 2 6 15 41 53=4), gen(region)
tab region
tab statefip
recode statefip (09 23 25 33 44 50 =1) (34 36 42=2) (17 18 26 39 55 = 3) (19 20 27 29 31 38 46 = 4) ///
(10 11 12 13 24 37 45 51 54 =5) (01 21 28 47=6) ( 05 22 40 48=7) (04 08 16 30 32 35 49 56 =8 ) (02 06 15 41 53 = 9) ///
, gen(division)

// flag for AZ to drop in robustness checks below
gen AZ = (statefip==4)
// flag early adopters to drop in robustness checks below
gen early = (SC_frac>0 & SC_frac~=. & year==2009)
bysort cpuma0010: egen max_early = max(early)
tab max_early
gen not_early = 1 if max_early==0

// how many CZ span multiple states and multiple regions
gen count_st = statefip
gen count_r = region


collapse (max) AZ not_early (count) count_st count_r (mean) division region statefip  ///
 (sum) emp_* pop_*  un_* nlf_*  deportations detainers cpuma0010_pop  d_* ///
 shift_share_sample_fb shift_share_sample_usb shift_share_sample_lskill shift_share_sample_hskill ///
	[pweight=af]  , by(cz year)
	
tab region
tab statefip
tab count_r
tab count_st

// some CZs span multple regions so round to region most of CZ is in
replace region= round(region)
replace division= round(division)

// merge in CZ control variables created above
merge 1:1 czone  year using  "$data/County Level/policy_pop_cz_5_13_22.dta"
keep if _merge ==3
drop _merge

// rename cz cpuma0010 to use below
rename cz 	cpuma0010	

drop if year<2005 | year>2014
drop if SC_frac==.
gen full = 1

******************************
/** Employment/Baseline Pop Variables **/
******************************

// generate total working age PUMA population in 2005 for denominator
foreach demog in all fb_men_ls usb_men {
gen pop_`demog'_2005=pop_`demog' if year==2005
bysort cpuma0010: egen max_pop_`demog'_2005=max(pop_`demog'_2005)	
}
	
gen emp_fb_ls = emp_fb_men_ls+emp_fb_wom_ls
gen pop_fb_ls = pop_fb_men_ls+pop_fb_wom_ls
for any ls scol col: gen emp_usb_X = emp_usb_men_X+emp_usb_wom_X
for any ls scol col: gen pop_usb_X = pop_usb_men_X+pop_usb_wom_X
gen emp_fb_hp_ls = emp_fb_hp_men_ls+emp_fb_hp_wom_ls
gen pop_fb_hp_ls = pop_fb_hp_men_ls+pop_fb_hp_wom_ls
gen emp_usb_hs = emp_usb_men_scol+emp_usb_wom_scol+emp_usb_men_col+emp_usb_wom_col
gen pop_usb_hs = pop_usb_men_scol+pop_usb_wom_scol+pop_usb_men_col+pop_usb_wom_col


#delimit ;
local demog_list "fb_hp_ls usb_ls usb_col usb_scol fb_ls cit_wom_hs_kid cit_wom_hs_ykid cit_men_hs_kid cit_men_hs_ykid usb_wom_hs_kid usb_wom_hs_ykid 
	usb_men_hs_kid usb_men_hs_ykid cit_wom_hs_nokid cit_men_hs_nokid usb_wom_hs_nokid usb_men_hs_nokid
	noncit noncit_ls noncit_men noncit_men_ls noncit_hp_men_ls undoc5_men undoc6_men undoc586_men undoc686_men 
	 fb_ca80_ls fb_hp80_ls fb_hp80_wom_ls fb_ca80_wom_ls fb_ca80_men_ls fb_hp80_men_ls
	 noncit_wom_ls_hh noncit_hp_wom_ls_hh noncit_wom80_ls_hh noncit_hp_wom80_ls_hh fb_wom_ls_hh fb_hp_wom_ls_hh fb_wom80_ls_hh fb_hp_wom80_ls_hh
     cit_men_scol cit_men_col usb_men_scol usb_men_col cit cit_ls cit_men_ls cit_men cit_men_hs cit_hp_men_ls all   
	 noncit_wom noncit_wom_ls noncit_hp_wom_ls undoc5_wom undoc6_wom  
	 cit_wom_ls cit_wom cit_wom_hs cit_hp_wom_ls cit_wom_col cit_wom_col_kid cit_wom_col_ykid
	 fb fb_men fb_men_ls fb_hp_men_ls fb_wom fb_wom_ls fb_hp_wom_ls  usb_wom_col usb_wom_scol
     usb usb_hs usb_men_ls usb_men usb_men_hs usb_hp_men_ls usb_wom_ls usb_wom usb_wom_hs usb_hp_wom_ls
" ;
#delimit cr
foreach demog in `demog_list'     {
gen erate_`demog'= (emp_`demog'/pop_`demog')*100       // group specific time varying emp / group specific time varying pop
gen efixpop_`demog'= (emp_`demog'/max_pop_all_2005)*100       // group specific time varying emp / working-age PUMA pop in 2005 * 100   
gen pshare_`demog'= (pop_`demog'/max_pop_all_2005)*100       // group specific time varying pop / working-age PUMA pop in 2005 * 100   
}


#delimit ;
local demog_list " 
	usb usb_wom usb_men 
	  fb_ca80_ls fb_hp80_ls fb_hp80_wom_ls fb_ca80_wom_ls fb_ca80_men_ls fb_hp80_men_ls 
	 fb fb_men  fb_men_ls fb_hp_men_ls fb_wom fb_wom_ls fb_hp_wom_ls  fb_ls
" ;
#delimit cr
foreach demog in `demog_list' {
gen urate_`demog' = (un_`demog'/pop_`demog')*100 
gen nlfpr_`demog' = (nlf_`demog'/pop_`demog')*100 
}




// generate employment outcome by occupational skill, drop milpa from skill def
foreach sk in 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 {
gen emp_fb_ls_sk`sk'mw= (emp_fb_men_ls_sk`sk'mw+emp_fb_wom_ls_sk`sk'mw)   
gen emp_usb_ls_sk`sk'mw= (emp_usb_men_ls_sk`sk'mw+emp_usb_wom_ls_sk`sk'mw)   
gen emp_usb_scol_sk`sk'mw= (emp_usb_men_scol_sk`sk'mw+emp_usb_wom_scol_sk`sk'mw)   
gen emp_usb_col_sk`sk'mw= (emp_usb_men_col_sk`sk'mw+emp_usb_wom_col_sk`sk'mw)   
gen emp_usb_hs_sk`sk'mw= (emp_usb_men_col_sk`sk'mw+emp_usb_wom_col_sk`sk'mw+emp_usb_men_scol_sk`sk'mw+emp_usb_wom_scol_sk`sk'mw)   
}

#delimit ;
local demog_list "usb_men usb_men_ls usb_men_scol usb_men_col  all cit_men cit_men_ls cit_hp_men_ls cit_men_hs  
 noncit_ls noncit_men_ls noncit_hp_men_ls undoc6_men undoc5_men  
 fb fb_ls fb_men fb_men_ls fb_hp_men_ls fb_ca80_men_ls fb_hp80_men_ls
 usb usb_ls usb_hs  usb_scol usb_col 
 " ;
#delimit cr
foreach demog in `demog_list'     {
foreach sk in 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 {
gen efixpop_`demog'_mp`sk'mw= (emp_`demog'_sk`sk'mw/max_pop_all_2005)*100    // group specific time varying pop /  working-age PUMA pop in 2005 * 100, old measure of skill
}
}


// generate detainers per pop 
foreach demog in detainers  {
gen fixpop_`demog'= (`demog'/max_pop_all_2005)*100       // group specific time varying emp / working-age PUMA pop in 2005 * 100
}

	
******************************
/** Intensity of Low Edu Male NonCitizen Employment by CZ in 2005 **/
******************************
// generate denominators and numerators
foreach demog in fb_ls fb_hp_men_ls fb_hp80_men_ls fb_ca80_men_ls fb_men fb_men_ls all  noncit_ls noncit_men_ls  {
gen e_`demog'_05=emp_`demog' if year==2005
bysort cpuma0010: egen mx_e_`demog'_05=max(e_`demog'_05)
foreach sk in 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 {
gen e_`demog'_sk`sk'mw_05=emp_`demog'_sk`sk'mw if year==2005
bysort cpuma0010: egen me_`demog'_sk`sk'mw_05=max(e_`demog'_sk`sk'mw_05)
}
}

// generate employment shares 
foreach demog in fb_ls fb_hp_men_ls fb_hp80_men_ls fb_ca80_men_ls fb_men fb_men_ls noncit_ls noncit_men_ls   {
gen esh05_`demog'_skmw0= (e_`demog'_05/mx_e_all_05)*100     // low edu male noncitizen employment in 2005 / total male employment in 2005 *100
foreach sk in 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 {
gen esh05_`demog'_skmw`sk'= (e_`demog'_sk`sk'mw_05/me_all_sk`sk'mw_05)*100     // low edu male noncitizen employment in 2005 / total male employment in 2005 *100
}
}
label variable SC_frac " $ \beta$: SC"


tab year
tab cpuma0010


*******************************
* GENERATE LAGS AND LEADS FOR DL MODEL
*******************************
cap drop L*_SC_frac F*_SC_frac 

sort cpuma0010 year 
forvalues l = 1/4 {
by cpuma0010: gen L`l'_SC_frac = SC_frac[_n-`l']
}
forvalues l = 1/4 {
by cpuma0010: gen F`l'_SC_frac = SC_frac[_n+`l']
}

gen L0_SC_frac=SC_frac

// we assume SC=0 before 2005
replace L1_SC_frac = 0 if L1_SC_frac==. & year==2005 
replace L2_SC_frac = 0 if L2_SC_frac==. & year<=2006 
replace L3_SC_frac = 0 if L3_SC_frac==. & year<=2007
replace L4_SC_frac = 0 if L4_SC_frac==. & year<=2008
 
label var F2_SC_frac "-2"  
label var F1_SC_frac "-1"  
label var L0_SC_frac "0"  
label var L1_SC_frac "1"  
label var L2_SC_frac "2"  


* One CZ has no individuals in any year so drop
drop if cpuma0010==34701

 
 
*******************************
* SUMMARY STATISTICS
*******************************

summ efixpop_fb_ls  efixpop_fb_wom_ls  efixpop_fb_men_ls   efixpop_fb_hp_men_ls  efixpop_fb_hp80_men_ls  efixpop_fb_ca80_men_ls  [aweight=pop2000]  if year<2015 

summ efixpop_usb  efixpop_usb_wom  efixpop_usb_men   efixpop_usb_men_ls  efixpop_usb_hp_men_ls   efixpop_usb_men_scol  efixpop_usb_men_col   [aweight=pop2000]  if year<2015 

gen share_pop_fb=pop_fb/pop_all
summ  share_pop_fb  erate_all [aweight=pop2000]  if year==2005
summ  share_pop_fb  erate_all  if year==2005

summ efixpop_all [aweight=pop2000]  if year<2015
summ efixpop_all [aweight=pop2000]  if year==2005

* Save data set to use for Callaway and Sant'Anna estimator
save "data/EHLMV_forCS.dta", replace


*******************************
* MOVING WINDOW PLOT BY OCCUPATIONAL SKILL, USING OCC SKILL AFTER DROPPING MIL/PA
*******************************
pause off
eststo clear
foreach j in    efixpop   {
if "`j'"=="efixpop" local depvar "Total Group Emp / Total CZ Pop in 2005 * 100"
eststo clear	
foreach k in usb_hs   usb_ls fb_ls { 
cap drop *_skmw_b* *_skmw_se*

				eststo : reghdfe `j'_`k'   SC_frac                ///
				shift_share_sample_fb shift_share_sample_usb  ///
 				 [aweight=pop2000] if year<2015    ,   vce (cluster cpuma0010) absorb( year   cpuma0010  i.cpuma0010#c.year      ) 
				gen `j'_skmw_b0 = _b[SC_frac]
				gen `j'_skmw_se0 = _se[SC_frac]
				
				foreach skill in 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 {

				eststo : reghdfe `j'_`k'_mp`skill'mw   SC_frac              ///
					shift_share_sample_fb shift_share_sample_usb   ///
 				 [aweight=pop2000] if year<2015     ,   vce (cluster cpuma0010) absorb( year   cpuma0010  i.cpuma0010#c.year      ) 
				gen `j'_skmw_b`skill' = _b[SC_frac]
				gen `j'_skmw_se`skill' = _se[SC_frac]	
	}

	preserve
	keep `j'_sk*mw_b*  `j'_sk*mw_se* esh05_*
	collapse `j'_sk*mw_b*  `j'_sk*mw_se* esh05_*
	gen id =1
	pause
	reshape long `j'_skmw_b  `j'_skmw_se esh05_`k'_skmw , i(id) j(mw)
	pause
	gen ci_top = `j'_sk`median'mw_b+1.96*`j'_skmw_se
	gen ci_bot =`j'_sk`median'mw_b-1.96*`j'_skmw_se
	gen zero = 0
	drop if mw==0
	twoway (bar esh05_`k'_skmw mw, color(gray)), ylabel(,nogrid)  graphregion(color(white))  xtitle("")  ytitle("% of Emp in 2005")  ///
	 xtitle("Occupational Skill")  ///
	xlabel( 25 "0-25" 30 "5-30" 35 "10-35" 40 "15-40" 45 "20-45" 50 "25-50" 55 "30-55" 60 "35-60" 65 "40-65" 70 "45-70" 75 "50-75"  80 "55-80" 85 "60-85" 90 "65-90" 95 "70-95" 100 "75-100", angle(90)) 
	graph export "$resultsfolder/emp_int_`k'_skill_mw.png", replace  height(600) width(800)
  	twoway  (scatter `j'_skmw_b mw, color(black) )    ///
 (rcap ci_top ci_bot mw,   lcolor(gray) lpattern(dash) )  (line zero mw, clcolor(gray) lpattern(dash)  )  ,   ylabel(,nogrid)  graphregion(color(white)) ///
 legend( off)  ytitle("Beta") xtitle("Occupational Skill") ylabel(-0.5(0.2)0.4)  yscale(r(-0.5(0.2)0.4)) ///
 xlabel( 25 "0-25" 30 "5-30" 35 "10-35" 40 "15-40" 45 "20-45" 50 "25-50" 55 "30-55" 60 "35-60" 65 "40-65" 70 "45-70" 75 "50-75"  80 "55-80" 85 "60-85" 90 "65-90" 95 "70-95" 100 "75-100", angle(90))
 graph export "$resultsfolder/effects_`j'_`k'_skill_mw_skill.png", replace  height(600) width(800)
restore
	}
	}
	
		
 

 
*******************************
* EFFECTS ON EMP/POP, SPLIT BY DEMOG GROUPS
*******************************

foreach group in  direct_indirect         {
if "`group'"=="direct_indirect" local grouplist " fb_ls fb_wom_ls fb_men_ls usb  usb_wom usb_men "
if  "`group'"=="direct_indirect" local titles " mtitles( "All"  "Females" "Males" "All"  "Females" "Males") "
if  ("`group'"=="direct_indirect"  ) local outcomes " efixpop  " 

foreach j in   `outcomes'   { 
if "`j'"=="efixpop" local depvar "Total Group Emp /  Total CZ Pop in 2005 * 100"

eststo clear	
** Baseline Model with CZ FE, Year FE, and CZ Trends	
foreach g in  `grouplist' {
				eststo : reghdfe `j'_`g'   SC_frac              ///
				 [aweight=pop2000] if year<2015   ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  ""
				estadd ysumm
				test SC_frac =  0  
				estadd scalar p = r(p)
				sum `j'_`g' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100

				 }									
		
		if  ("`group'"=="direct_indirect" )  {
		esttab    using "$resultsfolder/effects_`j'_`group'.tex", replace ///
					keep (SC_frac          ) ///
						order (  SC_frac        )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
							mgroups("\textbf{Low-Educated Foreign-Born}" "\textbf{U.S.-Born}"  , pattern(1 0 0  1 0 0  ) ///
			prefix(\multicolumn{@span}{c}{) suffix(}) span  erepeat(\cmidrule(lr){@span})) ///
						label stats(     czyrtnd bartik_vary ymean p perc N   , ///
							labels( "CZ-Year Trends"  "Bartiks"    "Y mean" "P-Value" "\% Effect" "Observations"   ) ///
						fmt(   0 0 2 2 2 0   )) nonumbers `titles' ///
						prefoot("") postfoot("")   varlabels( , blist(SC_frac "\midrule \it{\underline{A: Baseline}} \\ "))
						}
			 
			 
			 		 
			 
eststo clear	
** Add bartiks 
foreach g in  `grouplist' {
				eststo : reghdfe `j'_`g'   SC_frac             ///
 						shift_share_sample_fb shift_share_sample_usb ///
			  [aweight=pop2000] if year<2015  ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				local beta_`j'_`g'= _b[SC_frac]
				di `beta_`j'_`g''
				estadd ysumm 
				test SC_frac =  0  
				estadd scalar p = r(p)
				sum `j'_`g' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100							
				}				
				

			  
	esttab    using "$resultsfolder/effects_`j'_`group'.tex", append ///
					keep ( SC_frac       ) ///
						order (  SC_frac          )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
						label stats(      czyrtnd bartik_vary ymean p perc N   , ///
							labels(  "CZ-Year Trends"  "Bartiks"    "Y mean" "P-Value" "\% Effect" "Observations"   ) ///
						fmt(   0 0 2 2 2 0   )) nonumbers mtitles(  "" "" "" "" "" "" "" "" ""   ) ///
			  prefoot("") prehead("") posthead("")	  varlabels( , blist(SC_frac "\midrule \it{\underline{B: Add Bartiks }} \\ "))

 }
}


	
*******************************
* DISTRIBUTED LAG MODEL  
*******************************	
pause off
eststo clear
foreach grouplist in fb_ls  usb    {
foreach j in   efixpop    {
if "`j'"=="efixpop" local depvar "Total Group Emp /  Total CZ Pop in 2005 * 100"
 foreach g in `grouplist' {

	
eststo: reghdfe `j'_`g' F2_SC_frac  F1_SC_frac  L0_SC_frac  L1_SC_frac  L2_SC_frac   ///
shift_share_sample_fb shift_share_sample_usb  ///
 		  [aweight=pop2000]  if year<2015     ,   vce (cluster cpuma0010) absorb(  year  cpuma0010   i.cpuma0010#c.year    ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				estadd ysumm 
				

						
cap drop beta*
cap drop se*
noi lincom -(_b[F2_SC_frac] + _b[F1_SC_frac])
gen beta1 = r(estimate)
gen se1 = r(se)
noi lincom - _b[F1_SC_frac]
gen beta2 = r(estimate)
gen se2 = r(se)
gen beta3 = 0
gen se3 = 0
noi lincom _b[L0_SC_frac] 
gen beta4 = r(estimate)
gen se4 = r(se)
noi lincom _b[L0_SC_frac] + _b[L1_SC_frac] 
gen beta5 = r(estimate)
gen se5 = r(se)
noi lincom _b[L0_SC_frac] + _b[L1_SC_frac]  + _b[L2_SC_frac] 
gen beta6 = r(estimate)
gen se6 = r(se)


 
preserve
keep beta* se* 
duplicates drop 
gen id = 1
reshape long beta se, i(id) j(et)
replace et = et-4
gen ci_top = beta+se*1.96
gen ci_bot = beta-se*1.96
sum

gen DD = `beta_`j'_`g'' if et>=0

tabstat beta se, by(et)
pause

twoway (scatter  beta et, color(black))  (rcap  ci_top ci_bot et, lcolor(gray) lpattern(dash)) ///
(line DD et, lcolor(gray)), xline(-0.5) xtitle("Event Time (years)") ytitle("Beta") legend(off) yline(0) 
graph export "$resultsfolder/distlag2_`j'_`g'_sum.png", replace  height(600) width(800)
restore
	
	
	}
	}		
	}
	
					esttab    using "$resultsfolder/DL_results.tex", replace ///
					keep (F2_SC_frac  F1_SC_frac  L0_SC_frac  L1_SC_frac  L2_SC_frac          ) ///
						order (  F2_SC_frac  F1_SC_frac  L0_SC_frac  L1_SC_frac  L2_SC_frac        )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
							mgroups("Dep. Var: `depvar'"   , pattern(1 0 0 0 0   ) ///
			prefix(\multicolumn{@span}{c}{) suffix(}) span  erepeat(\cmidrule(lr){@span})) ///
						label stats(     czyrtnd bartik_vary ymean  N   , ///
							labels( "CZ-Year Trends"  "Bartiks"    "Y mean"  "Observations"   ) ///
						fmt(   0 0 2  0   )) nonumbers mtitles("Low-Edu Foreign-Born"  ///
						"US-Born" )
						
						

	
				

*******************************
* UNEMPLOYMENT AND OUT OF THE LABOR FORCE
*******************************	
eststo clear
foreach j in   urate nlfpr   { 
foreach g in  fb_ls   usb   {
if "`j'"=="urate" local depvar "Total Group Unemp /  Total Group Pop * 100"
if "`j'"=="nlfpr" local depvar "Total Group Out of LF /  Total Group Pop * 100"
	
	eststo : reghdfe `j'_`g'   SC_frac             ///
 						shift_share_sample_fb shift_share_sample_usb ///
			  [aweight=pop2000] if year<2015  ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				 
				estadd ysumm 
				sum `j'_`g' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100							
				}	
				}
		esttab    using "$resultsfolder/effects_uratelfp.tex", replace ///
				keep (SC_frac          ) ///
						order (  SC_frac        )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
						label mgroups("Total Group Unemp /  Total Group Pop * 100"   "Total Group Out of LF /  Total Group Pop * 100" , pattern(1 0 1 0   ) ///
						prefix(\multicolumn{@span}{c}{) suffix(}) span  erepeat(\cmidrule(lr){@span})) /// 
						stats(      czyrtnd bartik_vary ymean perc N   , ///
						labels(  "CZ-Year Trends"  "Bartiks"    "Y mean" "\% Effect" "Observations"   ) ///
						fmt(   0 0 2 2 0   )) nonumbers mtitles( "LEFB" "USB" "LEFB"  "USB"  )



*******************************
* SPLIT BY EDUCATION AND LIKELY UNDOCUMENTED DEMOGRPHICS
*******************************	
foreach group in  direct   indirect_educ {
if "`group'"=="direct" local grouplist "  fb_hp_men_ls fb_hp80_men_ls fb_ca80_men_ls"
if "`group'"=="indirect_educ" local grouplist "usb_ls usb_hs  "

if "`group'"=="direct"  local titles " mtitles("Hisp" "Hisp Arrive 80$+$"  "Mx/CA Arrive 80$+$") "
if  "`group'"=="indirect_educ" local titles " mtitles( "Low-Edu"  "Some Col$+$"  ) "

local outcomes " efixpop  " 

foreach j in   `outcomes'   { 
		 
eststo clear	
foreach g in  `grouplist' {
				eststo : reghdfe `j'_`g'   SC_frac             ///
 						shift_share_sample_fb shift_share_sample_usb ///
			  [aweight=pop2000] if year<2015  ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
				estadd local bartik_vary  "X"
				estadd local czyrtnd  "X"	
				 
				estadd ysumm 
				sum `j'_`g' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100							
				}							
		esttab    using "$resultsfolder/effects_`j'_`group'.tex", replace ///
				keep (SC_frac          ) ///
						order (  SC_frac        )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
							mgroups("Dep. Var: `depvar'"   , pattern(1 0 0 0 0   ) ///
			prefix(\multicolumn{@span}{c}{) suffix(}) span  erepeat(\cmidrule(lr){@span})) ///
						label stats(     czyrtnd bartik_vary ymean perc N   , ///
							labels(  "CZ-Year Trends"  "Bartiks"    "Y mean" "\% Effect" "Observations"   ) ///
						fmt(   0 0 2 2 0   )) nonumbers `titles' 

 }
}



*******************************
* SPLIT BY CITIZENSHIP
*******************************
foreach group in    directindirect_noncit   {
if "`group'"=="directindirect_noncit" local grouplist " noncit_ls cit"
if  "`group'"=="directindirect_noncit" local titles " mtitles( "Low-Educated Non-Citizens"  "Citizens" ) "
local outcomes " efixpop  erate" 
foreach j in   `outcomes'   { 
if "`j'"=="efixpop" local depvar "Total Group Emp /  Total CZ Pop in 2005 * 100"
			 
eststo clear	
foreach g in  `grouplist' {
				eststo : reghdfe `j'_`g'   SC_frac             ///
 						shift_share_sample_fb shift_share_sample_usb ///
			  [aweight=pop2000] if year<2015  ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				 
				estadd ysumm 
				sum `j'_`g' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100							
				}						
				
		if   "`group'"=="directindirect_noncit" {
		esttab using "$resultsfolder/effects_`j'_cit.tex", replace ///
				keep (SC_frac          ) ///
						order (  SC_frac        )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
							mgroups("Dep. Var: `depvar'"   , pattern(1 0 0 0 0   ) ///
			prefix(\multicolumn{@span}{c}{) suffix(}) span  erepeat(\cmidrule(lr){@span})) ///
						label stats(      czyrtnd bartik_vary ymean perc N   , ///
							labels(  "CZ-Year Trends"  "Bartiks"    "Y mean" "\% Effect" "Observations"   ) ///
						fmt(   0 0 2 2 0   )) nonumbers `titles' 
						}


 }
}





*******************************
* DROP CZS THAT ADOPTED SC POLICIES BEFORE 2010, ADOPTED SANCTURARY CITY POLICIES BEFORE SC, AZ
* CONTROL FOR OTHER IMMIGRATION POLICIES
* CONTROL FOR ECON CONDITIONS
*******************************
cap gen not_AZ = (AZ~=1)
cap gen no_sanctuary_on = (sanctuary_on~=1)


foreach grouplist in   fb_ls usb  {
eststo clear
foreach j in   efixpop    {
if "`j'"=="efixpop" local depvar "Total Group Emp /  Total CZ Pop in 2005 * 100"
 foreach g in `grouplist' {
foreach sample in full not_early no_sanctuary_on not_AZ { 

 				eststo : reghdfe `j'_`g' SC_frac            ///
					shift_share_sample_fb shift_share_sample_usb    ///
 				  [aweight=pop2000] if year<2015 & `sample'==1  ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year    ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				 
				estadd ysumm
				sum `j'_`g' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100	
				}
				
				
	
forvalues c = 1/2 {
local controls0 ""
local controls1 "task287g_frac jail287g_frac"
local controls2 "everify_all everify_public"
local controls3 "everify_all everify_public task287g_frac jail287g_frac"
				eststo : reghdfe `j'_`g' SC_frac    `controls`c''        ///
					shift_share_sample_fb shift_share_sample_usb   ///
 				  [aweight=pop2000] if year<2015   ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year    ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				 
				estadd ysumm
				sum `j'_`g' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100	
				}
				
				

 forvalues c = 1/2 {
local controls0 ""
local controls1 "division#year"
local controls2 "hpiboom_trend2  hstboom_trend2"
 				eststo : reghdfe `j'_`g' SC_frac    `controls`c''        ///
					shift_share_sample_fb shift_share_sample_usb    ///
 				  [aweight=pop2000] if year<2015   ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year    ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				 
				estadd ysumm
				sum `j'_`g' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100	
				}
				
				
				
		if "`g'"=="fb_ls" {		 
		esttab    using "$resultsfolder/effects_robustchecks_`j'.tex", replace ///
					keep (SC_frac          ) ///
						order (  SC_frac        )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
							mgroups("Baseline" "Robustness to Dropping CZs" "Control for Other Immigration Policies"  "Control for Economic Conditions" , pattern(1 1 0 0 1 0  1 0   ) ///
			prefix(\multicolumn{@span}{c}{) suffix(}) span  erepeat(\cmidrule(lr){@span})) ///
						label stats(     czyrtnd bartik_vary ymean perc N   , ///
							labels(  "CZ-Year Trends"  "Bartiks"    "Y mean" "\% Effect" "Observations"   ) ///
						fmt(   0 0 2 2 0   ))    nonumbers mtitles(  "" "Drop Early Adopt" "Drop Sanc. Cities" "Drop AZ" "Control for 287gs" "Control for E-Verify" ///
						 "Region*Year FE" "Quadratic Trend House Prices \& Starts") ///
						prefoot("") postfoot("")   varlabels( , blist(SC_frac "\midrule \it{\underline{A: Low-Edu Foreign-Born }} \\ "))
						eststo clear
						}
						
			if "`g'"=="usb"		{	
		esttab    using "$resultsfolder/effects_robustchecks_`j'.tex", append ///
					keep (SC_frac          ) ///
						order (  SC_frac        )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
						label stats(     czyrtnd bartik_vary ymean perc N   , ///
							labels(  "CZ-Year Trends"  "Bartiks"    "Y mean" "\% Effect" "Observations"   ) ///
						fmt(   0 0 2 2 0   ))   nonumbers mtitles( "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""  ) ///
							 prefoot("") prehead("") posthead("")   varlabels( , blist(SC_frac "\midrule \it{\underline{B: US-Born  }} \\ "))
						eststo clear
						}
						

						}
						}
						}
						
	


	
	
*******************************
* EFFECTS ON POP and Employment Rate, SPLIT BY DEMOG GROUPS
*******************************
foreach j in   pshare erate  { 
if "`j'"=="efixpop" local depvar "Total Group Emp /  Total CZ Pop in 2005 * 100"
if "`j'"=="erate" local depvar "Total Group Emp /  Total Group Pop * 100"
if "`j'"=="pshare" local depvar "Total Group Pop * 100 /  Total CZ Pop in 2005 * 100"

eststo clear	
** With bartiks and CZ trends
foreach g in  fb_ls fb_wom_ls fb_men_ls    usb   {
				eststo : reghdfe `j'_`g'   SC_frac             ///
 						shift_share_sample_fb shift_share_sample_usb  ///
			  [aweight=pop2000] if year<2015   ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 

				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				 
				estadd ysumm 
				sum `j'_`g' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100
				}	
				
				
		if "`j'"=="pshare" {
		esttab    using "$resultsfolder/effects_erate.tex", replace ///
					keep ( SC_frac       ) ///
						order (  SC_frac          )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
						label stats(       czyrtnd bartik_vary ymean perc N   , ///
							labels(   "CZ-Year Trends"  "Bartiks"    "Y mean" "\% Effect" "Observations"   ) ///
						 fmt( 0 0 2 2 0   )) nonumbers 	mgroups("Low-Edu Foreign-Born" "US-Born"  , pattern(1 0 0 1  ) ///
			prefix(\multicolumn{@span}{c}{) suffix(}) span  erepeat(\cmidrule(lr){@span})) ///
			mtitles(  "All"  "Females"  "Males"  "All"    ) ///
						 	prefoot("") postfoot("")   varlabels( , blist(SC_frac "\midrule \it{\underline{A: Effect on Population}} \\ "))
							}
		if "`j'"=="erate" {
		esttab    using "$resultsfolder/effects_erate.tex", append ///
					keep ( SC_frac       ) ///
						order (  SC_frac          )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
						label stats(       czyrtnd bartik_vary ymean perc N   , ///
							labels(   "CZ-Year Trends"  "Bartiks"    "Y mean" "\% Effect" "Observations"   ) ///
						 fmt( 0 0 2 2 0   )) nonumbers mtitles( "" "" "" "" "" ""  ) ///
						 		prefoot("") prehead("") posthead("")   varlabels( , blist(SC_frac "\midrule \it{\underline{B: Effect on Employment to Population Ratio}} \\ "))
							}
 }



	
 
*******************************
* DIRECT EFFECTS ON Detentions
*******************************
eststo clear
foreach j in fixpop_detainers detainers   {
if "`j'"=="fixpop_detainers" local depvar "Total Detainers/ Total Pop * 100  "
if "`j'"=="detainers" local depvar "Total Detainers"

eststo clear						
				
				eststo : reghdfe `j'   SC_frac              ///
				[aweight=pop2000]  ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  ""
				estadd ysumm 
				sum `j' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100	
				
				eststo : reghdfe `j'    SC_frac             ///
 						shift_share_sample_fb shift_share_sample_usb  ///
			  [aweight=pop2000] ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				estadd ysumm 
				sum `j' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100								

	
		esttab    using "$resultsfolder/direct_`j'.tex", replace ///
					keep (SC_frac          ) ///
						order (  SC_frac        )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
							mgroups("Dep. Var: Total Detainers / Total CZ Pop in 2005 * 100"   , pattern(1 0 0 0 0   ) ///
			prefix(\multicolumn{@span}{c}{) suffix(}) span  erepeat(\cmidrule(lr){@span})) ///
						label stats(       czyrtnd bartik_vary ymean perc N   , ///
							labels(   "CZ-Year Trends"  "Bartiks"    "Y mean" "\% Effect" "Observations"   ) ///
						 fmt( 0 0 2 2 0   ))  nonumbers  mtitles( "(1)" "(2)" "(3)"  "(4)" "(5)"  )
			 
 }
 

 
 
 
*******************************
* EXOGENEITY CHECKS
*******************************
preserve
gen year_SC = year if SC_frac>0 & SC_frac~=.
bysort  cpuma0010: egen min_year_SC = min(year_SC)
keep if year>=2005 & year<=2007

gen noncit_share=pop_noncit/pop_all
gen noncit_men_share=pop_noncit_men/pop_all
gen noncit_men_ls_share=pop_noncit_men_ls/pop_all
gen noncit_hp_men_ls_share=pop_noncit_hp_men_ls/pop_all
gen noncit_ls_share=pop_noncit_ls/pop_all

gen fb_share=pop_fb/pop_all
gen fb_men_share=pop_fb_men/pop_all
gen fb_men_ls_share=pop_fb_men_ls/pop_all
gen fb_hp_men_ls_share=pop_fb_hp_men_ls/pop_all
gen fb_ls_share=pop_fb_ls/pop_all

for any  shift_share_sample_fb shift_share_sample_usb shift_share_sample_lskill shift_share_sample_hskill: replace X = X/100000

foreach var in noncit_ls_share fb_ls_share fb_share fb_men_share fb_men_ls_share fb_hp_men_ls_share  noncit_share noncit_men_share noncit_men_ls_share noncit_hp_men_ls_share task287g_frac jail287g_frac  shift_share_sample_fb shift_share_sample_usb  shift_share_sample_lskill shift_share_sample_hskill  {
gen `var'05 = `var' if year==2005
gen `var'07 = `var' if year==2007
bysort cpuma0010: egen mx_`var'05=max(`var'05)
bysort cpuma0010: egen mx_`var'07=max(`var'07)
}
foreach var in noncit_ls_share fb_ls_share fb_share fb_men_share fb_men_ls_share fb_hp_men_ls_share  noncit_share noncit_men_share noncit_men_ls_share noncit_hp_men_ls_share   {
gen d_`var'_0507=(mx_`var'07-mx_`var'05)/mx_`var'05
replace d_`var'_0507=0 if d_`var'_0507==.
}
foreach var in task287g_frac jail287g_frac   shift_share_sample_fb shift_share_sample_usb shift_share_sample_lskill shift_share_sample_hskill  {
gen d_`var'_0507=(mx_`var'07-mx_`var'05) 
}
sum d_*

label var d_noncit_share_0507 "Change \% Non-Citizen"
label var d_noncit_men_share_0507 "Change \% Male Non-Citizen"
label var d_noncit_men_ls_share_0507 "Change \% Low-Edu Male Non-Cit"
label var d_noncit_hp_men_ls_share_0507 "Change \% His Low-Edu Male Non-Cit"
label var d_task287g_frac_0507 "Change Task 287(g)"
label var d_jail287g_frac_0507 "Change Jail 287(g)"
label var d_shift_share_sample_usb_0507 "Change U.S.-Born Bartik"
label var d_shift_share_sample_fb_0507 "Change Foreign-Born Bartik"
label var d_shift_share_sample_lskill_0507 "Change Low-Edu Bartik"
label var d_shift_share_sample_hskill_0507 "Change High-Edu Bartik"


keep if year==2005
eststo clear
qui xi: eststo: reg   min_year_SC  d_noncit_share_0507 d_noncit_men_share_0507 d_noncit_men_ls_share_0507 d_noncit_hp_men_ls_share_0507 d_task287g_frac_0507 d_jail287g_frac_0507    d_shift_share_sample_usb_0507 d_shift_share_sample_fb_0507 d_shift_share_sample_lskill_0507 d_shift_share_sample_hskill_0507   [aweight=pop2000]  
 estadd ysumm
esttab, keep( d_noncit_share_0507 d_noncit_men_share_0507 d_noncit_men_ls_share_0507 d_noncit_hp_men_ls_share_0507 d_task287g_frac_0507 d_jail287g_frac_0507    d_shift_share_sample_usb_0507 d_shift_share_sample_fb_0507 d_shift_share_sample_lskill_0507 d_shift_share_sample_hskill_0507 ) ///
star(* 0.10 ** 0.05 *** 0.01) se stats(ymean r2 N)
esttab   using "$resultsfolder/predict_rollout.tex", keep(d_noncit_share_0507 d_noncit_men_share_0507 d_noncit_men_ls_share_0507 d_noncit_hp_men_ls_share_0507 d_task287g_frac_0507 d_jail287g_frac_0507 d_shift_share_sample_usb_0507 d_shift_share_sample_fb_0507 d_shift_share_sample_lskill_0507 d_shift_share_sample_hskill_0507) ///
se(3) b(3) star(* 0.10 ** 0.05 *** 0.01) nonum  nonotes replace ///
 mtitles(""  "")  ///
stats(  ymean r2  N , ///
 labels ( "Mean Y" "R-Squared" "N") fmt( 2 2  0) ) nonumbers label

summ d_noncit_share_0507 d_noncit_men_share_0507 d_noncit_men_ls_share_0507 d_noncit_hp_men_ls_share_0507 d_task287g_frac_0507 d_jail287g_frac_0507     d_shift_share_sample_usb_0507 d_shift_share_sample_fb_0507 d_shift_share_sample_lskill_0507 d_shift_share_sample_hskill_0507  [aweight=pop2000]  
restore

		

 
*********************************************************
* BY TRADEABILITY OF INDUSTRY OF WORK
*********************************************************
use "$data/acs_aggregate_emp.dta" , clear

gen sector =0
merge m:1 ind1990 using $data/tradable1_BHVT.dta
sort   cpuma0010 year


replace sector =1 if ind1990 <=32                  		/* AGRICULTURE, FORESTRY, AND FISHERIES */
replace sector =2 if ind1990 <=50 & sector ==0			/* MINING */
replace sector =3 if ind1990 <=60 & sector ==0			/* CONSTRUCTION */
replace sector =4 if ind1990 <=392 & sector ==0			/* MANUFACTURING */
replace sector =5 if ind1990 <=472 & sector ==0			/* Transportation & Utilites */
replace sector =6 if ind1990 <=691 & sector ==0			/* WHOLESALE, RETAIL */
replace sector =7 if ind1990 <=712 & sector ==0			/* FINANCE, INSURANCE, AND REAL ESTATE */
replace sector =8 if ind1990 <=760 & sector ==0			/* BUSINESS AND REPAIR SERVICES */
replace sector =9 if ind1990 <=810 & sector ==0			/* PERSONAL, ENTERTAINMENT AND RECREATION SERVICES */
replace sector =10 if ind1990 <=893 & sector ==0		/* Education and Health & Other Services */
replace sector =11 if ind1990 <=932 & sector ==0		/* PUBLIC ADMINISTRATION */
replace sector =12 if ind1990 <=940 & sector ==0		/* ACTIVE DUTY MILITARY */
 
drop if sector ==11 |  sector ==12


collapse (sum) emp_* 	///
				(mean) pop_*  ///
						, by( year  cpuma0010 tradable2  statefip cpuma0010_pop SC_frac)
						
* MERGE IN NEW BARTIKS W SPLITS BY COUNTRY OF BIRTH
merge m:1 cpuma0010 year using $data/final_bartik_acs_cpuma0010_updated.dta
sum year
tab year _merge
keep if _merge==3 // everything merged except 2015
drop _merge 

joinby cpuma0010 using  "$data/crosswalks/cw_cpuma2010_czone.dta"

collapse (sum) shift_share_sample_usb  shift_share_sample_fb  emp_*  pop_*    cpuma0010_pop ///
				[pweight=af]   , by(cz year tradable2)

merge m:1 czone  year using  "$data/County Level/policy_pop_cz_5_13_22.dta"
keep if _merge ==3
drop _merge
rename cz 	cpuma0010	


// generate total working age PUMA population in 2005 for denominator
foreach demog in all fb_men_ls usb_men {
gen pop_`demog'_2005=pop_`demog' if year==2005
bysort cpuma0010: egen max_pop_`demog'_2005=max(pop_`demog'_2005)	
}

#delimit ;
local demog_list "usb
" ;
#delimit cr
foreach demog in `demog_list'     {
gen efixpop_`demog'= (emp_`demog'/max_pop_all_2005)*100       // group specific time varying emp / working-age PUMA pop in 2005 * 100   
}


* One CZ has no individuals in any year so drop
drop if cpuma0010==34701


foreach j in   efixpop   {
if "`j'"=="efixpop" local depvar "Total Group Emp / Total CZ Pop in 2005 * 100"

eststo clear	
** Add bartiks 
foreach g in   usb  {
				eststo : reghdfe `j'_`g'   SC_frac             ///
 						shift_share_sample_usb  shift_share_sample_fb ///
			  [aweight=pop2000] if year<2015  & tradable2 ==1  ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				local beta_`j'_`g'= _b[SC_frac]
				di `beta_`j'_`g''
				estadd ysumm 
				sum `j'_`g' if e(sample)==1  &tradable2 ==1  [aweight=pop2000]  
				estadd scalar perc = (_b[SC_frac]/r(mean))*100							
				}				
				

				
			  
	esttab    using "$resultsfolder/effects_`j'_tradability.tex", replace ///
					keep ( SC_frac       ) ///
						order (  SC_frac          )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
						label stats(      czyrtnd bartik_vary ymean N   , ///
							labels(  "CZ-Year Trends"  "Bartiks"    "Y mean"  "Observations"   ) ///
						fmt(   0 0  2 0   )) nonumbers mtitles(  "Low Ed For Born" "US Born" ""   ) ///
			  prefoot("") postfoot("")	  varlabels( , blist(SC_frac "\midrule \it{\underline{A: Tradable }} \\ "))

eststo clear	
** Add bartiks 
foreach g in    usb  {
				eststo : reghdfe `j'_`g'   SC_frac             ///
 						shift_share_sample_usb  shift_share_sample_fb ///
			  [aweight=pop2000] if year<2015  & tradable2 ==0  ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				local beta_`j'_`g'= _b[SC_frac]
				di `beta_`j'_`g''
				estadd ysumm 
				sum `j'_`g' if e(sample)==1 &tradable2 ==0  [aweight=pop2000]  
				estadd scalar perc = (_b[SC_frac]/r(mean))*100							
				}				
						  
	esttab    using "$resultsfolder/effects_`j'_tradability.tex", append ///
					keep ( SC_frac       ) ///
						order (  SC_frac          )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
						label stats(      czyrtnd bartik_vary ymean  N   , ///
							labels(  "CZ-Year Trends"  "Bartiks"    "Y mean"  "Observations"   ) ///
						fmt(   0 0  2 0   )) nonumbers mtitles(  "Low Ed For Born" "US Born" "" "" "" "" "" "" ""   ) ///
			  prefoot("") prehead("") posthead("")	  varlabels( , blist(SC_frac "\midrule \it{\underline{B: Non-Tradable  }} \\ "))
 }

 
 
 
 
 
 
 
 
 
 
 
 
 
 
