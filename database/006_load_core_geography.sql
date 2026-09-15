USE HealthcareHub;
GO

INSERT INTO core.Geography
(
    GeographyType,
    StateCode,
    StateName,
    CountyName,
    FipsCode
)
SELECT DISTINCT
    s.GeographyLevel,

    CASE
        WHEN s.GeographyLevel = 'National' THEN NULL
        ELSE s.StateAbbreviation
    END AS StateCode,

    CASE
        WHEN s.GeographyLevel = 'National' THEN NULL
        ELSE s.StateName
    END AS StateName,

    CASE
        WHEN s.GeographyLevel = 'County'
            THEN s.CountyName
        ELSE NULL
    END AS CountyName,

    CASE
        WHEN s.GeographyLevel = 'National'
            THEN NULL
        ELSE s.GeographyFips
    END AS FipsCode

FROM stage.MedicareMonthlyEnrollment s

WHERE NOT EXISTS
(
    SELECT 1
    FROM core.Geography g
    WHERE
        g.GeographyType = s.GeographyLevel

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
);
GO