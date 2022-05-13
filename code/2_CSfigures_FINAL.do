/***********************************************************************
PROGRAM:	2_CSfigures_FINAL.do 
PURPOSE:    Uses the estimates from the Distributed Lag Model (run in 1_EHLMV_results_emp_FINAL.do and 1_EHLMV_results_wages_FINAL.do)
			and the Callaway and Sant'Anna model (run in SC_CAEst_code.R)
CREATES:	Appendix Figure A2
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
global resultsfolder = "$user/Submission/JOLE/Accepted files/tab_fig"
global resultslog ="Results/Logs"


local  today = c(current_date)
cap log using "$resultslog/1_EHLMV_results`today'.log", replace

set more off
set scheme modern


set obs 6
gen event_time = _n
replace event_time = event_time - 4

gen beta_cs = .
replace beta_cs =0.1322      if event_time==-3
replace beta_cs =-0.0517        if event_time==-2
replace beta_cs =-0.5721         if event_time==-1
replace beta_cs = -0.2733       if event_time==0
replace beta_cs = -0.8753        if event_time==1
replace beta_cs = -2.7624       if event_time==2

gen se_cs = .
replace se_cs =  0.1432           if event_time==-3
replace se_cs =  0.1532                if event_time==-2
replace se_cs =  0.1783               if event_time==-1
replace se_cs =  0.1168              if event_time==0
replace se_cs =  0.3002               if event_time==1
replace se_cs =  0.3612              if event_time==2

gen ci_top = beta_cs+se_cs*1.96
gen ci_bot = beta_cs-se_cs*1.96




gen beta_dd = .
replace beta_dd =  0.394        if event_time==-3
replace beta_dd =   0.042           if event_time==-2
replace beta_dd = 0       if event_time==-1
replace beta_dd =  0.104          if event_time==0
replace beta_dd =    -0.175          if event_time==1
replace beta_dd =     0.213           if event_time==2

gen se_dd = .
replace se_dd =   (0.321)            if event_time==-3
replace se_dd =    (0.195)                  if event_time==-2
replace se_dd = 0             if event_time==-1
replace se_dd =     (0.237)                 if event_time==0
replace se_dd =      (0.438)           if event_time==1
replace se_dd =   (0.739)                  if event_time==2

gen ci_top_dd = beta_dd+se_dd*1.96
gen ci_bot_dd = beta_dd-se_dd*1.96


gen event_time2 = event_time+.15

twoway (scatter  beta_cs event_time2, msymbol(triangle) color(gray))  (rcap  ci_top ci_bot event_time2, msymbol(triangle) lcolor(gray) lpattern(dash)) ///
 (scatter  beta_dd event_time, color(black))  (rcap  ci_top_dd ci_bot_dd event_time, lcolor(black) lpattern(dash)), ///
 xline(-0.5) xtitle("Event Time (years)") ytitle("Beta") ///
 legend(order(1 3) label(1 "Callaway and Sant'Anna" ) label(3  "Distributed Lag") position(6) rows(1)) yline(0) 
graph export "$resultsfolder/cs_scfrac0_efixpop_usb_overlaydd.png", replace  height(600) width(800)


 
 




drop beta_cs se_cs

gen beta_cs = .
replace beta_cs =0.1595             if event_time==-3
replace beta_cs =-0.0482                if event_time==-2
replace beta_cs =-0.0482                  if event_time==-1
replace beta_cs = -0.1361                 if event_time==0
replace beta_cs = -0.2722               if event_time==1
replace beta_cs = -0.4987                 if event_time==2

gen se_cs = .
replace se_cs = 0.0462                     if event_time==-3
replace se_cs =  0.0638                             if event_time==-2
replace se_cs = 0.0658                          if event_time==-1
replace se_cs = 0.0593                   if event_time==0
replace se_cs = 0.1870                               if event_time==1
replace se_cs = 0.3349                        if event_time==2

drop ci_top ci_bot
gen ci_top = beta_cs+se_cs*1.96
gen ci_bot = beta_cs-se_cs*1.96





drop beta_dd se_dd ci_top_dd  ci_bot_dd
gen beta_dd = .
replace beta_dd = 0.064         if event_time==-3
replace beta_dd =  0.120             if event_time==-2
replace beta_dd = 0       if event_time==-1
replace beta_dd =  -0.261        if event_time==0
replace beta_dd =    -0.456            if event_time==1
replace beta_dd =   -0.774         if event_time==2

gen se_dd = .
replace se_dd =    (0.216)         if event_time==-3
replace se_dd = (0.118)                 if event_time==-2
replace se_dd = 0             if event_time==-1
replace se_dd =  (0.134)                 if event_time==0
replace se_dd =    (0.239)              if event_time==1
replace se_dd =  (0.386)                 if event_time==2

gen ci_top_dd = beta_dd+se_dd*1.96
gen ci_bot_dd = beta_dd-se_dd*1.96

cap drop event_time2
gen event_time2 = event_time+.15

twoway (scatter  beta_cs event_time2, msymbol(triangle) color(gray))  (rcap  ci_top ci_bot event_time2, msymbol(triangle) lcolor(gray) lpattern(dash)) ///
 (scatter  beta_dd event_time, color(black))  (rcap  ci_top_dd ci_bot_dd event_time, lcolor(black) lpattern(dash)), xline(-0.5) xtitle("Event Time (years)") ytitle("Beta") ///
 legend(order(1 3) label(1 "Callaway and Sant'Anna" ) label(3  "Distributed Lag") position(6) rows(1)) yline(0) 
graph export "$resultsfolder/cs_scfrac0_efixpop_fb_ls_overlaydd.png", replace  height(600) width(800)



 
 









drop beta_cs se_cs

gen beta_cs = .
replace beta_cs =0.0018             if event_time==-3
replace beta_cs =-0.0004                if event_time==-2
replace beta_cs =0.0001                  if event_time==-1
replace beta_cs = -0.0066               if event_time==0
replace beta_cs = -0.0217             if event_time==1
replace beta_cs = -0.0207                if event_time==2

gen se_cs = .
replace se_cs =0.0018                      if event_time==-3
replace se_cs =0.0017                             if event_time==-2
replace se_cs = 0.0026                          if event_time==-1
replace se_cs = 0.0025                    if event_time==0
replace se_cs = 0.0031                                if event_time==1
replace se_cs = 0.0047                          if event_time==2

drop ci_top ci_bot
gen ci_top = beta_cs+se_cs*1.96
gen ci_bot = beta_cs-se_cs*1.96


drop beta_dd se_dd ci_top_dd  ci_bot_dd
gen beta_dd = .
replace beta_dd =-.004      if event_time==-3
replace beta_dd = -.001           if event_time==-2
replace beta_dd = 0       if event_time==-1
replace beta_dd =   -.013          if event_time==0
replace beta_dd =  -.013         if event_time==1
replace beta_dd =  -.027          if event_time==2

gen se_dd = .
replace se_dd =.007           if event_time==-3
replace se_dd = .005                if event_time==-2
replace se_dd = 0             if event_time==-1
replace se_dd =   .004                 if event_time==0
replace se_dd =   .008            if event_time==1
replace se_dd =  .013               if event_time==2

gen ci_top_dd = beta_dd+se_dd*1.96
gen ci_bot_dd = beta_dd-se_dd*1.96

cap drop event_time2
gen event_time2 = event_time+.15

twoway (scatter  beta_cs event_time2, msymbol(triangle) color(gray))  (rcap  ci_top ci_bot event_time2, msymbol(triangle) lcolor(gray) lpattern(dash)) ///
 (scatter  beta_dd event_time, color(black))  (rcap  ci_top_dd ci_bot_dd event_time, lcolor(black) lpattern(dash)), xline(-0.5) xtitle("Event Time (years)") ytitle("Beta")  yline(0)  ///
  legend(order(1 3) label(1 "Callaway and Sant'Anna" ) label(3  "Distributed Lag") position(6) rows(1)) yline(0) 
graph export "$resultsfolder/cs_scfrac0_wage_usb_overlaydd.png", replace  height(600) width(800)








drop beta_cs se_cs

gen beta_cs = .
replace beta_cs =  -0.0121                if event_time==-3
replace beta_cs =0.0098                      if event_time==-2
replace beta_cs =-0.0024                     if event_time==-1
replace beta_cs =  -0.0195                    if event_time==0
replace beta_cs = -0.0464                    if event_time==1
replace beta_cs = -0.0655                 if event_time==2

gen se_cs = .
replace se_cs = 0.0082                          if event_time==-3
replace se_cs = 0.0116                                 if event_time==-2
replace se_cs = 0.0132                                if event_time==-1
replace se_cs = 0.0126                           if event_time==0
replace se_cs = 0.0258                                     if event_time==1
replace se_cs = 0.0345                               if event_time==2

drop ci_top ci_bot
gen ci_top = beta_cs+se_cs*1.96
gen ci_bot = beta_cs-se_cs*1.96

drop beta_dd se_dd ci_top_dd  ci_bot_dd
gen beta_dd = .
replace beta_dd =-0.007     if event_time==-3
replace beta_dd =-0.004          if event_time==-2
replace beta_dd = 0       if event_time==-1
replace beta_dd =  -0.034        if event_time==0
replace beta_dd =  -.027         if event_time==1
replace beta_dd = -.055        if event_time==2

gen se_dd = .
replace se_dd =.022           if event_time==-3
replace se_dd = .018              if event_time==-2
replace se_dd = 0             if event_time==-1
replace se_dd =  .023               if event_time==0
replace se_dd =   .031            if event_time==1
replace se_dd = .064             if event_time==2

gen ci_top_dd = beta_dd+se_dd*1.96
gen ci_bot_dd = beta_dd-se_dd*1.96

cap drop event_time2
gen event_time2 = event_time+.15

twoway (scatter  beta_cs event_time2, msymbol(triangle) color(gray))  (rcap  ci_top ci_bot event_time2, msymbol(triangle) lcolor(gray) lpattern(dash)) ///
 (scatter  beta_dd event_time, color(black))  (rcap  ci_top_dd ci_bot_dd event_time, lcolor(black) lpattern(dash)), xline(-0.5) xtitle("Event Time (years)") ytitle("Beta")  yline(0)  ///
  legend(order(1 3) label(1 "Callaway and Sant'Anna" ) label(3  "Distributed Lag") position(6) rows(1)) yline(0) 
graph export "$resultsfolder/cs_scfrac0_wage_fb_ls_overlaydd.png", replace  height(600) width(800)



 
 
 
 
 
 
 
 
 
 
 
