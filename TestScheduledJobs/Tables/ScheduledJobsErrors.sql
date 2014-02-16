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
