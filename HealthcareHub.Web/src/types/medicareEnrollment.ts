export interface MedicareEnrollmentNationalTrend {
    reportingPeriodId: number;
    reportingYear: number;
    reportingMonth: number;
    reportingPeriodStart: string;

    totalBeneficiaries: number | null;
    originalMedicareBeneficiaries: number | null;
    medicareAdvantageAndOtherBeneficiaries: number | null;
    medicareAdvantagePercent: number | null;

    prescriptionDrugBeneficiaries: number | null;
    dualEligibleBeneficiaries: number | null;

    hasSuppressedValues: boolean;
    suppressedValueCount: number;
    pipelineRunId: number;
}

export interface MedicareEnrollmentStateTrend
    extends MedicareEnrollmentNationalTrend {
    stateCode: string;
    stateName: string;
}

export interface MedicareEnrollmentStateOption {
    stateCode: string;
    stateName: string;
}

export interface MedicareEnrollmentCountyLatest {
    stateCode: string;
    stateName: string;
    countyName: string;
    fipsCode: string;

    reportingYear: number;
    reportingMonth: number;
    reportingPeriodStart: string;

    totalBeneficiaries: number | null;
    originalMedicareBeneficiaries: number | null;
    medicareAdvantageAndOtherBeneficiaries: number | null;
    medicareAdvantagePercent: number | null;

    prescriptionDrugBeneficiaries: number | null;
    dualEligibleBeneficiaries: number | null;

    hasSuppressedValues: boolean;
    suppressedValueCount: number;

    pipelineRunId: number;
}