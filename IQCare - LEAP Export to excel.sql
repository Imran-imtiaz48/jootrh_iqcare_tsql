CREATE procedure proc_generate_excel_with_columns
(
    @db_name    varchar(100),
    @table_name varchar(100),   
    @file_name  varchar(MAX)
)
as

--Generate column names as a recordset
declare @columns varchar(8000), @sql varchar(8000), @data_file varchar(8000)
select 
	@columns=coalesce(@columns+',','')+column_name+' as '+'[' + column_name + ']'
from 
    information_schema.columns
where 
    table_name=@table_name
select @columns=''''''+replace(replace(@columns,' as ',''''' as '),',',',''''')

--Create a dummy file to have actual data
select @data_file=substring(@file_name,1,len(@file_name)-charindex('\',reverse(@file_name)))+'\data_file.xls'

--Generate column names in the passed EXCEL file
set @sql='exec master..xp_cmdshell ''bcp " select * from (select '+@columns+') as t" queryout "'+@file_name+'" -c -T'''
exec(@sql)

--Generate data in the dummy file
set @sql='exec master..xp_cmdshell ''bcp "select * from '+@db_name+'..'+@table_name+'" queryout "'+@data_file+'" -c -T'''
--print @sql
exec(@sql)

--Copy dummy file to passed EXCEL file
set @sql= 'exec master..xp_cmdshell ''type '+@data_file+' >> "'+@file_name+'"'''
--print @sql
exec(@sql)

--Delete dummy file 
set @sql= 'exec master..xp_cmdshell ''del '+@data_file+''''
--print @sql
exec(@sql)

go
--select * from LEAPWeek6
EXEC proc_generate_excel_with_columns 'IQTools_KeHMIS', 'LEAPWeek6','D:\Users\Administrator\Documents\LEAP_Line_list\LEAPWeek6.xls'
