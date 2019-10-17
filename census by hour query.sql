
/*
Purpose: To comptue the census by provider and nursing unit at Richmond hospital from CapPlan given a specified hour for a specified date range
Author: Hans Aisake
Date Created: June 6, 2019
Date Modified:
Comments:
	The base idea came from Peter's query. I removed the classification as Hospitalist, GIM, etc... from this query.
	Those linkages have to be found elsewhere in other databses like DSSI if anywhere at all.

	Taking about 7 minutes to run these days.

 */


SELECT [AssignmentID]
      ,[EncounterID]
      ,[AssignmentDate] as AdmitDate
      ,[lu_WardID] as Unit
      ,case when [lu_SpecialtyID] ='ALC' then 'ALC' 
                when [lu_SpecialtyID]='TCU' then 'TCU' 
                when [lu_SpecialtyID]='SSL' then 'SSLTC' 
                 else 'ACUTE' end as ALCFlag
      ,[lu_SpecialtyID] as DrService
      ,'P'+isnull([lu_HealthCareProfessionalID],0) as DrCode
	  ,isnull([lu_RoomID]+'-'+[lu_BedID],'UNKNOWN') as Bed
     , case when 'P'+[lu_HealthCareProfessionalID] in (@Hospitalists) and [lu_WardID]='R4N' then 'P'+[lu_HealthCareProfessionalID] + '^^R4N' else 'P'+isnull([lu_HealthCareProfessionalID],0) end as LookupDrCodeUnit
FROM CapPlan_LGH.[dbo].[Assignments]
where assignmentenddate is null 
and lu_wardid not like 'en[0-9]%'
and lu_wardid not like 'es[0-9]%'
and lu_wardid not in ('ASC','ENDO','NSH','MI')
--and [lu_SpecialtyID]  in (@lu_SpecialtyID)
--and [lu_SpecialtyID] not in ('ssl','tcu')

GO


/* we have admissions everyday so we can use the admission table to get a list of dates without the CTE loop. This is easier for R to run. */
IF OBJECT_ID('tempdb.dbo.#dates') is not null DROP TABLE #dates;
GO

SELECT distinct CONVERT(date, [AdmissionDate]) as [date] 
INTO #dates
FROM [CapPlan_RHS].[dbo].[Admissions]
WHERE CONVERT(date, [AdmissionDate])  BETWEEN DATEADD(year, -3, CONVERT(date, GETDATE())) AND GETDATE()
;
GO

IF OBJECT_ID('tempdb.dbo.#dates2') is not null DROP TABLE #dates2;
GO

SELECT DATEADD(hour, 5, CONVERT(datetime, [date]) ) as 'Date_withHour' /* change the 7 to the hour of the day you want */
, [date]
INTO #dates2
FROM #dates
;
GO


/*find the census for each provider on the dates*/
SELECT Y.[Date]
, S.CLASS
, S.LOCUM_FLAG
, 5 as 'CensusHour'
, case when [lu_SpecialtyID]='ALC' then 'ALC' 
	   else 'Acute' 
END as ALCFlag
, [lu_HealthCareProfessionalID] as 'DrCode'
, S.DoctorName
, COUNT(1) as 'Census'
FROM [CapPlan_RHS].[dbo].[Assignments] as X
INNER JOIN #dates2 as Y
ON Y.[Date_withHour] BETWEEN AssignmentDate AND ISNULL(AssignmentEndDate,'2050-01-01')	/* filter to days relevant between @start and @end and assign a date for computing census */
INNER JOIN #service as S
ON CAST(X.[lu_HealthCareProfessionalID] as varchar(10)) =S.DoctorCode
where LEFT(X.lu_wardid,1)!='m'	/*ignore minoru*/
and X.lu_wardid not in ('rhbcb','ramb') /*ignore birth center and ambulatory care*/
GROUP BY Y.[Date]
, S.CLASS
, S.LOCUM_FLAG
, case when [lu_SpecialtyID]='ALC' then 'ALC' 
	   else 'Acute' 
END
, [lu_HealthCareProfessionalID]
, S.DoctorName
;



 
