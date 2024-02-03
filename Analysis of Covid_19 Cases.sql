
use Learnbay_project;


select * from Covid_Death;
-----Formatting date function----


SELECT REPLACE(data_period_end,'/','-') as formatteddata_end_period from Covid_Death;
SELECT REPLACE(data_period_start,'/','-') as formatteddata_start_period from Covid_Death;

SELECT ISDATE('10-24-2021');



-------------Replacing null values with 0-----------------------------
UPDATE Covid_Death
SET COVID_deaths=0
WHERE COVID_deaths IS NULL;


UPDATE Covid_Death
SET COVID_pct_of_total=0
WHERE COVID_pct_of_total IS NULL;

UPDATE Covid_Death
SET pct_change_wk=0
WHERE pct_change_wk IS NULL;

UPDATE Covid_Death
SET pct_diff_wk=0
WHERE pct_diff_wk IS NULL;


UPDATE Covid_Death
SET crude_COVID_rate=0
WHERE crude_COVID_rate IS NULL;

UPDATE Covid_Death
SET aa_COVID_rate=0
WHERE aa_COVID_rate IS NULL;
 


UPDATE Covid_Death
SET footnote=0
WHERE footnote IS NULL;


select * from Covid_Death;

-------------------------------adding formatted date_start and date_end period to table--------------------------
Alter table Covid_Death
Add formatteddata_end_period date;

update Covid_Death
set formatteddata_end_period=CONVERT(date,data_period_end);


alter table Covid_Death
drop column formatteddata_start_period;

Alter table Covid_Death
Add formatteddata_start_period date;

update Covid_Death
set formatteddata_start_period=CONVERT(date,data_period_start);


---1)1.	Retrieve the jurisdiction residence with the highest number of COVID deaths for the latest data period end date.----

      Select
	        TOP 1 Jurisdiction_Residence, max(COVID_deaths) as 'Highest no.covid_death',formatteddata_end_period  
      From 
	        Covid_Death
	  Where 
			formatteddata_end_period=(select max(formatteddata_end_period) from Covid_Death)
	  Group by 
	        Jurisdiction_Residence,formatteddata_end_period
	  Order by 
	        max(COVID_deaths) desc ;


---2) Calculate the week-over-week percentage change in crude COVID rate for all jurisdictions and groups, sorted by the highest percentage change first.----

----Use lag function to find week over week chnage------to calculate previous week difference---------
     	  
	  WITH week_week (crude_COVID_rate, Jurisdiction_Residence, Groups, percentchange) 
	  AS (
	  SELECT
		a.crude_COVID_rate,
		a.Jurisdiction_Residence,
		a.Groups,
		(CAST(a.crude_COVID_rate - LAG(a.crude_COVID_rate) OVER (PARTITION BY a.Jurisdiction_Residence ORDER BY a.crude_COVID_rate) AS float) / NULLIF(LAG(a.crude_COVID_rate) OVER (PARTITION BY a.Jurisdiction_Residence ORDER BY a.crude_COVID_rate), 0) * 100) AS percentchange
	  FROM
		Covid_Death a
	   )
	  SELECT
		 
		  crude_COVID_rate,
		  Jurisdiction_Residence,
		  Groups,
		  percentchange
	  FROM
	      week_week
	  Where 
	      Groups='weekly'
	  Order by  
	      percentchange desc;

 3)----3.	Retrieve the top 5 jurisdictions with the highest percentage difference in aa_COVID_rate compared to the overall crude COVID rate for the latest data period end date.----
   -------------------MAXIMUM FUNCTION OF EACH JURISDICTION-------
    Select 
	      Top 5 Jurisdiction_Residence,(max(crude_COVID_rate)-max(aa_covid_rate)) as Percentagedifference,max(formatteddata_end_period) as latest_end_period
    From 
	      Covid_Death
	Group by 
	      Jurisdiction_Residence
	Order by 
	      Percentagedifference Desc;

 4)---Calculate the average COVID deaths per week for each jurisdiction residence and group, for the latest 4 data period end dates.
    
	-----to find latest 4 data end period dates ---used rownumber function ------
	SELECT 
	      Jurisdiction_Residence,Groups,formatteddata_end_period,AVG(COVID_deaths) AS avgcountdeath
    FROM
    (
		SELECT Jurisdiction_Residence,Groups,formatteddata_end_period,COVID_deaths,
		ROW_NUMBER() OVER (PARTITION BY Jurisdiction_Residence, Groups ORDER BY formatteddata_end_period DESC) AS RowNum
		FROM Covid_Death
		WHERE Groups = 'weekly'
	) AS subquery
    WHERE
	      RowNum <= 4
    GROUP BY 
	      Jurisdiction_Residence, Groups,formatteddata_end_period;

   
5)--Retrieve the data for the latest data period end date, but exclude any jurisdictions that had zero COVID deaths and have missing values in any other column----

	Select * 
	From 
	     Covid_Death
	Where 
	     COVID_deaths != 0  and data_period_start is not null and footnote is not null and formatteddata_end_period=(select max(formatteddata_end_period) as latest_end_period
	From  
	     Covid_Death);

6)--Calculate the week-over-week percentage change in COVID_pct_of_total for all jurisdictions and groups, but only for the data period start dates after March 1, 2020.--
    
	----Used lag function to calculate week over week percentage,nullif function to remove zero division error-------------
	WITH week_week (formatteddata_start_period,COVID_pct_of_total, Jurisdiction_Residence, Groups, percentchange) 
	AS (
		SELECT a.formatteddata_start_period,a.COVID_pct_of_total,a.Jurisdiction_Residence,a.Groups,
		(CAST(a.COVID_pct_of_total - LAG(a.COVID_pct_of_total) OVER (PARTITION BY a.Jurisdiction_Residence ORDER BY a.COVID_pct_of_total) AS float) / NULLIF(LAG(a.COVID_pct_of_total) OVER (PARTITION BY a.Jurisdiction_Residence ORDER BY a.COVID_pct_of_total), 0) * 100) AS percentchange
		FROM Covid_Death a
		WHERE a.formatteddata_start_period>='2020-03-01'
        )
    SELECT 
	     formatteddata_start_period,COVID_pct_of_total,Jurisdiction_Residence,Groups,percentchange
    FROM  
	     week_week
    Order by  
	     percentchange desc;

7)---Group the data by jurisdiction residence and calculate the cumulative COVID deaths for each jurisdiction, but only up to the latest data period end date.
     select * from Covid_Death
	 where Jurisdiction_Residence='Region 1' and Groups='total';

	 Select 
	       Jurisdiction_Residence,SUM(COVID_deaths) as cumulative_death
	 From 
	       Covid_Death
	 Where 
	       formatteddata_end_period>='2020-01-04' and formatteddata_end_period<='2023-04-08' 
	 Group by 
	       Jurisdiction_Residence
	 Order by 
	       cumulative_death desc;

8)---Identify the jurisdiction with the highest percentage increase in COVID deaths from the previous week, 
  ---and provide the actual numbers of deaths for each week. This would require a subquery to calculate the previous week's deaths.

	 SELECT
	       Jurisdiction_Residence,formatteddata_start_period, formatteddata_end_period,MAX(COVID_pct_of_total) as highestperdiff,sum(COVID_deaths) AS total_deaths
     FROM  
	       Covid_Death
     WHERE 
	      DATEDIFF(ww, formatteddata_start_period, formatteddata_end_period) IN (SELECT DATEDIFF(ww, formatteddata_start_period, formatteddata_end_period) FROM Covid_Death)
     GROUP BY 
	       Jurisdiction_Residence,formatteddata_start_period,formatteddata_end_period
	 Order by 
	       highestperdiff desc;

9)----Compare the crude COVID death rates for different groups, but only for jurisdictions 
   ---where the total number of deaths exceeds a certain threshold (e.g. 100). 

   
	 SELECT 
	       Jurisdiction_Residence,Groups ,SUM(COVID_deaths) AS total_deaths,  AVG(crude_COVID_rate) AS average_crude_death_rate
     FROM 
	       Covid_Death
     WHERE 
	       Jurisdiction_Residence IN 
      (
		 SELECT Jurisdiction_Residence
		 FROM Covid_Death
		-- GROUP BY Jurisdiction_Residence
		-- HAVING SUM(COVID_deaths) >= 10000
	  )
     GROUP BY 
	        Jurisdiction_Residence,Groups
	 Having 
	        sum(COVID_deaths) >= 1000
     ORDER BY
	        average_crude_death_rate DESC;

10)----Stored procedure---
   --- takes in a date range and calculates the average weekly percentage change in COVID deaths for each jurisdiction.
   --- The procedure should return the average weekly percentage change along with the jurisdiction and date range as output.

-------------------Island and Gap issue --------

------------Without using avg(percentweekchange)-------------------

--------------STORED_PROCEDURE----------------------- 

drop procedure inform;


create procedure inform
   (@formatteddata_start_period as date ,@formatteddata_end_period as date)
     As
     Begin
SELECT
  Jurisdiction_Residence,
  IslandId,
  MAX (formatteddata_start_period) AS IslandStartDate,
  MIN (formatteddata_end_period) AS IslandEndDate
FROM
  (SELECT
   *,
   CASE WHEN Grouping.PreviousEndDate >= formatteddata_start_period THEN 0 ELSE 1 END AS IslandStartInd,
   SUM (CASE WHEN Grouping.PreviousEndDate >= formatteddata_start_period THEN 0 ELSE 1 END) OVER (ORDER BY Grouping.RN) AS IslandId
   FROM
   (
    SELECT
    ROW_NUMBER () OVER (ORDER BY Jurisdiction_Residence, formatteddata_start_period, formatteddata_end_period) AS RN,
    Jurisdiction_Residence,
    formatteddata_start_period,
    formatteddata_end_period,
    MAX(formatteddata_end_period) OVER (PARTITION BY Jurisdiction_Residence ORDER BY formatteddata_start_period, formatteddata_end_period ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS PreviousEndDate
    FROM
    Covid_Death
   ) Grouping
  ) Islands
Where formatteddata_start_period>=@formatteddata_start_period and formatteddata_end_period<=@formatteddata_end_period
GROUP BY
  Jurisdiction_Residence,
  IslandId
ORDER BY
  Jurisdiction_Residence, 
  IslandStartDate
  
End;
Execute  inform '2022-01-01','2023-02-15';                                                                 



  -----------------With Averagepercent week change------------------------

  drop procedure inform;

Create procedure inform
   (@formatteddata_start_period as date ,@formatteddata_end_period as date)
     As
     Begin
	 SELECT
	  Jurisdiction_Residence,avg(pct_change_wk) as 'Avgpercentageweek',
	  IslandId,
	  MAX (formatteddata_start_period) AS IslandStartDate,
	  MIN (formatteddata_end_period) AS IslandEndDate
	 FROM
	  (SELECT
	   *,
	   CASE WHEN Grouping.PreviousEndDate >= formatteddata_start_period THEN 0 ELSE 1 END AS IslandStartInd,
	   SUM (CASE WHEN Grouping.PreviousEndDate >= formatteddata_start_period THEN 0 ELSE 1 END) OVER (ORDER BY Grouping.RN) AS IslandId
	  FROM
	   (SELECT
		ROW_NUMBER () OVER (ORDER BY Jurisdiction_Residence,pct_change_wk, formatteddata_start_period, formatteddata_end_period) AS RN,
		Jurisdiction_Residence,
		formatteddata_start_period,
		formatteddata_end_period,
		pct_change_wk,
		MAX(formatteddata_end_period) OVER (PARTITION BY Jurisdiction_Residence ORDER BY pct_change_wk,formatteddata_start_period, formatteddata_end_period ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) AS PreviousEndDate
		FROM
		Covid_Death
	   ) Grouping
	  ) Islands
	  where formatteddata_start_period>=@formatteddata_start_period and formatteddata_end_period<=@formatteddata_end_period
	 GROUP BY
	  Jurisdiction_Residence,
	  IslandId
	 ORDER BY
	  Jurisdiction_Residence, 
	  IslandStartDate
  
	  End;


	  Execute  inform '2022-01-01','2023-02-15';  




  -----function----
Drop function GetAverageCrudeCOVIDRate;

CREATE FUNCTION GetAverageCrudeCOVIDRate(@Jurisdiction NVARCHAR(255))
RETURNS float
AS
Begin
    DECLARE @AvgCrudeCOVIDRate float;
    
    SELECT @AvgCrudeCOVIDRate =  AVG(crude_COVID_rate)
    FROM Covid_Death
    WHERE Jurisdiction_Residence = @Jurisdiction
	group by Jurisdiction_Residence ;
    
    RETURN @AvgCrudeCOVIDRate;
end;


select dbo.GetAverageCrudeCOVIDRate ('New York') as 'AvgCrudeCovidRate';




---------------------------------Function and stored procedure------------------------
Drop function Compare_rate; 
 
Create function Compare_rate(@jurisdiction NVARCHAR(255))
Returns float
As
Begin 
	Declare @AvgPercentWeek float;

	Select 
		  @AvgPercentWeek=avg(pct_change_wk)
    From
	     Covid_Death
    Where 
	     Jurisdiction_Residence=@Jurisdiction
    Group by 
	     Jurisdiction_Residence;
	Return @AvgPercentWeek
End;

select dbo.Compare_rate ('New York') as 'AvgPercentageweek';
  


  Drop procedure Compare_both;
  
  Create procedure Compare_both 
     (@jurisdiction nvarchar(255))
  As
  Begin
       Select Jurisdiction_Residence, dbo.Compare_rate(@jurisdiction) as 'AvgPercentWeek',dbo.GetAverageCrudeCOVIDRate(@jurisdiction) as 'AvgCrudeCovidRate'
	   From Covid_Death
	   Where Jurisdiction_Residence=@jurisdiction
	   Group by Jurisdiction_Residence
  End;
   
   execute Compare_both 'New York';