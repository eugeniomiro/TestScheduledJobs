CREATE SERVICE [//ScheduledJobService] 
    AUTHORIZATION dbo
    ON QUEUE ScheduledJobQueue ([//ScheduledJobContract])