CREATE TABLE ScheduledJobs
(
    ID INT IDENTITY(1,1), 
    JobScheduleId INT NOT NULL DEFAULT (-1), -- -1 for Run Once JobTypes
    ConversationHandle UNIQUEIDENTIFIER NULL,
    JobName NVARCHAR(256) NOT NULL DEFAULT (''),
    ValidFrom DATETIME NOT NULL,
    LastRunOn DATETIME, 
    NextRunOn DATETIME, 
    IsEnabled BIT NOT NULL DEFAULT (0),
    CreatedOn DATETIME NOT NULL DEFAULT GETUTCDATE()
)