CREATE PROCEDURE [dbo].[usp_RunScheduledJobSteps]
(
    @ScheduledJobId INT
)
AS
    IF NOT EXISTS (SELECT * FROM ScheduledJobSteps WHERE ScheduledJobId = @ScheduledJobId)
        RAISERROR ('Scheduled job ID %d has NO JOB STEPS.', 16, 1, @ScheduledJobId);
    
    DECLARE @ScheduledJobStepId INT, @SqlToRun NVARCHAR(MAX), @RetryOnFail BIT, @RetryOnFailTimes INT

    DECLARE JobStepsCursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT ID, SqlToRun, RetryOnFail, RetryOnFailTimes 
    FROM ScheduledJobSteps 
    WHERE ScheduledJobId = @ScheduledJobId
    ORDER BY ID

    OPEN JobStepsCursor

    FETCH NEXT FROM JobStepsCursor
    INTO @ScheduledJobStepId, @SqlToRun, @RetryOnFail, @RetryOnFailTimes 

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @repeats INT, @startTime DATETIME
        SELECT @repeats = 0
        -- we first run the SQL. of the first run fails it is repeated @RetryOnFailTimes.
        -- so if @RetryOnFailTimes = 3 the the loop and statement will be run 4 times (1st + 3 repeats on fail)
        WHILE @repeats <= @RetryOnFailTimes 
        BEGIN
            BEGIN TRY					
                SELECT @startTime = GETUTCDATE()
                EXEC sp_executesql @SqlToRun
            END TRY
            BEGIN CATCH
                -- save the error report
                INSERT INTO SchedulingErrors (ErrorProcedure, ErrorLine, ErrorNumber, ErrorMessage, ErrorSeverity, ErrorState, ScheduledJobId, ScheduledJobStepId)
                SELECT N'usp_RunScheduledJobSteps', ERROR_LINE(), ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_SEVERITY(), ERROR_STATE(), @ScheduledJobId, @ScheduledJobStepId	
                -- if we don't want to retry on fail then exit loop
                IF @RetryOnFail	= 0
                    BREAK;					
            END CATCH;			
            SELECT @repeats = @repeats + 1
        END
        UPDATE ScheduledJobSteps 
        SET DurationInSeconds = DATEDIFF(ms, @startTime, GETUTCDATE())/1000.0,
            FinishedOn = GETUTCDATE()
        WHERE ID = @ScheduledJobStepId
    
        FETCH NEXT FROM JobStepsCursor
        INTO @ScheduledJobStepId, @SqlToRun, @RetryOnFail, @RetryOnFailTimes
    END
    
    CLOSE JobStepsCursor 
    DEALLOCATE JobStepsCursor
