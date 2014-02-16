CREATE FUNCTION [dbo].[F_ISO_WEEK_OF_YEAR]
(
    @Date	datetime
)
returns		int
as
/*
Function F_ISO_WEEK_OF_YEAR returns the
ISO 8601 week of the year for the date passed.
*/
begin

declare @WeekOfYear		int

select
	-- Compute week of year as (days since start of year/7)+1
	-- Division by 7 gives whole weeks since start of year.
	-- Adding 1 starts week number at 1, instead of zero.
	@WeekOfYear =
	(datediff(dd,
	-- Case finds start of year
	case
	when	NextYrStart <= @date
	then	NextYrStart
	when	CurrYrStart <= @date
	then	CurrYrStart
	else	PriorYrStart
	end,@date)/7)+1
from
	(
	select
		-- First day of first week of prior year
		PriorYrStart =
		dateadd(dd,(datediff(dd,-53690,dateadd(yy,-1,aa.Jan4))/7)*7,-53690),
		-- First day of first week of current year
		CurrYrStart =
		dateadd(dd,(datediff(dd,-53690,aa.Jan4)/7)*7,-53690),
		-- First day of first week of next year
		NextYrStart =
		dateadd(dd,(datediff(dd,-53690,dateadd(yy,1,aa.Jan4))/7)*7,-53690)
	from
		(
		select
			--Find Jan 4 for the year of the input date
			Jan4	= 
			dateadd(dd,3,dateadd(yy,datediff(yy,0,@date),0))
		) aa
	) a

return @WeekOfYear

end
