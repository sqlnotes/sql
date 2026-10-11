# Pre-deployment scripts

Place SQL scripts here for checks or preparation that must happen before the
rest of the System deployment, such as validating database settings or prerequisites.

This folder runs first on every deployment, even when hash checking is enabled.
Scripts should be safe to run repeatedly. A script error stops deployment.

You can organize scripts into subfolders. These folders do not become separate
subsystems or receive their own version records. Follow the standard folder
execution order; SQL files within each folder run in name order.
