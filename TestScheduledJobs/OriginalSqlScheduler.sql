-- sample from
-- http://www.sqlteam.com/article/scheduling-jobs-in-sql-server-express

USE master
GO
IF EXISTS(SELECT * FROM sys.databases WHERE name = 'TestScheduledJobs')
	DROP DATABASE TestScheduledJobs
GO
CREATE DATABASE TestScheduledJobs
GO
ALTER DATABASE TestScheduledJobs SET ENABLE_BROKER
GO

USE TestScheduledJobs
GO

IF object_id('ScheduledJobs') IS NOT NULL
	DROP TABLE ScheduledJobs

GO	
CREATE TABLE ScheduledJobs
(
	ID INT IDENTITY(1,1), 
	ScheduledSql nvarchar(max) NOT NULL, 
	FirstRunOn datetime NOT NULL, 
	LastRunOn datetime, 
	LastRunOK BIT NOT NULL DEFAULT (0), 
	IsRepeatable BIT NOT NULL DEFAULT (0), 
	IsEnabled BIT NOT NULL DEFAULT (0), 
	ConversationHandle uniqueidentifier NULL
)
GO

IF object_id('ScheduledJobsErrors') IS NOT NULL
	DROP TABLE ScheduledJobsErrors	
CREATE TABLE ScheduledJobsErrors
(
	Id BIGINT IDENTITY(1, 1) PRIMARY KEY,
	ErrorLine INT,
	ErrorNumber INT,
	ErrorMessage NVARCHAR(MAX),
	ErrorSeverity INT,
	ErrorState INT,
	ScheduledJobId INT,
	ErrorDate DATETIME NOT NULL DEFAULT GETUTCDATE()
)

IF OBJECT_ID('usp_RemoveScheduledJob') IS NOT NULL
	DROP PROC usp_RemoveScheduledJob

GO
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

GO
IF OBJECT_ID('usp_AddScheduledJob') IS NOT NULL
	DROP PROC usp_AddScheduledJob

GO
CREATE PROC usp_AddScheduledJob
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

GO
IF OBJECT_ID('usp_RunScheduledJob') IS NOT NULL
	DROP PROC usp_RunScheduledJob

GO
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
GO

IF EXISTS(SELECT * FROM sys.services WHERE NAME = N'//ScheduledJobService')
	DROP SERVICE [//ScheduledJobService]

IF EXISTS(SELECT * FROM sys.service_queues WHERE NAME = N'ScheduledJobQueue')
	DROP QUEUE ScheduledJobQueue

IF EXISTS(SELECT * FROM sys.service_contracts  WHERE NAME = N'//ScheduledJobContract')
	DROP CONTRACT [//ScheduledJobContract]

GO
CREATE CONTRACT [//ScheduledJobContract]
	([http://schemas.microsoft.com/SQL/ServiceBroker/DialogTimer] SENT BY INITIATOR)

CREATE QUEUE ScheduledJobQueue 
	WITH STATUS = ON, 
	ACTIVATION (	
		PROCEDURE_NAME = usp_RunScheduledJob,
		MAX_QUEUE_READERS = 20, -- we expect max 20 jobs to start simultaneously
		EXECUTE AS 'dbo' );

CREATE SERVICE [//ScheduledJobService] 
	AUTHORIZATION dbo
	ON QUEUE ScheduledJobQueue ([//ScheduledJobContract])

--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
-- T E S T
--------------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------------------------
GO
DECLARE @ScheduledSql nvarchar(max), @RunOn datetime, @IsRepeatable BIT
SELECT	@ScheduledSql = N'DECLARE @backupTime DATETIME, @backupFile NVARCHAR(512); 
						  SELECT @backupTime = GETDATE(), 
						         @backupFile = ''C:\TestScheduledJobs_'' + 
						                       replace(replace(CONVERT(NVARCHAR(25), @backupTime, 120), '' '', ''_''), '':'', ''_'') + 
						                       N''.bak''; 
						  BACKUP DATABASE TestScheduledJobs TO DISK = @backupFile;',
		@RunOn = dateadd(s, 30, getdate()), 
		@IsRepeatable = 0

EXEC usp_AddScheduledJob @ScheduledSql, @RunOn, @IsRepeatable
GO

DECLARE @ScheduledSql nvarchar(max), @RunOn datetime, @IsRepeatable BIT
SELECT	@ScheduledSql = N'select 1 where 1=1',
		@RunOn = dateadd(s, 30, getdate()), 
		@IsRepeatable = 1

EXEC usp_AddScheduledJob @ScheduledSql, @RunOn, @IsRepeatable
GO

DECLARE @ScheduledSql nvarchar(max), @RunOn datetime, @IsRepeatable BIT
SELECT	@ScheduledSql = N'EXEC sp_updatestats;', 
		@RunOn = dateadd(s, 30, getdate()), 
		@IsRepeatable = 0

EXEC usp_AddScheduledJob @ScheduledSql, @RunOn, @IsRepeatable
GO

--EXEC usp_RemoveScheduledJob 4
--EXEC usp_RemoveScheduledJob 5
--EXEC usp_RemoveScheduledJob 3
GO

-- show the currently active conversations. 
-- Look at dialog_timer column to see when will the job be run next
SELECT * FROM sys.conversation_endpoints
-- shows the number of currently executing activation procedures
SELECT * FROM sys.dm_broker_activated_tasks
-- see how many unreceived messages are still in the queue. 
-- should be 0 when no jobs are running
SELECT * FROM ScheduledJobQueue with (nolock)
-- view our scheduled jobs' statuses
SELECT * FROM ScheduledJobs  with (nolock)
-- view any scheduled jobs errors that might have happend
SELECT * FROM ScheduledJobsErrors  with (nolock)


select getdate() as 'Now', dateadd(s, 30, getdate()) as 'Delayed'