clear

/*
import delimited "\\micro.intra\mydocs\mydocs\haldan\my documents\InBox\organ_donationsANSI.txt", clear
*/

********************************************************
* PART 1: Load data and basic DiD analysis
********************************************************

*********************************************************
* Load data
*********************************************************
* Option 1: Opened saved data
* Change "C:\data\" to the correct path.
use "C:\data\organ_donations.dta", clear

* Option 2: Load data from the web
use https://github.com/DanielHalvarsson/IntroductionDiD/tree/main/data/organ_donations.dta, clear

* Look at the data
browse *

*********************************************************
* Data cleaning
*********************************************************
// Make sure to look at the data after each operation 

* 0. Let's start by browsing the data
br *

* 1. Fix the time variable: gen countvar quarter_num -> 1-6
tab quarter

gen quarter_num = .
replace quarter_num = 1 if quarter == "Q42010"
replace quarter_num = 2 if quarter == "Q12011"
replace quarter_num = 3 if quarter == "Q22011"  
replace quarter_num = 4 if quarter == "Q32011" // First quarter of California being treated (July, 2011)
replace quarter_num = 5 if quarter == "Q42011"
replace quarter_num = 6 if quarter == "Q12012"

* 2. Define value label 
label define quarter_label  1 "Q42010" 2 "Q12011" 3 "Q22011" 4 "Q32011" 5 "Q42011" 6 "Q12012", replace

* 3. label values in quarter_num
label values quarter_num quarter_label

tab quarter_num

* For removing labels:
* label values quarter_num .

* 4. Encode a numeric id variable: state_id
encode state, gen(state_id)

// Why not encode quarter directly?

* 5. Set panel structure: state_id quarter_num
xtset state_id quarter_num

* 6. Plotting the data

* 6.1. Plot all the sates
twoway scatter rate quarter_num, msiz(small) m(Oh) mc(gray) legend(label(1 "All states"))

/*
	* How the pros do it: Add "jitter" for better visuals
	gen quarter_jitter = quarter_num + runiform(-0.2,0.2)

	twoway scatter rate quarter_jitter, msiz(small) m(Oh) mc(gray) legend(label(1 "All states"))
*/

* 6.2. Plot with the label
twoway scatter rate quarter_num, msiz(small) m(Oh) mc(gray) legend(label(1 "All states")) xlabel(, valuelabel angle(45)) xtitle("") ytitle("Organ Donation Rate")

* 6.3. Plot with Californian rates displayed along with treatment time
twoway (scatter rate quarter_num if state != "California", msiz(small) m(Oh) mc(gray) legend(label(1 "Other states")))(scatter rate quarter_num if state == "California", msiz(large) m(O) mc(red) legend(label(2 "California"))), xlabel(, valuelabel angle(45)) xtitle("") ytitle("Organ Donation Rate") xline(3.7)


*********************************************************
* Setting up the analysis
* Create DiD variables 
*********************************************************
// Did the policy in California have a causal effect on the organ donation rate in California?

// To begin answering that question, we need to create some variable  


* 1. TreatedGroup: A Dummy variable for the treated group, i.e. California
gen TreatedGroup = state == "California" 

* 2. AfterTreatment: A Dummy variable for post treatment
gen AfterTreatment = inlist(quarter_num, 4, 5, 6)

* 3. TreatedObs: Dummy variable for the treated group during the treated periods 
gen TreatedObs = state == "California" & inlist(quarter_num, 1, 2, 3)

// Important to check that the variables capture what we intend
* AfterTreatment has the correct quarter
tab quarter_num if AfterTreatment == 1
tab quarter_num if AfterTreatment == 0
* TreatedGroup is given by California
tab state if TreatedGroup == 1
* California is not part of the Untreated group
count if state == "California" & TreatedGroup == 0 
// California is not part of the control group

	
*********************************************************
* Calculate the Difference-in-Difference
*********************************************************

* 1. Lets calculate the different means of the treated and untreated group, before an after treatment. 

// For simplicity we collect the values in new variables	

* Treated group before treatment (avg_treated_before)
sum rate if TreatedGroup == 1 & AfterTreatment == 0
gen avg_treated_before = r(mean)
* Treated group after treatment (avg_treated_after) 
sum rate if TreatedGroup == 1 & AfterTreatment == 1
gen avg_treated_after = r(mean)
* Untreated group before treatment (avg_untreated_before)
sum rate if TreatedGroup == 0 & AfterTreatment == 0
gen avg_untreated_before = r(mean)
* Untreated group after treatment (avg_untreated_after)
sum rate if TreatedGroup == 0 & AfterTreatment == 1
gen avg_untreated_after = r(mean)

// browse and look at the data

br* 

* 2. Now, we just calculate the DiD 
gen DiD_2x2 = (avg_treated_after - avg_treated_before) - (avg_untreated_after - avg_untreated_before)

sum DiD_2x2

* 3.  What happened here?
* Let's have a look 
* Treated difference before and after treatment
sum avg_treated_after avg_treated_before 
disp avg_treated_after-avg_treated_before 


* Untreated difference before and after treatment
sum avg_untreated_after avg_untreated_before
disp avg_untreated_after-avg_untreated_before 

************************************************************
quietly{
* Not part of the excercise 
* To produce the plot for the slides showing the first differences for the respective group 
preserve
	ren avg_treated_after avg_treated_1
	ren avg_treated_before avg_treated_0

	ren avg_untreated_after avg_untreated_1
	ren avg_untreated_before avg_untreated_0
	keep avg* 

	keep if _n <= 1
	gen id = _n
	reshape long avg_treated_ avg_untreated_, i(id) j(timing)
	drop id
	list *
	replace timing = timing  
	* twoway (line avg_treated_ timing, legend(label(1 Avg. treated (Diff: -.0085))) lw(thick))(line avg_untreated_ timing, legend(label(2 Avg. untreated (Diff: .0139))) lw(thick)), xlabel(0 1) xtitle("Before treatment = 0 and After treatment = 1")
restore
}
***********************************************************


* 4. Alternative interpretation: subract the time effect
gen DiD = avg_treated_after - (avg_untreated_after - avg_untreated_before) - avg_treated_before

disp avg_treated_after
disp avg_untreated_after - avg_untreated_before  // Estimated time effect 
disp avg_treated_after - (avg_untreated_after - avg_untreated_before) // Subrtact it from the treated group
disp (avg_treated_after - (avg_untreated_after - avg_untreated_before) - avg_treated_before) // Se what remains from the treated group when compared to the before period -> DiD 

sum DiD


********************************************************
* PART 2: DiD and regression analysis 
********************************************************

*********************************************************************** TWFE models
* Simple 2x2 Difference-in-Difference
**********************************************************************

* Model 1.A. Regression with interactions
reg rate i.TreatedGroup i.AfterTreatment i.TreatedGroup#i.AfterTreatment, vce(cluster state)

* Let's interprete the coefficients
* Why DiD?

* Model 1.B. Equivalent specification but with fixed effects
reghdfe rate i1.TreatedGroup#i1.AfterTreatment, absorb(TreatedGroup AfterTreatment) vce(cluster state)

* Model 2. Regression with fixed effects for State and Quarter
reghdfe rate i1.TreatedGroup#i1.AfterTreatment, absorb(state quarter) vce(cluster state)



********************************************************
* PART 3: Robustnes analysis
*******************************************************

**********************************************************************
* Plot the pretrends: 
**********************************************************************
egen pretrend_treated   = mean(rate) if TreatedGroup == 1, by(quarter_num)
egen pretrend_untreated = mean(rate) if TreatedGroup == 0, by(quarter_num)

egen tag_group_period = tag(TreatedGroup quarter_num) 

twoway (line pretrend_treated quarter_num if quarter_num <= 3 & tag_group_period, legend(label(1 "Pre-trend California")) ytitle("", axis(1)))(line pretrend_untreated quarter_num if quarter_num <= 3 & tag_group_period == 1, legend(label(2 "Pre-trend Other states (2nd Y-axis)")) yaxis(2) ytitle("", axis(2))), xlabel(1 2 3) xtitle("Pre-treatment quarters") 

**********************************************************************
* Test for differences in pretrends
**********************************************************************
reghdfe rate c.quarter_num c.quarter_num#i.TreatedGroup if quarter_num <= 3 , absorb(TreatedGroup) vce(cluster state)


**********************************************************************
* Placebo tests
**********************************************************************
gen FakeTreat1 = state == "California" & inlist(quarter, "Q12011", "Q22011")
gen FakeTreat2 = state == "California" & quarter == "Q22011"

* if time<=3 gives the quarters: Q42010, Q12011 and Q22011.

reghdfe rate FakeTreat1 if quarter_num<=3, absorb(state quarter) vce(cluster state)
reghdfe rate FakeTreat2 if quarter_num<=3, absorb(state quarter) vce(cluster state)
**********************************************************************


********************************************************
* PART 3: Dynamic DiD regression 
*******************************************************


*******************************************************
* DiD with dynamic treatment effect (event study)
*******************************************************
tab quarter_num

* 1. Create time dummy variables
foreach k of numlist 1 2 4 5 6 {
	// Skip the period before treatment: relative_year == -1
   gen D`k' = quarter_num == `k'
}

* 2. Preferred specification for dynamic DID 
reghdfe rate i1.TreatedGroup#(i1.D1 i1.D2 i1.D4 i1.D5 i1.D6), absorb(state quarter_num) vce(cluster state)

* Alternative but equivalent specification
*reghdfe rate i.TreatedGroup##ib3.quarter_num, absorb(state quarter_num) vce(cluster state)


* 3. Create vector of estimates and s.e. to plot the results
* Collect estimates and standard deviations (version 1 - matrix)
mat B = e(b) // beta vector is saved as a matrix in e(b)
mat list B	 
mat beta = B[1,1..5] // Select the estimates of interest
mat beta = B[1,1..2],J(1,1,0),B[1,3..5] // We need to add a zero to the vector manually

* Retrieve covariance matrix
mat V    = e(V)  // Variance-covariance matrix is stored under e(V)
mat v = V[1..5,1..5] // Select the entires of interest
mat list v
cap mat drop se_temp

* Loop over the diagonal of "v" and take square roots to get the standard deviation 
forval i = 1/5{
	mat se_temp = nullmat(se_temp), sqrt(v[`i',`i'])
}

mat se = se_temp[1,1..2],J(1,1,0),se_temp[1,3..5] // Same here, we need to add a zero to the vector manually.
mat list beta
mat list se


* Plot version 1              
mat M = beta\se
mat list M

mat coln M = "Q42010" "Q12011" "Q13011" "Q32011" "Q42011" "Q12012"

coefplot matrix(M[1]), se(M[2]) vertical yline(0) plotregion(color(white))  graphregion(color(white)) 


*******************************************************
* Collect estimates and standard deviations (version 2 - no matrix)

gen time_plot = _n if _n <=6

cap drop beta se
gen beta = .
gen se   = .

foreach i of numlist 1 2 4 5 6{
	replace beta = _b[1.TreatedGroup#1.D`i']  if time_plot == `i'
	replace se   = _se[1.TreatedGroup#1.D`i'] if time_plot == `i'
}
br time_plot beta se 
replace beta = 0 if time_plot == 3
replace se = 0 if time_plot == 3

* Plot version 2
gen ci_top = beta + 1.96*se
gen ci_bottom = beta - 1.96*se
br beta se ci_top ci_bottom

label val time_plot quarter_label

twoway (scatter beta time_plot)(rcap ci_top ci_bottom time_plot), xlabel(, valuelabel) yline(0) xtitle("95% confidence interval shown")


********************************************************
* PART 4: Dynamic DiD regression 
*******************************************************



********************************************************************
* DiD with a roll out design. Sun and Abrahams (2020)


use "\\micro.intra\mydocs\mydocs\haldan\my documents\InBox\nlswork.dta", clear

*Data over young Women 14-26 years of age in 1968 observed for 1988, when they first joined the union.

* The treatment groups corresponds to the cohort that joined the union the first time during the same year.

* All years an individual (idcode) is a union member: union_year
gen union_year = year if union == 1

* Let's pick out the earliest year someone is union member.: first_union
egen first_union = min(union_year), by(idcode)

* For the control group we take women that never unionized: never_union
gen never_union = first_union == .
tab never_union

* With first union year, we can normalize time relative to treatment, which occurs at zero: relative_year
gen relative_year = year - first_union

* The distribution of treatment periods
tab relative_year

* For each relative relative year (leading and lagging), we need to create a dummy variable, which is quite a few.

* Separate dummy variables for leading and lagging periods:
forvalues k = 18(-1)2 {
	// Skip the period before treatment: relative_year == -1
   gen g_`k' = relative_year == -`k'
}
forvalues k = 0/18 {
	 gen g`k' = relative_year == `k'
}

* Sun and Abrahams (2020) estimator
eventstudyinteract ln_wage g_* g0-g18, absorb(idcode year) cohort(first_union) control_cohort(never_union) vce(cluster idcode)
		
* Collect estimates for plotting
matrix C = e(b_iw)
mata st_matrix("A", sqrt(diagonal(st_matrix("e(V_iw)"))))
matrix A = A'	
matrix M = C\A 	
coefplot matrix(M[1]), se(M[2]) vertical

* Make assumption on the pretrend values 
cap drop g_l4
gen g_l4 = relative_year <= 4
  
eventstudyinteract ln_wage g_* g0-g18, absorb(idcode year) cohort(first_union) control_cohort(never_union) vce(cluster idcode)
		
matrix C = e(b_iw)
mata st_matrix("A", sqrt(diagonal(st_matrix("e(V_iw)"))))
matrix A = A'	
matrix M = C\A 	
coefplot matrix(M[1]), se(M[2]) vertical xline(17.5) xlabel(, angle(90))

matrix b = e(b_iw)
matrix V = e(V_iw)
ereturn post b V
lincom g_l4 + g_3 + g_2

* The point estimates for the pretrend are jointly significant, which likely means problem for a causal interpretation of the post treatment effect, in this case the wage affect attributed to union membership among union members.

* We can look at the TWFE model and compare

*******************************************************************
* Compare with TWFE
*******************************************************************
gen TreatedGroup = -1*(never_union) + 1

gen TreatmentCount = relative_year + 19
tab TreatmentCount
drop if TreatmentCount <1

tab relative_year if TreatmentCount == 18

reghdfe ln_wage g_l4 g_3 g_2 g0-g18, absorb(idcode year) vce(cluster idcode)

lincom g_l4 + g_3 + g_2

matrix C = e(b)
mat C = C[1,1..22]
mat V = e(V)
mat V = V[1..22,1..22]
mata st_matrix("A", sqrt(diagonal(st_matrix("V"))))
matrix A = A'	
matrix TWFE = C\A 	
coefplot matrix(TWFE[1]), se(TWFE[2]) vertical
