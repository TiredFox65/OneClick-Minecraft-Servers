# OneClick-Minecraft-Servers

A simple Windows batch-based Minecraft server installer for creating and managing servers with a few guided commands.

## Features

- Create new Minecraft servers with a single command
- Supports multiple server types and versions
- Built-in status, start, stop, restart, and backup controls
- Update checking against the latest GitHub release
- Java detection and optional Java install flow
- Uninstall flow with confirmation and cleanup
- API-style commands for automation and scripting

## Supported Versions

The installer supports the following versions:

- Vanilla: 26.3
- Paper: 26.2
- Forge: 1.7.10, 1.8.9, 1.12.2, 1.16.5, 1.18.2, 1.19.2, 1.20.1, 1.20.2, 1.20.4, 1.21.1, 1.21.4
- Fabric: 1.14.4, 1.15.2, 1.16.5, 1.18.2, 1.19.2, 1.20.1, 1.20.4, 1.21.1, 1.21.4

## Requirements

- Windows 10 or Windows 11
- Java installed and available in PATH
- Internet access for downloading server files and updates
- At least 4 GB of RAM recommended for normal use

## Quick Start

1. Download `Main.bat`.
2. Place it in a new folder that will hold your Minecraft server files.
3. Run `Main.bat`.
4. Use `help` to see the available commands.

## Main Commands

The interactive menu accepts commands such as:

- `help` - show available commands
- `Create` - create or overwrite the current server
- `Settings` - configure RAM values
- `Start` - start the server
- `Stop` - force-stop the server
- `Restart` - restart the server
- `Status` - check whether the server is running
- `Backups` - create, load, or restore backups
- `Update` - check for newer releases and update the tool
- `InstallJava` - install the recommended Java version if needed
- `Uninstall` - remove the project and server files
- `Exit` - close the tool

## API Usage

The script also supports a basic API mode for scripted use:

- `Main.bat api --help`
- `Main.bat api --version`
- `Main.bat api --create <MCVersion>`
- `Main.bat api --get <VariableName>`

Example:

```bat
Main.bat api --create Fabric-1.21.4
```

## Backup Safety

- Backups should be created while the server is stopped.
- Restore and load operations can overwrite existing server data.
- Always keep a backup before making large configuration changes.

## Safety

This installer only:

- Downloads Minecraft server files from Mojang and supported modded-server sources
- Downloads required libraries from Maven repositories
- Creates files and folders inside the selected directory
- Generates standard server configuration files

This installer does NOT:

- Modify the Windows registry
- Install Windows services
- Add startup tasks
- Change system settings outside the generated server files
- Collect or transmit personal user data

To fully remove it, stop the server and delete the installation directory.

## Troubleshooting

### Java issues

- Make sure Java is installed and available in PATH.
- If Java is missing, use the `InstallJava` command from the main menu.
- Use Java JDK 25 or a supported equivalent when possible.

### Internet or download problems

- Confirm that internet access is available.
- Check firewall or antivirus software if downloads fail.
- Retry the operation after restarting the installer.

### Server does not appear on the network

Use one of these addresses when testing locally:

- `127.0.0.1`
- `127.0.0.1:25565`
- `localhost:25565`
- `<YourIPAddress>:25565`

Use a public IP or VPN solution for online hosting with friends.

## Notes

- Always keep backups before major changes.
- For mod-specific issues, consult the official Minecraft or mod documentation.
- If you discover a bug or missing feature, open an issue with as much detail as possible.

## Acknowledgements

- Thanks to PostHog for Helping with Surveys
- Thanks to GitHub for Helping with Distributing
- Debug harness design and implementation assisted by the Copilot SDK AI assistant in VS Code

## License

This project is licensed under the MIT License.
