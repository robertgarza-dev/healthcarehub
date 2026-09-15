USE HealthcareHub;
GO

CREATE TABLE core.MedicareEnrollment
(
    MedicareEnrollmentId BIGINT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Core_MedicareEnrollment PRIMARY KEY,

    GeographyId INT NOT NULL,
    ReportingPeriodId INT NOT NULL,

    PipelineRunId BIGINT NOT NULL,
    SourceStageId BIGINT NOT NULL,

    TotalBeneficiaries BIGINT NULL,
    OriginalMedicareBeneficiaries BIGINT NULL,
    MedicareAdvantageAndOtherBeneficiaries BIGINT NULL,

    AgedTotalBeneficiaries BIGINT NULL,
    AgedEsrdBeneficiaries BIGINT NULL,
    AgedNonEsrdBeneficiaries BIGINT NULL,

    DisabledTotalBeneficiaries BIGINT NULL,
    DisabledEsrdBeneficiaries BIGINT NULL,
    DisabledNonEsrdBeneficiaries BIGINT NULL,

    MaleBeneficiaries BIGINT NULL,
    FemaleBeneficiaries BIGINT NULL,

    WhiteBeneficiaries BIGINT NULL,
    BlackBeneficiaries BIGINT NULL,
    AsianPacificIslanderBeneficiaries BIGINT NULL,
    HispanicBeneficiaries BIGINT NULL,
    AmericanIndianAlaskaNativeBeneficiaries BIGINT NULL,
    OtherRaceBeneficiaries BIGINT NULL,

    AgeUnder25Beneficiaries BIGINT NULL,
    Age25To44Beneficiaries BIGINT NULL,
    Age45To64Beneficiaries BIGINT NULL,
    Age65To69Beneficiaries BIGINT NULL,
    Age70To74Beneficiaries BIGINT NULL,
    Age75To79Beneficiaries BIGINT NULL,
    Age80To84Beneficiaries BIGINT NULL,
    Age85To89Beneficiaries BIGINT NULL,
    Age90To94Beneficiaries BIGINT NULL,
    Age95PlusBeneficiaries BIGINT NULL,

    DualEligibleBeneficiaries BIGINT NULL,
    FullDualEligibleBeneficiaries BIGINT NULL,
    PartialDualEligibleBeneficiaries BIGINT NULL,
    NonDualBeneficiaries BIGINT NULL,

    QmbOnlyBeneficiaries BIGINT NULL,
    QmbPlusBeneficiaries BIGINT NULL,
    SlmbOnlyBeneficiaries BIGINT NULL,
    SlmbPlusBeneficiaries BIGINT NULL,
    QdwiQiBeneficiaries BIGINT NULL,
    OtherFullDualMedicaidBeneficiaries BIGINT NULL,

    PartAAndBBeneficiaries BIGINT NULL,
    PartAAndBOriginalMedicareBeneficiaries BIGINT NULL,
    PartAAndBMedicareAdvantageBeneficiaries BIGINT NULL,

    PartABeneficiaries BIGINT NULL,
    PartAOriginalMedicareBeneficiaries BIGINT NULL,
    PartAMedicareAdvantageBeneficiaries BIGINT NULL,

    PartBBeneficiaries BIGINT NULL,
    PartBOriginalMedicareBeneficiaries BIGINT NULL,
    PartBMedicareAdvantageBeneficiaries BIGINT NULL,

    PrescriptionDrugBeneficiaries BIGINT NULL,
    PrescriptionDrugPdpBeneficiaries BIGINT NULL,
    PrescriptionDrugMapdBeneficiaries BIGINT NULL,
    PrescriptionDrugDeemedFullLisBeneficiaries BIGINT NULL,
    PrescriptionDrugFullLisBeneficiaries BIGINT NULL,
    PrescriptionDrugPartialLisBeneficiaries BIGINT NULL,
    PrescriptionDrugNoLisBeneficiaries BIGINT NULL,

    HasSuppressedValues BIT NOT NULL,
    SuppressedValueCount SMALLINT NOT NULL,

    CreatedUtc DATETIME2(0) NOT NULL
        CONSTRAINT DF_Core_MedicareEnrollment_CreatedUtc
        DEFAULT SYSUTCDATETIME(),

    UpdatedUtc DATETIME2(0) NULL,

    CONSTRAINT FK_Core_MedicareEnrollment_Geography
        FOREIGN KEY (GeographyId)
        REFERENCES core.Geography(GeographyId),

    CONSTRAINT FK_Core_MedicareEnrollment_ReportingPeriod
        FOREIGN KEY (ReportingPeriodId)
        REFERENCES core.ReportingPeriod(ReportingPeriodId),

    CONSTRAINT FK_Core_MedicareEnrollment_PipelineRun
        FOREIGN KEY (PipelineRunId)
        REFERENCES ops.PipelineRun(PipelineRunId),

    CONSTRAINT FK_Core_MedicareEnrollment_Stage
        FOREIGN KEY (SourceStageId)
        REFERENCES stage.MedicareMonthlyEnrollment
            (MedicareMonthlyEnrollmentStageId),

    CONSTRAINT UQ_Core_MedicareEnrollment_GeographyPeriod
        UNIQUE (GeographyId, ReportingPeriodId),

    CONSTRAINT UQ_Core_MedicareEnrollment_SourceStage
        UNIQUE (SourceStageId)
);
GO

CREATE INDEX IX_Core_MedicareEnrollment_ReportingPeriod
    ON core.MedicareEnrollment(ReportingPeriodId);
GO

CREATE INDEX IX_Core_MedicareEnrollment_Geography
    ON core.MedicareEnrollment(GeographyId);
GO

CREATE INDEX IX_Core_MedicareEnrollment_PipelineRun
    ON core.MedicareEnrollment(PipelineRunId);
GO