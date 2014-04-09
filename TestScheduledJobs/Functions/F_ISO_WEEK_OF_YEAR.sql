CREATE FUNCTION [dbo].[F_ISO_WEEK_OF_YEAR]
(
    @Date	DATETIME
)
RETURNS		INT
AS
/*
Function F_ISO_WEEK_OF_YEAR returns the
ISO 8601 week of the year for the date passed.
*/
BEGIN

DECLARE @WeekOfYear		INT

SELECT
    -- Compute week of year as (days since start of year/7)+1
    -- Division by 7 gives whole weeks since start of year.
    -- Adding 1 starts week number at 1, instead of zero.
    @WeekOfYear = (DATEDIFF(dd, CASE    -- Case finds start of year
                                WHEN	NextYrStart <= @date
                                THEN	NextYrStart
                                WHEN	CurrYrStart <= @date
                                THEN	CurrYrStart
                                ELSE	PriorYrStart
                                END, @date) / 7) + 1
FROM
    (
    SELECT
        -- First day of first week of prior year
        PriorYrStart = DATEADD(dd, (DATEDIFF(dd, -53690, DATEADD(yy, -1, aa.Jan4)) / 7) * 7, -53690),
        -- First day of first week of current year
        CurrYrStart = DATEADD(dd, (DATEDIFF(dd, -53690, aa.Jan4) / 7) * 7, -53690),
        -- First day of first week of next year
        NextYrStart = DATEADD(dd, (DATEDIFF(dd, -53690, DATEADD(yy, 1, aa.Jan4)) / 7) * 7, -53690)
    FROM
        (
        SELECT
            --Find Jan 4 for the year of the input date
            Jan4	= DATEADD(dd, 3, DATEADD(yy, DATEDIFF(yy, 0, @date), 0))
        ) aa
    ) a

RETURN @WeekOfYear
END
