USE HealthcareHub;
GO

INSERT INTO core.MedicareEnrollment
(
    GeographyId,
    ReportingPeriodId,

    PipelineRunId,
    SourceStageId,

    TotalBeneficiaries,
    OriginalMedicareBeneficiaries,
    MedicareAdvantageAndOtherBeneficiaries,

    AgedTotalBeneficiaries,
    AgedEsrdBeneficiaries,
    AgedNonEsrdBeneficiaries,

    DisabledTotalBeneficiaries,
    DisabledEsrdBeneficiaries,
    DisabledNonEsrdBeneficiaries,

    MaleBeneficiaries,
    FemaleBeneficiaries,

    WhiteBeneficiaries,
    BlackBeneficiaries,
    AsianPacificIslanderBeneficiaries,
    HispanicBeneficiaries,
    AmericanIndianAlaskaNativeBeneficiaries,
    OtherRaceBeneficiaries,

    AgeUnder25Beneficiaries,
    Age25To44Beneficiaries,
    Age45To64Beneficiaries,
    Age65To69Beneficiaries,
    Age70To74Beneficiaries,
    Age75To79Beneficiaries,
    Age80To84Beneficiaries,
    Age85To89Beneficiaries,
    Age90To94Beneficiaries,
    Age95PlusBeneficiaries,

    DualEligibleBeneficiaries,
    FullDualEligibleBeneficiaries,
    PartialDualEligibleBeneficiaries,
    NonDualBeneficiaries,

    QmbOnlyBeneficiaries,
    QmbPlusBeneficiaries,
    SlmbOnlyBeneficiaries,
    SlmbPlusBeneficiaries,
    QdwiQiBeneficiaries,
    OtherFullDualMedicaidBeneficiaries,

    PartAAndBBeneficiaries,
    PartAAndBOriginalMedicareBeneficiaries,
    PartAAndBMedicareAdvantageBeneficiaries,

    PartABeneficiaries,
    PartAOriginalMedicareBeneficiaries,
    PartAMedicareAdvantageBeneficiaries,

    PartBBeneficiaries,
    PartBOriginalMedicareBeneficiaries,
    PartBMedicareAdvantageBeneficiaries,

    PrescriptionDrugBeneficiaries,
    PrescriptionDrugPdpBeneficiaries,
    PrescriptionDrugMapdBeneficiaries,
    PrescriptionDrugDeemedFullLisBeneficiaries,
    PrescriptionDrugFullLisBeneficiaries,
    PrescriptionDrugPartialLisBeneficiaries,
    PrescriptionDrugNoLisBeneficiaries,

    HasSuppressedValues,
    SuppressedValueCount
)
SELECT
    g.GeographyId,
    rp.ReportingPeriodId,

    s.PipelineRunId,
    s.MedicareMonthlyEnrollmentStageId,

    s.TOT_BENES,
    s.ORGNL_MDCR_BENES,
    s.MA_AND_OTH_BENES,

    s.AGED_TOT_BENES,
    s.AGED_ESRD_BENES,
    s.AGED_NO_ESRD_BENES,

    s.DSBLD_TOT_BENES,
    s.DSBLD_ESRD_AND_ESRD_ONLY_BENES,
    s.DSBLD_NO_ESRD_BENES,

    s.MALE_TOT_BENES,
    s.FEMALE_TOT_BENES,

    s.WHITE_TOT_BENES,
    s.BLACK_TOT_BENES,
    s.API_TOT_BENES,
    s.HSPNC_TOT_BENES,
    s.NATIND_TOT_BENES,
    s.OTHR_TOT_BENES,

    s.AGE_LT_25_BENES,
    s.AGE_25_TO_44_BENES,
    s.AGE_45_TO_64_BENES,
    s.AGE_65_TO_69_BENES,
    s.AGE_70_TO_74_BENES,
    s.AGE_75_TO_79_BENES,
    s.AGE_80_TO_84_BENES,
    s.AGE_85_TO_89_BENES,
    s.AGE_90_TO_94_BENES,
    s.AGE_GT_94_BENES,

    s.DUAL_TOT_BENES,
    s.FULL_DUAL_TOT_BENES,
    s.PART_DUAL_TOT_BENES,
    s.NODUAL_TOT_BENES,

    s.QMB_ONLY_BENES,
    s.QMB_PLUS_BENES,
    s.SLMB_ONLY_BENES,
    s.SLMB_PLUS_BENES,
    s.QDWI_QI_BENES,
    s.OTHR_FULL_DUAL_MDCD_BENES,

    s.A_B_TOT_BENES,
    s.A_B_ORGNL_MDCR_BENES,
    s.A_B_MA_AND_OTH_BENES,

    s.A_TOT_BENES,
    s.A_ORGNL_MDCR_BENES,
    s.A_MA_AND_OTH_BENES,

    s.B_TOT_BENES,
    s.B_ORGNL_MDCR_BENES,
    s.B_MA_AND_OTH_BENES,

    s.PRSCRPTN_DRUG_TOT_BENES,
    s.PRSCRPTN_DRUG_PDP_BENES,
    s.PRSCRPTN_DRUG_MAPD_BENES,
    s.PRSCRPTN_DRUG_DEEMED_ELIGIBLE_FULL_LIS_BENES,
    s.PRSCRPTN_DRUG_FULL_LIS_BENES,
    s.PRSCRPTN_DRUG_PARTIAL_LIS_BENES,
    s.PRSCRPTN_DRUG_NO_LIS_BENES,

    s.IsAnyValueSuppressed,
    s.SuppressedValueCount

FROM stage.MedicareMonthlyEnrollment s

JOIN core.Geography g
    ON g.GeographyType = s.GeographyLevel
    AND ISNULL(g.StateCode, '') =
        ISNULL(
            CASE
                WHEN s.GeographyLevel = 'National'
                    THEN NULL
                ELSE s.StateAbbreviation
            END,
            ''
        )
    AND ISNULL(g.FipsCode, '') =
        ISNULL(
            CASE
                WHEN s.GeographyLevel = 'National'
                    THEN NULL
                ELSE s.GeographyFips
            END,
            ''
        )

JOIN core.ReportingPeriod rp
    ON rp.ReportingYear = s.ReportingYear
    AND ISNULL(rp.ReportingMonth, 0) =
        ISNULL(s.ReportingMonth, 0)
    AND rp.IsAnnualSummary = s.IsAnnualSummary

WHERE NOT EXISTS
(
    SELECT 1
    FROM core.MedicareEnrollment me
    WHERE me.SourceStageId =
          s.MedicareMonthlyEnrollmentStageId
);
GO