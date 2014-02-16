CREATE TABLE JobSchedules
(
    ID INT IDENTITY(1, 1) PRIMARY KEY,
    FrequencyType INT NOT NULL CHECK (FrequencyType IN (1, 2, 3)), -- , daily = 1, weekly = 2, monthly = 3. "Run once" jobs don't have a job schedule 
    Frequency INT NOT NULL DEFAULT(1) CHECK (Frequency BETWEEN 1 AND 100),
    AbsoluteSubFrequency VARCHAR(100), -- '' if daily, '1,2,3,4,5,6,7' day of week if weekly, '1,2,3,...,28,29,30,31' if montly	
    MontlyRelativeSubFrequencyWhich INT, 
    MontlyRelativeSubFrequencyWhat INT,
    RunAtInSecondsFromMidnight INT NOT NULL DEFAULT(0) CHECK (RunAtInSecondsFromMidnight BETWEEN 0 AND 84599), -- 0-84599 = 1 day in seconds
    CONSTRAINT CK_AbsoluteSubFrequency CHECK 
                ((FrequencyType = 1 AND ISNULL(AbsoluteSubFrequency, '') = '') OR -- daily check
                 (FrequencyType = 2 AND LEN(AbsoluteSubFrequency) > 0) OR -- weekly check (days of week CSV)
                 (FrequencyType = 3 AND (LEN(AbsoluteSubFrequency) > 0 -- monthly absolute option (days of month CSV)
                                         AND MontlyRelativeSubFrequencyWhich IS NULL 
                                         AND MontlyRelativeSubFrequencyWhat IS NULL)
                                    OR ISNULL(AbsoluteSubFrequency, '') = '') -- monthly relative option
                ), 
    CONSTRAINT MontlyRelativeSubFrequencyWhich CHECK -- only allow values if frequency type is monthly
                                              (MontlyRelativeSubFrequencyWhich IS NULL OR 
                                              (FrequencyType = 3 AND 
                                               AbsoluteSubFrequency IS NULL AND 
                                               MontlyRelativeSubFrequencyWhich IN (1,2,3,4,5)) -- 1st-4th, 5=Last
                                              ), 
    CONSTRAINT MontlyRelativeSubFrequencyWhat CHECK  -- only allow values if frequency type is monthly
                                              (MontlyRelativeSubFrequencyWhich IS NULL OR 
                                              (FrequencyType = 3 AND 
                                                AbsoluteSubFrequency IS NULL AND
                                                MontlyRelativeSubFrequencyWhich IN (1,2,3,4,5,6,7,-1)) -- 1=Mon to 7=Sun, -1=Day
                                              )
)
