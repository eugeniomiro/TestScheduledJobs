CREATE QUEUE ScheduledJobQueue 
	WITH STATUS = ON, 
	ACTIVATION (	
		PROCEDURE_NAME = usp_RunScheduledJob,
		MAX_QUEUE_READERS = 20, -- we expect max 20 jobs to start simultaneously
		EXECUTE AS 'dbo' );
