CREATE PROCEDURE [dbo].[usp_AddScheduledJob]
(
    @ScheduledJobId INT OUT,
    @JobName        NVARCHAR(256),
    @ValidFrom      DATETIME,
    @JobScheduleId  INT             = -1,
    @NextRunOn      DATETIME        = NULL
)
AS
    IF @JobScheduleId > 0 AND @NextRunOn IS NOT NULL 
        RAISERROR ('Job Schedule can NOT be set for "Run Once" job types. "Run Once" job type is indicated by setting parameters @NextRunOn to a future date and @JobScheduleId to -1 (default value).', 16, 1); 
    
    IF @NextRunOn IS NULL 
    -- calculate the next run time from job schedule
    BEGIN		
        SELECT	-- get the valid from start time to calculate from 
                @NextRunOn = CASE WHEN @ValidFrom > GETUTCDATE() THEN @ValidFrom ELSE GETUTCDATE() END, 
                -- get next run time based on our valid from starting time
                @NextRunOn = dbo.GetNextRunTime(@NextRunOn, @JobScheduleId)
    END
    
    IF @NextRunOn < GETUTCDATE()
        RAISERROR ('@NextRunOn parameter has to be in the future in the UTC date format.', 16, 1); 

    
    INSERT INTO ScheduledJobs(JobScheduleId, JobName, ValidFrom, NextRunOn)
    VALUES (@JobScheduleId, @JobName, @ValidFrom, @NextRunOn)
    
    SELECT @ScheduledJobId = SCOPE_IDENTITY()