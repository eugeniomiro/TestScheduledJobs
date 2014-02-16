CREATE PROC usp_RemoveScheduledJob
	@ScheduledJobId INT
AS	
	BEGIN TRANSACTION
	BEGIN TRY
		DECLARE @ConversationHandle UNIQUEIDENTIFIER
		-- get the conversation handle for our job
		SELECT	@ConversationHandle = ConversationHandle
		FROM	ScheduledJobs 
		WHERE	Id = @ScheduledJobId 
		
		-- if the job doesn't exist return
		IF @@ROWCOUNT = 0
			RETURN;
		
		-- end the conversation if it is active
		IF EXISTS (SELECT * FROM sys.conversation_endpoints WHERE conversation_handle = @ConversationHandle)
			END CONVERSATION @ConversationHandle
		
		-- delete the scheduled job from out table
		DELETE ScheduledJobs WHERE Id = @ScheduledJobId 		
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN 
			ROLLBACK;
		END
		INSERT INTO ScheduledJobsErrors (
				ErrorLine, ErrorNumber, ErrorMessage, 
				ErrorSeverity, ErrorState, ScheduledJobId)
		SELECT	ERROR_LINE(), ERROR_NUMBER(), 'usp_RemoveScheduledJob: ' + ERROR_MESSAGE(), 
				ERROR_SEVERITY(), ERROR_STATE(), @ScheduledJobId
	END CATCH
