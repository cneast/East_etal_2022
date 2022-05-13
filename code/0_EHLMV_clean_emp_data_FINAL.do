/***********************************************************************
PROGRAM:	0_EHLMV_clean_emp_data_FINAL.do 
PURPOSE:    Clean the ACS Data to Create Population, Employment, Unemployment and Out of the Labor Force Variables 
CREATES: 	Figure: A1, A3
************************************************************************/

clear 
clear matrix 
set mem 500m 
set more off 


*********************************************************************
/* DIRECTORY AND FILE NAMES: */  
clear all 

	if c(username)=="chloeeast" {  		// for Chloe's computer
			global dir "/Users/chloeeast/Dropbox"	 	 	
		} 
		else{ 
			if c(username)=="Chloe" {  		// for Chloe's laptop
			global dir "/Users/Chloe/Dropbox"	 	 	
			} 
			} 
		else{
			if c(username)=="philipluck" { 		// for Chloe's laptop
				global dir  "/Users/philipluck/Dropbox/Research/" 
			}
			}
		else{
			if c(username)=="hmansour" { 		// for Hani's desktop
				global dir  "\Users\hmansour\Dropbox" 
			}
			}	
		else{
			if c(username)=="annielauriehines" { 	// for Annie's laptop
				global dir  "/Users/annielauriehines/Dropbox" 
			}
			}			

		else{
			if c(username)=="ahines" { 	// for Annie's Sapper 
				global dir  "/home/users/ahines.AD3"
			}
			}	
********************************************************************* 
 
macro define DATA     "$dir/Skills_demand_and_immigration/Data" 
global resultslog ="Results/Logs"


local  today = c(current_date)
cap log using "$resultslog/0_prepare_ACS_Sample_emp_CNE_`today'.log", replace
	
**************************************************
*Create Skill Measure of Occupation Using ACS dropping military and pa
**************************************************
	
	use $DATA/acs.dta, clear  
	* Age 20-64 
	keep if age>=20 & age<=64
	* Dropping people in group quarters:
	keep if gq ==1 | gq==2 
	*drop observations for which education is not observed:
	drop if educd ==1
	tab occ2010, nolabel
	drop if occ2010==. | occ2010==9920 //	Unemployed, with No Work Experienoncite in the Last 5 Years or Earlier or Never Worked
	 
	keep if year ==2005 
	 
	gen lhs =0 
	replace lhs =1 if educd <=61

	gen hs_scol  = 0 

	replace hs_scol =1 if   educd < 101

	gen col = 0 
	replace col =1 if  educd >=101

	gen prof_deg= 0 
	replace prof_deg = 1 if educd >101

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

		drop if sector ==11 |  sector ==12

	*Not enough variation across occupations using median:
	collapse (mean) lhs hs_scol col prof_deg     [aweight=perwt] , by(occ2010)

	gen hs = col- lhs

	qui sum hs, d

	gen lowskill =0 
	replace lowskill =1 if hs<=r(p25)
	gen midskill =0 
	replace midskill=1 if hs>r(p25) & hs<r(p75) 
	gen hiskill =0
	replace hiskill =1 if hs>r(p75) 

	_pctile col, percentiles(20 25 33 40 50 60 66 75 80 )

	forvalues i= 1/9{
		gen colptl_`i' = r(r`i')
		}

	*By Quartile
	gen skilmpa_25qrt = 0
	replace skilmpa_25qrt =1 if col<=colptl_2
	gen skilmpa_50qrt = 0
	replace skilmpa_50qrt =1 if col> colptl_2 & col<=colptl_5
	gen skilmpa_75qrt = 0
	replace skilmpa_75qrt =1 if col> colptl_5 & col<=colptl_8
	gen skilmpa_100qrt = 0
	replace skilmpa_100qrt =1 if col>colptl_8
	
	* Moving Window: 25 pp bins 
	drop colptl_*
	_pctile col, percentiles(5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 )

	forvalues i= 1/19{
		gen colptl_`i' = r(r`i')
		}

		sum col, d
		gen colptl_0 = r(min)
		sum col, d
		gen colptl_20 = r(max)
		
	forvalues i= 5/20{
		local j = `i'-5
		local p = (`i')*5
		gen skilmpa_`p'mw = (col>=colptl_`j' & col<=colptl_`i')
		}
		
	* Bins of 10 pp, not moving window
	forvalues i= 2(2)18{
		local j = `i'-2
		local p = (`i')*5
		gen skilmpa_`p'b10 = (col>=colptl_`j' & col<colptl_`i')
		}	
		gen skilmpa_100b10 = (col>=colptl_18 & col<=colptl_20)

		drop colptl_*
		
		sum skilmpa_*mw

	
	save "$DATA/temp_ACS_occ_edu_dropmilpa.dta", replace
	
	
	* GENERATE OCCUPATION SKILL FIGURE FOR APPENDIX		
	use $DATA/acs.dta, clear  
	* Age 20-64 
	keep if age>=20 & age<=64
	* Dropping people in group quarters:
	keep if gq ==1 | gq==2 
	*drop observations for which education is not observed:
	drop if educd ==1
	tab occ2010, nolabel
	drop if occ2010==. | occ2010==9920 //	Unemployed, with No Work Experienoncite in the Last 5 Years or Earlier or Never Worked
	 
	keep if year ==2005 
	 

		
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

		*drop observations for which education is not observed:
		drop if educd ==1
		drop if occ1990 == 999
		gen lhs =0 
		replace lhs =1 if educd <=61
		gen hs_scol  = 0 
		replace hs_scol =1 if   educd < 101
		gen col = 0 
		replace col =1 if  educd >=101

		*Not enough variation across occupations using median:
		collapse (mean) lhs hs_scol col  [aweight=perwt] , by(occ1990)

		replace col = col*100

		sum col, d
		
		_pctile col, percentiles( 25 50  75 )
	

		forvalues i= 1/7{
			local colptl_`i' = r(r`i')
			}
			
		
		histogram  col  , ///
			xtitle(Percentages of Workers with College Degree) ///
		 graphregion(color(white)) width(2) ///
		 xline( `colptl_1' , lc(blue)) xline( `colptl_2' , lc(black)) xline( `colptl_3' , lc(red)) xlabel( 0 (10) 100)
		global resultsfolder = "$user/Drafts/Draft_Spring_2021/tab_fig/"
		 graph export "$resultsfolder/Occ_skill.png", replace
		
		
		
**************************************************
*Tab what occupations and sectors are in diff skill bins and gender makeup
**************************************************
use $DATA/acs.dta, clear  
* Age 20-64, 2005
keep if age>=20 & age<=64
keep if year==2005 

* Dropping people in group quarters:
keep if gq ==1 | gq==2 

sum perwt, d

* Create demographic groups 
gen all = 1
gen cit = 1 if bpl>=1 & bpl<=120 // born in US or US territory 
replace cit = 1 if bpl>120 & citizen==2 // born outside US and US territories, naturalized US citizen
replace cit = 1 if bpl>120 & citizen==1 // born outside US and US territories, but born to US parents (very likely a citizen: https://travel.state.gov/content/travel/en/legal-considerations/us-citizenship-laws-policies/citizenship-child-born-abroad.html)
gen cit_men = (cit==1 & sex==1) // Citizen Men
gen cit_wom = (cit==1 & sex==2) // Citizen Wom
gen cit_men_ls = (cit==1 & sex==1 & educ<=6) // Low-skill  Citizen Men
gen cit_men_hs = (cit==1 & sex==1 & educ>6) // High-skill  Citizen Men
gen cit_hp_men_ls=1 if (cit==1 & educ<=6   & sex==1 & hispan>0 & hispan<9)
gen noncit_men_ls = (cit~=1 & sex==1 & educ<=6)
gen male =(sex==1)
gen usb = 1 if bpl>=1 & bpl<=120 // born in US or US territory 
replace usb = 0 if bpl>120
gen ls = (educ<=6) // Low-education
gen hs = (educ>6) // High-education
gen hp = (hispan>0 & hispan<9) // Hispanic
gen noncit=(citizen==3)
gen fb=(usb==0)

foreach pob in  usb fb {
gen `pob'_wom=(`pob'==1  & sex==2)
gen `pob'_men=(`pob'==1  & sex==1)
foreach edu in ls hs {
gen `pob'_`edu'=(`pob'==1 & `edu'==1)
gen `pob'_wom_`edu'=(`pob'==1 & `edu'==1 & sex==2)
gen `pob'_men_`edu'=(`pob'==1 & `edu'==1 & sex==1)
}
}


merge m:1 occ2010 using "$DATA/temp_ACS_occ_edu_dropmilpa", gen(merge_ACS_occ_edu)
tab occ2010 merge_ACS_occ_edu, m // unemployed not matched and the two occupations that don't appear until later dates
tab occ2010 merge_ACS_occ_edu, m nolabel 
drop if merge_ACS_occ_edu~=3
drop merge_ACS_occ_edu

merge m:1 occ2010 using "$DATA/temp_ACS_occ_wage", gen(merge_ACS_occ_edu)
tab occ2010 merge_ACS_occ_edu, m // unemployed not matched and the two occupations that don't appear until later dates
tab occ2010 merge_ACS_occ_edu, m nolabel 
drop if merge_ACS_occ_edu~=3
drop merge_ACS_occ_edu

gen     emp=empstat==1 if empstat!=0 
for any fb_ls usb_ls  male cit all noncit_men_ls cit_men cit_wom cit_men_ls cit_hp_men_ls cit_men_hs: gen emp_X = emp if X==1

gen skillw = 1 if skilw_25mw==1
replace skillw = 2 if skilw_30mw==1
replace skillw = 3 if skilw_35mw==1
replace skillw = 4 if skilw_40mw==1
replace skillw = 5 if skilw_45mw==1
replace skillw = 6 if skilw_50mw==1
replace skillw = 7 if skilw_55mw==1
replace skillw = 8 if skilw_60mw==1
replace skillw = 9 if skilw_65mw==1
replace skillw = 10 if skilw_70mw==1
replace skillw = 11 if skilw_75mw==1
replace skillw = 12 if skilw_80mw==1
replace skillw = 13 if skilw_85mw==1
replace skillw = 14 if skilw_90mw==1
replace skillw = 15 if skilw_95mw==1
replace skillw = 16 if skilw_100mw==1


gen skillmpa = 1 if skilmpa_10b10==1
replace skillmpa = 2 if skilmpa_20b10==1
replace skillmpa = 3 if skilmpa_30b10==1
replace skillmpa = 4 if skilmpa_40b10==1
replace skillmpa = 5 if skilmpa_50b10==1
replace skillmpa = 6 if skilmpa_60b10==1
replace skillmpa = 7 if skilmpa_70b10==1
replace skillmpa = 8 if skilmpa_80b10==1
replace skillmpa = 9 if skilmpa_90b10==1
replace skillmpa = 10 if skilmpa_100b10==1



tab occ2010 if emp_usb_ls==1  [aweight=perwt], sort
tab occ2010 if emp_fb_ls==1  [aweight=perwt], sort

gen undoc = 1 if emp_fb_ls==1 
replace undoc = 0 if emp_usb_ls==1 

duncan2 occ2010 undoc [aweight=perwt] if year==2005
sort skillmpa
by skillmpa: duncan2 occ2010 undoc [aweight=perwt] if year==2005
sort skillw
by skillw: duncan2 occ2010 undoc [aweight=perwt] if year==2005


local demog_list "cit all noncit_men_ls cit_men cit_men_ls cit_hp_men_ls  cit_men_hs"
foreach o in 25 50 75 100  { 
foreach y in `demog_list'   {
gen emp_`y'_skmpa`o'= emp_`y' if skilmpa_`o'qrt==1
}
}

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

* drop 
drop if sector ==11 |  sector ==12



label define sector1 1 "AGRICULTURE, FORESTRY, AND FISHERIE"  2 "MINING" 3 "CONSTRUCTION" 4 "MANUFACTURING" 5 "Transportation & Utilites" ///
6 "WHOLESALE, RETAIL" 7 " FINANCE, INSURANCE, AND REAL ESTATE" 8 "BUSINESS AND REPAIR SERVICES" 9 "PERSONAL, ENTERTAINMENT AND RECREATION SERVICES" ///
10 "Education and Health & Other Services" 11 "PUBLIC ADMINISTRATION" 12 "ACTIVE DUTY MILITARY"
label values sector sector1

bysort sector: sum emp_male


gen LENCaboveshr4 = 1 if (sector ==1| sector==3 | sector==9 | sector==6 | sector==4 )
replace LENCaboveshr4 = 0 if (sector ==5 | sector ==2 | sector ==7| sector==8 |  sector ==10 | sector ==12 |sector ==11)


tab occ2010 if emp_cit_men==1  [aweight=perwt], sort
tab ind1990 if emp_cit_men==1  [aweight=perwt], sort
tab sector if emp_cit_men==1  [aweight=perwt], sort
tab sector if emp_cit_wom==1  [aweight=perwt], sort


tab sector if emp_cit==1  [aweight=perwt], sort
tab sector if emp_cit_men==1  [aweight=perwt], sort
tab sector if emp_cit_men_ls==1  [aweight=perwt], sort
tab sector if emp_noncit_men_ls==1  [aweight=perwt], sort


tab sector if emp_cit==1  [aweight=perwt]
tab sector if emp_cit_men==1  [aweight=perwt]
tab sector if emp_cit_men_hs==1  [aweight=perwt]
tab sector if emp_cit_men_ls==1  [aweight=perwt]
tab sector if emp_cit_hp_men_ls==1  [aweight=perwt]
tab sector if emp_noncit_men_ls==1  [aweight=perwt]

tab occ2010 if emp_cit==1  [aweight=perwt], sort
tab occ2010 if emp_cit_men==1  [aweight=perwt], sort
tab occ2010 if emp_cit_men_hs==1  [aweight=perwt], sort
tab occ2010 if emp_cit_men_ls==1  [aweight=perwt], sort
tab occ2010 if emp_cit_hp_men_ls==1  [aweight=perwt], sort
tab occ2010 if emp_noncit_men_ls==1  [aweight=perwt], sort

preserve
for any emp_noncit_men_ls_sk25 emp_cit_men_sk25 emp_cit_men_ls_sk25 emp_cit_men_hs emp_cit_men_ls emp_noncit_men_ls: gen Xo = 1 if X==1
collapse (sum) emp_noncit_men_ls_sk25o emp_cit_men_sk25o emp_cit_men_ls_sk25o emp_cit_men_hso emp_cit_men_lso emp_noncit_men_lso [aweight=perwt], by(occ2010)
corr emp_cit_men_lso emp_noncit_men_lso
twoway (scatter emp_cit_men_lso emp_noncit_men_lso) (lfit emp_cit_men_lso emp_noncit_men_lso)
corr emp_noncit_men_ls_sk25o emp_cit_men_sk25o
twoway (scatter emp_noncit_men_ls_sk25o emp_cit_men_sk25o) (lfit emp_noncit_men_ls_sk25o emp_cit_men_sk25o)
corr emp_noncit_men_ls_sk25o emp_cit_men_ls_sk25o
twoway (scatter emp_noncit_men_ls_sk25o emp_cit_men_ls_sk25o) (lfit emp_noncit_men_ls_sk25o emp_cit_men_ls_sk25o)
corr emp_cit_men_hso emp_noncit_men_lso
twoway (scatter emp_cit_men_hso emp_noncit_men_lso) (lfit emp_cit_men_hso emp_noncit_men_lso)
restore

 
levelsof occ2010, local(levels)
foreach l in `levels' {
for any emp_cit_men_ls emp_noncit_men_ls: replace X = .
}

tab occ2010 if emp_cit_men_sk75==1  [aweight=perwt], sort
tab ind1990 if emp_cit_men_sk75==1  [aweight=perwt], sort
tab sector if emp_cit_men_sk75==1  [aweight=perwt], sort

tab occ2010 if emp_cit_men_ls_sk75==1  [aweight=perwt], sort
tab ind1990 if emp_cit_men_ls_sk75==1  [aweight=perwt], sort
tab sector if emp_cit_men_ls_sk75==1  [aweight=perwt], sort

tab occ2010 if emp_cit_men_hs_sk75==1  [aweight=perwt], sort
tab ind1990 if emp_cit_men_hs_sk75==1  [aweight=perwt], sort
tab sector if emp_cit_men_hs_sk75==1  [aweight=perwt], sort

tab occ2010 if emp_noncit_men_ls_sk75==1  [aweight=perwt], sort


tab occ2010 if emp_cit_men_sk25==1  [aweight=perwt], sort
tab occ2010 if emp_cit_men_ls_sk25==1  [aweight=perwt], sort
tab occ2010 if emp_cit_men_hs_sk25==1  [aweight=perwt], sort
tab occ2010 if emp_noncit_men_ls_sk25==1  [aweight=perwt], sort

tab occ2010 if emp_cit_men_sk50==1  [aweight=perwt], sort
tab occ2010 if emp_cit_men_ls_sk50==1  [aweight=perwt], sort
tab occ2010 if emp_cit_men_hs_sk50==1  [aweight=perwt], sort
tab occ2010 if emp_noncit_men_ls_sk50==1  [aweight=perwt], sort

tab occ2010 if emp_cit_men_sk75==1  [aweight=perwt], sort
tab occ2010 if emp_cit_men_ls_sk75==1  [aweight=perwt], sort
tab occ2010 if emp_cit_men_hs_sk75==1  [aweight=perwt], sort
tab occ2010 if emp_noncit_men_ls_sk75==1  [aweight=perwt], sort

tab occ2010 if emp_cit_men_sk100==1  [aweight=perwt], sort
tab occ2010 if emp_cit_men_ls_sk100==1  [aweight=perwt], sort
tab occ2010 if emp_cit_men_hs_sk100==1  [aweight=perwt], sort
tab occ2010 if emp_noncit_men_ls_sk100==1  [aweight=perwt], sort

preserve
collapse (sum) emp_male emp_all [aw=perwt], by(LENCaboveshr4)
gen frac = emp_male/emp_all
bysort LENCaboveshr4: sum frac
restore


preserve
collapse (sum) emp_noncit_men_ls emp_all emp_cit_men emp_cit , by(ind1990)
gen var1 = emp_noncit_men_ls/emp_all
gen var2 = emp_cit_men/emp_cit
corr var1 var2
label var var1 "% of Industry Employment LENC Men"
label var var2 "% of Industry Cit Employment Men"
twoway (scatter var1 var2)
restore

// male employment intensity by industry and occ
cap drop hi_ind_male hi_occ_male
preserve
collapse (sum) emp_male emp_all [aw=perwt], by(ind1990)
gen frac = emp_male/emp_all
sum  
gen hi_ind_male =(frac>.6 & frac~=.)
tempfile hi_ind_male
save "`hi_ind_male'", replace
restore
preserve
collapse (sum) emp_male emp_all [aw=perwt], by(occ1990)
gen frac = emp_male/emp_all
sum  
gen hi_occ_male =(frac>.6 & frac~=.)
tempfile hi_occ_male
save "`hi_occ_male'", replace
restore
cap drop _merge
merge m:1 ind1990 using "`hi_ind_male'"
drop _merge
merge m:1 occ1990 using "`hi_occ_male'"
drop _merge

tab hi_ind_male if emp_noncit_men_ls==1 [aw=perwt]
tab hi_occ_male if emp_noncit_men_ls==1 [aw=perwt]



	
	




**************************************************
* CONSTURCT MAIN ANALYSIS DATA SET
**************************************************

use $DATA/acs.dta, clear  
cap drop _merge 


* Age 20-64, 2005-2014
keep if age>=20 & age<=64
drop if year==2015
keep if year>=2005 

* Dropping people in group quarters (NOW DO THIS BELOW):
* keep if gq ==1 | gq==2 
gen ins=(gq ==3)

sum perwt, d

**************************************************
*Demographic Groups
**************************************************

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

foreach pob in noncit fb {
foreach edu in ls {
gen `pob'_wom_`edu'_hh=(`pob'==1 & `edu'==1 & sex==2 & (occ1990==468|occ1990==405 ))
gen `pob'_hp_wom_`edu'_hh=(`pob'==1 & `edu'==1 & sex==2 & hp==1 & (occ1990==468|occ1990==405 ))
gen `pob'_wom80_`edu'_hh=(`pob'==1 & `edu'==1 & sex==2 & (occ1990==468|occ1990==405 )  & yrimmig>1980)
gen `pob'_hp_wom80_`edu'_hh=(`pob'==1 & `edu'==1 & sex==2 & hp==1 & (occ1990==468|occ1990==405 )  & yrimmig>1980)
}
}


foreach pob in cit usb  {
gen `pob'_men_scol=(`pob'==1  & sex==1 & educd>65 & educd<101 & educd~=.)
gen `pob'_wom_scol=(`pob'==1  & sex==2 & educd>65 & educd<101 & educd~=.)
gen `pob'_men_col=(`pob'==1  & sex==1 & educd>=101 & educd~=.)
gen `pob'_wom_col=(`pob'==1  & sex==2 & educd>=101 & educd~=.)
gen `pob'_scol=(`pob'==1   & educd>65 & educd<101 & educd~=.)
gen `pob'_col=(`pob'==1  & sex==1 & educd>=101 & educd~=.)
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
gen     lfp=labforce==2  
gen     emp=empstat==1 
gen     uhrs_c=uhrswork if uhrswork!=0 
replace uhrs_c=. if uhrswork==0 
gen     uhrs50=uhrswork>=50 
gen     uhrs60=uhrswork>=60 
gen     uhrs50_c=uhrswork>=50 
replace uhrs50_c=. if uhrswork==0 
gen     uhrs60_c=uhrswork>=60 
replace uhrs60_c=. if uhrswork==0 
gen     weeks_c=wkswork2 if wkswork2!=0 
replace weeks_c=. if wkswork2==0 

gen pop =1



#delimit ;
local demog_list "cit_wom_hs_kid cit_wom_hs_ykid cit_men_hs_kid cit_men_hs_ykid usb_wom_hs_kid usb_wom_hs_ykid 
	usb_men_hs_kid usb_men_hs_ykid cit_wom_hs_nokid cit_men_hs_nokid usb_wom_hs_nokid usb_men_hs_nokid
	noncit noncit_ls noncit_men noncit_men_ls noncit_hp_men_ls undoc5_men undoc6_men undoc586_men undoc686_men 
	 fb_ca80_ls fb_hp80_ls fb_hp80_wom_ls fb_ca80_wom_ls fb_ca80_men_ls fb_hp80_men_ls
	 noncit_wom_ls_hh noncit_hp_wom_ls_hh noncit_wom80_ls_hh noncit_hp_wom80_ls_hh fb_wom_ls_hh fb_hp_wom_ls_hh fb_wom80_ls_hh fb_hp_wom80_ls_hh
	 
     cit_men_scol cit_men_col usb_men_scol usb_men_col cit cit_ls cit_men_ls cit_men cit_men_hs cit_hp_men_ls all   
	 
	 noncit_wom noncit_wom_ls noncit_hp_wom_ls undoc5_wom undoc6_wom   usb_wom_scol usb_wom_col
	 cit_wom_ls cit_wom cit_wom_hs cit_hp_wom_ls cit_wom_scol cit_wom_col cit_wom_col_kid cit_wom_col_ykid
	 
	 fb fb_men fb_men_ls fb_hp_men_ls fb_wom fb_wom_ls fb_hp_wom_ls 
     usb usb_men_ls usb_men usb_men_hs usb_hp_men_ls usb_wom_ls usb_wom usb_wom_hs usb_hp_wom_ls
	 
" ;
#delimit cr
foreach g in `demog_list' {
gen emp_`g' = emp if `g'==1 & (gq ==1 | gq==2) // keep only those not in gropu quarters, eg drop those in jail etc
gen pop_`g' = 1 if `g'==1
}




#delimit ;
local demog_list " usb usb_wom 
	  usb_men  fb_ls
	 fb_ca80_ls fb_hp80_ls fb_hp80_wom_ls fb_ca80_wom_ls fb_ca80_men_ls fb_hp80_men_ls 
	 fb fb_men fb_men_ls fb_hp_men_ls fb_wom fb_wom_ls fb_hp_wom_ls 
" ;
#delimit cr
foreach g in `demog_list' {
gen un_`g' = (empstat==2) if `g'==1 & (gq ==1 | gq==2)
gen nlf_`g' = (empstat==3) if `g'==1 & (gq ==1 | gq==2)
}


save $DATA/TEMP_acs_emp_aggregate.dta, replace


**************************************************
*Collapse to Puma, Year, Industry, and Occupation Level
************************************************** 

set more off
use $DATA/TEMP_acs_emp_aggregate.dta, clear
tab bpl citizen 
gen weight=perwt 
keep weight  pop_*     statefip perwt cpuma0010 year 

collapse   (sum)   pop_*    ///
 (max) statefip [fw=perwt]  , by(cpuma0010 year  ) 
 sum
	save "$DATA/temp_ACS_pop_allyears", replace

 use $DATA/TEMP_acs_aggregate.dta, clear
gen weight=perwt 
keep weight emp_* ins_*  hrs_* hrsc_*  hours_* age_* yrsusa1_* educd_* hp_* un_* nlf_* statefip perwt cpuma0010 year ind1990 occ2010


forvalues y = 2005/2014 {
preserve
keep if year==`y'
collapse  (rawsum) weight (mean) hrs_* hrsc_* age_* yrsusa1_* educd_* hp_* (sum) un_* nlf_* emp_* ins_* hours_*   ///
 (max) statefip [fw=perwt]  , by(cpuma0010 year ind1990 occ2010) fast
	save "$DATA/TEMP_acs_emp_aggregate_ind_occ_`y'", replace
restore
}

use "$DATA/TEMP_acs_emp_aggregate_ind_occ_2005", clear
forvalues y = 2006/2014 {
append using "$DATA/TEMP_acs_emp_aggregate_ind_occ_`y'"
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
local demog_list "all      fb_ls
 usb        
 usb_ls usb_hs 
 " ;
#delimit cr
foreach o in 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100  { 
foreach y in `demog_list'   {
cap gen emp_`y'_sk`o'mw = emp_`y' if skilmpa_`o'mw==1
}
}

// create new variable for weight
gen weight2 = weight 
sum weight2
sum year


keep emp* un_* nlf_* weight statefip   cpuma0010 ind1990 year

 
 forvalues y = 2005/2014 {
preserve
keep if year==`y'
collapse  (sum) un_* nlf_* emp_*  weight  ///
 (max) statefip  , by(cpuma0010 year ind1990 ) fast
	save "$DATA/TEMP_acs_emp_aggregate_ind_`y'", replace
restore
}

use "$DATA/TEMP_acs_emp_aggregate_ind_2005", clear
forvalues y = 2006/2014 {
append using "$DATA/TEMP_acs_emp_aggregate_ind_`y'"
}

 
label var weight "ACS Population Estimate by Cell"
label var cpuma0010 "Consistent PUMA ID"
label var ind1990 "Consistent Industry ID"


* Merge in Other Demographic Variables
merge m:1 statefip cpuma0010 using $DATA/temp_ACS_num_undoc
sum year
tab year _merge
keep if _merge==3  // everything merged 
drop _merge 

merge m:1 statefip cpuma0010 year using "$DATA/temp_ACS_pop_allyears"
tab year _merge
keep if _merge==3  // everything merged 
drop _merge 

merge m:1 cpuma0010  using $DATA/temp_pop 
sum year
tab year _merge
keep if _merge==3  // almost everything merged except 2015 and <2005
drop _merge 
  

merge m:1 cpuma0010 year using $DATA/deportations_cpuma0010.dta
sum year
	tab year _merge
	tab statefip _merge
	*keep if _merge==3
	drop _merge
	
merge m:1 cpuma0010 year using $DATA/detainers_cpuma0010.dta
sum year
	tab year _merge
	tab statefip _merge
	*keep if _merge==3
	drop _merge
	

sum

compress
 
save $DATA/acs_aggregate_emp.dta , replace







