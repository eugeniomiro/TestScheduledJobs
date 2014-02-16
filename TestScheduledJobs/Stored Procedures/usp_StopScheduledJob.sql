CREATE PROCEDURE [dbo].[usp_StopScheduledJob]
(
    @ScheduledJobId INT
)
AS
    BEGIN TRY
        BEGIN TRAN
        DECLARE @ConversationHandle UNIQUEIDENTIFIER
        
        SELECT	@ConversationHandle = ConversationHandle 
        FROM	ScheduledJobs
        WHERE	ID = @ScheduledJobId AND IsEnabled = 1 AND ConversationHandle IS NOT NULL
        
        IF @@ROWCOUNT = 0
            RAISERROR ('Scheduled job ID %d does NOT exists.', 16, 1, @ScheduledJobId);
        
        IF EXISTS (SELECT * FROM sys.conversation_endpoints WHERE conversation_handle = @ConversationHandle)
            END CONVERSATION @ConversationHandle
        
        UPDATE	ScheduledJobs
        SET		IsEnabled = 0, ConversationHandle = NULL, NextRunOn = NULL
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
        SELECT	N'usp_StopScheduledJob', ERROR_LINE(), ERROR_NUMBER(), @ErrorMessage, @ErrorSeverity, @ErrorState, @ScheduledJobId		
        
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);
    END CATCH;
