# Contributing

Thanks for your interest in improving OneClick-Minecraft-Servers! Bug reports,
documentation improvements, and focused code changes are welcome.

## Before You Start

- Check the README and existing GitHub issues to see whether the problem or
  proposal has already been covered.
- For substantial changes, open an issue first to discuss the approach.
- Keep changes focused and avoid including generated server files, backups,
  logs, or other personal data in commits or issue reports.

## Reporting a Bug

Open a GitHub issue with:

- The Windows version and the version of `Main.bat` you are using.
- Clear steps to reproduce the problem and what you expected to happen.
- The exact error message or relevant logs, with personal or sensitive
  information removed.

For security issues, follow the private reporting instructions in
[SECURITY.md](./SECURITY.md) instead of opening a public issue.

## Submitting a Change

1. Fork the repository and create a branch for your change.
2. Make the smallest clear change that addresses the issue.
3. Keep the program compatible with the Windows versions documented in the
   README, and preserve existing command behavior unless the change requires
   otherwise.
4. Update relevant user-facing documentation when behavior or instructions
   change.
5. Test the affected behavior via `debug.bat`, then open a pull request describing the
   motivation, the changes, and how you tested them. Link any related issue.

## Testing

There is no automated test suite at this time. Test batch-file changes on
Windows in a disposable working directory. Where applicable, check startup,
status, settings, and the commands affected by your change. Test backup and
restore operations only with disposable server data; these operations can
overwrite files. Changes involving downloads or server installation may
require Java and an internet connection.

## Project License

By submitting a contribution, you agree that it may be distributed under the
project's [MIT License](./LICENSE).