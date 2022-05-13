/***********************************************************************
PROGRAM:	1a_detrend_CS_emp_FINAL.do 
PURPOSE:    Detrend the ACS Wage Data to Prepare for Callaway and Sant'Anna (2021) Estimation in R
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

use "$data/EHLMV_forCS_wages.dta"

drop if SC_frac==.
gen SC_dummy = 0
replace SC_dummy=1 if SC_frac>0 

gen cal_year = year if SC_dummy==1

bysort cpuma0010: egen effyear = min(cal_year)

*for first year that SC_frac > 0.5
gen SC_dummy5 = 0
replace SC_dummy5=1 if SC_frac>0.5 

gen cal_year5 = year if SC_dummy5==1

bysort cpuma0010: egen effyear5 = min(cal_year5)

*for first year that SC_frac > 0.75
gen SC_dummy75 = 0
replace SC_dummy75=1 if SC_frac>0 

gen cal_year75 = year if SC_dummy75==1

bysort cpuma0010: egen effyear75 = min(cal_year75)


***Detrend outcome variables by cz;
*For lw2w_ft_fb_ls;
#delimit;
gen lw2w_ft_fb_ls_detrend_cz =. ;
levelsof cpuma0010, local(levels);
foreach l of local levels {;
cap reg lw2w_ft_fb_ls year [aw=pop2000] if cpuma0010 == `l' & year < effyear ; 
cap replace lw2w_ft_fb_ls_detrend_cz = lw2w_ft_fb_ls - _b[year]*year - _b[_cons] if cpuma0010==`l';
};

*For lw2w_ft_usb
#delimit;
gen lw2w_ft_usb_detrend_cz =. ;
levelsof cpuma0010, local(levels);
foreach l of local levels {;
reg lw2w_ft_usb year [aw=pop2000] if cpuma0010 == `l' & year < effyear ; 
replace lw2w_ft_usb_detrend_cz = lw2w_ft_usb - _b[year]*year - _b[_cons] if cpuma0010==`l';
};


keep year cpuma0010 lw2w_ft_usb_detrend_cz lw2w_ft_fb_ls_detrend_cz pop2000 effyear;
save "$user/Data/SCwages_forR.dta", replace;



