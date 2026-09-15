USE HealthcareHub;
GO

CREATE TABLE core.Geography
(
    GeographyId INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Core_Geography PRIMARY KEY,

    GeographyType NVARCHAR(20) NOT NULL,

    StateCode NVARCHAR(10) NULL,
    StateName NVARCHAR(100) NULL,
    CountyName NVARCHAR(150) NULL,
    FipsCode NVARCHAR(5) NULL,

    CreatedUtc DATETIME2(0) NOT NULL
        CONSTRAINT DF_Core_Geography_CreatedUtc
        DEFAULT SYSUTCDATETIME(),

    CONSTRAINT CK_Core_Geography_Type
        CHECK (GeographyType IN ('National', 'State', 'County'))
);
GO

ALTER TABLE core.Geography
ADD GeographyNaturalKey AS
(
    CONCAT(
        GeographyType,
        '|',
        ISNULL(StateCode, ''),
        '|',
        ISNULL(FipsCode, '')
    )
) PERSISTED;
GO

CREATE UNIQUE INDEX UX_Core_Geography_NaturalKey
    ON core.Geography(GeographyNaturalKey);
GO