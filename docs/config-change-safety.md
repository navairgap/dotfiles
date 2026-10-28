# config change safety

Make one configuration change at a time and keep a known-good backup. Validate syntax before logging out of the working session. Preserve a TTY recovery path and avoid changing display manager settings and compositor configuration simultaneously. For new autostart commands, verify executable paths and avoid blocking the session. Document package prerequisites and review install scripts before running them.

## Recovery sequence

If the graphical session fails after a configuration change, switch to a TTY before reinstalling packages. Restore only the affected configuration from the known-good backup, then run the compositor's configuration validation command where available. Check the session log and disable the most recently added autostart entry if startup blocks. Keep the backup until login, keyboard shortcuts, audio, networking, and wallpaper selection have been checked in a fresh session.
