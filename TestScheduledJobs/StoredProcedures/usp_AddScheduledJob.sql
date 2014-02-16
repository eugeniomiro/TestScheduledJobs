﻿CREATE PROC usp_AddScheduledJob
(
	@ScheduledSql NVARCHAR(MAX), 
	@FirstRunOn DATETIME, 
	@IsRepeatable BIT	
)
AS
	DECLARE @ScheduledJobId INT, @TimeoutInSeconds INT, @ConversationHandle UNIQUEIDENTIFIER	
	BEGIN TRANSACTION
	BEGIN TRY
		-- add job to our table
		INSERT INTO ScheduledJobs(ScheduledSql, FirstRunOn, IsRepeatable, ConversationHandle)
		VALUES (@ScheduledSql, @FirstRunOn, @IsRepeatable, NULL)
		SELECT @ScheduledJobId = SCOPE_IDENTITY()
		
		-- set the timeout. It's in seconds so we need the datediff
		SELECT @TimeoutInSeconds = DATEDIFF(s, GETDATE(), @FirstRunOn);
		-- begin a conversation for our scheduled job
		BEGIN DIALOG CONVERSATION @ConversationHandle
			FROM SERVICE   [//ScheduledJobService]
			TO SERVICE      '//ScheduledJobService', 
							'CURRENT DATABASE'
			ON CONTRACT     [//ScheduledJobContract]
			WITH ENCRYPTION = OFF;

		-- start the conversation timer
		BEGIN CONVERSATION TIMER (@ConversationHandle)
		TIMEOUT = @TimeoutInSeconds;
		-- associate or scheduled job with the conversation via the Conversation Handle
		UPDATE	ScheduledJobs
		SET		ConversationHandle = @ConversationHandle, 
				IsEnabled = 1
		WHERE	ID = @ScheduledJobId 
		IF @@TRANCOUNT > 0
		BEGIN 
			COMMIT;
		END
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK;
		END
		INSERT INTO ScheduledJobsErrors (
				ErrorLine, ErrorNumber, ErrorMessage, 
				ErrorSeverity, ErrorState, ScheduledJobId)
		SELECT	ERROR_LINE(), ERROR_NUMBER(), 'usp_AddScheduledJob: ' + ERROR_MESSAGE(), 
				ERROR_SEVERITY(), ERROR_STATE(), @ScheduledJobId
	END CATCH
