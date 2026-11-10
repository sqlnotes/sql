/*
Author: John Huang
Author blog: https://www.sqlnotes.info/
Repository: https://github.com/sqlnotes/sql
Source: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/modules/1040%20Procedures/z.usp_AsyncChannelDeploy.sql
Documentation: https://github.com/sqlnotes/sql/blob/main/z/System/050-AsyncChannel/docs/reference/z.usp_AsyncChannelDeploy.md

Executes missing or explicitly forced generated scripts in order.
*/
create or alter procedure z.usp_AsyncChannelDeploy
(
	@AsyncChannelID int,
	@ForceDeployment bit = 0
)
as
begin
	set nocount, xact_abort on;
	declare @GeneratedScript nvarchar(max)
	declare Scripts cursor local static for
		select GeneratedScript
		from z.v_AsyncChannelScripts
		where AsyncChannelID = @AsyncChannelID
			and (NeedDeployment = 1 or (@ForceDeployment = 1 and ObjectType not in ('Interface','Queue','Service','Processing')))
		order by Ordinal
	open Scripts
	fetch next from Scripts into @GeneratedScript
	while @@fetch_status = 0
	begin
		exec(@GeneratedScript)
		fetch next from Scripts into @GeneratedScript
	end
	close Scripts
	deallocate Scripts
end
