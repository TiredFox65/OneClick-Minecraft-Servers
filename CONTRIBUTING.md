# Contributing

Thanks for your interest in improving OneClick Minecraft Servers. Bug reports, documentation updates, and focused code changes are welcome.

## Before you start

- Read the project documentation and review the current issues before starting work.
- For larger or behavioral changes, open an issue first so the approach is discussed with the maintainers.
- Keep changes focused and avoid committing generated server data, backups, logs, or personal files.

## Reporting a bug

Open a GitHub issue with:

- your Windows version
- the `Main.bat` version you are using
- clear reproduction steps
- the expected result and the actual behavior
- the exact error message or logs, with any private data removed

For security issues, follow the private reporting instructions in [SECURITY.md](./SECURITY.md) instead of opening a public issue.

## Submitting a change

1. Fork the repository and create a branch for your fix or feature.
2. Keep the patch as small and targeted as possible.
3. Preserve existing server creation behavior unless the change intentionally updates it.
4. Update the README or other user-facing docs when behavior, setup, or commands change.
5. Validate the change with the project debug tools before opening a merge request.

## Required validation before a merge request

This project includes a built-in debug harness and a full compatibility flow. Contributors must run the debug validation flow before starting a merge request.

Use the project root and run:

```bat
debug.bat all
```

You can also inspect the available debug modes with:

```bat
debug.bat help
debug.bat list
```

The `debug all` flow runs the automated compatibility harness, which:

- creates isolated debug copies of the project
- exercises supported Minecraft versions
- validates server generation and startup behavior
- checks launch and readiness conditions
- records issue details in `debugreport.txt`

Do not open a merge request until the debug suite passes or any failing result is clearly understood and documented.

## Local testing guidance

There is no full automated CI suite in this repository. Use a disposable Windows working directory and validate the behavior that your change affects.

For server creation or startup changes, confirm:

- the version still creates successfully
- the generated `run.bat` launches correctly
- the server process starts and remains healthy
- the relevant commands still behave as expected

For backup, restore, update, and uninstall flows, test only with disposable data because these operations can overwrite files and folders.

## Project license

By submitting a contribution, you agree that it may be distributed under the project's [MIT License](./LICENSE).
