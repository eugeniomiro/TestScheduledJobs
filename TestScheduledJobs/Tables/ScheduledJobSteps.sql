CREATE TABLE [dbo].[ScheduledJobSteps]
(
    ID INT IDENTITY(1,1),
    ScheduledJobId INT NOT NULL,	
    StepName NVARCHAR(256) NOT NULL DEFAULT (''), 
    SqlToRun NVARCHAR(MAX) NOT NULL, -- sql statement to run
    RetryOnFail BIT NOT NULL DEFAULT (0), -- do we wish to retry the job step on failure
    RetryOnFailTimes INT NOT NULL DEFAULT (0), -- if we do how many times do we wish to retry it
    DurationInSeconds DECIMAL(14,4) DEFAULT (0), -- duration of the step with all retries 
    CreatedOn DATETIME NOT NULL DEFAULT GETUTCDATE(),
    FinishedOn DATETIME
)