# installation recovery

Before installing, confirm the target is Arch-based, review the installer, and verify a backup can be created. Avoid elevated privileges unless required. Keep a TTY login path available during desktop changes. If the graphical session fails, switch to a TTY, restore the timestamped configuration backup, disable newly added autostart entries if needed, and inspect Hyprland logs before reinstalling packages.

## Preflight before applying changes

- Confirm the checkout path and back up the exact files the installer will replace.
- Inspect shell scripts and follow any downloaded installer or package instructions before running them with elevated privileges.
- Verify required commands are installed before enabling autostart entries; quote paths and avoid relying on the current working directory.
- Apply one compositor or display-manager change at a time, validate configuration where the application supports it, and keep a working TTY recovery route.
- After a successful login, test keyboard shortcuts, networking, audio, and wallpaper selection before removing the backup.

## Symlink and backup handling

Before replacing a configuration file, inspect whether the destination is a regular file, symlink, or directory. Do not follow an unexpected symlink into an unrelated location during backup or restore. Store backups with restrictive permissions and preserve the original file mode where practical. Restore to a temporary file in the same directory, validate it, and then replace the target atomically; never delete the only known-good copy before the replacement is confirmed.
