CREATE PROCEDURE [dbo].[usp_RunScheduledJob]
AS
    DECLARE @ConversationHandle UNIQUEIDENTIFIER, 
            @ScheduledJobId INT, @ScheduledJobStepId INT, @JobScheduleId INT, 
            @LastRunOn DATETIME, @NextRunOn DATETIME, @ValidFrom DATETIME
    
    -- we don't need transactions since we don't want to put the job back in the queue if it fails
    -- if that's desired transactions could be added but extra error checking would have to added
    BEGIN TRY
        -- receive only one message from the queue
        ;RECEIVE TOP(1) @ConversationHandle = conversation_handle FROM ScheduledJobQueue
    
        -- exit if no message in the queue
        IF @@ROWCOUNT = 0
            RETURN;

        -- get id of the scheduled job associated with the currently received conversation handle
        SELECT	@ScheduledJobId = SJ.ID, @JobScheduleId = JobScheduleId, @ValidFrom = ValidFrom
        FROM	ScheduledJobs SJ
        WHERE	ConversationHandle = @ConversationHandle AND IsEnabled = 1

        IF @@ROWCOUNT = 0
        BEGIN 
            DECLARE @ConversationHandleString VARCHAR(36)
            SELECT @ConversationHandleString = @ConversationHandle 
            RAISERROR ('Scheduled job for conversation handle "%s" does NOT EXISTS or is NOT ENABLED.', 16, 1, @ConversationHandleString);
        END

        -- get the true time the job started executing
        SELECT	@LastRunOn = GETUTCDATE() 
        
        EXEC usp_RunScheduledJobSteps @ScheduledJobId

        IF @JobScheduleId = -1
        BEGIN
            -- if it's "run once" job, stop it
            EXEC usp_StopScheduledJob @ScheduledJobId
            SELECT @NextRunOn = NULL
        END
        ELSE
        BEGIN
            -- else restart the job to the next scheduled date
            EXEC usp_StartScheduledJob @ScheduledJobId, @ConversationHandle

            SELECT	-- get the valid from start time to calculate from 
                    @NextRunOn = CASE WHEN @ValidFrom > GETUTCDATE() THEN @ValidFrom ELSE GETUTCDATE() END, 
                    -- get next run time based on our valid from starting time
                    @NextRunOn = dbo.GetNextRunTime(@NextRunOn, @JobScheduleId)
        END
        -- update the job Last run time.
        UPDATE	ScheduledJobs
        SET		LastRunOn = @LastRunOn,
                NextRunOn = @NextRunOn
        WHERE	ID = @ScheduledJobId		
        
    END TRY
    BEGIN CATCH
        INSERT INTO SchedulingErrors (ErrorProcedure, ErrorLine, ErrorNumber, ErrorMessage, ErrorSeverity, ErrorState, ScheduledJobId, ScheduledJobStepId)
        SELECT N'usp_RunScheduledJob', ERROR_LINE(), ERROR_NUMBER(), ERROR_MESSAGE(), ERROR_SEVERITY(), ERROR_STATE(), @ScheduledJobId, @ScheduledJobStepId	
        
        -- if an error happens end our conversation if it exists
        IF @ScheduledJobId IS NOT NULL
            EXEC usp_StopScheduledJob @ScheduledJobId
    END CATCH;	
