CREATE PROCEDURE [dbo].[usp_StartScheduledJob]
(
    @ScheduledJobId INT,	
    @ConversationHandle UNIQUEIDENTIFIER = NULL,
    @ValidFrom DATETIME = NULL
)
AS	
    BEGIN TRY
        IF NOT EXISTS (SELECT * FROM ScheduledJobSteps WHERE ScheduledJobId = @ScheduledJobId)
            RAISERROR ('Scheduled job ID %d has no steps. Job has to have steps to start.', 16, 1, @ScheduledJobId); 
        
        BEGIN TRANSACTION

        -- by passing in new @ValidFrom we can reenable a disabled job		
        IF @ValidFrom IS NOT NULL
        BEGIN
            UPDATE	ScheduledJobs
            SET		ValidFrom = @ValidFrom,
                    -- calculate the next run datetime
                    NextRunOn = dbo.GetNextRunTime(CASE WHEN @ValidFrom > GETUTCDATE() THEN @ValidFrom ELSE GETUTCDATE() END, JobScheduleId),
                    IsEnabled = 0
            WHERE	ID = @ScheduledJobId
        END

        DECLARE @TimeoutInSeconds INT, @NextRunOn DATETIME, @JobScheduleId INT 
                
        SELECT	@ValidFrom = ValidFrom, @NextRunOn = NextRunOn, @JobScheduleId = JobScheduleId
        FROM	ScheduledJobs
        WHERE	ID = @ScheduledJobId AND IsEnabled = 0
        
        IF @@ROWCOUNT = 0
        BEGIN
            IF @@TRANCOUNT > 0
                ROLLBACK;
            RETURN;
        END 
    
        -- for the first call when @ConversationHandle is null. 
        -- this sproc is also called by the usp_RunScheduledJob 
        -- activation stored procedure with @ConversationHandle parameter set 
        -- when setting the job to run on the next scheduled run time time 
        IF @ConversationHandle IS NULL
        BEGIN
            BEGIN DIALOG CONVERSATION @ConversationHandle
                FROM SERVICE   [//ScheduledJobService]
                TO SERVICE      '//ScheduledJobService', 
                                'CURRENT DATABASE'
                ON CONTRACT     [//ScheduledJobContract]
                WITH ENCRYPTION = OFF;
        
            UPDATE	ScheduledJobs
            SET		ConversationHandle  = @ConversationHandle, 
                    IsEnabled           = 1
            WHERE	ID = @ScheduledJobId
        END
    
        -- get next run time in seconds. DATEADD(ms, -DATEPART(ms, GETUTCDATE()), GETUTCDATE()) gets utc without miliseconds
        SELECT @TimeoutInSeconds = DATEDIFF(s, DATEADD(ms, -DATEPART(ms, GETUTCDATE()), GETUTCDATE()), @NextRunOn)

        IF @TimeoutInSeconds <= 0
            RAISERROR ('NextRunOn date for scheduled job ID %d is les than current UTC date.', 16, 1, @ScheduledJobId); 

        BEGIN CONVERSATION TIMER (@ConversationHandle) TIMEOUT = @TimeoutInSeconds;

        -- update the NextRunOn for the job
        UPDATE	ScheduledJobs
        SET		NextRunOn = @NextRunOn
        WHERE	ID = @ScheduledJobId
                
        IF @@TRANCOUNT > 0
            COMMIT;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK;
        
        DECLARE @ErrorMessage NVARCHAR(2048), @ErrorSeverity INT, @ErrorState INT
        SELECT @ErrorMessage = ERROR_MESSAGE(), @ErrorSeverity = ERROR_SEVERITY(), @ErrorState = ERROR_STATE()
        
        INSERT INTO SchedulingErrors (ErrorProcedure, ErrorLine, ErrorNumber, ErrorMessage, ErrorSeverity, ErrorState, ScheduledJobId)
        SELECT N'usp_StartScheduledJob', ERROR_LINE(), ERROR_NUMBER(), @ErrorMessage, @ErrorSeverity, @ErrorState, @ScheduledJobId		
        
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
