CREATE PROCEDURE [dbo].[usp_RemoveScheduledJobStep]
(	
    @ScheduledJobStepId INT
)
AS
    DELETE ScheduledJobSteps
    WHERE id = @ScheduledJobStepId
GO

