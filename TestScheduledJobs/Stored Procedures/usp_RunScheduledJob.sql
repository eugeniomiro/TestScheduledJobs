CREATE PROC usp_RunScheduledJob
AS
	DECLARE @ConversationHandle UNIQUEIDENTIFIER, @ScheduledJobId INT, @LastRunOn DATETIME, @IsEnabled BIT, @LastRunOK BIT
	
	SELECT	@LastRunOn = GETDATE(), @IsEnabled = 0, @LastRunOK = 0
	-- we don't need transactions since we don't want to put the job back in the queue if it fails
	BEGIN TRY
		DECLARE @message_type_name sysname;			
		-- receive only one message from the queue
		RECEIVE TOP(1) 
			    @ConversationHandle = conversation_handle,
			    @message_type_name = message_type_name
		FROM ScheduledJobQueue
	
		-- exit if no message or other type of message than DialgTimer 
		IF @@ROWCOUNT = 0 OR ISNULL(@message_type_name, '') != 'http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer'
			RETURN;
		
		DECLARE @ScheduledSql NVARCHAR(MAX), @IsRepeatable BIT				
		-- get a scheduled job that is enabled and is associated with our conversation handle.
		-- if a job fails we disable it by setting IsEnabled to 0
		SELECT	@ScheduledJobId = ID, @ScheduledSql = ScheduledSql, @IsRepeatable = IsRepeatable
		FROM	ScheduledJobs 
		WHERE	ConversationHandle = @ConversationHandle AND IsEnabled = 1
					
		-- end the conversation if it's non repeatable
		IF @IsRepeatable = 0
		BEGIN			
			END CONVERSATION @ConversationHandle
			SELECT @IsEnabled = 0
		END
		ELSE
		BEGIN 
			-- reset the timer to fire again in one day
			BEGIN CONVERSATION TIMER (@ConversationHandle)
				TIMEOUT = 86400; -- 60*60*24 secs = 1 DAY
			SELECT @IsEnabled = 1
		END

		-- run our job
		EXEC (@ScheduledSql)
		
		SELECT @LastRunOK = 1
	END TRY
	BEGIN CATCH		
		SELECT @IsEnabled = 0
		
		INSERT INTO ScheduledJobsErrors (
				ErrorLine, ErrorNumber, ErrorMessage, 
				ErrorSeverity, ErrorState, ScheduledJobId)
		SELECT	ERROR_LINE(), ERROR_NUMBER(), 'usp_RunScheduledJob: ' + ERROR_MESSAGE(), 
				ERROR_SEVERITY(), ERROR_STATE(), @ScheduledJobId
		
		-- if an error happens end our conversation if it exists
		IF @ConversationHandle != NULL		
		BEGIN
			IF EXISTS (SELECT * FROM sys.conversation_endpoints WHERE conversation_handle = @ConversationHandle)
				END CONVERSATION @ConversationHandle
		END
			
	END CATCH;
	-- update the job status
	UPDATE	ScheduledJobs
	SET		LastRunOn = @LastRunOn,
			IsEnabled = @IsEnabled,
			LastRunOK = @LastRunOK
	WHERE	ID = @ScheduledJobId
