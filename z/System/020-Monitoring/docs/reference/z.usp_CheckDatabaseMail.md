# z.usp_CheckDatabaseMail

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CheckDatabaseMail.sql)

## Purpose and behavior

Configures a Database Mail profile and account for outgoing SQL Server mail. Despite its name, this changes server configuration and `msdb`; it is not a read-only health check. Use it only when its fixed SMTP settings match your environment: `smtp.office365.com`, port 25, with SSL.

It enables Database Mail when needed, creates missing profile/account entries, associates them, and makes the selected profile the guest default, replacing existing default guest-profile associations. Existing account settings are retained rather than updated. A later error can leave earlier configuration changes applied.

## Parameters and defaults

```text
@ProfileName nvarchar(128) = 'Default Email',
@DisplayName nvarchar(128) = 'Database Alert',
@DefaultEmailAddress nvarchar(128) = 'aaa@bbb.com',
@Password nvarchar(128) = 'passwrod'
```

`@ProfileName` names the profile/account to create or reuse. `@DisplayName` is the sender display name, `@DefaultEmailAddress` is the sender address and SMTP username, and `@Password` supplies its SMTP password. Replace the shipped address/password placeholders with deployment-specific values.

## Results, permissions, and limits

No defined result set. Requires authority to reconfigure the server and administer Database Mail. Supply deployment-specific values at runtime; shipped email/password defaults are placeholders, not usable configuration.

## Dependencies

Native dependencies: `msdb.dbo.sysmail_account`, `msdb.dbo.sysmail_add_account_sp`, `msdb.dbo.sysmail_add_principalprofile_sp`, `msdb.dbo.sysmail_add_profile_sp`, `msdb.dbo.sysmail_add_profileaccount_sp`, `msdb.dbo.sysmail_delete_principalprofile_sp`, `msdb.dbo.sysmail_principalprofile`, `msdb.dbo.sysmail_profile`, `msdb.dbo.sysmail_profileaccount`, `sys.configurations`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
