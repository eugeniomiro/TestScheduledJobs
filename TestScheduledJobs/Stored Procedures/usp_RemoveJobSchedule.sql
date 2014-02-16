CREATE PROCEDURE [dbo].[usp_RemoveJobSchedule]
(	
    @JobScheduleId INT
)
AS
    IF EXISTS (SELECT * FROM ScheduledJobs WHERE JobScheduleId = @JobScheduleId)
        RAISERROR ('Job schedule ID %d is used by Scheduled Jobs. Please delete referencing Scheduled jobs before deleting Job Schedule.', 16, 1, @JobScheduleId ); 
        
    DELETE JobSchedules
    WHERE id = @JobScheduleId
