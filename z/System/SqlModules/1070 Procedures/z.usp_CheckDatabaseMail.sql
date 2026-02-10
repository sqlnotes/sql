create or alter  procedure z.usp_CheckDatabaseMail
(
	@ProfileName nvarchar(128) = 'Default Email',
	@DisplayName nvarchar(128) = 'Database Alert',
	@DefaultEmailAddress nvarchar(128) = 'aaa@bbb.com',
	@Password nvarchar(128) = 'passwrod'
	
)
as
begin
	set nocount on
	if exists(select * from sys.configurations where name = 'show advanced options' and value_in_use = 0)
	begin
		exec sp_configure 'show advanced options',1
		reconfigure with override 
	end
	if exists(select * from sys.configurations where name = 'Database Mail XPs' and value_in_use = 0)
	begin
		exec sp_configure 'Database Mail XPs',1
		reconfigure with override 
	end

	if not exists(select * from msdb.dbo.sysmail_profile where  name = @ProfileName) 
	begin
		exec msdb.dbo.sysmail_add_profile_sp @profile_name = @ProfileName, @description  = 'This profile is to send alert.';
	end
	if not exists(select * from msdb.dbo.sysmail_account WHERE  name = @ProfileName)
	begin
		exec msdb.dbo.sysmail_add_account_sp	@account_name            = @ProfileName,
												@email_address           = @DefaultEmailAddress,
												@display_name            = @DisplayName,
												@replyto_address         = @DefaultEmailAddress,
												@description             = '',
												@mailserver_name         = 'smtp.office365.com',
												@mailserver_type         = 'SMTP',
												@port                    = '25',
												@username                = @DefaultEmailAddress,
												@password                = @Password, 
												@use_default_credentials =  0 ,
												@enable_ssl              =  1 ;
	end

	if not exists(
					select *
					from msdb.dbo.sysmail_profileaccount pa
						inner join msdb.dbo.sysmail_profile p on pa.profile_id = p.profile_id
						inner join msdb.dbo.sysmail_account a on pa.account_id = a.account_id  
					where p.name = @ProfileName
						and a.name = @ProfileName
				) 
	begin
		exec msdb.dbo.sysmail_add_profileaccount_sp @profile_name = @ProfileName, @account_name = @ProfileName, @sequence_number = 1 ;
	end
	declare @SQL nvarchar(max)
	select @SQL = (
					select 'exec msdb.dbo.sysmail_delete_principalprofile_sp @principal_name=N''guest'', @profile_name=N'''+p.name+''';'
					from msdb.dbo.sysmail_profile  p
						inner join msdb.dbo.sysmail_principalprofile pp on p.profile_id = pp.profile_id
					where pp.principal_sid = 0x00
						and pp.is_default = 1
					for xml path(''), type
					).value('.', 'nvarchar(max)')
	exec(@SQL)
	exec msdb.dbo.sysmail_add_principalprofile_sp @principal_name = N'guest', @profile_name = @ProfileName, @is_default = 1
end
GO

