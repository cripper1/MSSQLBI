# MSSQLBI
Shared code useful for MSBI
DimDateMaster is code that creates a well formed Date Dimension table for SQL Server all versions 2005 through 2017.  This date dimenson will populate per your settings and also will contain sequential integer keys at every level of the dimension, very useful for olap and simple math between any two periods.  Will also optionally populate all fiscal columns.  Dimension table is meant to be future dated and the view it creates will be current dates, as it will also create a stored proc and a SQL job (Optional) that will set an iscurrent flag in the table each night at a time you choose to run the job, and the view will set the iscurrent flag. Thus the view will be current dated.
