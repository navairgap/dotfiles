# config change safety

Make one configuration change at a time and keep a known-good backup. Validate syntax before logging out of the working session. Preserve a TTY recovery path and avoid changing display manager settings and compositor configuration simultaneously. For new autostart commands, verify executable paths and avoid blocking the session. Document package prerequisites and review install scripts before running them.
