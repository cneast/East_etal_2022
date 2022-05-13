library(readstata13)
library(ggplot2)
library(did) # Callaway & Sant'Anna

SC_data <- data.frame(read.dta13("/Users/chloeeast/Dropbox/Skills_demand_and_immigration/Data/SCemp_forR.dta")) #remember to change all the backslashes if necessary
#SC_data <- data.frame(read.dta13("/Users/chloeeast/Dropbox/Skills_demand_and_immigration/Data/SCwages_forR.dta")) #remember to change all the backslashes if necessary

# Estimating the effect on log(homicide)
atts <- att_gt(yname = "efixpop_usb_detrend_cz", # and efixpop_fb_ls_detrend_cz efixpop_usb_detrend_cz lw2w_ft_fb_ls_detrend_cz lw2w_ft_usb_detrend_cz
               tname = "year", # time variable
               idname = "cpuma0010", # id variable
               gname = "effyear", # first treatment period variable
               data = SC_data, # data
               xformla = NULL, # no covariates
               #xformla = ~shift_share_sample, # with covariates
               est_method = "reg", # "dr" is doubly robust. "ipw" is inverse probability weighting. "reg" is regression
               control_group = "notyettreated", # set the comparison group which is either "nevertreated" or "notyettreated" 
               weightsname = "pop2000",
               bstrap = TRUE, # if TRUE compute bootstrapped SE
               biters = 1000, # number of bootstrap iterations
               print_details = FALSE, # if TRUE, print detailed results
               clustervars = "cpuma0010", # cluster level
               panel = TRUE) # whether the data is panel or repeated cross-sectional

# Aggregate ATT
agg_effects <- aggte(atts, type = "group")
summary(agg_effects)

# Group-time ATTs
summary(atts)

# Plot group-time ATTs
ggdid(atts)

# Event-study
agg_effects_es <- aggte(atts, type = "dynamic")
summary(agg_effects_es)

# Plot event-study coefficients
ggdid(agg_effects_es, ylim=c(-3.5,1.5))+xlim(-4,2) #change y-axis and x-axis here
