clear 
clear matrix 
set mem 500m 
set more off 
clear mata
set matsize 11000
set maxvar 11000 


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
********************************************************************* 
 
macro define DATA     "$dir/Skills_demand_and_immigration/Data/" 
global resultsfolder = "$user/Submission/JOLE/Accepted files/tab_fig"
macro define ENFOR     "$dir/Skills_demand_and_immigration/Data/" 

/*ssc install spmap
ssc install shp2dta
ssc install mif2dta*/
use "$DATA/County Level/287g_SC_EVerify_5_13_22.dta" 

//shp2dta using cb_2016_us_county_5m,  database(usdb) coordinates(uscoord) genid(id) replace //Translates census map data into a dta file
rename statefip STATEFIP
rename countyfip COUNTYFIP
merge m:1 STATEFIP COUNTYFIP using $DATA/usdb //Merges Secure Communities data with map data
drop if STATEFP == "02" | STATEFP == "15" //Drops data for Alaska & Hawaii
drop if STATEFIP >= 60 //Drops data for US Territories

tab year jail287g if month==1, m

keep if month==12

drop if STATEFIP==2 | STATEFIP==15

forvalues n = 2005/2014 {
preserve
keep if year==`n' & month==12
duplicates drop id, force
foreach pol in SC {
if "`pol'"=="jail287g" local policy "Jail 287(g) Model"
if "`pol'"=="task287g" local policy "Task Force 287(g) Model"
if "`pol'"=="SC" local policy "Secure Communities"
	sum `pol'
	if r(mean)>0 & year<2014 {
	replace `pol'=2 if _merge~=3
	drop if STATEFIP==2 | STATEFIP==15
	spmap `pol' using $ENFOR/uscoord, id(id) fcolor(Blues)  clmethod(custom) clbreaks(-1 0 1 2 3 ) ocolor(gray) osize(*.25) ///
	legend(off    )
	graph export "$resultsfolder/`pol'_`n'.png", replace
	}
	if r(mean)>0 & year==2014 {
	replace `pol'=2 if _merge~=3
	spmap `pol' using $ENFOR/uscoord, id(id) fcolor(Blues)  clmethod(custom) clbreaks(-1 0 1 2 3 ) ocolor(gray) osize(*.25)  ///
	legend(size(*2) order(3 )   label(3 "`policy'")  )
	graph export "$resultsfolder/`pol'_`n'.png", replace
	}
}
restore
}
 
