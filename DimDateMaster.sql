/******
Copyright (C) 2003
Created, enhanced, and edited beginning in 2003.
By Dave Rodabaugh at Atlas Analytics. drodabaugh@AtlasAnalytics.com
And Chris Ciappa as Atlas Analytics.  cciappa@AtlasAnalytics.com, cciappa@gmail.com


UPDATED AND CONSOLIDATED
4/1/2010 Chris Ciappa
12/21/2014  Chris Ciappa

   This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see https://www.gnu.org/licenses/.


This script will create all necessary relational objects for a working Date Dimension
It will also populate the DateMaster dimension table with data as well as creating a
view to use in your OLAP solution which will contain only dates through today's date
and which begin when you choose.

The ability to create fiscal dates is also available, but is not initially populated and needs to be run manually after this script if you desire to have a fiscal calendar as
well.  In order to populate the Fiscal Date data you should open, read, and thoroughly
understand the documentation contained in spUpdateFiscalYearColumnsDateMaster which is created by this script.


SPECIAL NOTE:
This script will also attempt to create a job and schedule to update the "IsDateActive"
column in the DateMaster table if you choose to do so.  It will do this utilizing the MSDB datase where the jobs and
and schedule information are stored.  All you need to do is uncomment the bottom section of
this script and also edit the name of the database and the login in the create job portion of
this script.  Currently, this code is commented out.
EX.
@database_name=N'YOURDATABASEFORDATEDIMENSION'
@owner_login_name=N'MSCORP\cciap01'


Please read and understand this script before executing.  Comments are extensive and describe EVERYTHING that this
script is doing and why.

Objects this script will create the following objects you must first create the schema [DW] else edit the schema
on all objects and code in this script.  Only objects with a star "*" by their names below are required to remain
for use of this data warehouse date solution once the table is fully populated.  The rest may be deleted upon
completion of this script and as desired population of the fiscal year data previously mentioned.  However, some
of the functions may be useful moving forward.


FUNCTIONS
dbo.[fnFindFYFirstDate]
dbo.[fnFindFYLastDateOfYear]
dbo.[fnFindFYMonthOfYearNumber]
dbo.[fnFindFYQuarterOfYearNumber]
dbo.[fnFindFYQuarterStartDate]
dbo.[fnFindFYYearName]

STORED PROCS
dbo.[spBuildDateMaster]
dbo.[spUpdateFiscalYearColumnsDateMaster]
dbo.[spUpdateDateMasterActiveFlag]  *

TABLES
dbo.[DateMaster] *

VIEWS
dbo.[vwDimDate] *

JOB
[UpdateDateMaster] Commented out at this time, uncomment as desired

UPDATED AND CONSOLIDATED
4/1/2010 Chris Ciappa

December 2014  Chris Ciappa
Updated to use DW Schema for object creation and renamed from "TimeMaster" to "DateMaster"

******/

/****** Object:  UserDefinedFunction dbo.[fnFindFYFirstDate]    Script Date: 03/24/2010 14:14:30 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.[fnFindFYFirstDate]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION dbo.[fnFindFYFirstDate]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.[fnFindFYFirstDate]
(
@FYMonthOneInNativeYear nvarchar(3),
@MonthOfYearNumber		smallint,
@FYStartMonth			nvarchar(3),
@YearName				nchar(4)
)
RETURNS datetime
WITH EXECUTE AS CALLER
AS
BEGIN
DECLARE @FYStartMonthCalendarYear nchar(4)
DECLARE	@FYFirstDate	datetime

IF	@FYMonthOneInNativeYear = 'Yes'
SET @FYStartMonthCalendarYear = dbo.fnFindFYYearName(
		@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
		@MonthOfYearNumber,			-- parameter @MonthOfYearNumber
		@FYStartMonth,				-- parameter @FYStartMonth
		@YearName)					-- parameter @YearName

IF	@FYMonthOneInNativeYear = 'No'
SET @FYStartMonthCalendarYear = dbo.fnFindFYYearName(
		@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
		@MonthOfYearNumber,			-- parameter @MonthOfYearNumber
		@FYStartMonth,				-- parameter @FYStartMonth
		@YearName) - 1				-- parameter @YearName

SET @FYFirstDate = cast(@FYStartMonth + '/1/' + @FYStartMonthCalendarYear AS datetime)

RETURN(@FYFirstDate)
END;

GO

/****** Object:  UserDefinedFunction dbo.[fnFindFYLastDateOfYear]    Script Date: 03/24/2010 14:14:53 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.[fnFindFYLastDateOfYear]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION dbo.[fnFindFYLastDateOfYear]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.[fnFindFYLastDateOfYear]
(
@MonthOfYearNumber		smallint,
@FYStartMonth			nvarchar(2),
@FYMonthOffset			smallint,
@MonthID				int
)
RETURNS datetime
WITH EXECUTE AS CALLER
AS
BEGIN
DECLARE @FYLastDateOfYear			datetime
DECLARE @FYMonthOfYearNumber		smallint
DECLARE	@FYLastMonthOfYearCYMonthID	int

SET @FYMonthOfYearNumber = dbo.fnFindFYMonthOfYearNumber (
		@MonthOfYearNumber,
		@FYStartMonth,
		@FYMonthOffset ) -- Item (1)

SET @FYLastMonthOfYearCYMonthID =
				(12 - @FYMonthOfYearNumber) + @MonthID -- Item (2)

SET @FYLastDateOfYear =
	(SELECT max(ActualDate) FROM dimTime
	WHERE dimTime.MonthId = @FYLastMonthOFYearCYMonthID) -- Item (3)

RETURN(@FYLastDateOfYear)
END;
GO


/****** Object:  UserDefinedFunction dbo.[fnFindFYMonthOfYearNumber]    Script Date: 03/24/2010 14:15:31 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.[fnFindFYMonthOfYearNumber]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION dbo.[fnFindFYMonthOfYearNumber]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.[fnFindFYMonthOfYearNumber]
(
@MonthOfYearNumber		smallint,
@FYStartMonth			nvarchar(2),
@FYMonthOffset			smallint
)
RETURNS smallint
WITH EXECUTE AS CALLER
AS
BEGIN
DECLARE @FYMonthOfYearNumber smallint

IF	@MonthOfYearNumber >= @FYStartMonth -- (1) above.
	SET @FYMonthOfYearNumber = @MonthOfYearNumber - @FYMonthOffset
ELSE	-- (2) above
	SET @FYMonthOfYearNumber = (@MonthOfYearNumber - @FYMonthOffset) + 12

RETURN(@FYMonthOfYearNumber)
END;

GO

/****** Object:  UserDefinedFunction dbo.[fnFindFYQuarterOfYearNumber]    Script Date: 03/24/2010 14:15:56 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.[fnFindFYQuarterOfYearNumber]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION dbo.[fnFindFYQuarterOfYearNumber]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.[fnFindFYQuarterOfYearNumber]
(
@MonthOfYearNumber		smallint,
@FYStartMonth			nvarchar(2),
@FYMonthOffset			smallint
)
RETURNS smallint
WITH EXECUTE AS CALLER
AS
BEGIN
DECLARE @FYQuarterOfYearNumber smallint

IF	dbo.fnFindFYMonthOfYearNumber (
	@MonthOfYearNumber,
	@FYStartMonth,
	@FYMonthOffset ) IN (1, 2, 3) SET @FYQuarterOfYearNumber = 1

IF	dbo.fnFindFYMonthOfYearNumber (
	@MonthOfYearNumber,
	@FYStartMonth,
	@FYMonthOffset ) IN (4, 5, 6) SET @FYQuarterOfYearNumber = 2

IF	dbo.fnFindFYMonthOfYearNumber (
	@MonthOfYearNumber,
	@FYStartMonth,
	@FYMonthOffset ) IN (7, 8, 9) SET @FYQuarterOfYearNumber = 3

IF	dbo.fnFindFYMonthOfYearNumber (
	@MonthOfYearNumber,
	@FYStartMonth,
	@FYMonthOffset ) IN (10, 11, 12) SET @FYQuarterOfYearNumber = 4

RETURN(@FYQuarterOfYearNumber)
END;

GO

/****** Object:  UserDefinedFunction dbo.[fnFindFYQuarterStartDate]    Script Date: 03/24/2010 14:16:15 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.[fnFindFYQuarterStartDate]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION dbo.[fnFindFYQuarterStartDate]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.[fnFindFYQuarterStartDate]
(
@MonthOfYearNumber		smallint,
@FYStartMonth			nvarchar(2),
@FYMonthOffset			smallint,
@YearName				nchar(4)
)
RETURNS nvarchar(10)
WITH EXECUTE AS CALLER
AS
BEGIN
DECLARE @FYQuarterStartMonth nvarchar(2)
DECLARE @FYQuarterStartDate nvarchar(10)

/********************************************************************
The following works when the row in question is in
FYQuarterOfYearNumber = 1.  No test for over/under 12 is required
because the first date of the quarter is the same as the first date
of the fiscal year, so the year designation for the quarter first
date is always the same as that of the FY year's first date.
*********************************************************************/
IF	dbo.fnFindFYQuarterOfYearNumber (
	@MonthOfYearNumber,
	@FYStartMonth,
	@FYMonthOffset ) = 1
	BEGIN
		SET @FYQuarterStartMonth = @FYStartMonth
		SET @FYQuarterStartDate = @FYQuarterStartMonth + '/1/' + @YearName
	END

/********************************************************************
The following works when the row in question is in
FYQuarterOfYearNumber = 2.

There are two additional conditions, which answer the following question:
Does the quarter end in the current calendar year?  If it does, then the
calendar year designation for the quarter start date is the same as that
of the date on the row calling this function.  If not, then the calendar
year designation for the quarter start date is the year prior to the date
on the row calling this function.

These two additional conditions are repeated for any quarter number 2, 3,
or 4.  This explanation will not be repeated for the next two comment
blocks.

(1) When the FY start month number + 3 < 12.  The quarter in question
ends in the current calendar year.  Return the current calendar year as
the year designation for the quarter start date.
(2) When the FY start month number + 3 >= 12.  The quarter in question
crosses December 31.  Return the prior calendar year as the year designation
for the quarter start date.

Additional note:  There is a computation in the second condition as follows:

SET @FYQuarterStartMonth = @FYStartMonth + 3 - 12

This is functionally equivalent to @FYStartMonth - 9, but is written
this way for clarity.  For quarter 3, the "3" is replaced by a "6"; for
quarter 4, the "3" is replaced by a "9".
*********************************************************************/

IF	dbo.fnFindFYQuarterOfYearNumber (
	@MonthOfYearNumber,
	@FYStartMonth,
	@FYMonthOffset ) = 2 -- Is FYQuarterOfYearNumber = 2?
AND @FYStartMonth + 3 < 12 -- And is the FY start month number + 3 < 12?
	BEGIN
		SET @FYQuarterStartMonth = @FYStartMonth + 3
		SET @FYQuarterStartDate = @FYQuarterStartMonth + '/1/' + @YearName
	END

IF	dbo.fnFindFYQuarterOfYearNumber (
	@MonthOfYearNumber,
	@FYStartMonth,
	@FYMonthOffset ) = 2 -- Is FYQuarterOfYearNumber = 2?
AND @FYStartMonth + 3 >= 12 -- And is the FY start month number + 3 >= 12?
	BEGIN
		SET @FYQuarterStartMonth = @FYStartMonth + 3 - 12
		SET @FYQuarterStartDate = @FYQuarterStartMonth + '/1/' + @YearName
	END

/********************************************************************
The following works when the row in question is in
FYQuarterOfYearNumber = 3.

There are two additional conditions.  Refer to the
FYQuarterOfYearNumber = 2 comment block for a full logic explanation.

(1) When the FY start month number + 6 < 12.  The quarter in question
ends in the current calendar year.  Return the current calendar year as
the year designation for the quarter start date.
(2) When the FY start month number + 6 >= 12.  The quarter in question
crosses December 31.  Return the prior calendar year as the year designation
for the quarter start date.
*********************************************************************/

IF	dbo.fnFindFYQuarterOfYearNumber (
	@MonthOfYearNumber,
	@FYStartMonth,
	@FYMonthOffset ) = 3 -- Is FYQuarterOfYearNumber = 3?
AND @FYStartMonth + 6 < 12 -- And is the FY start month number + 6 < 12?
	BEGIN
		SET @FYQuarterStartMonth = @FYStartMonth + 6
		SET @FYQuarterStartDate = @FYQuarterStartMonth + '/1/' + @YearName
	END

IF	dbo.fnFindFYQuarterOfYearNumber (
	@MonthOfYearNumber,
	@FYStartMonth,
	@FYMonthOffset ) = 3 -- Is FYQuarterOfYearNumber = 3?
AND @FYStartMonth + 6 >= 12 -- And is the FY start month number + 6 >= 12?
	BEGIN
		SET @FYQuarterStartMonth = @FYStartMonth + 6 - 12
		SET @FYQuarterStartDate = @FYQuarterStartMonth + '/1/' + @YearName
	END

/********************************************************************
The following works when the row in question is in
FYQuarterOfYearNumber = 4.

There are two additional conditions.  Refer to the
FYQuarterOfYearNumber = 2 comment block for a full logic explanation.

(1) When the FY start month number + 9 < 12.  The quarter in question
ends in the current calendar year.  Return the current calendar year as
the year designation for the quarter start date.
(2) When the FY start month number + 9 >= 12.  The quarter in question
crosses December 31.  Return the prior calendar year as the year designation
for the quarter start date.
*********************************************************************/
IF	dbo.fnFindFYQuarterOfYearNumber (
	@MonthOfYearNumber,
	@FYStartMonth,
	@FYMonthOffset ) = 4 -- Is FYQuarterOfYearNumber = 4?
AND @FYStartMonth + 9 < 12 -- And is the FY start month number + 9 < 12?
	BEGIN
		SET @FYQuarterStartMonth = @FYStartMonth + 9
		SET @FYQuarterStartDate = @FYQuarterStartMonth + '/1/' + @YearName
	END

IF	dbo.fnFindFYQuarterOfYearNumber (
	@MonthOfYearNumber,
	@FYStartMonth,
	@FYMonthOffset ) = 4 -- Is FYQuarterOfYearNumber = 4?
AND @FYStartMonth + 9 >= 12 -- And is the FY start month number + 9 >= 12?
	BEGIN
		SET @FYQuarterStartMonth = @FYStartMonth + 9 - 12
		SET @FYQuarterStartDate = @FYQuarterStartMonth + '/1/' + @YearName
	END

RETURN(@FYQuarterStartDate)
END;

GO


/****** Object:  UserDefinedFunction dbo.[fnFindFYYearName]    Script Date: 03/24/2010 14:16:41 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.[fnFindFYYearName]') AND type in (N'FN', N'IF', N'TF', N'FS', N'FT'))
DROP FUNCTION dbo.[fnFindFYYearName]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE FUNCTION dbo.[fnFindFYYearName]
(
@FYMonthOneInNativeYear nvarchar(3),
@MonthOfYearNumber		smallint,
@FYStartMonth			nvarchar(2),
@YearName				nchar(4)
)
RETURNS nchar(4)
WITH EXECUTE AS CALLER
AS
BEGIN
DECLARE @FYYearName nchar(4)
IF	@FYMonthOneInNativeYear = 'Yes' AND @MonthOfYearNumber >= @FYStartMonth
		SET		@FYYearName = @YearName

IF	@FYMonthOneInNativeYear = 'Yes' AND @MonthOfYearNumber < @FYStartMonth
		SET		@FYYearName = @YearName - 1

IF	@FYMonthOneInNativeYear = 'No' AND @MonthOfYearNumber >= @FYStartMonth
		SET		@FYYearName = @YearName + 1

IF	@FYMonthOneInNativeYear = 'No' AND @MonthOfYearNumber < @FYStartMonth
		SET		@FYYearName = @YearName

RETURN(@FYYearName)
END;

GO


/****** Object:  StoredProcedure dbo.[spBuildDateMaster]    Script Date: 03/24/2010 14:25:01 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.[spBuildDateMaster]') AND type in (N'P', N'PC'))
DROP PROCEDURE dbo.[spBuildDateMaster]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.[spBuildDateMaster]
--						 @BeginDate nvarchar(50),
--						 @EndDate nvarchar(50)
/**************************************************************************************
DESCRIPTION
Copyright (C) 2003

Created, enhanced, and edited beginning in 2003.
By Dave Rodabaugh at Atlas Analytics. drodabaugh@AtlasAnalytics.com
And Chris Ciappa as Atlas Analytics.  cciappa@AtlasAnalytics.com, cciappa@gmail.com

UPDATED AND CONSOLIDATED
4/1/2010 Chris Ciappa
12/21/2014  Chris Ciappa

   This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see https://www.gnu.org/licenses/.


This procedure creates a DateMaster table and is a version of procedure
spBuildDimTime.  This version has dates hard coded to build the underlying master date
table.  The remainder of these comments are applicable to both dimDate and DateMaster.

This DateMaster table has two groupings of columns.
The first is for the standard calendar year hierarchy, and those columns are
populated by this script.  The second is for an optional fiscal year hierarchy, and
those columns are NOT populated by this script. They are populated by a follow-on
procedure which reads each calendar row populated by this procedure, and updating the
fiscal columns.

Specifically, this procedure peforms the following work:

(1)  Checks for the existence of an existing DateMaster table and drops it.
(2)  Recreates the table.  Fiscal year columns are prefixed by "FY"; calendar year columns
	 have no prefix.
(3)  Reads a start date and an end date, supplied as parameters.
(4)  Inserts one row per day between the start date and end date, assigns surrogate keys for
	 all attribute levels (not just the day level) and computes attributes
	 related to the standard calendar time columns.

The "grain" of this dimDate table is day.  That is, each row represents a unique day.

This script produces unique, integerial, sequential surrogate keys at the day, week, month,
quarter, and year levels.

"Unique" means that these keys will never be duplicated anywhere else in this date table.
Once a member has a key, it is the sole owner of that key.

"Sequential" means that, at a level, these keys are sequential.  This permits easy
arithmetic between members, regardless of level.  For example, the distance between two
days could be the simple difference of their surrogates.  Likewise, the third month following
the current month could be computed by adding three to the surrogate key for the current
month.

Item (3) above notes that a start date and end date must be specified for this script to
work properly.  This script natively ships with a start date of 1/1/1800.  Always select a
start date that is sure to encompass all current and imaginable time requirements for the
enterprise.

Furthermore, the start date is the "peg" to which all sequential surrogates are tied.
For example, if the start date is 1/1/1800, then the seminal day id will be 1.  1/2/1800
will have a surrogate of 2, and so on.  The week associated with 1/1/1800 is week 1 in
the time table.  The month associated with 1/1/1800 is month 1 in the time table.  The
quarter associated with 1/1/1800 is quarter 1 in the time table.  The year associated
with 1/1/1800 is 1800 (not year 1).

As noted, day surrogates are pegged to the start date in the script.  The first day
in the table has a day surrogate = 1; the second 2, etc.  Each day's surrogate, then,
is an integer representing the distance between the first date in the script and
the date represented by the current row.

Week surrogates are built by adding 1,000,000 to the sequential week number, where
the sequential week number begins at 1 for the first day in the time dimension table.
The week associated with 1/1/1800 is 1. (NOTE: this is NOT week of the year; it is an
absolute week number).  Adding 1000000 to 1 yields a week id of 1000001.

Month surrogates are built by adding 2,000,000 to the sequential month number, where
the sequential month number begins at 1 for the first day in the time dimension table.
The month associated with the 1/1/1800 is 1 (NOTE: this is NOT month of the year; it is an
absolute month number).  Adding 2000000 to 1 yields a month id of 2000001.

Quarter surrogates are built by adding 3,000,000 to the sequential quarter number, where
the sequential quarter number begins at 1 for the first day in the time dimension table.
The quarter associated with 1/1/1800 is 1. (NOTE: this is NOT quarter of the year; it is an
absolute quarter number).  Adding 3000000 to 1 yields a quarter id of 3000001.

Year surrogates are built by adding 4,000,000 to the four digit year code.  The year id for
1800 is 4000000 + 1800 = 4001800.

Feel free to add, delete, or modify attributes as required.

One final note: not only are all surrogate keys unique and sequential, but they are
repeatable provided that the start date passed as a parameter never changes.  In production,
this table can be dropped and recreated without requiring an SSAS full process so long
as the start date never changes.

SPECIAL FOR ADS:

(1) ADS has customer time member names in their legachy MSAS system.
Those columns have been added to this procedure and are noted as such.

(2) This procedure no longer accepts input parameters.  This table has hardcoded
parameters for dates, starting at 1/1/2005 and running through 12/31/2029.  There is
an additional update SP that sets an active flag so that the Time dimension view
does not load members into the future.  This table, however, is used as the lookup
for various dates that may be well into the future (such as date promised) and
must be loaded well into the future.  This procedure should never need to be run
again during the life of this application.
*************************************************************************************/

AS
/********* Test parameters as variables moved out and hard coded below**************************
declare @BeginDate		nvarchar(50)
declare @EndDate		nvarchar(50)
set		@BeginDate		= '1/1/1950'
set		@EndDate		= '12/31/2050'
*****************************************************************/
declare @BeginDate		nvarchar(50)
declare @EndDate		nvarchar(50)
set		@BeginDate		= '1/1/1950'
set		@EndDate		= '12/31/2150'
-- If exists, drop dimDate table.
if exists (select * from sysobjects where id = object_id(N'dbo.[DateMaster]')
	and OBJECTPROPERTY(id, N'IsUserTable') = 1)
	BEGIN
	drop table dbo.[DateMaster]
	END

-- Create dimDate table.  Note both CY and FY columns.
CREATE TABLE dbo.[DateMaster] (
/**************** Date/Day Information *****************************/
	DayID					int				NOT NULL,
	ActualDate				datetime		NULL,
	DateString				nvarchar(50)	NULL,
	ISODate					nvarchar(20)	NULL,

/**************** Day Information *****************************/
	--DayName				Add LongMonth + DD, YYYY to this column; January 01, 2006
	DayOfWeek				tinyint			NULL,
	DayOfWeekName			nvarchar(50)	NULL,
	DayOfMonth				tinyint			NULL,
	DayOfQuarter			tinyint			NULL,
	DayOfYear				smallint		NULL,
	Weekday					bit				NULL,
	Weekend					bit				NULL,
	Holiday					bit				NULL,
	LeapDay					bit				NULL,

/**************** Week Information ****************************/
	WeekID					int				NULL,
	WeekOfYearNumber		tinyint			NULL,
	WeekName				nvarchar(50)	NULL,
	WeekNameWithYear		nvarchar(50)	NULL,
	WeekShortName			nvarchar(50)	NULL,
	WeekShortNameWithYear	nvarchar(50)	NULL,
	WeekFirstDate			datetime		NULL,
	WeekFirstDateString		nvarchar(50)	NULL,
	WeekLastDate			datetime		NULL,
	WeekLastDateString		nvarchar(50)	NULL,

/**************** Month Information ****************************/
	MonthID					int				NULL,
	MonthOfYearNumber		tinyint			NULL,
	MonthName				nvarchar(50)	NULL,
	MonthNameWithYear		nvarchar(50)	NULL,
	MonthShortName			nvarchar(50)	NULL,
	MonthShortNameWithYear	nvarchar(50)	NULL,
	MonthShortNameWith2DigitYear	nvarchar(50)	NULL,
	MonthFirstDate			datetime		NULL,
	MonthFirstDateString	nvarchar(50)	NULL,
	MonthLastDate			datetime		NULL,
	MonthLastDateString		nvarchar(50)	NULL,
	MonthISOMonth			nvarchar(50)	NULL,
	LegacyCalendarMonthName nvarchar(50)    NULL, -- Specific to ADS.  Legacy
                                                  -- from old MSAS cubes.

/**************** Quarter Information **************************/
	QuarterID				int				NULL,
	QuarterOfYearNumber		tinyint			NULL,
	QuarterName				nvarchar(50)	NULL,
	QuarterNameWithYear		nvarchar(50)	NULL,
	QuarterShortName		nvarchar(50)	NULL,
	QuarterShortNameWithYear nvarchar(50)	NULL,
	QuarterShortNameWith2DigitYear	nvarchar(50)	NULL,
	QuarterFirstDate		datetime		NULL,
	QuarterFirstDateString	nvarchar(50)	NULL,
	QuarterLastDate			datetime		NULL,
	QuarterLastDateString	nvarchar(50)	NULL,
    LegacyCalendarQuarterName nvarchar(50)  NULL, -- Specific to ADS.  Legacy
                                                  -- from old MSAS cubes.

/**************** Year Information *****************************/
	YearID					int				NULL,
	YearName				nvarchar(50)	NULL,
	YearShortName			nchar(2)		NULL,
	YearFirstDate			datetime		NULL,
	YearFirstDateString		nvarchar(50)	NULL,
	YearLastDate			datetime		NULL,
	YearLastDateString		nvarchar(50)	NULL,
	LeapYear				bit				NULL,
    LegacyCalendarYearName  nvarchar(50)    NULL, -- Specific to ADS.  Legacy
                                                  -- from old MSAS cubes.

/**************** FY Month Information *****************************/
	FYMonthID						int				NULL,
	FYMonthOfYearNumber				smallint		NULL,
	FYMonthName						nvarchar(50)	NULL,
	FYMonthNameWithYear				nvarchar(55)	NULL,
	FYMonthShortName				nvarchar(50)	NULL,
	FYMonthShortNameWithYear		nvarchar(50)	NULL,
	FYMonthShortNameWith2DigitFYYear	nvarchar(50)	NULL,
	FYMonthFirstDate				datetime		NULL,
	FYMonthFirstDateString			nvarchar(50)	NULL,
	FYMonthLastDate					datetime		NULL,
	FYMonthLastDateString			nvarchar(50)	NULL,
	FYMonthISOMonth					nvarchar(50)	NULL,
    LegacyFiscalMonthName           nvarchar(50)    NULL, -- Specific to ADS. Legacy
                                                          -- from old MSAS cubes.

/**************** FY Quarter Information *****************************/
	FYQuarterID						int				NULL,
	FYQuarterOfYearNumber			smallint		NULL,
	FYQuarterName					nvarchar(50)	NULL,
	FYQuarterNameWithYear			nvarchar(50)	NULL,
	FYQuarterShortName				nvarchar(50)    NULL,
	FYQuarterShortNameWithYear		nvarchar(50)	NULL,
	FYQuarterShortNameWith2DigitYear	nvarchar(50) NULL,
    LegacyFiscalQuarterName          nvarchar(50)    NULL, -- Specific to ADS. Legacy
                                                           -- from old MSAS cubes.

/**************** FY Year Information *****************************/
	FYYearID						int				NULL,
	FYYearName						nvarchar(50)	NULL,
	FYYearShortName					nchar(4)		NULL,
	FYYearFirstDate					datetime		NULL,
	FYYearFirstDateString			nvarchar(50)	NULL,
	FYYearLastDate					datetime		NULL,
	FYYearLastDateString			nvarchar(50)	NULL,
	FYLeapYear						bit				NULL,
    LegacyFiscalYearName            nvarchar(50)    NULL,  -- Specific to ADS. Legacy
                                                          -- from old MSAS cubes.
	IsDateActiveFlag				bit				NULL
)
ALTER TABLE dbo.[DateMaster] ADD  CONSTRAINT [PK_DateMaster] PRIMARY KEY CLUSTERED
(
	[DayID] ASC
)WITH (SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF) ON [PRIMARY]

CREATE NONCLUSTERED INDEX [ActualDateAndMonthID] ON dbo.[DateMaster]
(
	[MonthID] ASC,
	[ActualDate] ASC
)WITH (SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF) ON [PRIMARY]
/*********************************************************************
Variable Declarations
NOTE:  The variables are grouped by time unit (day, week, month, etc.) but
they are in reverse order from the table column grouping for ease of variable
usage.  For example, year information is included at nearly every level; it
must be computed first.  Days are done last because some of the day attributes
(e.g. -- DayOfQuarter) require additional attributes from another group to be
computed first. They appear in the following order:
(1)  Date information
(2)  Year
(3)  Quarter
(4)  Month
(5)  Week
(6)  Day
*********************************************************************/

/**************** Date/Day Information *****************************/
DECLARE @DayID				int -- Integerial surrogate key for the time table, indexed to 1/1/1753.
DECLARE @LoopDate			datetime -- The date used by the WHILE loop; must be between @StartDate and @EndDate
DECLARE @DateString			nvarchar(10)
DECLARE @ISODate			nchar(8)
DECLARE @DayofMonth			int

/**************** Year Information, used by other variables ********/
DECLARE	@YearID				int
DECLARE	@YearName			nchar(4)
DECLARE	@YearShortName		nchar(2)
DECLARE	@YearFirstDate		datetime
DECLARE @YearFirstDateString	nvarchar(50)
DECLARE	@YearLastDate		datetime
DECLARE @YearLastDateString		nvarchar(50)
DECLARE	@LeapYear			bit
DECLARE @LegacyCalendarYearName nvarchar(50) -- Specific to ADS. Legacy
                                             -- from old MSAS cubes.

/********************* Quarter Information **************************/
DECLARE @QuarterID					int
	SET @QuarterID = 3000001 -- Always set to 30000001 to begin the loop.
DECLARE @QuarterOfYearNumber		tinyint
DECLARE	@QuarterName				nvarchar(50)
DECLARE	@QuarterNameWithYear		nvarchar(50)
DECLARE	@QuarterShortName			nvarchar(50)
DECLARE	@QuarterShortNameWithYear	nvarchar(50)
DECLARE @QuarterShortNameWith2DigitYear	nvarchar(50)
DECLARE @QuarterFirstDate			datetime
DECLARE @QuarterFirstDateString		nvarchar(50)
DECLARE @QuarterLastDate			datetime
DECLARE @QuarterLastDateString		nvarchar(50)

DECLARE @OldQuarterOfYearNumber		nvarchar(50)
	SET @OldQuarterOfYearNumber = 1

DECLARE @LegacyCalendarQuarterName  nvarchar(50) -- Specific to ADS. Legacy
                                                 -- from old MSAS cubes.

/********************* Month Information ****************************/
DECLARE	@MonthID					int
	SET @MonthID = 2000001 -- Always set to 2000001 to begin the loop.
DECLARE	@MonthOfYearNumber			tinyint
DECLARE	@MonthName					nvarchar(50)
DECLARE @MonthNameWithYear			nvarchar(50)
DECLARE	@MonthShortName				nvarchar(50)
DECLARE @MonthShortNameWithYear		nvarchar(50)
DECLARE @MonthShortNameWith2DigitYear	nvarchar(50)
DECLARE	@MonthFirstDate				datetime
DECLARE	@MonthFirstDateString		nvarchar(50)
DECLARE	@MonthLastDate				datetime
DECLARE @MonthLastDateString		nvarchar(50)
DECLARE	@MonthISOMonth				nvarchar(50)

DECLARE @OldMonthOfYearNumber		nvarchar(50)
	SET @OldMonthOfYearNumber = 1

DECLARE @LegacyCalendarMonthName    nvarchar(50) -- Specific to ADS. Legacy
                                                 -- from old MSAS cubes.

/********************  Week Information *****************************/
DECLARE @WeekOfYearNumber	tinyint
DECLARE @WeekID				int
	SET @WeekID = 1000001 -- Always set to 1000001 to begin the loop.
DECLARE @WeekName			nvarchar(50)
DECLARE @WeekNameWithYear	nvarchar(50)
DECLARE @WeekShortName		nvarchar(50)
DECLARE @WeekShortNameWithYear nvarchar(50)
DECLARE @WeekFirstDate		datetime
DECLARE @WeekFirstDateString nvarchar(50)
DECLARE @WeekLastDate		datetime
DECLARE @WeekLastDateString	nvarchar(50)

DECLARE @OldWeekOfYearNumber	nvarchar(50)
	SET @OldWeekOfYearNumber = 1

/********************  Day Information *****************************/
DECLARE @DayofWeek			int
DECLARE @DayOfWeekName		nvarchar(20)
DECLARE @DayofQuarter		int
DECLARE @DayOfYear			int
DECLARE @Weekday			bit
DECLARE @Weekend			bit
DECLARE @Holiday			bit
DECLARE @LeapDay			bit

-- Set @LoopDate to @BeginDate to allow the WHILE loop to operate.
SET @LoopDate  = @BeginDate

-- Loop through once for every day between @StartDate and @EndDate
WHILE (@LoopDate <= @EndDate)

    BEGIN

	/**************** Date/Day Information *****************************/
    SET @DayID		= DATEDIFF(dd,	@BeginDate, @LoopDate) + 1 -- TimeKey
	--print @DayID
	SET @DateString =
		RIGHT('0' + CAST(DATEPART(mm, @LoopDate) AS NVARCHAR(2)), 2) + '/' +
		RIGHT('0' + CAST(DATEPART(dd, @LoopDate) AS NVARCHAR(2)), 2) + '/' +
		CAST(DATEPART (yyyy, @LoopDate) AS NCHAR(4))
	print @DateString
	SET @ISODate = convert(nchar(8), @LoopDate,112)
	--print @ISODate
	SET @DayOfMonth		= DATEPART(DAY,	@LoopDate) -- Done in date/day info because
									-- other variables require it.
	--print '@DayOfMonth = ' + cast(@DayOfMonth as nvarchar(2))
	--print '==============================================================='

	/**************** Year Information **********************************
	Year surrogates are created by adding 4000000 to the year value.  Years are
	already integerial and sequential; adding 4000000 to the year value also
	ensures that each year member's surrogate is unique across the entire
	dimension.
	**********************************************************************/
	SET @YearName	= DATEPART(yyyy, @LoopDate)
	--print '@YearName = ' + @YearName
	SET @YearID		= @YearName + 4000000
	--print '@YearID = ' + cast(@YearID AS nchar(4))
	SET @YearShortName	= right(@YearName, 2)
	--print '@YearShortName = ' + @YearShortName
	SET @YearFirstDate	= cast('01/01/' + @YearName AS datetime)
	--print '@YearFirstDate = ' + cast(@YearFirstDate AS nvarchar(50))
	SET @YearFirstDateString =
		RIGHT('0' + CAST(DATEPART(mm, @YearFirstDate) AS NVARCHAR(2)), 2) + '/' +
		RIGHT('0' + CAST(DATEPART(dd, @YearFirstDate) AS NVARCHAR(2)), 2) + '/' +
		CAST(DATEPART (yyyy, @YearFirstDate) AS NCHAR(4))
	--print '@YearFirstDateString = ' + @YearFirstDateString
	SET @YearLastDate	= cast('12/31/' + @YearName AS datetime)
	--print '@YearLastDate = ' + cast(@YearLastDate AS nvarchar(15))
	SET @YearLastDateString	=
		RIGHT('0' + CAST(DATEPART(mm, @YearLastDate) AS NVARCHAR(2)), 2) + '/' +
		RIGHT('0' + CAST(DATEPART(dd, @YearLastDate) AS NVARCHAR(2)), 2) + '/' +
		CAST(DATEPART (yyyy, @YearLastDate) AS NCHAR(4))
	--print '@YearLastDateString = ' + @YearLastDateString
	IF ((@YearName % 4 = 0)  AND (@YearName % 100 != 0 OR @YearName % 400 = 0))
		SET @LeapYear = 1 ELSE SET @LeapYear = 0
	--PRINT '@LeapYear = ' + cast(@LeapYear AS nvarchar(10))
	SET @LegacyCalendarYearName = 'Cal ' + cast(@YearName as nchar(4)) -- Specific to ADS. Legacy
                                                     -- from old MSAS system.

	/**************** Quarter Information **********************************
	Quarter surrogates begin at 3000001.  This ensures that all quarter
	surrogates are integerial, sequential, and that quarter member surrogates
	are unique among all members across the entire dimension.
	**********************************************************************/
	SET @QuarterOfYearNumber			= datepart(qq, @LoopDate)
	--print '@QuarterOfYearNumber = ' + cast(@QuarterOfYearNumber as varchar(10))

	IF @OldQuarterOfYearNumber <> @QuarterOfYearNumber SET @QuarterID = @QuarterID + 1
	IF @OldQuarterOfYearNumber <> @QuarterOfYearNumber SET @OldQuarterOfYearNumber = @QuarterOfYearNumber
	--print '@QuarterID = ' + CAST(@QuarterID as varchar(10))

	SET @QuarterName			= 'Qtr ' + datename(qq, @LoopDate)
	--print '@QuarterName = ' + @QuarterName
	SET @QuarterNameWithYear	= @QuarterName + ' ' + @YearName
	--print '@QuarterNameWithYear = ' + @QuarterNameWithYear
	SET @QuarterShortName		= 'Q' + left(datename(qq, @LoopDate),3)
	--print '@QuarterShortName = ' + @QuarterShortName
	SET @QuarterShortNameWithYear	= 'Q' + left(datename(qq, @LoopDate),3) + ' ' + @YearName
	--print '@QuarterShortNameWithYear = ' + @QuarterShortNameWithYear
	SET @QuarterShortNameWith2DigitYear = @QuarterShortName + ' ' + right(@YearName, 2)
	--print '@QuarterShortNameWith2DigitYear = ' + @QuarterShortNameWith2DigitYear

	SET @QuarterFirstDate =
		CASE @QuarterOfYearNumber
			WHEN 1 THEN cast('01/01/' + @YearName as datetime)
			WHEN 2 THEN cast('04/01/' + @YearName as datetime)
			WHEN 3 THEN cast('07/01/' + @YearName as datetime)
			WHEN 4 THEN cast('10/01/' + @YearName as datetime)
		END
	--print '@QuarterFirstDate = ' + cast(@QuarterFirstDate as nvarchar(50))
	SET @QuarterFirstDateString =
		RIGHT('0' + CAST(DATEPART(mm, @QuarterFirstDate) AS NVARCHAR(2)), 2) + '/' +
		RIGHT('0' + CAST(DATEPART(dd, @QuarterFirstDate) AS NVARCHAR(2)), 2) + '/' +
		CAST(DATEPART (yyyy, @QuarterFirstDate) AS NCHAR(4))
	--print '@QuarterFirstDateString = ' + @QuarterFirstDateString
	SET @QuarterLastDate		= dateadd(day, -1, dateadd(q, 1, @QuarterFirstDate))
	--print '@QuarterLastDate = ' + cast(@QuarterLastDate as nvarchar(50))
	SET @QuarterLastDateString =
		RIGHT('0' + CAST(DATEPART(mm, @QuarterLastDate) AS NVARCHAR(2)), 2) + '/' +
		RIGHT('0' + CAST(DATEPART(dd, @QuarterLastDate) AS NVARCHAR(2)), 2) + '/' +
		CAST(DATEPART (yyyy, @QuarterLastDate) AS NCHAR(4))
	SET @LegacyCalendarQuarterName = 'Cal ' + cast(@YearName as nchar(4))
        + '-Quarter ' + cast(@QuarterOfYearNumber as nchar(4))-- Specific to ADS. Legacy
                                             -- from old MSAS system.

	/**************** Month Information **********************************
	Month surrogates are created by adding 2000000 to the integerial,
	sequential month surrogate computed by this script.  Adding 2000000
	to the month value also ensures that each month member's surrogate is
	unique across the entire dimension.
	**********************************************************************/
	SET @MonthOfYearNumber			= datepart(mm, @LoopDate)
	--print '@MonthOfYearNumber = ' + cast(@MonthOfYearNumber as varchar(10))

	IF @OldMonthOfYearNumber <> @MonthOfYearNumber SET @MonthID = @MonthID + 1
	IF @OldMonthOfYearNumber <> @MonthOfYearNumber SET @OldMonthOfYearNumber = @MonthOfYearNumber
	--print '@MonthID = ' + CAST(@MonthID as varchar(10))

	SET @MonthName			= datename(mm, @LoopDate)
	--print '@MonthName = ' + @MonthName
	SET @MonthNameWithYear	= @MonthName + ' ' + @YearName
	--print '@MonthNameWithYear = ' + @MonthNameWithYear
	SET @MonthShortName		= left(datename(mm, @LoopDate),3)
	--print '@MonthShortName = ' + @MonthShortName
	SET @MonthShortNameWithYear	= left(datename(mm, @LoopDate),3) + ' ' + @YearName
	--print '@MonthShortNameWithYear = ' + @MonthShortNameWithYear
	SET @MonthShortNameWith2DigitYear = @MonthShortName + right(@YearName, 2)
	--print '@MonthShortNameWith2DigitYear = ' + @MonthShortNameWith2DigitYear

	SET @MonthFirstDate	= dateadd(day, (@DayOfMonth - 1) * -1, @LoopDate)
	--print '@MonthFirstDate = ' + cast(@MonthFirstDate as nvarchar(50))
	SET @MonthFirstDateString =
		RIGHT('0' + CAST(DATEPART(mm, @MonthFirstDate) AS NVARCHAR(2)), 2) + '/' +
		RIGHT('0' + CAST(DATEPART(dd, @MonthFirstDate) AS NVARCHAR(2)), 2) + '/' +
		CAST(DATEPART (yyyy, @MonthFirstDate) AS NCHAR(4))
	--print '@MonthFirstDateString = ' + @MonthFirstDateString
	SET @MonthLastDate		= dateadd(day, -1, dateadd(mm, 1, @MonthFirstDate))
	--print '@MonthLastDate = ' + cast(@MonthLastDate as nvarchar(50))
	SET @MonthLastDateString =
		RIGHT('0' + CAST(DATEPART(mm, @MonthLastDate) AS NVARCHAR(2)), 2) + '/' +
		RIGHT('0' + CAST(DATEPART(dd, @MonthLastDate) AS NVARCHAR(2)), 2) + '/' +
		CAST(DATEPART (yyyy, @MonthLastDate) AS NCHAR(4))
	--print '@MonthLastDateString = ' + @MonthLastDateString
	SET @MonthISOMonth = @YearName + right('0' + cast(@MonthOfYearNumber as nvarchar(2) ), 2)
	SET @LegacyCalendarMonthName = 'Cal ' + cast(@YearName as nchar(4))
              + '-' + cast(@MonthName as nvarchar(15)) -- Specific to ADS. Legacy
                                 -- from old MSAS system.

	/**************** Week Information **********************************
	Week surrogates are created by adding 1000000 to the integerial,
	sequential week surrogate computed by this script.  Adding 1000000
	to the week value also ensures that each week member's surrogate is
	unique across the entire dimension.
	**********************************************************************/
	SET @WeekOfYearNumber			= datepart(wk, @LoopDate)
	--print '@WeekOfYearNumber = ' + cast(@WeekOfYearNumber as varchar(10))

	IF @OldWeekOfYearNumber <> @WeekOfYearNumber SET @WeekID = @WeekID + 1
	IF @OldWeekOfYearNumber <> @WeekOfYearNumber SET @OldWeekOfYearNumber = @WeekOfYearNumber
	--print '@WeekID = ' + CAST(@WeekID as varchar(10))

	SET @WeekName			= 'Week ' + datename(wk, @LoopDate)
	--print '@WeekName = ' + @WeekName
	SET @WeekNameWithYear	= @WeekName + ', ' + @YearName
	--print '@WeekNameWithYear = ' + @WeekNameWithYear
	SET @WeekShortName		= 'WK' + right('00' + datename(wk, @LoopDate),2)
	--print '@WeekShortName = ' + @WeekShortName
	SET @WeekShortNameWithYear	= @WeekShortName + ' ' + @YearName
	--print '@WeekShortNameWithYear = ' + @WeekShortNameWithYear

	SET @WeekFirstDate	= dateadd(day,(datepart(dw, @LoopDate) -1) * -1, @LoopDate)
	--print  '@WeekFirstDate = ' + cast(@WeekFirstDate as nvarchar(50))
	SET @WeekFirstDateString =
		RIGHT('0' + CAST(DATEPART(mm, @WeekFirstDate) AS NVARCHAR(2)), 2) + '/' +
		RIGHT('0' + CAST(DATEPART(dd, @WeekFirstDate) AS NVARCHAR(2)), 2) + '/' +
		CAST(DATEPART (yyyy, @WeekFirstDate) AS NCHAR(4))
	--print '@WeekFirstDateString = ' + @WeekFirstDateString
	SET @WeekLastDate		= dateadd(day, -1, dateadd(wk, 1, @WeekFirstDate))
	--print '@WeekLastDate = ' + cast(@WeekLastDate as nvarchar(50))
	SET @WeekLastDateString =
		RIGHT('0' + CAST(DATEPART(mm, @WeekLastDate) AS NVARCHAR(2)), 2) + '/' +
		RIGHT('0' + CAST(DATEPART(dd, @WeekLastDate) AS NVARCHAR(2)), 2) + '/' +
		CAST(DATEPART (yyyy, @WeekLastDate) AS NCHAR(4))
	--print '@WeekLastDateString = ' + @WeekLastDateString
	--print '================================================================='

	/**************** Additional Day Information *****************************/
	SET @DayOfWeek		= DATEPART(DW,	@LoopDate)
	--print '@DayOfWeek = ' + cast(@DayOfWeek as nchar(1))
		IF		DATEPART(DW, @LoopDate) = 1 SET @DayOfWeekName = 'Sunday'
		ELSE IF DATEPART(DW, @LoopDate) = 2 SET @DayOfWeekName = 'Monday'
		ELSE IF DATEPART(DW, @LoopDate) = 3 SET @DayOfWeekName = 'Tuesday'
		ELSE IF DATEPART(DW, @LoopDate) = 4 SET @DayOfWeekName = 'Wednesday'
		ELSE IF DATEPART(DW, @LoopDate) = 5 SET @DayOfWeekName = 'Thursday'
		ELSE IF DATEPART(DW, @LoopDate) = 6 SET @DayOfWeekName = 'Friday'
		ELSE IF DATEPART(DW, @LoopDate) = 7 SET @DayOfWeekName = 'Saturday' -- DayofWeekName
	--print '@DayOfWeekName = ' + @DayOfWeekName
	SET @DayOfYear		= DATEPART(DY,	@LoopDate)
	--print '@DayOfYear = ' + cast(@DayOfYear  as nvarchar(3))
	IF (@DayOfWeek = 1 OR @DayOfWeek = 7) SET @Weekday = 0 ELSE SET @Weekday = 1
	--print '@Weekend = ' + cast(@Weekend as nchar(4))
	IF (@DayOfWeek = 1 OR @DayOfWeek = 7) SET @Weekend = 1 ELSE SET @Weekend = 0
	--print '@Weekend = ' + cast(@Weekend as nchar(4))
	SET @Holiday		= 0
	--print '@Holiday = ' + cast(@Holiday as nchar(4))
	IF 	RIGHT('0' + CAST(DATEPART(mm, @LoopDate) AS NVARCHAR(2)), 2) + '/' +
		RIGHT('0' + CAST(DATEPART(dd, @LoopDate) AS NVARCHAR(2)), 2) = '02/29'
		SET @LeapDay = 1 ELSE SET @LeapDay = 0
	--print '================================================================='

	--insert values into Date Dimension table
	INSERT dbo.DateMaster (
		DayID,
		ActualDate,
		DateString,
		ISODate,

		DayofWeek,
		DayOfWeekName,
		DayofMonth,
		DayOfQuarter,
		DayOfYear,
		Weekday,
		Weekend,
		Holiday,
		LeapDay,

		WeekID,
		WeekOfYearNumber,
		WeekName,
		WeekNameWithYear,
		WeekShortName,
		WeekShortNameWithYear,
		WeekFirstDate,
		WeekFirstDateString,
		WeekLastDate,
		WeekLastDateString,

		MonthID,
		MonthOfYearNumber,
		MonthName,
		MonthNameWithYear,
		MonthShortName,
		MonthShortNameWithYear,
		MonthShortNameWith2DigitYear,
		MonthFirstDate,
		MonthFirstDateString,
		MonthLastDate,
		MonthLastDateString,
		MonthISOMonth,
        LegacyCalendarMonthName, -- Specific to ADS. Legacy from old MSAS system.

		QuarterID,
		QuarterOfYearNumber,
		QuarterName,
		QuarterNameWithYear,
		QuarterShortName,
		QuarterShortNameWithYear,
		QuarterShortNameWith2DigitYear,
		QuarterFirstDate,
		QuarterFirstDateString,
		QuarterLastDate,
		QuarterLastDateString,
        LegacyCalendarQuarterName, -- Specific to ADS. Legacy from old MSAS system.

		YearID,
		YearName,
		YearShortName,
		YearFirstDate,
		YearFirstDateString,
		YearLastDate,
		YearLastDateString,
		LeapYear,
        LegacyCalendarYearName -- Specific to ADS. Legacy from old MSAS system.
	)

	VALUES (
		@DayID,
		@LoopDate,
		@DateString,
		@ISODate,

		@DayOfWeek,
		@DayOfWeekName,
		@DayofMonth,
		@DayOfQuarter,
		@DayOfYear,
		@Weekday,
		@Weekend,
		@Holiday,
		@LeapDay,

		@WeekID,
		@WeekOfYearNumber,
		@WeekName,
		@WeekNameWithYear,
		@WeekShortName,
		@WeekShortNameWithYear,
		@WeekFirstDate,
		@WeekFirstDateString,
		@WeekLastDate,
		@WeekLastDateString,

		@MonthID,
		@MonthOfYearNumber,
		@MonthName,
		@MonthNameWithYear,
		@MonthShortName,
		@MonthShortNameWithYear,
		@MonthShortNameWith2DigitYear,
		@MonthFirstDate,
		@MonthFirstDateString,
		@MonthLastDate,
		@MonthLastDateString,
		@MonthISOMonth,
        @LegacyCalendarMonthName, -- Specific to ADS. Legacy from old MSAS system.

		@QuarterID,
		@QuarterOfYearNumber,
		@QuarterName,
		@QuarterNameWithYear,
		@QuarterShortName,
		@QuarterShortNameWithYear,
		@QuarterShortNameWith2DigitYear,
		@QuarterFirstDate,
		@QuarterFirstDateString,
		@QuarterLastDate,
		@QuarterLastDateString,
        @LegacyCalendarQuarterName, -- Specific to ADS. Legacy from old MSAS system.

		@YearID,
		@YearName,
		@YearShortName,
		@YearFirstDate,
		@YearFirstDateString,
		@YearLastDate,
		@YearLastDateString,
		@LeapYear,
        @LegacyCalendarYearName -- Specific to ADS. Legacy from old MSAS system.
	)

	--increment the date one day
	SELECT @LoopDate  = DATEADD(DAY, 1, @LoopDate)

      END -- WHILE loop

/******************************************************************************
The following inserts an unknown row into table DateMaster.
******************************************************************************/
INSERT dbo.DateMaster (
	DayID,
	ActualDate,
	DateString,
	ISODate,

	DayofWeek,
	DayOfWeekName,
	DayofMonth,
	DayOfQuarter,
	DayOfYear,
	Weekday,
	Weekend,
	Holiday,
	LeapDay,

	WeekID,
	WeekOfYearNumber,
	WeekName,
	WeekNameWithYear,
	WeekShortName,
	WeekShortNameWithYear,
	WeekFirstDate,
	WeekFirstDateString,
	WeekLastDate,
	WeekLastDateString,

	MonthID,
	MonthOfYearNumber,
	MonthName,
	MonthNameWithYear,
	MonthShortName,
	MonthShortNameWithYear,
	MonthShortNameWith2DigitYear,
	MonthFirstDate,
	MonthFirstDateString,
	MonthLastDate,
	MonthLastDateString,
	MonthISOMonth,
    LegacyCalendarMonthName, -- Specific to ADS. Legacy from old MSAS system.

	QuarterID,
	QuarterOfYearNumber,
	QuarterName,
	QuarterNameWithYear,
	QuarterShortName,
	QuarterShortNameWithYear,
	QuarterShortNameWith2DigitYear,
	QuarterFirstDate,
	QuarterFirstDateString,
	QuarterLastDate,
	QuarterLastDateString,
    LegacyCalendarQuarterName, -- Specific to ADS. Legacy from old MSAS system.

	YearID,
	YearName,
	YearShortName,
	YearFirstDate,
	YearFirstDateString,
	YearLastDate,
	YearLastDateString,
	LeapYear,
    LegacyCalendarYearName, -- Specific to ADS. Legacy from old MSAS system.

	/**************** Fiscal Columns *****************************/
	FYMonthID,
	FYMonthOfYearNumber,
	FYMonthName,
	FYMonthNameWithYear,
	FYMonthShortName,
	FYMonthShortNameWithYear,
	FYMonthShortNameWith2DigitFYYear,
	FYMonthFirstDate,
	FYMonthFirstDateString,
	FYMonthLastDate,
	FYMonthLastDateString,
	FYMonthISOMonth,
	LegacyFiscalMonthName , -- Specific to ADS. Legacy
                                                          -- from old MSAS cubes.
	FYQuarterID,
	FYQuarterOfYearNumber,
	FYQuarterName,
	FYQuarterNameWithYear,
	FYQuarterShortName,
	FYQuarterShortNameWithYear,
	FYQuarterShortNameWith2DigitYear,
    LegacyFiscalQuarterName, -- Specific to ADS. Legacy
							 -- from old MSAS cubes.
	FYYearID,
	FYYearName,
	FYYearShortName,
	FYYearFirstDate,
	FYYearFirstDateString,
	FYYearLastDate,
	FYYearLastDateString,
	FYLeapYear,
    LegacyFiscalYearName  -- Specific to ADS. Legacy
						  -- from old MSAS cubes.
)

VALUES (
	-1,				-- DayID,
	NULL,			-- LoopDate,
	NULL,			-- DateString,
	'Unknown Date',  -- ISODate,

	NULL, --DayOfWeek,
	'Unknown', --DayOfWeekName,
	NULL, --DayofMonth,
	NULL, --DayOfQuarter,
	NULL, --DayOfYear,
	NULL, --Weekday,
	NULL, --Weekend,
	NULL, --Holiday,
	NULL, --LeapDay,

	-1000000, -- @WeekID,
	NULL, --WeekOfYearNumber,
	'Unknown Week', --WeekName,
	'Unknown Week', --WeekNameWithYear,
	'Unknown Week', --WeekShortName,
	'Unknown Week', --WeekShortNameWithYear,
	NULL, --WeekFirstDate,
	'Unknown Week', --WeekFirstDateString,
	NULL, --WeekLastDate,
	'Unknown Week', --WeekLastDateString,

	-2000000, --MonthID,
	NULL, --MonthOfYearNumber,
	'Unknown Month', --MonthName,
	'Unknown Month', --MonthNameWithYear,
	'Unknown Month', --MonthShortName,
	'Unknown Month', --MonthShortNameWithYear,
	'Unknown Month', --MonthShortNameWith2DigitYear,
	NULL, --MonthFirstDate,
	'Unknown Month', --MonthFirstDateString,
	NULL, --MonthLastDate,
	'Unknown Month', --MonthLastDateString,
	NULL, --MonthISOMonth,
    'Unknown Month', --LegacyCalendarMonthName, -- Specific to ADS. Legacy from old MSAS system.

	-3000000, --QuarterID,
	NULL, --QuarterOfYearNumber,
	'Unknown Quarter', --QuarterName,
	'Unknown Quarter', --QuarterNameWithYear,
	'Unknown Quarter', --QuarterShortName,
	'Unknown Quarter', --QuarterShortNameWithYear,
	'Unknown Quarter', --QuarterShortNameWith2DigitYear,
	NULL, --QuarterFirstDate,
	'Unknown Quarter', --QuarterFirstDateString,
	NULL, --QuarterLastDate,
	'Unknown Quarter', --QuarterLastDateString,
    'Unknown Quarter', --LegacyCalendarQuarterName, -- Specific to ADS. Legacy from old MSAS system.

	-4000000, --YearID,
	'Unknown Year', --YearName,
	NULL, --YearShortName,
	NULL, --YearFirstDate,
	NULL, --YearFirstDateString,
	NULL, --YearLastDate,
	NULL, --YearLastDateString,
	NULL, --LeapYear,
    'Unknown Year', --LegacyCalendarYearName -- Specific to ADS. Legacy from old MSAS system.

    /*********** Fiscal column unknowns **************************************/
	-2200000, --FYMonthID
	NULL, --FYMonthOfYearNumber
	'Unknown Month', --FYMonthName
	'Unknown Month', --FYMonthNameWithYear
	'Unknown Month', --FYMonthShortName
	'Unknown Month', --FYMonthShortNameWithYear
	'Unknown Month', --FYMonthShortNameWith2DigitFYYear
	NULL, --FYMonthFirstDate
	'Unknown Month', --FYMonthFirstDateString
	NULL, --FYMonthLastDate
	'Unknown Month', --FYMonthLastDateString
	NULL, --FYMonthISOMonth
    'Unknown Month', --LegacyFiscalMonthName -- Specific to ADS. Legacy
                                                          -- from old MSAS cubes.

	-3300000, --FYQuarterID
	NULL, --FYQuarterOfYearNumber
	'Unknown Quarter', --FYQuarterName
	'Unknown Quarter', --FYQuarterNameWithYear
	'Unknown Quarter', --FYQuarterShortName
	'Unknown Quarter', --FYQuarterShortNameWithYear
	'Unknown Quarter', --FYQuarterShortNameWith2DigitYear
    'Unknown Quarter', --LegacyFiscalQuarterName -- Specific to ADS. Legacy
                      -- from old MSAS cubes.

	-4400000, --FYYearID
	'Unknown Year', --FYYearName
	NULL, --FYYearShortName
	NULL, --FYYearFirstDate
	NULL, --FYYearFirstDateString
	NULL, --FYYearLastDate
	NULL, --FYYearLastDateString
	NULL, --FYLeapYear
    'Unknown Year' --LegacyFiscalYearName  -- Specific to ADS. Legacy
                          -- from old MSAS cubes.
)

GO


/****** Object:  StoredProcedure dbo.[spUpdateFiscalYearColumnsDateMaster]    Script Date: 03/24/2010 14:25:32 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.[spUpdateFiscalYearColumnsDateMaster]') AND type in (N'P', N'PC'))
DROP PROCEDURE dbo.[spUpdateFiscalYearColumnsDateMaster]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE dbo.[spUpdateFiscalYearColumnsDateMaster]
--					@FYStartMonth			nvarchar(2),
--					@FYMonthOneInNativeYear nvarchar(3)
/**************************************************************************************
Copyright (C) 2003

Created, enhanced, and edited beginning in 2003.
By Dave Rodabaugh at Atlas Analytics. drodabaugh@AtlasAnalytics.com
And Chris Ciappa as Atlas Analytics.  cciappa@AtlasAnalytics.com, cciappa@gmail.com

UPDATED AND CONSOLIDATED
4/1/2010 Chris Ciappa
12/21/2014  Chris Ciappa

   This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see https://www.gnu.org/licenses/.

This procedure adds a fiscal calendar hierarchy to an existing DateMaster table by reading
data from that table and updating rows with new content by populating the fiscal date
columns.

It performs the following steps:
(1)  Validates the existence of a parameter listing the fiscal start and end date.  If
	 one of the two is not present or is not valid, the procedure exits.
(2)  Validates the existence of table DateMaster.  If none exists, the procedure exits.
(3)  Identifies the first and last dates in the DateMaster table.
(4)  Uses data in DateMaster to populate the fiscal standard time columns.

SPECIAL FOR ADS:

(1) ADS has customer time member names in their legacy MSAS system.
Those columns have been added to this procedure and are noted as such.

(2) This procedure no longer accepts input parameters.  Thhey have been hardcoded
below, setting @FYStartMonth = '4' and @FYMonthOneInNativeYear = 'No'.
This procedure should never need to be run again during the life of this application.
*************************************************************************************/

AS

/****************** Variables (SEE SPECIAL NOTE ABOVE)************************************************
@FYMonthOneInNativeYear is a yes/no flag which tells the script how to shift
the fiscal year relative to the calendar year.  By definition, the fiscal year
cannot be identical to the calendar year; it must be shifted by at least one
month.  (See the Time dimension's documentation.)

This script uses the start of the fiscal year to determine the fiscal year
designation.  FY's that start in the first six months of the calendar year
tend to have the same year designation as the calendar year of the first
month.  FY's that start in the last six months of the calendar year tend to
have the next calendar year's designation as the fiscal year designation.
However, this guideline was not deemed enough to make the determination, so this
script requires verification of the shift via parameterized input.

If @FYMonthOneInCalYear is set to 'Yes' then the fiscal year designation is
the same as the calendar year associated with the fiscal year's first month.
If @FYMonthOneInCalYear is set to 'No' then the fiscal year designation is the
calendar year following the year associated with the first fiscal month.  Stated
another way, when the variable is 'No' then the fiscal year designation is the
same as the calendar year associated with the last month of the fiscal year.

Example:  Suppose the fiscal year starts on 2/1/2005 and ends on 1/31/2006.
@FYMonthOneInCalYear = 'Yes' sets the fiscal year for all 12 months to 2005.
@FYMonthOneInCalYear = 'No' sets the fiscal year for all 12 months to 2006.

Formula:
For each row in dimTime...
CONDITION 1:
If @FYMonthOneInCalYear = 'Yes' and the MonthOfYearNumber in the standard hierarchy
>= the first month of the fiscal year, then the FY year = calendar year for the
row in question.  If MonthOfYearNumber < the first month of the fiscal year,
then the FY year = calendar year of the row - 1.

CONDITION 1 Example:  @FYMonthOneInCalYear = 'Yes' and @FYStartMonth = '6/1'
For row 1/1/2006, MonthOfYearNumber = 1, which is < 6: FY year for the row is 2005.
For row 6/1/2006, MonthOfYearNumber = 6, which is >= 6: FY year for the row is 2006.
For row 1/1/2007, MonthOfYearNumber = 12, which is >= 6:  FY year for the row is 2006.

CONDITION 2:
If @FYMonthOneInCalYear = 'No' and the MonthOfYearNumber in the standard hierarchy
>= the first month of the fiscal year, then the FY year = calendar year + 1 for the
row in question.  If MonthOfYearNumber < the first month of the fiscal year,
then the FY year = calendar year of the row.

CONDITION 2 Example:  @FYMonthOneInCalYear = 'No" and @FYStartMonth = '6/1'
For row 1/1/2006, MonthOfYearNumber = 1, which is < 6: FY year for the row is 2006.
For row 6/1/2006, MonthOfYearNumber = 6, which is >= 6: FY year for the row is 2007.
For row 1/1/2007, MonthOfYearNumber = 12, which is >= 6:  FY year for the row is 2007.
******************************************************************************/
/**************** Parameter Test Variables ***********************************
DECLARE @FYStartMonth			nvarchar(2) 1/1/2005
SET		@FYStartMonth			= '4'
DECLARE @FYMonthOneInNativeYear	nvarchar(3)
SET		@FYMonthOneInNativeYear	= 'No'
******************************************************************************/
DECLARE @FYStartMonth			nvarchar(2)
SET		@FYStartMonth			= '4'
DECLARE @FYMonthOneInNativeYear	nvarchar(3)
SET		@FYMonthOneInNativeYear	= 'No'

DECLARE @FYEndMonth				nvarchar(2)
DECLARE @FYMonthOffset			smallint
IF		@FYStartMonth = 1 SET @FYEndMonth = '12' ELSE SET @FYEndMonth = @FYStartMonth - 1
-- @FYEndMonth may need work.  (1) This script assigns a "1" to each day for FYYearEndDate String.
--(2) It should find the actual latest date associated with the month and year in question.
--(3) This is particularly critical if the FY ends in February, and the year in question is a leap year.
--SET		@FYMonthOneInNativeYear	= 'No'
SET		@FYMonthOffset = @FYStartMonth - 1
--PRINT '@FYMonthOffset =' + cast(@FYMonthOffset AS nvarchar(50))

/*************************************************************************************
Verify the existence of the DateMaster table.
*************************************************************************************/
if NOT exists (select * from dbo.sysobjects where id = object_id(N'dbo.[DateMaster]')
	and OBJECTPROPERTY(id, N'IsUserTable') = 1)
BEGIN
	PRINT 'DateMaster table is not present in the database.
	Please create and populate the table, and run this procedure again.'
	RETURN
END

/*************************************************************************************
Find the earliest and latest dates in the DateMaster table.
*************************************************************************************/
DECLARE @FirstDateIndimTime	nvarchar(50)
DECLARE @LastDateIndimTime	nvarchar(50)
/*
SET		@FirstDateIndimTime = (SELECT min(DateString) FROM dimTime)
--PRINT	@FirstDateIndimTime

SET		@LastDateIndimTime = (SELECT max(DateString) FROM dimTime)
--PRINT	@LastDateIndimTime
*/

UPDATE DateMaster

/********** FY Year Information *********************************/
SET
--SELECT
FYYearID = 4400000 + dbo.fnFindFYYearName(
	@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
	DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
	@FYStartMonth,				-- parameter @FYStartMonth
	DateMaster.YearName			-- parameter @YearName
	),
FYYearName = 'FY' + dbo.fnFindFYYearName(
	@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
	DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
	@FYStartMonth,				-- parameter @FYStartMonth
	DateMaster.YearName			-- parameter @YearName
	),
FYYearShortName = 'FY' + right(dbo.fnFindFYYearName(
	@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
	DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
	@FYStartMonth,				-- parameter @FYStartMonth
	DateMaster.YearName			-- parameter @YearName
	), 2),
FYYearFirstDate = dbo.fnFindFYFirstDate (
	@FYMonthOneInNativeYear,
	DateMaster.MonthOfYearNumber,
	@FYStartMonth,
	DateMaster.YearName),
FYYearFirstDateString = cast(@FYStartMonth + '/1/' + substring(cast(dbo.fnFindFYFirstDate(
	@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
	DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
	@FYStartMonth,				-- parameter @FYStartMonth
	DateMaster.YearName			-- parameter @YearName
	) AS nvarchar(25) ), 8 ,4) AS nvarchar(10) ),
FYYearLastDate = dbo.fnFindFYLastDateOfYear(
	DateMaster.MonthOfYearNumber,		-- parameter @MonthOfYearNumber
	@FYStartMonth,					-- parameter @FYStartMonth
	@FYMonthOffset,					-- parameter @FYMonthOffset
	DateMaster.MonthID					-- parameter @MonthID
),
FYYearLastDateString = @FYEndMonth + '/' + right(left(dbo.fnFindFYLastDateOfYear(
	DateMaster.MonthOfYearNumber,		-- parameter @MonthOfYearNumber
	@FYStartMonth,					-- parameter @FYStartMonth
	@FYMonthOffset,					-- parameter @FYMonthOffset
	DateMaster.MonthID					-- parameter @MonthID
), 6) ,2) + '/' + substring(cast(dbo.fnFindFYLastDateOfYear(
		DateMaster.MonthOfYearNumber,		-- parameter @MonthOfYearNumber
		@FYStartMonth,					-- parameter @FYStartMonth
		@FYMonthOffset,					-- parameter @FYMonthOffset
		DateMaster.MonthID					-- parameter @MonthID
		) AS nvarchar(25) ), 8, 4),

-- Legacy column from ADS' old system.
LegacyFiscalYearName = 'Fisc ' + dbo.fnFindFYYearName(
	@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
	DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
	@FYStartMonth,				-- parameter @FYStartMonth
	DateMaster.YearName			-- parameter @YearName
	), -- AS LegacyFiscalYearName,


/********** FY Quarter Information ********************************/

FYQuarterID = DateMaster.QuarterID + 300000,
FYQuarterOfYearNumber = dbo.fnFindFYQuarterOfYearNumber (
		DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
		@FYStartMonth,				-- parameter @FYStartMonth
		@FYMonthOffset				-- parameter @FYMonthOffset
		),
FYQuarterName = 'Qtr ' + cast(dbo.fnFindFYQuarterOfYearNumber (
		DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
		@FYStartMonth,				-- parameter @FYStartMonth
		@FYMonthOffset				-- parameter @FYMonthOffset
		) AS nchar(1) ),
FYQuarterNameWithYear = 'Qtr ' + cast(dbo.fnFindFYQuarterOfYearNumber (
		DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
		@FYStartMonth,				-- parameter @FYStartMonth
		@FYMonthOffset				-- parameter @FYMonthOffset
		) AS nchar(1) ) + ' ' +
		dbo.fnFindFYYearName(
		@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
		DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
		@FYStartMonth,					-- parameter @FYStartMonth
		DateMaster.YearName			-- parameter @YearName
		),
FYQuarterShortName = 'Q' + cast(dbo.fnFindFYQuarterOfYearNumber (
		DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
		@FYStartMonth,				-- parameter @FYStartMonth
		@FYMonthOffset				-- parameter @FYMonthOffset
		) AS nchar(1) ),
FYQuarterShortNameWithYear = 'Q' + cast(dbo.fnFindFYQuarterOfYearNumber (
		DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
		@FYStartMonth,				-- parameter @FYStartMonth
		@FYMonthOffset				-- parameter @FYMonthOffset
		) AS nchar(1) ) + ' FY' +
		dbo.fnFindFYYearName(
		@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
		DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
		@FYStartMonth,				-- parameter @FYStartMonth
		DateMaster.YearName			-- parameter @YearName
		),
FYQuarterShortNameWith2DigitYear = 'Q' + cast(dbo.fnFindFYQuarterOfYearNumber (
		DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
		@FYStartMonth,				-- parameter @FYStartMonth
		@FYMonthOffset				-- parameter @FYMonthOffset
		) AS nchar(1) ) + ' FY' +
			right(dbo.fnFindFYYearName(
			@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
			DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
			@FYStartMonth,				-- parameter @FYStartMonth
			DateMaster.YearName			-- parameter @YearName
			), 2),

-- Legacy column from ADS' old system.
LegacyFiscalQuarterName = 'Fisc ' + dbo.fnFindFYYearName(
	@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
	DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
	@FYStartMonth,				-- parameter @FYStartMonth
	DateMaster.YearName			-- parameter @YearName
	)
+ '-' +
'Quarter ' + cast(dbo.fnFindFYQuarterOfYearNumber (
		DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
		@FYStartMonth,				-- parameter @FYStartMonth
		@FYMonthOffset				-- parameter @FYMonthOffset
		) AS nchar(1) ), --AS LegacyFiscalQuarterName,


/********** FY Month Information ********************************/
FYMonthID = DateMaster.MonthID + 200000,
FYMonthOfYearNumber = dbo.fnFindFYMonthOfYearNumber(
		DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
		@FYStartMonth,				-- parameter @FYStartMonth
		@FYMonthOffset				-- parameter @FYMonthOffset
		),
FYMonthName = DateMaster.MonthName,
FYMonthNameWithYear = DateMaster.MonthName + ' FY' + dbo.fnFindFYYearName(
	@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
	DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
	@FYStartMonth,				-- parameter @FYStartMonth
	DateMaster.YearName			-- parameter @YearName
	),
FYMonthShortName = DateMaster.MonthShortName,
FYMonthShortNameWithYear = DateMaster.MonthShortName + ' FY' + dbo.fnFindFYYearName(
	@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
	DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
	@FYStartMonth,				-- parameter @FYStartMonth
	DateMaster.YearName			-- parameter @YearName
	),
FYMonthShortNameWith2DigitFYYear = DateMaster.MonthShortName + ' FY' + right(dbo.fnFindFYYearName(
	@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
	DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
	@FYStartMonth,				-- parameter @FYStartMonth
	DateMaster.YearName			-- parameter @YearName
	) ,2),
FYMonthFirstDate = DateMaster.MonthFirstDate,
FYMonthFirstDateString = DateMaster.MonthFirstDateString,
FYMonthLastDate = DateMaster.MonthLastDate,
FYMonthLastDateString = DateMaster.MonthLastDateString,

-- Legacy column from ADS' old system.
LegacyFiscalMonthName =
'Fisc ' + dbo.fnFindFYYearName(
	@FYMonthOneInNativeYear,	-- parameter @FYMonthOneInNativeYear
	DateMaster.MonthOfYearNumber,	-- parameter @MonthOfYearNumber
	@FYStartMonth,				-- parameter @FYStartMonth
	DateMaster.YearName			-- parameter @YearName
	)
+ '-' + MonthName --AS LegacyFiscalMonthName

FROM
DateMaster
WHERE
DayID <> -1 --This prevents the UNKNOWN row from being overwritten


GO


/****** Object:  StoredProcedure dbo.[spUpdateDateMasterActiveFlag]    Script Date: 03/24/2010 14:27:35 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.[spUpdateDateMasterActiveFlag]') AND type in (N'P', N'PC'))
DROP PROCEDURE dbo.[spUpdateDateMasterActiveFlag]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE dbo.[spUpdateDateMasterActiveFlag]
/*****
Copyright (C) 2003

Created, enhanced, and edited beginning in 2003.
By Dave Rodabaugh at Atlas Analytics. drodabaugh@AtlasAnalytics.com
And Chris Ciappa as Atlas Analytics.  cciappa@AtlasAnalytics.com, cciappa@gmail.com

UPDATED AND CONSOLIDATED
4/1/2010 Chris Ciappa
12/21/2014  Chris Ciappa

   This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see https://www.gnu.org/licenses/.

From Chris Ciappa: This procedure is to set the IsDateActiveFlag in DateMaster
to 1.  The IsDateActiveFlag column is used to determine selectivity
for the accompanying view vwDimDate which will only display dates
up to the current or last load date and avoid displaying future
dates and times so that they do not have to be suppressed in code or cubes.

This procedure uses GetDate to set the parameter.  However, in the future
this procedure could read data from a control table and the SET statement
removed and the process automated and run using the ISODate input parameter.


****/

@ISODate nVarChar(20) = NULL

AS

SET @ISODate = CONVERT(nVarChar(20),GetDate(),112)

UPDATE DateMaster
SET IsDateActiveFlag = 1
WHERE ISODate <= @ISODate
OR DayID = -1


GO

/****** Object:  View dbo.[dimTime]    Script Date: 03/24/2010 14:28:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



EXECUTE dbo.[spBuildDateMaster] --Parameter values hard coded in proc. See documentation in the proc
GO

IF  EXISTS (SELECT * FROM sys.views WHERE object_id = OBJECT_ID(N'dbo.[vwDimDate]'))
DROP VIEW dbo.[vwDimDate]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW dbo.[vwDimDate]
/****** Object:  View dbo.[vwQADimDateMaster]    Script Date: 05/28/2009 14:28:00
This view is generated from DateMaster to meet the OLAP needs for specific time dimensions
which need only to show dates up to and including the current date and no future dates.

Chris Ciappa      cciappa@atlasanalytics.com

******/

AS

SELECT     DayID, ActualDate, DateString, ISODate, DayOfWeek, DayOfWeekName, DayOfMonth, DayOfQuarter, DayOfYear, Weekday, Weekend, Holiday,
                      LeapDay, WeekID, WeekOfYearNumber, WeekName, WeekNameWithYear, WeekShortName, WeekShortNameWithYear, WeekFirstDate,
                      WeekFirstDateString, WeekLastDate, WeekLastDateString, MonthID, MonthOfYearNumber, MonthName, MonthNameWithYear, MonthShortName,
                      MonthShortNameWithYear, MonthShortNameWith2DigitYear, MonthFirstDate, MonthFirstDateString, MonthLastDate, MonthLastDateString,
                      MonthISOMonth, LegacyCalendarMonthName, QuarterID, QuarterOfYearNumber, QuarterName, QuarterNameWithYear, QuarterShortName,
                      QuarterShortNameWithYear, QuarterShortNameWith2DigitYear, QuarterFirstDate, QuarterFirstDateString, QuarterLastDate, QuarterLastDateString,
                      LegacyCalendarQuarterName, YearID, YearName, YearShortName, YearFirstDate, YearFirstDateString, YearLastDate, YearLastDateString, LeapYear,
                      LegacyCalendarYearName, FYMonthID, FYMonthOfYearNumber, FYMonthName, FYMonthNameWithYear, FYMonthShortName,
                      FYMonthShortNameWithYear, FYMonthShortNameWith2DigitFYYear, FYMonthFirstDate, FYMonthFirstDateString, FYMonthLastDate,
                      FYMonthLastDateString, FYMonthISOMonth, LegacyFiscalMonthName, FYQuarterID, FYQuarterOfYearNumber, FYQuarterName,
                      FYQuarterNameWithYear, FYQuarterShortName, FYQuarterShortNameWithYear, FYQuarterShortNameWith2DigitYear, LegacyFiscalQuarterName,
                      FYYearID, FYYearName, FYYearShortName, FYYearFirstDate, FYYearFirstDateString, FYYearLastDate, FYYearLastDateString, FYLeapYear,
                      LegacyFiscalYearName, IsDateActiveFlag
FROM         dbo.DateMaster
WHERE     (IsDateActiveFlag = 1)

GO


EXECUTE spUpdateDateMasterActiveFlag

GO
/*****
USE [msdb]
GO

/****** Object:  Job [UpdateDateMaster]    Script Date: 03/24/2010 14:33:42 ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Object:  JobCategory [[Uncategorized (Local)]]]    Script Date: 03/24/2010 14:33:42 ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'UpdateDateMaster',
		@enabled=1,
		@notify_level_eventlog=2,
		@notify_level_email=0,
		@notify_level_netsend=0,
		@notify_level_page=0,
		@delete_level=0,
		@description=N'No description available.',
		@category_name=N'[Uncategorized (Local)]',
		@owner_login_name=N'MSCORP\cciap01', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Object:  Step [ExecuteUpdateDateMaster]    Script Date: 03/24/2010 14:33:42 ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'ExecuteUpdateDateMaster',
		@step_id=1,
		@cmdexec_success_code=0,
		@on_success_action=1,
		@on_success_step_id=0,
		@on_fail_action=2,
		@on_fail_step_id=0,
		@retry_attempts=0,
		@retry_interval=0,
		@os_run_priority=0, @subsystem=N'TSQL',
		@command=N'EXEC spUpdateDateMasterActiveFlag',
		@database_name=N'ClientDemo',
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'UpdateTimeSchedule',
		@enabled=1,
		@freq_type=4,
		@freq_interval=1,
		@freq_subday_type=1,
		@freq_subday_interval=0,
		@freq_relative_interval=0,
		@freq_recurrence_factor=0,
		@active_start_date=20100324,
		@active_end_date=99991231,
		@active_start_time=5,
		@active_end_time=235959,
		@schedule_uid=N'54a72299-fd21-43c6-91a4-18cc1b22815b'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
*****/

--SELECT * FROM DateMaster
--SELECT * FROM dimTime
