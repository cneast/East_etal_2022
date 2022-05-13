/***********************************************************************
PROGRAM:	0_EHLMV_clean_wage_data_FINAL.do 
PURPOSE:    Clean the ACS Data to Create Wage Variables 
************************************************************************/
clear 
clear matrix 
set mem 500m 
set more off 

 
macro define DATA     
global resultslog  


local  today = c(current_date)
cap log using "X", replace

**************************************************
* CONSTURCT MAIN ANALYSIS DATA SET
**************************************************
* Age 20-64, 2005-2014
keep if age>=20 & age<=64
drop if year==2015
keep if year>=2005 

gen ins=(gq ==3)

sum perwt, d


gen all=1
gen usb = 1 if bpl>=1 & bpl<=120 // born in US or US territory 
replace usb = 0 if bpl>120
gen cit = 1 if bpl>=1 & bpl<=120 // born in US or US territory 
replace cit = 1 if bpl>120 & citizen==2 // born outside US and US territories, naturalized US citizen
replace cit = 1 if bpl>120 & citizen==1 // born outside US and US territories, but born to US parents (very likely a citizen: https://travel.state.gov/content/travel/en/legal-considerations/us-citizenship-laws-policies/citizenship-child-born-abroad.html)
gen ls = (educ<=6) // Low-education
gen hs = (educ>6) // High-education
gen hp = (hispan>0 & hispan<9) // Hispanic
gen noncit=(citizen==3)
gen fb=(usb==0)

foreach pob in cit noncit usb fb {
gen `pob'_wom=(`pob'==1  & sex==2)
gen `pob'_men=(`pob'==1  & sex==1)
foreach edu in ls hs {
gen `pob'_`edu'=(`pob'==1 & `edu'==1)
gen `pob'_wom_`edu'=(`pob'==1 & `edu'==1 & sex==2)
gen `pob'_men_`edu'=(`pob'==1 & `edu'==1 & sex==1)
}
foreach edu in ls {
gen `pob'_hp_wom_`edu'=(`pob'==1 & `edu'==1 & sex==2 & hp==1)
gen `pob'_hp_men_`edu'=(`pob'==1 & `edu'==1 & sex==1 & hp==1)
}
}




/* Undocumented using ethnicity */
	* changing to 1980; excludes naturalized citizens and n/a
gen undoc5 = 1 if citizen==3 & educd<=64 & yrimmig>1980 & bpl>=200 & bpl<=210 // noncitizen, HS or less, after 1986, born in Mexico/Central America
gen undoc6 = 1 if citizen==3 & educd<=64 & yrimmig>1980 & hispan>0 & hispan<9 // noncitizen, HS or less, after 1986, hispanic ethnicity
gen undoc5_wom = 1 if citizen==3 & educd<=64 & yrimmig>1980 & bpl>=200 & bpl<=210 & sex==2 // noncitizen, HS or less, after 1986, born in Mexico/Central America
gen undoc6_wom = 1 if citizen==3 & educd<=64 & yrimmig>1980 & hispan>0 & hispan<9 & sex==2 // noncitizen, HS or less, after 1986, hispanic ethnicity
gen undoc5_men = 1 if citizen==3 & educd<=64 & yrimmig>1980 & bpl>=200 & bpl<=210 & sex==1 // noncitizen, HS or less, after 1986, born in Mexico/Central America
gen undoc6_men = 1 if citizen==3 & educd<=64 & yrimmig>1980 & hispan>0 & hispan<9 & sex==1 // noncitizen, HS or less, after 1986, hispanic ethnicity


/* Undocumented using ethnicity */
	* changing to 1986; excludes naturalized citizens and n/a
gen undoc586 = 1 if citizen==3 & educd<=64 & yrimmig>1986 & bpl>=200 & bpl<=210 // noncitizen, HS or less, after 1986, born in Mexico/Central America
gen undoc686 = 1 if citizen==3 & educd<=64 & yrimmig>1986 & hispan>0 & hispan<9 // noncitizen, HS or less, after 1986, hispanic ethnicity
gen undoc586_wom = 1 if citizen==3 & educd<=64 & yrimmig>1986 & bpl>=200 & bpl<=210 & sex==2 // noncitizen, HS or less, after 1986, born in Mexico/Central America
gen undoc686_wom = 1 if citizen==3 & educd<=64 & yrimmig>1986 & hispan>0 & hispan<9 & sex==2 // noncitizen, HS or less, after 1986, hispanic ethnicity
gen undoc586_men = 1 if citizen==3 & educd<=64 & yrimmig>1986 & bpl>=200 & bpl<=210 & sex==1 // noncitizen, HS or less, after 1986, born in Mexico/Central America
gen undoc686_men = 1 if citizen==3 & educd<=64 & yrimmig>1986 & hispan>0 & hispan<9 & sex==1 // noncitizen, HS or less, after 1986, hispanic ethnicity


/* Undocumented using ethnicity but not citizenship status */
gen fb_ca80_ls = 1 if fb==1 & educd<=64 & yrimmig>1980 & bpl>=200 & bpl<=210 // fb, HS or less, after 1986, born in Mexico/Central America
gen fb_hp80_ls = 1 if fb==1 & educd<=64 & yrimmig>1980 & hispan>0 & hispan<9 // fb, HS or less, after 1986, hispanic ethnicity
gen fb_ca80_wom_ls = 1 if fb==1 & educd<=64 & yrimmig>1980 & bpl>=200 & bpl<=210 & sex==2 // fb, HS or less, after 1986, born in Mexico/Central America
gen fb_hp80_wom_ls = 1 if fb==1 & educd<=64 & yrimmig>1980 & hispan>0 & hispan<9 & sex==2 // fb, HS or less, after 1986, hispanic ethnicity
gen fb_ca80_men_ls = 1 if fb==1 & educd<=64 & yrimmig>1980 & bpl>=200 & bpl<=210 & sex==1 // fb, HS or less, after 1986, born in Mexico/Central America
gen fb_hp80_men_ls = 1 if fb==1 & educd<=64 & yrimmig>1980 & hispan>0 & hispan<9 & sex==1 // fb, HS or less, after 1986, hispanic ethnicity




**************************************************
*Outcome Variables
**************************************************
gen     emp=empstat==1 if empstat!=0 

* Wages 
	replace incwage=. if wkswork2==0 // positive hours/weeks worked
	replace incwage=. if uhrswork==0 | uhrswork==. 
	replace incwage=. if school ==2 // exclude attending school
	replace incwage=. if classwkrd ==29 | classwkr==1 // exclude self-employed and unpaid family workers
	replace incwage =. if incwage==0 |incwage ==999999 |incwage==999998 

* Weeks Worked
	generate weeks=8.0*(wkswork2==1) + 20.8*(wkswork2==2) + 33.1*(wkswork2==3) ///
		+ 42.4*(wkswork2==4) + 48.3*(wkswork2==5) + 51.9*(wkswork2==6)
		
* Hours Worked
	gen hours = uhrswork // Hours worked

	
* Adjust income vars to real 2014 dollars 
merge m:1 year using "$DATA/cpi"
	drop if _merge<3
	drop _merge 

	sum cpi if year==2014
	scalar cpi14 = r(mean)
foreach x in tot wage earn {
	gen inc`x'_unadj = inc`x'
	replace inc`x' = inc`x'*cpi14/cpi
	}

	gen wage2 = incwage/(weeks*hours)
		label var wage2 "hourly wage (wage/(weeks*hours)"
		
		
		
	winsor wage2, gen(wage2w) p(0.025)
	winsor wage2, gen(wage2w2) p(0.025) highonly
	
	
	gen wage2d = wage2
	_pctile wage2, p(99.9)
	local w2=r(r1)	
	gen wage2d2 = wage2
	replace wage2d2=. if wage2>1000
		
	* full time vs. part time - based on usual hours per week 
	gen full_time = emp==1 & hours>=30 
		label var full_time "Full-time employed (at least 35 hours)"
	gen part_time = emp==1 & hours<30 
		label var part_time "Part-time employed (fewer than 35 hours)"
		
	* wages for full time only
	gen wage2_full_time = wage2 if full_time==1
	label var wage2_full_time "Wages for full-time employed (at least 30 hours)"
	
	* wages for full time only Winsorized and with highest values dropped
	gen wage2wft = wage2w if full_time==1
	label var wage2wft "Wages for full-time employed Winsorized (at least 30 hours)"
	gen wage2w2ft = wage2w2 if full_time==1
	label var wage2w2ft "Wages for full-time employed Winsorized top only (at least 30 hours)"
	gen wage2d2ft = wage2d2 if full_time==1
	label var wage2d2ft "Wages for full-time employed drop top 2.5 percentiles only (at least 30 hours)"
	
	
	* wages for ALL
	label var wage2 "Wages for all employed"
	
	* wages for ALL Winsorized
	label var wage2w "Wages for all employed Winsorized"
	label var wage2w2 "Wages for all employed Winsorized top only"
	label var wage2d2 "Wages for all employed drop top 2.5 percentiles only"


#delimit ;
local demog_list "
	noncit noncit_ls 
	 fb_ca80_ls fb_hp80_ls 
	 
     cit  all   
	 fb fb_ls  fb_men_ls   fb_wom_ls  
     usb usb_ls usb_hs  usb_men  usb_wom 
	 
" ;
#delimit cr
foreach g in `demog_list' {
	gen w2_`g' = wage2 if `g'==1 & (gq ==1 | gq==2) // keep only those not in gropu quarters, eg drop those in jail etc
	gen w2w_`g' = wage2w if `g'==1 & (gq ==1 | gq==2) // keep only those not in gropu quarters, eg drop those in jail etc
	gen w2w2_`g' = wage2w2 if `g'==1 & (gq ==1 | gq==2) // keep only those not in gropu quarters, eg drop those in jail etc
	gen w2d2_`g' = wage2d2 if `g'==1 & (gq ==1 | gq==2) // keep only those not in gropu quarters, eg drop those in jail etc
		
	
	gen w2_ft_`g' = wage2_full_time if `g'==1 & (gq ==1 | gq==2) // keep only those not in gropu quarters, eg drop those in jail etc
	gen w2w_ft_`g' = wage2wft if `g'==1 & (gq ==1 | gq==2) // keep only those not in gropu quarters, eg drop those in jail etc
	gen w2w2_ft_`g' = wage2w2ft if `g'==1 & (gq ==1 | gq==2) // keep only those not in gropu quarters, eg drop those in jail etc
	gen w2d2_ft_`g' = wage2d2ft if `g'==1 & (gq ==1 | gq==2) // keep only those not in gropu quarters, eg drop those in jail etc
	}





save $DATA/TEMP_acs_wage_aggregate.dta, replace



**************************************************
*Collapse to Puma, Year, Industry, and Occupation Level
************************************************** 
use $DATA/TEMP_acs_wage_aggregate.dta, clear
gen weight=perwt 
keep weight   w2*   statefip perwt cpuma0010 year ind1990 occ2010

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

forvalues y = 2005/2014 {
preserve
keep if year==`y'
cap replace perwt = round(perwt)
collapse  (rawsum) weight (mean)  w2*    ///
 (max) statefip [fw=perwt]  ,  by(cpuma0010 year ind1990 occ2010 sector) fast
	save "$DATA/TEMP_acs_wage_aggregate_`y'", replace
restore
}

use "$DATA/TEMP_acs_wage_aggregate_2005", clear
forvalues y = 2006/2014 {
	append using "$DATA/TEMP_acs_wage_aggregate_`y'"
	}

sum weight

**************************************************
*Merge occupation and industry charecteristics with ACS and drop Military and Public Admin 
**************************************************

merge m:1 occ2010 using "$DATA/temp_ACS_occ_edu_dropmilpa", gen(merge_ACS_occ_edu)
drop if merge_ACS_occ_edu~=3
drop merge_ACS_occ_edu

sum weight


**************************************************
*Collapse to Puma, Detailed Industry, and Year Level 
**************************************************
// generate occupation group specific outcome variables based on education-defined skill groups
// occupational skill based on % college dropping mil/pa
#delimit ;
local demog_list "
 usb_ls usb_hs 
 " ;
#delimit cr
foreach o in 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100  { 
foreach y in `demog_list'   {
gen w2_`y'_sk_`o'mw = w2w_ft_`y' if skilmpa_`o'mw==1 /* if hs or less change to skilh_ */
gen w2w_`y'_sk_`o'mw = w2w_ft_`y' if skilmpa_`o'mw==1 /* if hs or less change to skilh_ */
gen w2_ft_`y'_sk_`o'mw = w2w_ft_`y' if skilmpa_`o'mw==1 /* if hs or less change to skilh_ */
gen w2w_ft_`y'_sk_`o'mw = w2w_ft_`y' if skilmpa_`o'mw==1 /* if hs or less change to skilh_ */
}
}


* create new variable for weight
gen weight2 = weight 
sum weight2
sum year

keep   w2*   weight statefip sector ind cpuma0010 year

save $DATA/TEMP_acs_wage_aggregate.dta , replace

**************************************************
*Save Industry level version of dataset
**************************************************
use $DATA/TEMP_acs_wage_aggregate.dta , clear


	forvalues y = 2005/2014 {
	preserve
	keep if year==`y'
	collapse  (mean)  w2*  (sum)  weight     ///
	 (max) statefip  , by(cpuma0010 year sec ind ) fast
		save "$DATA/TEMP_acs_wage_aggregate_ind_`y'", replace
	restore
	}
	use "$DATA/TEMP_acs_wage_aggregate_ind_2005", clear
	forvalues y = 2006/2014 {
	append using "$DATA/TEMP_acs_wage_aggregate_ind_`y'"
cap sum *hours*
	}
	label var weight "ACS Population Estimate by Cell"
	label var cpuma0010 "Consistent PUMA ID"



	label var weight "ACS Population Estimate by Cell"
	label var cpuma0010 "Consistent PUMA ID"

cap sum *hours*

* Merge in Other Demographic Variables
* Merge in Policy/Control Variables
merge m:1 statefip cpuma0010 using $DATA/temp_ACS_num_undoc
sum year
tab year _merge
keep if _merge==3  // everything merged 
drop _merge 


merge m:1 statefip cpuma0010 year using "$DATA/temp_ACS_num_undoc_allyears"
tab year _merge
keep if _merge==3  // everything merged 
drop _merge 

merge m:1 cpuma0010  using $DATA/temp_pop 
sum year
tab year _merge
keep if _merge==3  // almost everything merged except 2015 and <2005
drop _merge 


	sum
cap sum *hours*

	compress

save $DATA/acs_aggregate_wage_ind.dta , replace




	
* Save main wage dataset	
use  $DATA/TEMP_acs_wage_aggregate.dta , clear

	
forvalues y = 2005/2014 {
preserve
keep if year==`y'
collapse  (mean)  w2*  (sum)  weight    ///
 (max) statefip  , by(cpuma0010 year  ) fast
	save "$DATA/TEMP_acs_aggregate_ind_`y'", replace
restore
}

use "$DATA/TEMP_acs_aggregate_ind_2005", clear
forvalues y = 2006/2014 {
append using "$DATA/TEMP_acs_aggregate_ind_`y'"
}

 
label var weight "ACS Population Estimate by Cell"
label var cpuma0010 "Consistent PUMA ID"


* Merge in Other Demographic Variables
merge m:1 statefip cpuma0010 using $DATA/temp_ACS_num_undoc
sum year
tab year _merge
keep if _merge==3  // everything merged 
drop _merge 


merge m:1 statefip cpuma0010 year using "$DATA/temp_ACS_num_undoc_allyears"
tab year _merge
keep if _merge==3  // everything merged 
drop _merge 

merge m:1 cpuma0010  using $DATA/temp_pop 
sum year
tab year _merge
keep if _merge==3  // almost everything merged except 2015 and <2005
drop _merge 


compress
 
save $DATA/acs_aggregate_wage.dta , replace



