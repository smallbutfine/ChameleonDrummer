# Contributing to MyProject

Thank you for your interest in improving this FreePascal/Lazarus project!
We welcome all forms of contributions.

## How to Contribute

### 1. Reporting Bugs
- Check the existing Issues to see if the bug has already been reported.
- If not, open a new Issue and describe the problem, your OS, and steps to reproduce it.

### 2. Submitting Changes (Pull Requests)
1. Fork the repository.
2. Create a new branch for your feature or fix (`git checkout -b feature/my-feature`).
3. Make your changes in the Pascal source files inside the `src/` directory.
4. Test your changes locally using `./build_all.bat`.
5. Commit your changes and push them to your fork.
6. Open a Pull Request against the `main` branch.

## Code Style
- Keep the code clean and use standard Object Pascal / Free Pascal formatting.
- Do not change the build scripts (`build_all.bat`, `installer.iss`) without discussing it in an Issue first.
- The source must be platform-independent — never hardcode `.exe` or path separators.
  Use the conditional pattern from `gui/CliLookup.pas`:

```pascal
Result := ExtractFilePath(ParamStr(0)) + 'tool' +
  {$IFDEF MSWINDOWS}'.exe'{$ELSE}''{$ENDIF};
```

## Build

See `README.md` for build instructions. In short:

```bash
./build_all.bat            # all targets + packages into Deploy/
./build_all.bat --check    # verify the toolchain only
```

## License

By contributing, you agree that your contributions will be licensed under the
MIT License (see `LICENSE`).