CREATE PROCEDURE [dbo].[usp_RemoveScheduledJob]
(
    @ScheduledJobId INT
)
AS
    SET xact_abort ON
    BEGIN TRAN
    DELETE FROM ScheduledJobSteps WHERE ScheduledJobId = @ScheduledJobId
    DELETE FROM ScheduledJobs WHERE id = @ScheduledJobId
    COMMIT
GO

