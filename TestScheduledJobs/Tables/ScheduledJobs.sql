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