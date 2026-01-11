# Wyoming Assessment Data Expansion Research

## Package Status

**Current Scope:** Enrollment data only

---

## Assessment Data Availability

### Data Source
**Wyoming Department of Education (WDE)**
- **Assessment Reports:** https://edu.wyoming.gov/data/assessment-reports/
- **Assessment Portal:** https://wyoassessment.org/
- **Transparency - Assessment:** https://edu.wyoming.gov/transparency/assessment/

### Assessment Systems

**Current Assessments:**
- **WY-TOPP (Wyoming Test of Proficiency and Progress):**
  - Grades 3-10
  - Subjects: ELA, Mathematics, Science
- **WY-ALT:** Alternate assessment for students with significant cognitive disabilities
- **ACT:** Grade 11 (may be excluded per user instructions)
- **ACCESS:** English Learner proficiency assessment

**Historical Assessments:**
- **PAWS (Proficiency Assessments for Wyoming Students):** Replaced by WY-TOPP

**Historical Timeline:**
- **PAWS Era:** 2000s-2010s (exact years vary by subject)
- **Transition to WY-TOPP:** Implemented in late 2010s
- **Current:** WY-TOPP fully operational

---

## Data Access Analysis

### WDE Assessment Reports Page

**URL:** https://edu.wyoming.gov/data/assessment-reports/

**What It Provides:**
- Grade 11 ACT Averages
- Grades 3-10 WY-TOPP/WY-ALT Performance Results
- K-12 English Learner English Proficiency data
- Historical assessment data
- Downloadable data files

**Data Structure:**
- School, district, and state-level results
- Performance level breakdowns
- Student group disaggregations
- Multiple years of data

**File Formats:**
- Likely PDF reports and possibly Excel/CSV downloads
- Format verification needed

**Years Available:**
- WY-TOPP: Recent years (exact range requires verification)
- PAWS: Historical data may be archived
- ACT: Multiple years available

---

## Implementation Complexity

### Complexity Level: **MEDIUM**

**Advantages:**
1. **Centralized Data:** Single WDE assessment reports page
2. **Official Source:** Direct from WDE (no federal aggregation)
3. **Multiple Assessments:** WY-TOPP, ACT, ACCESS data available
4. **Regular Updates:** Annual data releases

**Challenges:**
1. **PAWS → WY-TOPP Transition:** Not directly comparable
2. **File Format Uncertainty:** May be PDF-heavy (difficult to parse)
3. **Small State:** Wyoming has small student population → extensive suppression
4. **Rural Districts:** Many small schools → data gaps due to FERPA

---

## Implementation Recommendations

### Phase 1: Data File Investigation

**Tasks:**
1. Navigate to WDE Assessment Reports page
2. Download sample WY-TOPP files
3. Check for Excel/CSV format (vs PDF only)
4. Document file structure and columns

**Time Estimate:** 2 hours

### Phase 2: Implementation Decision

**If Excel/CSV available:**
- Implement automated download functions
- Estimated effort: 10-12 hours

**If PDF only:**
- Recommend manual import approach
- Create `import_local_assessment()` function
- Estimated effort: 6-8 hours

---

## Data Quality Considerations

### Known Issues

1. **Small Population Suppression:**
   - Wyoming has ~93,000 students statewide
   - Many small schools and districts
   - Extensive FERPA suppression likely

2. **Rural Districts:**
   - Small enrollments → data gaps
   - Some entities may have no reportable data
   - Aggregation challenges

3. **Assessment Transition:**
   - PAWS → WY-TOPP: Different scales, not comparable
   - Transition year(s) may have data issues

---

## Next Steps

1. **Verify file formats** - Check for Excel/CSV vs PDF
2. **Download sample files** - Analyze structure
3. **Assess suppression** - Document privacy rules
4. **Decide implementation approach** - Automated vs manual

---

## References

- [WDE Assessment Reports](https://edu.wyoming.gov/data/assessment-reports/)
- [Wyoming Assessment Portal](https://wyoassessment.org/)
- [WDE Transparency - Assessment](https://edu.wyoming.gov/transparency/assessment/)
- [July 2025 Assessment Updates](https://edu.wyoming.gov/sups-memo/7-28-2025-assessment-updates-fall/)

---

**Last Updated:** 2025-01-11
**Research Status:** Complete - File format verification required
**Recommended Next Phase:** Download and analyze WDE assessment file formats (2 hours)
**Critical Unknown:** Whether data is available in machine-readable formats (Excel/CSV) or PDF only
