CREATE FUNCTION [dbo].[GetNextRunTime]
(
    @LastRunTime DATETIME, 
    @JobScheduleId INT
)
RETURNS DATETIME
AS
BEGIN
    DECLARE @NextRunTime DATETIME,
            @FrequencyType INT, @Frequency INT, @AbsoluteSubFrequency VARCHAR(100), 
            @MontlyRelativeSubFrequencyWhich INT, @MontlyRelativeSubFrequencyWhat INT, @RunAtInSecondsFromMidnight INT,
            @StartIntervalDate DATETIME, @EndIntervalDate DATETIME,		
            @LastRunTimeDayOfYear INT, @LastRunTimeMonth INT, @LastRunTimeISOWeek INT

    -- get required job schedule data
    SELECT	@FrequencyType = FrequencyType, @Frequency = Frequency, @AbsoluteSubFrequency = AbsoluteSubFrequency, 
            @MontlyRelativeSubFrequencyWhich = MontlyRelativeSubFrequencyWhich, @MontlyRelativeSubFrequencyWhat = MontlyRelativeSubFrequencyWhat, 
            @RunAtInSecondsFromMidnight = RunAtInSecondsFromMidnight 
    FROM	JobSchedules
    WHERE	id = @JobScheduleId

    -- no schedule found so return the input date
    IF @@ROWCOUNT = 0
    BEGIN
        RETURN @LastRunTime;		
    END 

    SELECT	-- set the interval start to the first of the month
            @startIntervalDate = DATEADD(m, DATEDIFF(m, 0, @LastRunTime), 0),
            -- set the interval end to 2 times frequency in months in the future
            @endIntervalDate = DATEADD(m, 2*@Frequency, @startIntervalDate),
            -- get ISO week of the year for the last run time
            @LastRunTimeISOWeek = dbo.F_ISO_WEEK_OF_YEAR(@LastRunTime),
            @LastRunTimeMonth = MONTH(@LastRunTime),
            @LastRunTimeDayOfYear = DATEPART(dy, @LastRunTime)

    -- DAILY SCHEDULE TYPE
    IF @FrequencyType = 1
    BEGIN		
        SELECT	TOP 1 @NextRunTime = DATE
        FROM (
                SELECT	DATEADD(s, @RunAtInSecondsFromMidnight, DATE) AS DATE, ROW_NUMBER() OVER(ORDER BY DATE) - 1 AS CorrectDaySelector
                FROM	dbo.F_TABLE_DATE(@LastRunTime, DATEADD(d, 2*@Frequency, @LastRunTime))
              ) t
        WHERE	DATE > @LastRunTime
                AND CorrectDaySelector % @Frequency = 0
        ORDER BY DATE
    END
    -- WEEKLY SCHEDULE TYPE
    ELSE IF @FrequencyType = 2
    BEGIN
        SELECT @AbsoluteSubFrequency = ',' + REPLACE(@AbsoluteSubFrequency, ' ', '') + ',' -- add prefix and suffix for correct split

        SELECT	TOP 1 @NextRunTime = DATEADD(s, @RunAtInSecondsFromMidnight, DT.DATE)
        FROM	dbo.F_TABLE_DATE(@startIntervalDate, @endIntervalDate) DT
                JOIN
                (	-- split our CSV into table to join to
                    SELECT DISTINCT
                            CONVERT(INT, SUBSTRING(@AbsoluteSubFrequency, V1.number+1, CHARINDEX(',', @AbsoluteSubFrequency, V1.number+1) - V1.number - 1)) AS D
                    FROM	master..spt_values V1
                    WHERE	V1.number  < LEN(@AbsoluteSubFrequency)
                            AND SUBSTRING(@AbsoluteSubFrequency, V1.number, 1) = ','
                ) T ON T.D = DT.ISO_DAY_OF_WEEK
        WHERE	DATEADD(s, @RunAtInSecondsFromMidnight, DT.DATE) > @LastRunTime 
                AND (DT.ISO_WEEK_NO - @LastRunTimeISOWeek) % @Frequency = 0 -- select only weeks that match our frequency
        ORDER BY DT.DATE
    END
    ELSE IF @FrequencyType = 3 -- MONTHLY SCHEDULE TYPE
    BEGIN
        -- RELATIVE SCHEDULE
        IF ISNULL(@AbsoluteSubFrequency, '') = ''
        BEGIN
            -- handle "Last X" option
            IF @MontlyRelativeSubFrequencyWhich = 5
            BEGIN 	
                -- handle Last Day of month option
                IF @MontlyRelativeSubFrequencyWhat = -1
                BEGIN 
                    SELECT	TOP 1 @NextRunTime = DATEADD(s, @RunAtInSecondsFromMidnight, DATE)
                    FROM	dbo.F_TABLE_DATE(@startIntervalDate, @endIntervalDate)
                    WHERE	DATEADD(s, @RunAtInSecondsFromMidnight, DATE) > @LastRunTime 
                            AND (MONTH - MONTH(@LastRunTime)) % @Frequency  = 0 -- select only months that match our frequency
                            AND DATE = END_OF_MONTH_DATE
                    ORDER BY DATE
                END 
                -- handle last Monday, Tuesday, ..., Sunday option
                ELSE
                BEGIN
                    DECLARE @temp TABLE (DATE DATETIME PRIMARY KEY CLUSTERED, ISO_DAY_OF_WEEK INT, MONTH INT, DAY_OCCURRENCE_IN_MONTH INT)
                    INSERT INTO @temp
                    SELECT	DATEADD(s, @RunAtInSecondsFromMidnight, DATE), ISO_DAY_OF_WEEK, MONTH,
                            ROW_NUMBER() OVER(PARTITION BY MONTH, ISO_DAY_OF_WEEK ORDER BY DATE) AS DAY_OCCURRENCE_IN_MONTH
                    FROM	dbo.F_TABLE_DATE(@startIntervalDate, @endIntervalDate)				
                    WHERE	(MONTH - MONTH(@LastRunTime)) % @Frequency  = 0 -- select only months that match our frequency
                    
                    SELECT	TOP 1 @NextRunTime = T1.DATE
                    FROM	@temp T1
                            JOIN (
                                  SELECT MAX(DAY_OCCURRENCE_IN_MONTH) AS DAY_OCCURRENCE_IN_MONTH, ISO_DAY_OF_WEEK, MONTH
                                  FROM @temp
                                  WHERE ISO_DAY_OF_WEEK = @MontlyRelativeSubFrequencyWhat 
                                  GROUP BY MONTH, ISO_DAY_OF_WEEK
                                 ) T2 ON T1.ISO_DAY_OF_WEEK = T2.ISO_DAY_OF_WEEK 
                                            AND T1.DAY_OCCURRENCE_IN_MONTH = T2.DAY_OCCURRENCE_IN_MONTH
                                            AND T1.MONTH = T2.MONTH
                    WHERE	T1.DATE > @LastRunTime 
                    ORDER BY DATE
                END			
            END
            -- handle "1st, 2nd, 3rd, 4th" option
            ELSE
            BEGIN 
                SELECT TOP 1 @NextRunTime = DATEADD(s, @RunAtInSecondsFromMidnight, DATE)
                FROM (	-- get correct months for our frequency
                        SELECT	ROW_NUMBER() OVER(PARTITION BY MONTH, ISO_DAY_OF_WEEK ORDER BY DATE) AS DAY_OCCURRENCE_IN_MONTH,
                                DATE, ISO_DAY_OF_WEEK, DAY_OF_MONTH				
                        FROM	dbo.F_TABLE_DATE(@startIntervalDate, @endIntervalDate)
                        WHERE	(MONTH - MONTH(@LastRunTime)) % @Frequency  = 0 -- select only months that match our frequency
                      ) T
                WHERE	DATEADD(s, @RunAtInSecondsFromMidnight, DATE) > @LastRunTime 
                        AND
                        (
                        -- 1st, 2nd, 3rd, 4th day of month option
                        1 = CASE WHEN	@MontlyRelativeSubFrequencyWhat = -1 
                                        AND DAY_OF_MONTH = @MontlyRelativeSubFrequencyWhich THEN 1 ELSE 0 END
                        OR
                        -- 1st, 2nd, 3rd, 4th Monday, Tuesday, ..., Sunday option
                        1 = CASE WHEN	@MontlyRelativeSubFrequencyWhat != -1 
                                        AND ISO_DAY_OF_WEEK = @MontlyRelativeSubFrequencyWhat 
                                        AND DAY_OCCURRENCE_IN_MONTH = @MontlyRelativeSubFrequencyWhich THEN 1 ELSE 0 END)
                ORDER BY DATE
            END		
        END
        -- ABSOLUTE SCHEDULE
        ELSE
        BEGIN
            SELECT	@AbsoluteSubFrequency = ',' + REPLACE(@AbsoluteSubFrequency, ' ', '') + ',' -- add prefix and suffix for correct split
            SELECT	TOP 1 @NextRunTime = DATEADD(s, @RunAtInSecondsFromMidnight, DT.DATE)
            FROM	dbo.F_TABLE_DATE(@startIntervalDate, @endIntervalDate) DT
                    JOIN
                    (
                        SELECT DISTINCT
                                CONVERT(INT, SUBSTRING(@AbsoluteSubFrequency, V1.number+1, CHARINDEX(',', @AbsoluteSubFrequency, V1.number+1) - V1.number - 1)) AS D
                        FROM	master..spt_values V1
                        WHERE	V1.number  < LEN(@AbsoluteSubFrequency)
                                AND SUBSTRING(@AbsoluteSubFrequency, V1.number, 1) = ','
                    ) T ON T.D = DT.DAY_OF_MONTH
            WHERE	DATEADD(s, @RunAtInSecondsFromMidnight, DT.DATE) > @LastRunTime 
                    AND (DT.MONTH - @LastRunTimeMonth) % @Frequency = 0 -- select only months that match our frequency
            ORDER BY DT.DATE
        END
    END

    RETURN @NextRunTime
    END