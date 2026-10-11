# z.usp_CheckDatabaseMail

[Monitoring](../readme.md) | [Source](../../modules/1070%20Procedures/z.usp_CheckDatabaseMail.sql)

## Purpose and behavior

Enable show advanced options and Database Mail XPs when needed. Create a missing profile/account, associate them, remove existing default guest-profile associations and add this profile as guest default. Existing accounts are not updated. SMTP host smtp.office365.com, port 25, and SSL are fixed in source. No explicit transaction or catch provides atomic rollback.

## Parameters and defaults

```text
@ProfileName nvarchar(128) = 'Default Email',@DisplayName nvarchar(128) = 'Database Alert',@DefaultEmailAddress nvarchar(128) = 'aaa@bbb.com',@Password nvarchar(128) = 'passwrod'
```

These are the source-declared types and defaults.

## Results, permissions, and limits

No defined result set. Requires authority to reconfigure the server and administer Database Mail. Supply deployment-specific values at runtime; shipped email/password defaults are placeholders, not usable configuration.

## Dependencies

Native dependencies: `msdb.dbo.sysmail_account`, `msdb.dbo.sysmail_add_account_sp`, `msdb.dbo.sysmail_add_principalprofile_sp`, `msdb.dbo.sysmail_add_profile_sp`, `msdb.dbo.sysmail_add_profileaccount_sp`, `msdb.dbo.sysmail_delete_principalprofile_sp`, `msdb.dbo.sysmail_principalprofile`, `msdb.dbo.sysmail_profile`, `msdb.dbo.sysmail_profileaccount`, `sys.configurations`.

See [architecture](../architecture.md) and [troubleshooting](../troubleshooting.md) for subsystem-wide constraints.
