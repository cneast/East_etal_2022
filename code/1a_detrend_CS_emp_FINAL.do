/***********************************************************************
PROGRAM:	1a_detrend_CS_emp_FINAL.do 
PURPOSE:    Detrend the ACS Employment Data to Prepare for Callaway and Sant'Anna (2021) Estimation in R
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

*********************************************************************
/* DIRECTORY AND FILE NAMES: */ 
clear all

	if c(username)=="chloeeast" { 		// for Chloe's computer
			global user  "/Users/chloeeast/Dropbox/Skills_demand_and_immigration/" 
		}
		else{
			if c(username)=="Chloe" { 		// for Chloe's laptop
				global user  "/Users/Chloe/Dropbox/Skills_demand_and_immigration/" 
 
			}
			}
		else{
			if c(username)=="philipluck" { 		// for Phil's computer
				global user  "/Users/philipluck/Dropbox/Research/Skills_demand_and_immigration/" 
 
			}
			}
					else{
			if c(username)=="hmansour" { 		// for Hani's desktop
				global user  "\Users\hmansour\Dropbox\Skills_demand_and_immigration/" 
 
			}
			}
			
			else {
			if c(username)=="annielauriehines" { 	// for Annie's laptop
				global user  "/Users/annielauriehines/Dropbox/Skills_demand_and_immigration/"		
						}
						}
*********************************************************************


*set directory
cd "$user"

global data= "Data"
global resultslog ="Results/Logs"
use "$data/EHLMV_forCS.dta"

*Generate the effyear variable for CA Estimator
*for first year that SC_frac > 0

drop if SC_frac==.
gen SC_dummy = 0
replace SC_dummy=1 if SC_frac>0 

gen cal_year = year if SC_dummy==1

bysort cpuma0010: egen effyear = min(cal_year)


***Detrend outcome variables by cohort;
#delimit;
gen efixpop_usb_detrend =. ;
global effyear " 2008 2009 2010 2011 2012 2013 ";

#delimit;
foreach effyear of global effyear {;
reg efixpop_usb year [aw=pop2000] if effyear == `effyear' & year < `effyear' ; 
replace efixpop_usb_detrend = efixpop_usb - _b[year]*year - _b[_cons] if effyear==`effyear';
};

#delimit;
gen efixpop_fb_ls_detrend =. ;
foreach effyear of global effyear {;
reg efixpop_fb_ls year [aw=pop2000] if effyear == `effyear' & year < `effyear' ; 
replace efixpop_fb_ls_detrend = efixpop_fb_ls - _b[year]*year - _b[_cons] if effyear==`effyear';
};

***Detrend outcome variables by cz;
#delimit;
gen efixpop_usb_detrend_cz =. ;
levelsof cpuma0010, local(levels);
foreach l of local levels {;
reg efixpop_usb year [aw=pop2000] if cpuma0010 == `l' & year < effyear ; 
replace efixpop_usb_detrend_cz = efixpop_usb - _b[year]*year - _b[_cons] if cpuma0010==`l';
};

#delimit;
gen efixpop_fb_ls_detrend_cz =. ;
levelsof cpuma0010, local(levels);
foreach l of local levels {;
reg efixpop_fb_ls year [aw=pop2000] if cpuma0010 == `l' & year < effyear ; 
replace efixpop_fb_ls_detrend_cz = efixpop_fb_ls - _b[year]*year - _b[_cons] if cpuma0010==`l';
};

save "$user/Data/SCemp_forR.dta", replace;
