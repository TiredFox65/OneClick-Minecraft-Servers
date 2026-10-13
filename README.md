# OneClick Minecraft Servers

OneClick Minecraft Servers is a Windows batch-based server manager for creating, launching, configuring, updating, and backing up Minecraft servers with minimal manual setup. It supports a wide range of vanilla, Paper, Forge, and Fabric versions and includes a built-in compatibility harness for validating server creation and startup behavior before release.

## What’s new in this project

The current installer includes more than a simple server generator. It now supports:

- one-click server creation for multiple Minecraft versions
- automatic version discovery and alias matching
- guided RAM configuration and safe allocation checks
- Java detection and a built-in Java JDK installer flow
- update checks against the latest GitHub release
- uninstall confirmation and cleanup
- backup creation, restore, and load workflows
- automatic `run.bat`, `stop.bat`, and `restart.bat` generation
- an API-style automation mode for scripted creation and inspection
- a debug harness and full compatibility validation flow (`debug.bat all`)

## Supported server versions

The current project supports the following targets:

### Vanilla
- Vanilla-26.3

### Paper
- Paper-26.2

### Forge
- Forge-1.7.10
- Forge-1.8.9
- Forge-1.12.2
- Forge-1.16.5
- Forge-1.18.2
- Forge-1.19.2
- Forge-1.20.1
- Forge-1.20.2
- Forge-1.20.4
- Forge-1.21.1
- Forge-1.21.4

### Fabric
- Fabric-1.14.4
- Fabric-1.15.2
- Fabric-1.16.5
- Fabric-1.18.2
- Fabric-1.19.2
- Fabric-1.20.1
- Fabric-1.20.4
- Fabric-1.21.1
- Fabric-1.21.4

## Requirements

- Windows 10 or Windows 11
- Java installed and available in PATH
- Internet access while downloading server files, Java, or updates
- At least 4 GB of system RAM recommended for normal use

## Quick start

1. Download `Main.bat`.
2. Place it in a new folder that will hold your Minecraft server files.
3. Run `Main.bat`.
4. Use the in-app `help` command or type `help` at the prompt for the menu.

## Main interactive commands

The menu supports the following operations:

- `help` — show available commands
- `Create` — create or overwrite the active server configuration
- `Settings` — configure min/max RAM values and launch memory limits
- `Start` — start the server
- `Stop` — stop the Java server process
- `Restart` — restart the server
- `Status` — show whether the server is currently running
- `Backups` — create, load, or restore backup archives
- `Update` — check GitHub for the latest project release and update the tool
- `InstallJava` — install the recommended Java JDK for the script
- `Uninstall` — remove the project files and generated server data
- `Exit` — close the tool

## API / automation mode

The script supports a lightweight API-style command mode for automation and scripting:

- `Main.bat api --help`
- `Main.bat api --version`
- `Main.bat api --create <MCVersion>`
- `Main.bat api --get <VariableName>`

Example:

```bat
Main.bat api --create Fabric-1.21.4
```

This is useful for automated setup or CI-style validation when a server should be created without using the interactive menu.

## Built-in debug and validation flow

This project includes a dedicated debug tool to validate server creation and startup behavior before shipping changes.

### Debug commands

From the repo root:

```bat
debug.bat
debug.bat all
debug.bat list
debug.bat help
```

What the debug flow does:

- copies `Main.bat` into an isolated temporary test directory
- runs each supported version through the harness
- validates that the server creates successfully
- checks whether the Java process launches and stays running as expected
- verifies RCON readiness and server startup markers
- writes a detailed report to `debugreport.txt`

The `debug.bat all` mode is the full compatibility test flow and should be used before a merge request or release candidate is prepared.

## Backup and data safety

- Backups should be created while the server is stopped.
- Restore and load operations can overwrite the existing server directory.
- Always keep a backup before making large configuration or world changes.

## Safety and scope

This installer only:

- downloads official Minecraft server packages and required dependencies
- downloads required libraries from Maven repositories
- creates files and folders inside the working directory
- generates standard server configuration and launch files

This installer does NOT:

- modify the Windows registry
- install Windows services
- add startup tasks globally
- change unrelated system settings
- collect or transmit personal user data outside the built-in optional telemetry flow

To fully remove it, stop the server and delete the generated project directory.

## Troubleshooting

### Java issues

- Make sure Java is installed and available in PATH.
- If Java is missing, use `InstallJava` from the main menu.
- The script is configured to prefer Eclipse Temurin JDK 25 when Java needs to be installed.

### Internet or download problems

- Confirm that internet access is available.
- Check firewall or antivirus software if a download fails.
- Retry the operation after restarting the tool.

### Server does not appear on the network

Try one of these local addresses when testing:

- `127.0.0.1`
- `127.0.0.1:25565`
- `localhost:25565`
- `<YourIPAddress>:25565`

Use a public IP or a VPN solution for online hosting with friends.

## Notes

- Always keep backups before major changes.
- For mod-specific issues, consult the official Minecraft or mod-loader documentation.
- If you discover a bug or a feature gap, open an issue with as much detail as possible.
- Before a merge request, validate the change with `debug.bat all` so the supported version matrix is covered.

## Acknowledgements

- Thanks to PostHog for supporting anonymized project analytics and survey workflows
- Thanks to GitHub for distribution and release workflows
- Debug harness design and implementation was assisted by the Copilot SDK AI assistant in VS Code

## License

This project is licensed under the MIT License.
