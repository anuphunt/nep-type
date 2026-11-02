# Contributing to NepType

NepType is an open-source Nepali typing project. Bug reports, spelling
corrections, documentation, and code contributions are welcome through
[GitHub issues and pull requests](https://github.com/anuphunt/nep-type).

For a typing issue, include the platform, Roman input, actual Nepali output,
expected output, and output mode. Use an invented example if the original text
contains private information.

Before changing behavior, read the [README](README.md) and the relevant
platform instructions under `platforms/`. Keep changes focused and describe
how you checked them. For changes to the Swift core, run `swift test`; for
platform-specific changes, run the checks documented for that platform.
Preserve original text, cursor behavior, undo/redo, and literal handling.

New dictionaries, training pairs, icons, or other third-party material must
have a documented source and explicit reuse terms. Keep their attribution
with the files and update [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
Do not assume a source repository's code license also covers its datasets.

By submitting your original contributions, you agree to make them available
under the project's [MIT license](LICENSE). Identify any third-party material
and its separate terms in the pull request.
