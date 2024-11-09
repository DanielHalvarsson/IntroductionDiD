
********************************************************************************
* EVENTSTUDYINTERACT for different periods (unbalanced):
********************************************************************************

gen t = year-treatment_year  

* Generate dynamic treatment dummies 		

* Pretreatment
forvalues k = 9(-1)2 {
	cap drop g_`k'
	gen g_`k' = t == -`k'
}

* Treatment and posttreatment 
forvalues k = 0/7{
	cap drop g`k'
	gen g`k' = t == `k'
}
	
****  Dummy for control group (2015)
cap drop last_treated_cohort_2015
gen last_treated_cohort_2015 = 1 if treatment_year >= 2015 & treatment_year !=.
replace last_treated_cohort_2015 = 0 if last_treated_cohort_2015 != 1 & treated == 1

******************************************************
* Program
eventstudyinteract Y g_* g0-g6 if year<2015,  cohort(treatment_year) control_cohort(last_treated_cohort_2015) absorb(OrgLopNr year) vce(cluster OrgLopNr) 

* Vizualize results
matrix C = e(b_iw)
mata st_matrix("A",sqrt(diagonal(st_matrix("e(V_iw)"))))
matrix A = A'
matrix C = (C[1,1..8],J(1,1,0),C[1,9..15]) \ (A[1,1..8],J(1,1,0),A[1,9..15])
mat coln C = "t=-9" "t=-8" "t=-7" "t=-6" "t=-5" "t=-4" "t=-3" "t=-2" "t=-1" "t=0" "t=1" "t=2" "t=3" "t=4" "t=5" "t=6" 
mat list C

re_define
cd "\\Mfso03\oru_esi$\Halvarsson\Results\Revise\"
outreg2  using Revise, append tex nocons

coefplot matrix(C[1]), se(C[2]) vertical yline(0) plotregion(color(white))  graphregion(color(white)) 
*
