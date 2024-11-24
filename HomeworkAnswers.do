* STATA do-file
* Homework 2024-11-25

* Open crime data 
 use "\\micro.intra\mydocs\mydocs\haldan\my documents\InBox\castle.dta"

* Always look at the data 

* QUESTION 1. 
******************************************************************
* - Use the information in 'post' to tabulate the treated years
tab year if post == 1 

* - Use the information in sid and post to describe the number of states that is part of the treated group.
levelsof(state) if post == 1
disp r(r)
	* disp r(levels)
line l_homicide year if state == "Florida"

* - create the variable 'count_treated_obs'
egen count_treated_obs = sum(post), by(sid)
tab count_treated_obs

* - create the 'never_treated' variabel
gen never_treated = count_treated_obs == 0

* - create the 'avg_untreated' variabel that takes the average homidice rate across states year-by-year
egen avg_untreated = mean(l_homicide) if never_treated == 1, by(year)

* - plot the average homicide rate for non-treated states compared with florida in the same plot
twoway (line avg_untreated year if state == "Utah")(line l_homicide year if state == "Florida")

	* Normalize of put on different y-axis is a bonus
twoway (line avg_untreated year if state == "Utah")(line l_homicide year if state == "Florida", yaxis(2))
 *: Pre-trends are diverging

* Test the linearity of the pretrends
gen FloridaDummy = state == "Florida"
replace avg_untreated = l_homicide if state == "Florida"
reghdfe avg_untreated c.year##c.FloridaDummy if year <2006, absorb(sid year) vce(cluster sid) 


* QUESTION 2.
************************************************************************
* - Estimate the DiD for the castle doctrine in Florida

reghdfe l_homicide post if state == "Florida" | never_treated == 1, absorb(sid year) vce(cluster sid) 

gen PostTreatment = year>=2006 & year !=.

reghdfe l_homicide i.FloridaDummy i.PostTreatment i.FloridaDummy#i.PostTreatment if state == "Florida" | never_treated == 1, absorb(sid year) vce(cluster sid) 


* The homicide rate increased by 0.14*100=14 percent in Florida as a consequence of the reform.

* - Eventstudy interact
 eventstudyinteract l_homicide lead9 lead8 lead7 lead6 lead5 lead4 lead3 lead2 lag0 lag1 lag2 lag3 lag4 lag5, absorb(sid year) cohort(treatment_date) control_cohort(never_treated) vce(cluster sid)

matrix C = e(b_iw)
mata st_matrix("A",sqrt(diagonal(st_matrix("e(V_iw)"))))
matrix C = C \ A'
matrix list C
coefplot matrix(C[1]), se(C[2]) vertical
