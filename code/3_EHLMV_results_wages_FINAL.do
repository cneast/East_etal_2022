/***********************************************************************
PROGRAM:	1_EHLMV_results_wages_FINAL.do 
PURPOSE:    Convert the ACS Wage Data Set from PUMA Level to CZ level  and Merge in Controls
			Conduct Main Analysis on Wage Variables 
CREATES: 	Figures: 2B, 2D, 3A, 3D, 3E
			Tables: 3 (col 4-6), 4 (col 5-6), 6 (panel B), 8, 9 (panel B), 10 (column 2)
			A1 (2nd two panels), A2 (col 3-4), A5 (panel B)
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




******************************
* Use PUMA-Year Level ACS Data and Collapse to CZ level and Merge in Control Variables
******************************

*merge to ACS employment Data:	
use "$data/acs_aggregate_wage.dta" , clear

* DROP OLD BARTIKS AND MERGE IN NEW ONES W SPLITS BY COUNTRY OF BIRTH
drop shift_share_sample*
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

collapse (max) AZ not_early  (mean)  division region statefip  w2*    (sum)  pop*    ///
shift_share_sample_fb shift_share_sample_usb   ///
	[pweight=af]  , by(cz year)
	
// some CZs span multple regions so round to region most of CZ is in
replace region= round(region)
replace division= round(division)

// merge in CZ control variables created in the employment do file
merge 1:1 czone  year using  "$data/County Level/policy_pop_cz_5_13_22.dta"
keep if _merge ==3
drop _merge

// rename cz cpuma0010 to use below
rename cz 	cpuma0010	

drop if year<2005 | year>2014
drop if SC_frac==.
gen full = 1

label variable SC_frac " $ \beta$: SC"



******************************
/** Wage Variables **/
******************************

// generate total working age PUMA population in 2005 for denominator
foreach demog in all fb_men_ls usb_men {
gen pop_`demog'_2005=pop_`demog' if year==2005
bysort cpuma0010: egen max_pop_`demog'_2005=max(pop_`demog'_2005)	
}
	
*gen emp_fb_ls = emp_fb_men_ls+emp_fb_wom_ls
gen pop_fb_ls = pop_fb_men_ls+pop_fb_wom_ls


	
#delimit ;
local demog_list "
	noncit noncit_ls 
	 fb_ca80_ls fb_hp80_ls 
	 
     cit  all   
	 fb fb_ls  fb_men_ls   fb_wom_ls  
     usb usb_ls usb_hs  usb_men  usb_wom 
	 
" ;
#delimit cr
foreach demog in `demog_list'     {  
	cap gen lw2_`demog'= ln(w2_`demog')
	cap gen lw2w_`demog'= ln(w2w_`demog')
	cap gen lw2w2_`demog'= ln(w2w2_`demog')
	cap gen lw2d2_`demog'= ln(w2d2_`demog')
	
	cap gen lw2w_ft_`demog'= ln(w2w_ft_`demog')
	cap gen lw2_ft_`demog'= ln(w2_ft_`demog')
	cap gen lw2w2_ft_`demog'= ln(w2w2_ft_`demog')
	cap gen lw2d2_ft_`demog'= ln(w2d2_ft_`demog')
	

	}


#delimit ;
local demog_list "
 usb_ls usb_hs 
 " ;
 #delimit cr

foreach demog in `demog_list'     {
foreach o in 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100  { 
	cap gen lw2w_ft_`demog'_sk`o'mw = ln(w2w_ft_`demog'_sk_`o'mw)
	}
}



tab year
tab cpuma0010

* One CZ has no individuals in any year so drop
drop if cpuma0010==34701


*******************************
* Construct Summary Stats:
*******************************
sum w2w_ft_fb_ls w2w_ft_fb_men_ls w2w_ft_fb_wom_ls w2w_ft_usb w2w_ft_usb_men w2w_ft_usb_wom  [aweight=pop2000] if year<2015 


*******************************
* GENERATE LAGS AND LEADS
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
 
save "data/EHLMV_wages_forCS.dta", replace

 ;
 

	
*******************************
* MOVING WINDOW PLOT BY OCCUPATIONAL SKILL, USING OCC SKILL AFTER DROPPING MIL/PA
*******************************
pause off
eststo clear
foreach j in    lw2w_ft   {
eststo clear	
foreach k in    usb_ls  usb_hs {
cap drop *_skmw_b* *_skmw_se*

				eststo : reghdfe `j'_`k'   SC_frac             ///
					shift_share_sample_fb shift_share_sample_usb  ///
 				 [aweight=pop2000] if year<2015    ,   vce (cluster cpuma0010) absorb( year   cpuma0010  i.cpuma0010#c.year      ) 
				gen `j'_skmw_b0 = _b[SC_frac]
				gen `j'_skmw_se0 = _se[SC_frac]
				
				foreach skill in 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 {

				eststo : reghdfe `j'_`k'_sk`skill'mw   SC_frac             ///
					shift_share_sample_fb shift_share_sample_usb   ///
 				 [aweight=pop2000] if year<2015     ,   vce (cluster cpuma0010) absorb( year   cpuma0010  i.cpuma0010#c.year      ) 
				gen `j'_skmw_b`skill' = _b[SC_frac]
				gen `j'_skmw_se`skill' = _se[SC_frac]	
	}

	preserve
	keep `j'_sk*mw_b*  `j'_sk*mw_se* 
	collapse `j'_sk*mw_b*  `j'_sk*mw_se* 
	gen id =1
	pause
	reshape long `j'_skmw_b  `j'_skmw_se esh05_`k'_skmw , i(id) j(mw)
	pause
	gen ci_top = `j'_sk`median'mw_b+1.96*`j'_skmw_se
	gen ci_bot =`j'_sk`median'mw_b-1.96*`j'_skmw_se
	gen zero = 0
	drop if mw==0
  	twoway  (scatter `j'_skmw_b mw, color(black) )    ///
 (rcap ci_top ci_bot mw,   lcolor(gray) lpattern(dash) )  (line zero mw, clcolor(gray) lpattern(dash)  )  ,   ylabel(,nogrid)  graphregion(color(white)) ///
 legend( off)  ytitle("Beta") xtitle("Occupational Skill")  ///
 xlabel( 25 "0-25" 30 "5-30" 35 "10-35" 40 "15-40" 45 "20-45" 50 "25-50" 55 "30-55" 60 "35-60" 65 "40-65" 70 "45-70" 75 "50-75"  80 "55-80" 85 "60-85" 90 "65-90" 95 "70-95" 100 "75-100", angle(90))
 graph export "$resultsfolder/effects_wage_`j'_`k'_skill_mw_skill.png", replace  height(600) width(800)
restore
	}
	}

	
	
*******************************
* EFFECTS ON WAGES, SPLIT BY DEMOG GROUPS
*******************************

foreach j in  lw2w_ft  {
if "`j'"=="lw2w_ft" local depvar "Log wages, FT"

eststo clear	
** Baseline Model with CZ FE, Year FE, and CZ Trends	
foreach g in  fb_ls fb_wom_ls fb_men_ls   usb usb_wom usb_men  {
				eststo : reghdfe `j'_`g'   SC_frac             ///
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
				

			  
	esttab    using "$resultsfolder/effects_`j'.tex", replace ///
					keep ( SC_frac       ) ///
						order (  SC_frac          )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
						label stats(      czyrtnd bartik_vary ymean p perc N   , ///
							labels(  "CZ-Year Trends"  "Bartiks"    "Y mean" "P-Value" "\% Effect" "Observations"   ) ///
						fmt(   0 0 2 2 2 0   )) nonumbers mtitles(  "fb_ls" "fb_wom_ls" "fb_men_ls"   "usb" "usb_wom" "usb_men"  ) ///
						prefoot("") postfoot("")   varlabels( , blist(SC_frac "\midrule \it{\underline{A: Baseline}} \\ "))
			  
			  eststo clear	
** Add bartiks 
foreach g in  fb_ls fb_wom_ls fb_men_ls   usb usb_wom usb_men  {
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
				

			  
	esttab    using "$resultsfolder/effects_`j'.tex", append ///
					keep ( SC_frac       ) ///
						order (  SC_frac          )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
						label stats(      czyrtnd bartik_vary ymean p perc N   , ///
							labels(  "CZ-Year Trends"  "Bartiks"    "Y mean" "P-Value" "\% Effect" "Observations"   ) ///
						fmt(   0 0 2 2 2 0   )) nonumbers mtitles(  "" "" "" "" "" "" "" "" ""   ) ///
			  prefoot("") prehead("") posthead("")	  varlabels( , blist(SC_frac "\midrule \it{\underline{B: Add Bartiks }} \\ "))
			  eststo clear	
 }


 
	
	
*******************************
* DISTRIBUTED LAG MODEL  
*******************************	
foreach grouplist in fb_ls  usb  {
foreach j in  lw2w_ft  {
if "`j'"=="lw2_ft" local depvar "Log wages"
 foreach g in `grouplist' {

eststo: reghdfe `j'_`g'  F2_SC_frac  F1_SC_frac  L0_SC_frac  L1_SC_frac  L2_SC_frac   ///
shift_share_sample_fb shift_share_sample_usb  ///
 		  [aweight=pop2000]  if year<2015    ,   vce (cluster cpuma0010) absorb(  year  cpuma0010   i.cpuma0010#c.year    ) 
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

		esttab    using "$resultsfolder/DL_results_wages.tex", replace ///
					keep (F2_SC_frac  F1_SC_frac  L0_SC_frac  L1_SC_frac  L2_SC_frac          ) ///
						order (  F2_SC_frac  F1_SC_frac  L0_SC_frac  L1_SC_frac  L2_SC_frac        )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
							mgroups("Dep. Var: `depvar'"   , pattern(1 0 0 0 0   ) ///
			prefix(\multicolumn{@span}{c}{) suffix(}) span  erepeat(\cmidrule(lr){@span})) ///
						label stats(     czyrtnd bartik_vary ymean  N   , ///
							labels( "CZ-Year Trends"  "Bartiks"    "Y mean"  "Observations"   ) ///
						fmt(   0 0 2  0   )) nonumbers mtitles("Low-Edu Foreign-Born"  ///
						"US-Born" )
						
	
	
	
	
	
*******************************
* SPLIT BY LIKELY UNDOCUMENTED DEMOGRPHICS
*******************************

local group = "direct"
if "`group'"=="direct" local grouplist " fb_ls fb_hp80_ls fb_ca80_ls  "
if  "`group'"=="direct" local titles "  mtitles("All"  "Hisp Arrive 80$+$"  "Mx/CA Arrive 80$+$") "
local outcomes "  lw2w_ft" 

foreach j in   `outcomes'   {  
eststo clear	
foreach g in  `grouplist' {
				eststo : reghdfe `j'_`g'   SC_frac             ///
 						shift_share_sample_fb shift_share_sample_usb  ///
			  [aweight=pop2000] if year<2015  ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  "X"
				estadd local house_trend  ""
				estadd ysumm 
				sum `j'_`g' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100							
				}							
		esttab    using "$resultsfolder/effects_`j'_direct.tex", replace ///
					keep ( SC_frac       ) ///
						order (  SC_frac          )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
						label stats(     czyrtnd bartik_vary ymean  N   , ///
							labels(  "CZ-Year Trends"  "Bartiks"    "Y mean"   "Observations"   ) ///
						fmt(  0 0  2 0   )) nonumbers `titles' 
	}		  
			  
		
*******************************
* SPLIT BY EDUCATION
*******************************
			  
local group = "indirect"
if "`group'"=="indirect" local grouplist " usb_ls  usb_hs"
if  "`group'"=="indirect" local titles " mtitles(  "Low-Edu"   "Some Col$+$" ) "
local outcomes "  lw2w_ft" 

foreach j in   `outcomes'   { 	 
eststo clear	
foreach g in  `grouplist' {
				eststo : reghdfe `j'_`g'   SC_frac              /// 
				shift_share_sample_fb shift_share_sample_usb ///
				 [aweight=pop2000] if year<2015   ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
				estadd local czyrtnd  "X"	
				estadd local bartik_vary  ""
				estadd local house_trend  ""
				estadd ysumm 
				sum `j'_`g' if e(sample)==1  [aweight=pop2000]
				estadd scalar perc = (_b[SC_frac]/r(mean))*100							
				}							
		esttab    using "$resultsfolder/effects_`j'_indirect_educ.tex", replace ///
										keep (SC_frac          ) ///
						order (  SC_frac        )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
							mgroups("Dep. Var: `depvar'"   , pattern(1 0 0 0 0   ) ///
			prefix(\multicolumn{@span}{c}{) suffix(}) span  erepeat(\cmidrule(lr){@span})) ///
						label stats(      czyrtnd bartik_vary ymean  N   , ///
							labels(  "CZ-Year Trends"  "Bartiks"    "Y mean"   "Observations"   ) ///
						fmt(  0 0  2 0   )) nonumbers `titles' ///

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
foreach j in   lw2w_ft   {
foreach g in `grouplist' {
foreach sample in full not_early no_sanctuary_on not_AZ {

		  eststo : reghdfe `j'_`g' SC_frac            ///
		shift_share_sample_fb shift_share_sample_usb     ///
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
shift_share_sample_fb shift_share_sample_usb     ///
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
shift_share_sample_fb shift_share_sample_usb     ///
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
mgroups("Baseline" "Robustness to Dropping CZs" "Control for Other Immigration Policies"  "Control for Economic Conditions" , pattern(1 1 0 0 1 0 1 0   ) ///
prefix(\multicolumn{@span}{c}{) suffix(}) span  erepeat(\cmidrule(lr){@span})) ///
label stats(     czyrtnd bartik_vary ymean N   , ///
labels(  "CZ-Year Trends"  "Bartiks"    "Y mean"  "Observations"   ) ///
fmt(   0 0 2  0   ))    nonumbers mtitles(  "" "Drop Early Adopt" "Drop Sanc. Cities" "Drop AZ" "Control for 287gs" "Control for E-Verify" ///
"Region*Year FE" "Quadratic Trend House Prices \& Starts") ///
prefoot("") postfoot("")   varlabels( , blist(SC_frac "\midrule \it{\underline{A: All Low-Edu Foreign-Born }} \\ "))
eststo clear
}

if "`g'"=="usb" {
esttab    using "$resultsfolder/effects_robustchecks_`j'.tex", append ///
keep (SC_frac          ) ///
order (  SC_frac        )  nodepvar se(3) b(3) star( * 0.10 ** 0.05 *** 0.01) nonum nonotes ///
label stats(     czyrtnd bartik_vary ymean  N   , ///
labels(  "CZ-Year Trends"  "Bartiks"    "Y mean" "Observations"   ) ///
fmt(   0 0 2  0   ))   nonumbers mtitles( "" "" "" "" "" "" "" "" "" "" "" "" "" "" ""  ) ///
prefoot("") prehead("") posthead("")   varlabels( , blist(SC_frac "\midrule \it{\underline{B: All US-Born }} \\ "))
eststo clear
}


}
}
}


 
*******************************
* SPLIT BY CITIZENSHIP
*******************************
 
foreach group in    directindirect_noncit   {
if "`group'"=="directindirect_noncit" local grouplist " noncit_ls cit"

if  "`group'"=="directindirect_noncit" local titles " mtitles( "Low-Educated Non-Citizens"  "All Citizens" ) "

local outcomes "lw2w_ft" 

foreach j in   `outcomes'   { 
			 
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



 
*********************************************************
* BY TRADEABILITY OF INDUSTRY OF WORK
*********************************************************

use $data/acs_aggregate_wage_ind.dta , clear

merge m:1 ind1990 using $data/tradable1_BHVT.dta
sort   cpuma0010 year

* DROP OLD BARTIKS AND MERGE IN NEW ONES W SPLITS BY COUNTRY OF BIRTH
drop _merge  
drop shift_share_sample*
merge m:1 statefip cpuma0010 year using $data/final_bartik_acs_cpuma0010_updated.dta
sum year
tab year _merge
keep if _merge==3 // everything merged except 2015
drop _merge  



drop if sector ==11 |  sector ==12


collapse (mean) w* 	///
				 pop_* shift_share_sample_usb shift_share_sample_fb ///
					[aweight=emp_ind]	, by( year  cpuma0010 tradable2  statefip SC_frac)
	
joinby cpuma0010 using  "$data/crosswalks/cw_cpuma2010_czone.dta"

collapse (sum)  w*  pop_*  shift_share_sample_usb shift_share_sample_fb ///
				[pweight=af]   , by(cz year tradable2)

merge m:1 czone  year using  "$data/County Level/policy_pop_cz_5_13_22.dta"
keep if _merge ==3
drop _merge
rename cz 	cpuma0010	



drop if year<2005 | year>2014
drop if SC_frac==.
gen full = 1


#delimit ;
local demog_list " usb
" ;

#delimit cr
foreach demog in `demog_list'     {
	cap gen lw2w_ft_`demog'= ln(w2w_ft_`demog')
	}

label variable SC_frac " $ \beta$: SC"

****************************
* Table by tradabilty
foreach j in   lw2w_ft   {
if "`j'"=="lw2w_ft" local depvar "Log wages"

eststo clear	
foreach g in   usb  {
				eststo : reghdfe `j'_`g'   SC_frac             ///
 						shift_share_sample_fb shift_share_sample_usb ///
			  [aweight=pop2000] if year<2015  & tradable2 ==1 ,   vce (cluster cpuma0010) absorb(  year cpuma0010 i.cpuma0010#c.year ) 
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
foreach g in  usb  {
				eststo : reghdfe `j'_`g'   SC_frac             ///
 						shift_share_sample_fb shift_share_sample_usb ///
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




 
 
 
 
 
 
 
 
 
