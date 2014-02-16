CREATE QUEUE ScheduledJobQueue 
    WITH STATUS = ON, 
    ACTIVATION (	
        PROCEDURE_NAME = usp_RunScheduledJob,
        MAX_QUEUE_READERS = 20,
        EXECUTE AS SELF );