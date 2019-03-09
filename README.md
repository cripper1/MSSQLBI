# MSSQLBI
Shared code useful for MSBI
DimDateMaster is code that creates a well formed Date Dimension table for SQL Server all versions 2005 through 2017.  This date dimenson will populate per your settings and also will contain sequential integer keys at every level of the dimension, very useful for olap and simple math between any two periods.  Will also optionally populate all fiscal columns.  Set to be future dated and the view it creates as well as a SQL job (Optional) will set an iscurrent flag in the table each night at midnight and the view will be through the current date.
