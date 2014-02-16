DECLARE @JobScheduleId INT, @ScheduledJobId INT, @validFrom DATETIME, @ScheduledJobStepId INT, @secondsOffset INT, @NextRunOn DATETIME
SELECT	@validFrom = GETUTCDATE(), -- the job is valid from current UTC time
         -- run the job 2 minutes after the validFrom time. 
         -- we need the offset in seconds from midnight of that day for all jobs
        @secondsOffset = 28800, -- set the job time time to 8 in the morning of the selected day
        @NextRunOn = DATEADD(n, 1, @validFrom) -- set next run for once only job to 1 minute from now

-- SIMPLE RUN ONCE SCHEDULING EXAMPLE
-- add new "run once" scheduled job 
EXEC usp_AddScheduledJob @ScheduledJobId OUT, 'test job', @validFrom, -1, @NextRunOn
-- add just one simple step for our job
EXEC usp_AddScheduledJobStep @ScheduledJobStepId OUT, @ScheduledJobId, 'EXEC sp_updatestats', 'step 1'
-- start the scheduled job
EXEC usp_StartScheduledJob @ScheduledJobId 

-- SIMPLE DAILY SCHEDULING EXAMPLE
-- run the job daily
EXEC usp_AddJobSchedule @JobScheduleId OUT,
                        @RunAtInSecondsFromMidnight = @secondsOffset,
                        @FrequencyType = 1  -- run every day                      
-- add new scheduled job 
EXEC usp_AddScheduledJob @ScheduledJobId OUT, 'test job', @validFrom, @JobScheduleId
DECLARE @backupSQL NVARCHAR(MAX)
SELECT  @backupSQL = N'DECLARE @backupTime DATETIME, @backupFile NVARCHAR(512); 
                          SELECT @backupTime = GETDATE(), 
                                 @backupFile = ''C:\Program Files\Microsoft SQL Server\MSSQL.1\MSSQL\Backup\AdventureWorks_'' + 
                                               replace(replace(CONVERT(NVARCHAR(25), @backupTime, 120), '' '', ''_''), '':'', ''_'') + 
                                               N''.bak''; 
                          BACKUP DATABASE AdventureWorks TO DISK = @backupFile;'

EXEC usp_AddScheduledJobStep @ScheduledJobStepId OUT, @ScheduledJobId, @backupSQL, 'step 1'
-- start the scheduled job
EXEC usp_StartScheduledJob @ScheduledJobId 

-- COMPLEX WEEKLY ABSOLUTE SCHEDULING EXAMPLE
-- run the job on every tuesday, wednesday, friday and sunday of every second week
EXEC usp_AddJobSchedule @JobScheduleId OUT,
                        @RunAtInSecondsFromMidnight = @secondsOffset,
                        @FrequencyType = 2, -- weekly frequency type
                        @Frequency = 2, -- run every every 2 weeks,
                        @AbsoluteSubFrequency = '2,3,5,7' -- run every Tuesday(2), Wednesday(3), Friday(5) and Sunday(7)	
-- add new scheduled job 
EXEC usp_AddScheduledJob @ScheduledJobId OUT, 'test job', @validFrom, @JobScheduleId
-- add three steps for our job
EXEC usp_AddScheduledJobStep @ScheduledJobStepId OUT, @ScheduledJobId, 'EXEC sp_updatestats', 'step 1'
EXEC usp_AddScheduledJobStep @ScheduledJobStepId OUT, @ScheduledJobId, 'DBCC CHECKDB', 'step 2'
EXEC usp_AddScheduledJobStep @ScheduledJobStepId OUT, @ScheduledJobId, 'select 1,', 'step 3 will fail', 1, 2 -- retry on fail 2 times
-- start the scheduled job
EXEC usp_StartScheduledJob @ScheduledJobId 

-- COMPLEX RELATIVE SCHEDULING SCHEDULING EXAMPLE
DECLARE @relativeWhichDay INT, @relativeWhatDay INT
SELECT	@relativeWhichDay = 4, -- 1 = First, 2 = Second, 3 = Third, 4 = Fourth, 5 = Last
        @relativeWhatDay = 3 -- 1 = Monday, 2 = Tuesday, ..., 7 = Sunday, -1 = Day
-- run the job on the 4th monday of every month 
EXEC usp_AddJobSchedule @JobScheduleId OUT,
                        @RunAtInSecondsFromMidnight = @secondsOffset, -- int
                        @FrequencyType = 3, -- monthly frequency type
                        @Frequency = 1, -- run every month,
                        @AbsoluteSubFrequency = NULL, -- no aboslute frequence if relative is set
                        @MontlyRelativeSubFrequencyWhich = @relativeWhichDay,
                        @MontlyRelativeSubFrequencyWhat = @relativeWhatDay
/*
some more relative monthly scheduling examples
run on:
the first day of the month:
  - @MontlyRelativeSubFrequencyWhich = 1, @MontlyRelativeSubFrequencyWhat = -1
the third thursday of the month:
  - @MontlyRelativeSubFrequencyWhich = 3, @MontlyRelativeSubFrequencyWhat = 4
the last sunday of the month:
  - @MontlyRelativeSubFrequencyWhich = 5, @MontlyRelativeSubFrequencyWhat = 7
the second wedensday of the month:
  - @MontlyRelativeSubFrequencyWhich = 2, @MontlyRelativeSubFrequencyWhat = 3
*/
-- add new scheduled job 
EXEC usp_AddScheduledJob @ScheduledJobId OUT, 'test job', @validFrom, @JobScheduleId
-- add just one simple step for our job
EXEC usp_AddScheduledJobStep @ScheduledJobStepId OUT, @ScheduledJobId, 'EXEC sp_updatestats', 'step 1'
-- start the scheduled job
EXEC usp_StartScheduledJob @ScheduledJobId 

-- SEE WHAT GOING ON WITH OUR JOBS
-- show the currently active conversations
-- look at dialog_timer column (in UTC time) to see when will the job be run next
SELECT GETUTCDATE(), dialog_timer, * FROM sys.conversation_endpoints
-- shows the number of currently executing activation procedures
SELECT * FROM sys.dm_broker_activated_tasks
-- see how many unreceived messages are still in the queue. should be 0 when no jobs are running
SELECT * FROM ScheduledJobQueue WITH (NOLOCK)
-- view our scheduled jobs' statuses
SELECT * FROM ScheduledJobs  WITH (NOLOCK)
SELECT * FROM ScheduledJobSteps WITH (NOLOCK)
SELECT * FROM JobSchedules  WITH (NOLOCK)
SELECT * FROM SchedulingErrors WITH (NOLOCK)
