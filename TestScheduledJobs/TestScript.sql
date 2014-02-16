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
