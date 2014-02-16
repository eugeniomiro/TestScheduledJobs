CREATE TABLE SchedulingErrors
(
    ID INT IDENTITY(1, 1) PRIMARY KEY,
    ScheduledJobId INT, 
    ScheduledJobStepId INT,	
    ErrorProcedure NVARCHAR(256),
    ErrorLine INT,
    ErrorNumber INT,
    ErrorMessage NVARCHAR(2048),
    ErrorSeverity INT,
    ErrorState INT,	
    ErrorDate DATETIME NOT NULL DEFAULT GETUTCDATE()
)