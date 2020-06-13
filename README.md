btrbu
=====

btrbu is another btrfs snapshot and backup script.  I wrote it because my needs were modest and it seemed like a nice project to sink my teeth into.  It will bootstrap itself if no backups exist and uses a keep policy similar to that of borg (ie- specifying a number of keeps at different time intervals).  It's written in lua, because lua lends itself to sensible looking config files in it's native syntax and lua is a pretty easy language to use.

The information btrbu needs is minimal- a snapshot directory, an archive name and a subvolume that corresponds to that name.  If a backup is desired, then a backup path must also be specified.  For now, it is assumed that the destination is a btrfs file system since the script takes advantage of btrfs send/receive commands.

Another (I think!) nice "feature" of btrbu is that it doesn't rely on any external databases or files for information about the system.  It simply gets all it's needed information from the system and goes from there.  So external dependencies beyond lua are minimized.

Usage
-----

For simple snapshot and backup needs, a command can be as simple as:

    btrbu --snapshot-dir=/pool/snapshots --backup-dir=/backup archive1=/path/to/subvolume

Assuming a start from nothing, this will take a snapshot of `/path/to/subvolume` and place it in `/pool/snapshots` with a timestamp suffix.  So the snapshot name will be of the form `archive.YYYYMMddhhmm`.  This snapshot will then be used to send a full backup to `/backup`. 

Subsequent use of this same command will result in incremental backups which will just advance the timestamp associated with the archive.  The default keep policy is 1 day, so only 1 snapshot and backup are kept.  See [keep policy][] below for how to change the keep behavior.

[keep policy]: #keep-policy

More than 1 archive can be specified on the command line:

    btrbu --snapshot-dir=/pool/snapshots --backup-dir=/backup archive1=/path/to/subvolume archive2=/path/to/subvolume2

These archives will share the same snapshot and backup destination, but obviously have different names qualified with a timestamp.

For a full list of options and their explanations, `btrbu --help` is useful.

Configuration Files
-------------------

At some point, if backing up several different subvolumes for instance, a configuration file might become desirable to make the command line more manageable.  btrbu will look for a configuration file in `~/.config/btrbu-conf` if no file is specified on the command line.  Alternatively:

    btrbu --config=/path/to/myconfig

Configuration files take advantage of lua's table syntax.  Don't worry, it's extremely easy to use.  A configuration file looks simply like so:

```
    return { 
        subvolumes =  {
            archive1="/path/to/subvolume1",
            archive2="/path/to/subvolume2",
            archive3="/path/to/subvolume3",
        },
        -- the leading double-dash means a comment to lua, so that can be taken
        -- advantage of as well
        snapshot_dir = "/pool/snapshots",
        backup_dir = "/backup",
    }
```

If an option can be specified on the command line, it can also be specified in the configuration file.  Be sure to susbstitute a `'_'` for any `'-'` characters in the command line option.  So the `--snapshot-dir` option would be specified as `snapshot_dir` in a configuration file.

Configuration files and command line options can be mixed and matched as well.  The rule is that the command line overrides any configuration file settings.  For archive name/ subvolume pairs, anything specified on the command line overrides ALL of the subvolumes in the configuration file.  So if there are 5 subvolumes specified in the configuration file, but a single achive/subvolume is specified on the command line, only the command line archive/subvolume is dealt with.  Basically, btrbu assumes the user knows what they are doing and tries not to get in the way.

Keep Policy
-----------

btrbu uses a keep policy for snapshots similar to [borgbackup][].  It uses daily, weekly and monthly timeframes to determine what to keep.  The relevant options are `keep-daily`, `keep-weekly` and `keep-monthly` and the value assigned is the number of backups to keep at that particular timeframe. The timeframes are applied in ascending order and there is no overlap, meaning a snapshot/backup kept because of a daily keep doesn't count towards a weekly or monthly keep.  The keep is ALWAYS the most recent available for a given timeframe.

When first starting up, weekly and monthly keeps will not apply until those timeframes become relevant.  Weekly timeframes are referenced from Saturday, meaning that weekly keeps won't be applied until a Saturday backup becomes available.  Similarly, monthly keeps will not apply until snapshots and backups are made in a new month, since daily and weekly keeps will initially satisfy a monthly requirement.

If there is an existing set of backups, then the keep policy will be applied to all those and only those snapshot and backups that meet the keep policy criteria will be kept.  Note that the keep policy applies to BOTH snapshots and backups.

An example of a configuration file with a keep policy:

```
    return { 
        subvolumes =  {
            archive1="/path/to/subvolume1",
            archive2="/path/to/subvolume2",
            archive3="/path/to/subvolume3",
        },
        -- the leading double-dash means a comment to lua, so that can be taken
        -- advantage of as well
        snapshot_dir = "/pool/snapshots",
        backup_dir = "/backup",

        keep_daily = 4,
        keep_weekly = 2,
        keep_monthly = 1,
    }
```

btrbu does NOT have a keep policy below a 1 day timeframe.  So multiple backups within the same day will be subject to pruning by any keep policy.  The most recent snapshot/backups from that day will be kept in those cases.

[borgbackup]: https://borgbackup.org

Hooks
-----

Hooks allow for external programs to be coordinated with the creation of snapshots and backups.  There are 3 types of hooks:  pre-snapshot, post-snapshot and backup.  All referring to the timing when the hooks are run.  The idea was to facilitate creating an all-in-one-place backup solution so that snapshot or backup creation could be paired with backing up to a remote server.  Or some kind of pre-processing or massaging could be done prior to taking snapshots.

Hooks can only be configured in a configuration file.  They are not availabe on the command line.  The configuration values for the file are as follows:
+ `presnaphooks` - a list of commands to run
+ `postsnaphooks` - a table of commands where the key is an archive name
+ `backuphooks` - a table of commands where the key is an archive name

To make the hooks more useful, it is possible to use substitution strings when creating a hook command.  btrbu will parse the command and swap in the appropriate value for the substitution string.  Following are lists of the substitution strings availabe for each type of hook.

presnapshot:
+ `{timestamp}` - the timestamp for the current run of btrbu is substituted
+ `{backupdir}` - the configured backup directory is substituted
+ `{snapshotdir}` - the configured snapshot directory is substituted

postsnapshot:
+ `{snapshot}` - the full path and name of the snapshot is substituted
+ `{archive}` - just the name of the archive, no path, is substituted
+ `{timestamp}`
+ `{backupdir}`
+ `{snapshotdir}`

backup:
+ `{backup}` - the full path and name of the backup is substituted
+ `{snapshot}`
+ `{archive}`
+ `{timestamp}`
+ `{backupdir}`
+ `{snapshotdir}`

An example of a configuration file with some hooks in it:

```
return {
    subvolumes = {
        archive1 = "/home/user1",
        archive2 = "/usr/local/cloud",
    },

    -- lua allows for dbl brackets to denote a string, making it easy to craft a shell command with 
    -- funky characters
    presnaphooks = {
        [[echo "Starting snapshot and backup process- {timestamp}" > ~/backuplog]],
        [[/home/user/myspecialprebackupscript]]
    },

    postsnaphooks = {
        archive1 = [[borg create --verbose --list --filter AME user@server:repo::{archive} {snapshot} 2>~/borglog]],
    },

    -- note that table entries are separated with commas
    backuphooks = {
        archive1 = [[echo "Can't think of anything more original to show here."]],
        archive2 = [[borg create user@server:repo::{archive} {backup} 2>>~/borglog]],
    },

    snapshot_dir = "/pool/snapshots",
    backup_dir = "/backups/,
    .
    .
    .
    .
}
```

The `presnaphook` in the above example is trivial.  It does show a substitution usage. It invokes a timestamp substitution, so the output of the echo would actually be something like `Starting snapshot and backup process- 202006122148.`  The second entry would run the named script.

The `postsnaphook` shows how a potential `borgback` could be launched, using the just taken snapshot as the source for a backup to a remote server.  btrbu will make sure that it does not exit until the borg process is completed.  The association with `archive1` in the table gives the user access to the extra substitutions such as `{snapshot}`. In this case, `{archive}` would become `archive1` in the actual command and `{snapshot}` would become `/pool/snapshots/archive1.202006122148`. (Note I just made up the timestamp value.  Obviously this would be different when actually run.)

Finally, the `backuphook` shows multiple hooks, one associated with each archive.  The `{backup}` substitution would work out to be `/backups/archive2.202006122148` with the same caveat as before applying to the timestamp portion of the name.

It should be mentioned that there is a slight difference in timing of the execution between `postsnaphooks` and `backuphooks`.  The `postsnaphooks` are executed after ALL snapshots are taken.  While `backuphooks` are run after EACH backup is completed.  So in the above example, the `echo` command in the `backuphooks` is executed immediately after the backup for `archive1` is completed.  Whereas the `borg create` command in the `postsnaphooks` section is run after both snapshots are taken.  Snapshots happen more or less immediately, while backups can vary depending on the size, changes and whether it's an incremental or full backup.
