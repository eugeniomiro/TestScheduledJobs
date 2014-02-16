CREATE PROCEDURE [dbo].[usp_AddScueduledJobStep]
(	
    @ScheduledJobStepId INT OUT,	
    @ScheduledJobId INT, 
    @SqlToRun NVARCHAR(MAX),
    @StepName NVARCHAR(256) = '', 
    @RetryOnFail BIT = 0,
    @RetryOnFailTimes INT = 0 	
)
AS

    INSERT INTO ScheduledJobSteps(ScheduledJobId, StepName, SqlToRun, RetryOnFail, RetryOnFailTimes)
    SELECT @ScheduledJobId, @StepName, @SqlToRun, @RetryOnFail, @RetryOnFailTimes 
    
    SELECT @ScheduledJobStepId = SCOPE_IDENTITY()