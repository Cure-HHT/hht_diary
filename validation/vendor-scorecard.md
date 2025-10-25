# Vendor Validation Package Scorecard

**Version**: 1.0
**Last Updated**: 2025-10-24
**Purpose**: Quantitative evaluation and scoring of vendor validation documentation

> **Use This**: After receiving vendor validation package
> **See**: validation/checklist.md for comprehensive checklist
> **See**: spec/prd-validation.md for validation requirements

---

## Instructions

### Scoring System

**Each Category Scored 0-10**:
- **10**: Exceptional - Exceeds industry standards
- **8-9**: Excellent - Meets all requirements, high quality
- **6-7**: Good - Meets most requirements, acceptable quality
- **4-5**: Fair - Meets minimum requirements, some concerns
- **2-3**: Poor - Significant gaps or quality issues
- **0-1**: Unacceptable - Critical failures, major gaps

**Weighting**:
- Categories weighted by criticality
- Total score = Weighted average
- Minimum acceptable score: 7.0/10

---

## Vendor Information

**Vendor Name**: _________________________________
**System Name**: _________________________________
**Evaluation Date**: _________________________________
**Evaluated By**: _________________________________
**Evaluation Team**: _________________________________

---

## Category 1: Core Validation Documentation

**Weight**: 35% (most critical)

### 1.1 Validation Master Plan (VMP)

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Document provided: YES (+3 points) / NO (0 points)
- [ ] Current (<12 months): YES (+1) / NO (0)
- [ ] Comprehensive strategy: YES (+2) / PARTIAL (+1) / NO (0)
- [ ] Risk-based approach: YES (+2) / NO (0)
- [ ] Proper sign-offs: YES (+2) / NO (0)

**Strengths**:
```


```

**Weaknesses**:
```


```

**Notes**:
```


```

---

### 1.2 User Requirements Specification (URS)

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Document provided: YES (+2) / NO (0)
- [ ] Unique IDs for requirements: YES (+1) / NO (0)
- [ ] FDA 21 CFR Part 11 requirements covered: YES (+2) / PARTIAL (+1) / NO (0)
- [ ] Audit trail requirements: YES (+2) / NO (0)
- [ ] Security requirements (RBAC, RLS): YES (+1) / NO (0)
- [ ] Offline functionality requirements: YES (+1) / NO (0)
- [ ] Multi-sponsor isolation requirements: YES (+1) / NO (0)

**Total Requirements**: ______ (expect 80-150)
**Requirements Relevant to Our Trial**: ______%

**Strengths**:
```


```

**Gaps**:
```


```

---

### 1.3 Functional Specifications (FS)

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Document provided: YES (+2) / NO (0)
- [ ] Architecture diagrams: YES (+1) / NO (0)
- [ ] Database schema (Event Sourcing): YES (+2) / NO (0)
- [ ] Security architecture (RBAC, RLS): YES (+2) / NO (0)
- [ ] Offline sync mechanism explained: YES (+1) / NO (0)
- [ ] Traceability to URS: YES (+2) / PARTIAL (+1) / NO (0)

**Strengths**:
```


```

**Technical Concerns**:
```


```

---

### 1.4 Traceability Matrix

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Matrix provided: YES (+3) / NO (0)
- [ ] Links URS → FS → Tests: YES (+2) / PARTIAL (+1) / NO (0)
- [ ] Coverage: 100% (+3) / 95-99% (+2) / 90-94% (+1) / <90% (0)
- [ ] All tests passed: YES (+2) / NO (0)

**URS Coverage**: ______% (must be 100%)
**Test Pass Rate**: ______% (must be >95%)

**Gaps in Coverage**:
```


```

---

### 1.5 IQ/OQ/PQ Protocols and Reports

**IQ Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] IQ Protocol provided: YES (+2) / NO (0)
- [ ] IQ Report provided: YES (+2) / NO (0)
- [ ] Environment verified: YES (+2) / NO (0)
- [ ] Database config verified: YES (+2) / NO (0)
- [ ] Security config verified: YES (+2) / NO (0)

**OQ Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] OQ Protocol provided: YES (+1) / NO (0)
- [ ] OQ Report provided: YES (+1) / NO (0)
- [ ] Authentication tested: YES (+1) / NO (0)
- [ ] RBAC tested: YES (+1) / NO (0)
- [ ] RLS policies tested: YES (+2) / NO (0)
- [ ] Audit trail tested: YES (+2) / NO (0)
- [ ] Offline sync tested: YES (+1) / NO (0)
- [ ] Security testing (SQL injection, etc.): YES (+1) / NO (0)

**Total OQ Test Cases**: ______ (expect 100-200)
**Pass Rate**: ______%

**PQ Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] PQ Protocol provided: YES (+2) / NO (0)
- [ ] PQ Report provided: YES (+2) / NO (0)
- [ ] End-to-end workflows tested: YES (+2) / NO (0)
- [ ] Load testing performed: YES (+2) / NO (0)
- [ ] Backup/recovery tested: YES (+2) / NO (0)

**Performance Benchmarks Met**: ☐ Yes ☐ No ☐ Unknown

**Critical Test Gaps** (tests not performed):
```


```

---

### 1.6 Validation Summary Report

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Report provided: YES (+3) / NO (0)
- [ ] Executive summary: YES (+1) / NO (0)
- [ ] All deviations resolved: YES (+3) / NO (0)
- [ ] Proper sign-offs: YES (+3) / PARTIAL (+1) / NO (0)

**Deviations**: ______ (total count)
**Unresolved Deviations**: ______ (must be 0)

**Recommendation in Report**: ☐ Approved for use ☐ Conditional ☐ Not approved

---

**Category 1 Sub-Scores**:
- VMP: ______ / 10
- URS: ______ / 10
- FS: ______ / 10
- Traceability: ______ / 10
- IQ: ______ / 10
- OQ: ______ / 10
- PQ: ______ / 10
- Summary: ______ / 10

**Category 1 Average**: ______ / 10
**Category 1 Weighted Score** (35%): ______ / 3.5

**Minimum Acceptable**: 7.0/10
**Status**: ☐ PASS ☐ FAIL

---

## Category 2: Risk and Compliance

**Weight**: 25%

### 2.1 Risk Assessment

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Risk assessment provided: YES (+3) / NO (0)
- [ ] Methodology defined (FMEA, risk matrix): YES (+1) / NO (0)
- [ ] Data integrity risks identified: YES (+2) / NO (0)
- [ ] Security risks identified: YES (+1) / NO (0)
- [ ] Mitigation strategies defined: YES (+2) / NO (0)
- [ ] Residual risk acceptable: YES (+1) / NO (0)

**High Risks Identified**: ______
**High Risks Mitigated**: ______

**Unmitigated High Risks**:
```


```

---

### 2.2 FDA 21 CFR Part 11 Compliance

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Compliance statement provided: YES (+2) / NO (0)
- [ ] Audit trail requirements tested: YES (+3) / NO (0)
- [ ] Electronic signatures implemented: YES (+2) / NO (0)
- [ ] System validation documented: YES (+2) / NO (0)
- [ ] Access controls tested: YES (+1) / NO (0)

**Compliance Gaps**:
```


```

---

### 2.3 FDA Submission History

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Submission history provided: YES (+2) / NO (0)
- [ ] Successful submissions: 5+ (+4) / 3-4 (+3) / 1-2 (+2) / 0 (0)
- [ ] Phase 1 trial experience: YES (+2) / NO (0)
- [ ] No FDA warning letters: YES (+2) / NO (-5)

**Successful FDA Submissions**: ______
**Phase 1 Trials**: ______

**FDA Issues** (warning letters, observations):
```


```

---

### 2.4 Regulatory Inspection History

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] No inspections (new system): (5 points)
- [ ] Inspections with no findings: (+10)
- [ ] Inspections with minor findings (all resolved): (+7)
- [ ] Inspections with major findings (resolved): (+4)
- [ ] Unresolved findings: (0)

**Inspection Count**: ______
**Findings**: ______
**Status**: ☐ All resolved ☐ Pending ☐ Unresolved

---

**Category 2 Sub-Scores**:
- Risk Assessment: ______ / 10
- FDA Compliance: ______ / 10
- Submission History: ______ / 10
- Inspection History: ______ / 10

**Category 2 Average**: ______ / 10
**Category 2 Weighted Score** (25%): ______ / 2.5

**Minimum Acceptable**: 7.0/10
**Status**: ☐ PASS ☐ FAIL

---

## Category 3: Security and Data Integrity

**Weight**: 20%

### 3.1 Security Architecture

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] RBAC design documented: YES (+2) / NO (0)
- [ ] RLS policies documented: YES (+2) / NO (0)
- [ ] Multi-sponsor isolation design: YES (+2) / NO (0)
- [ ] Encryption (transit + rest): YES (+2) / NO (0)
- [ ] Two-factor authentication: YES (+1) / NO (0)
- [ ] Session management: YES (+1) / NO (0)

**Architecture Concerns**:
```


```

---

### 3.2 Security Testing

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Penetration test report provided: YES (+3) / NO (0)
- [ ] Test conducted within 12 months: YES (+2) / NO (0)
- [ ] Independent testing firm: YES (+1) / NO (0)
- [ ] All high/critical findings resolved: YES (+3) / NO (0)
- [ ] SQL injection tested: YES (+1) / NO (0)

**Penetration Test Date**: __________
**Testing Firm**: __________
**Critical Findings**: ______ (all resolved: ☐ Yes ☐ No)

**Unresolved Vulnerabilities**:
```


```

---

### 3.3 Audit Trail Integrity

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Event Sourcing design documented: YES (+3) / NO (0)
- [ ] Audit immutability tested: YES (+3) / NO (0)
- [ ] Tamper detection tested: YES (+2) / NO (0)
- [ ] All CRUD operations logged: YES (+2) / NO (0)

**Audit Trail Gaps**:
```


```

---

### 3.4 Data Backup and Recovery

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Backup procedures documented: YES (+2) / NO (0)
- [ ] Automated backups configured: YES (+2) / NO (0)
- [ ] Backup frequency: Daily (+2) / Weekly (+1) / Less (0)
- [ ] Recovery tested (PQ): YES (+3) / NO (0)
- [ ] Recovery time objective (RTO) defined: YES (+1) / NO (0)

**Backup Frequency**: __________
**RTO**: __________ (acceptable: <24 hours)

---

**Category 3 Sub-Scores**:
- Security Architecture: ______ / 10
- Security Testing: ______ / 10
- Audit Trail: ______ / 10
- Backup/Recovery: ______ / 10

**Category 3 Average**: ______ / 10
**Category 3 Weighted Score** (20%): ______ / 2.0

**Minimum Acceptable**: 7.0/10
**Status**: ☐ PASS ☐ FAIL

---

## Category 4: Quality System and Processes

**Weight**: 10%

### 4.1 Quality Management System

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] ISO 13485 certified: YES (+4) / NO (0)
- [ ] Quality manual provided: YES (+2) / NO (0)
- [ ] Document control procedures: YES (+2) / NO (0)
- [ ] Internal audit procedures: YES (+2) / NO (0)

**ISO 13485 Status**: ☐ Certified ☐ In progress ☐ Not applicable
**Certificate Expiration**: __________

---

### 4.2 Change Control

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Change control SOP provided: YES (+3) / NO (0)
- [ ] Impact assessment process defined: YES (+2) / NO (0)
- [ ] Re-validation triggers clear: YES (+3) / NO (0)
- [ ] Approval process defined: YES (+2) / NO (0)

**Re-validation Triggers Clearly Defined**: ☐ Yes ☐ No

**Change Control Concerns**:
```


```

---

### 4.3 Standard Operating Procedures

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] System access management SOP: YES (+2) / NO (0)
- [ ] Data entry/correction SOP: YES (+2) / NO (0)
- [ ] Backup/recovery SOP: YES (+2) / NO (0)
- [ ] Incident response SOP: YES (+2) / NO (0)
- [ ] Audit/compliance SOP: YES (+2) / NO (0)

**SOPs Provided**: ______ / 7 (from checklist)

---

**Category 4 Sub-Scores**:
- QMS: ______ / 10
- Change Control: ______ / 10
- SOPs: ______ / 10

**Category 4 Average**: ______ / 10
**Category 4 Weighted Score** (10%): ______ / 1.0

**Minimum Acceptable**: 6.0/10
**Status**: ☐ PASS ☐ FAIL

---

## Category 5: References and Track Record

**Weight**: 10%

### 5.1 Reference Customers

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Reference customers: 5+ (+4) / 3-4 (+3) / 1-2 (+2) / 0 (0)
- [ ] Phase 1 trial references: 3+ (+3) / 1-2 (+2) / 0 (0)
- [ ] Contact info provided: YES (+2) / NO (0)
- [ ] Similar therapeutic area: YES (+1) / NO (0)

**Reference Customers**: ______ (total)
**Phase 1 Trials**: ______

**Reference Feedback** (from calls):
```


```

---

### 5.2 Company Stability and Experience

**Score**: ☐ 0 ☐ 1 ☐ 2 ☐ 3 ☐ 4 ☐ 5 ☐ 6 ☐ 7 ☐ 8 ☐ 9 ☐ 10

**Evaluation Criteria**:
- [ ] Years in business: 5+ (+3) / 2-4 (+2) / <2 (+1)
- [ ] Clinical trial system experience: 5+ years (+3) / 2-4 (+2) / <2 (+1)
- [ ] Team size adequate: YES (+2) / NO (0)
- [ ] Financial stability demonstrated: YES (+2) / NO (0)

**Years in Business**: ______
**Clinical Trial Experience**: ______ years
**Employees**: ______

---

**Category 5 Sub-Scores**:
- Reference Customers: ______ / 10
- Company Stability: ______ / 10

**Category 5 Average**: ______ / 10
**Category 5 Weighted Score** (10%): ______ / 1.0

**Minimum Acceptable**: 6.0/10
**Status**: ☐ PASS ☐ FAIL

---

## Overall Score Summary

| Category | Weight | Score (/10) | Weighted Score | Min. Required | Pass/Fail |
|----------|--------|-------------|----------------|---------------|-----------|
| 1. Core Validation | 35% | ______ | ______ / 3.5 | 7.0 | ☐ PASS ☐ FAIL |
| 2. Risk & Compliance | 25% | ______ | ______ / 2.5 | 7.0 | ☐ PASS ☐ FAIL |
| 3. Security & Integrity | 20% | ______ | ______ / 2.0 | 7.0 | ☐ PASS ☐ FAIL |
| 4. Quality System | 10% | ______ | ______ / 1.0 | 6.0 | ☐ PASS ☐ FAIL |
| 5. References | 10% | ______ | ______ / 1.0 | 6.0 | ☐ PASS ☐ FAIL |
| **TOTAL** | **100%** | **N/A** | **______ / 10.0** | **7.0** | **☐ PASS ☐ FAIL** |

---

## Rating Scale

**Total Score Interpretation**:

| Score Range | Rating | Recommendation |
|-------------|--------|----------------|
| 9.0 - 10.0 | **EXCELLENT** | Strong recommend - Best in class |
| 8.0 - 8.9 | **VERY GOOD** | Recommend - High confidence |
| 7.0 - 7.9 | **GOOD** | Recommend - Acceptable with minor gaps |
| 6.0 - 6.9 | **FAIR** | Conditional - Significant improvement needed |
| 5.0 - 5.9 | **POOR** | Do not recommend - Major gaps |
| < 5.0 | **UNACCEPTABLE** | Do not proceed - Critical failures |

**Final Rating**: ______________

---

## Critical Failure Criteria

**Automatic Disqualification** (regardless of overall score):

- ❌ No validation package exists
- ❌ Traceability matrix shows <80% coverage
- ❌ Active FDA warning letter related to this system
- ❌ Unresolved critical security vulnerabilities
- ❌ Audit trail immutability not tested or failed
- ❌ Multi-sponsor isolation not verified
- ❌ No change control procedures
- ❌ RLS policies not tested or failed

**Critical Failures Identified**: ☐ None ☐ Yes (list below)
```


```

---

## Gap Analysis

### High Priority Gaps (Must Address Before Proceeding)

1. _______________________________________________________________
2. _______________________________________________________________
3. _______________________________________________________________
4. _______________________________________________________________
5. _______________________________________________________________

### Medium Priority Gaps (Should Address)

1. _______________________________________________________________
2. _______________________________________________________________
3. _______________________________________________________________

### Low Priority Gaps (Nice to Have)

1. _______________________________________________________________
2. _______________________________________________________________

---

## Vendor Response

**Gap Remediation Plan**:

| Gap # | Description | Vendor Commitment | Timeline | Acceptable? |
|-------|-------------|-------------------|----------|-------------|
| 1 | | | | ☐ Yes ☐ No |
| 2 | | | | ☐ Yes ☐ No |
| 3 | | | | ☐ Yes ☐ No |
| 4 | | | | ☐ Yes ☐ No |
| 5 | | | | ☐ Yes ☐ No |

**Vendor Response Date**: __________
**Remediation Acceptable**: ☐ Yes ☐ No ☐ Partial

---

## Final Recommendation

**Overall Assessment**:
```




```

**Recommendation**:

☐ **STRONGLY RECOMMEND** - Proceed to contract negotiation immediately

☐ **RECOMMEND** - Proceed with standard due diligence

☐ **CONDITIONAL RECOMMEND** - Proceed if vendor addresses gaps within ____ days

☐ **DO NOT RECOMMEND** - Pursue alternative vendors

☐ **REJECT** - System unsuitable for our needs

**Conditions** (if applicable):
```


```

**Next Steps**:
1. _______________________________________________________________
2. _______________________________________________________________
3. _______________________________________________________________

---

## Approvals

**Evaluation Team Lead**: ______________________ Date: __________

**Quality Assurance**: ______________________ Date: __________

**Regulatory Affairs**: ______________________ Date: __________

**Clinical Operations**: ______________________ Date: __________

**IT/Technology**: ______________________ Date: __________

**Executive Sponsor**: ______________________ Date: __________

---

## Appendix A: Vendor Comparison

**Use this section to compare multiple vendors side-by-side**

| Category | Vendor A | Vendor B | Vendor C |
|----------|----------|----------|----------|
| **Core Validation** (/3.5) | | | |
| **Risk & Compliance** (/2.5) | | | |
| **Security** (/2.0) | | | |
| **Quality System** (/1.0) | | | |
| **References** (/1.0) | | | |
| **TOTAL** (/10.0) | | | |
| **Rating** | | | |
| **Recommendation** | | | |

**Best Overall**: _____________
**Best Value**: _____________
**Lowest Risk**: _____________

---

## Appendix B: Reference Call Notes

### Reference 1

**Company**: _________________________
**Contact**: _________________________
**Title**: _________________________
**Date of Call**: _________________________

**Questions Asked**:

1. **How long have you used the system?**
   ```

   ```

2. **What clinical trial phases have you used it for?**
   ```

   ```

3. **Have you submitted data to FDA using this system? Outcome?**
   ```

   ```

4. **Any FDA inspection findings related to this system?**
   ```

   ```

5. **How was the validation process? Vendor support?**
   ```

   ```

6. **Any significant issues or system failures?**
   ```

   ```

7. **Would you recommend this vendor? Why or why not?**
   ```

   ```

8. **What could be improved?**
   ```

   ```

**Overall Impression**: ☐ Very Positive ☐ Positive ☐ Neutral ☐ Negative

---

### Reference 2

**Company**: _________________________
**Contact**: _________________________
**Title**: _________________________
**Date of Call**: _________________________

*(Use same questions as Reference 1)*

**Overall Impression**: ☐ Very Positive ☐ Positive ☐ Neutral ☐ Negative

---

### Reference 3

**Company**: _________________________
**Contact**: _________________________
**Title**: _________________________
**Date of Call**: _________________________

*(Use same questions as Reference 1)*

**Overall Impression**: ☐ Very Positive ☐ Positive ☐ Neutral ☐ Negative

---

## Document Control

**Document Version**: 1.0
**Created By**: _________________________
**Review Date**: _________________________
**Next Review**: _________________________ (annual or after major changes)

---

## References

- **Validation Requirements**: spec/prd-validation.md
- **Validation Checklist**: validation/checklist.md
- **Execution Procedures**: validation/ops-validation.md
