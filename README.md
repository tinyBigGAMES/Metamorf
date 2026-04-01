<div align="center">

![Metamorf](media/logo.png)

<br>

[![Discord](https://img.shields.io/discord/1457450179254026250?style=for-the-badge&logo=discord&label=Discord)](https://discord.gg/Wb6z8Wam7p) [![Follow on Bluesky](https://img.shields.io/badge/Bluesky-tinyBigGAMES-blue?style=for-the-badge&logo=bluesky)](https://bsky.app/profile/tinybiggames.com)

</div>

## What is Metamorf?

**Metamorf** is a Turing complete programming language for building compilers. You describe a complete programming language in a `.mor` file, covering tokens, types, grammar rules, semantic analysis, and C++23 code generation. Metamorf reads that file and immediately uses it to compile source files to native Win64/Linux64 binaries via Zig/Clang.

```bash
Metamorf -l pascal.mor -s hello.pas -r
```

One file defines your language. One command compiles and runs your program.

## Why Metamorf?

Most language definition tools (YACC, ANTLR, traditional BNF grammars) give you a declarative grammar and then punt to a host language for anything non-trivial. Metamorf is different. It is a **complete, Turing complete language** with variables, assignment, unbounded loops, conditionals, arithmetic, string operations, and user-defined routines with recursion, all first-class constructs alongside declarative grammar rules and token definitions.

No host language glue code. No build system integration. No escape hatch to C, Java, or Python. A single `.mor` file is a complete, portable, standalone language specification that produces native binaries.

**What you get:**

- **Single-file language definitions** covering the entire pipeline: lexer tokens, Pratt parser grammar, semantic analysis, and C++23 code generation
- **Turing complete language** with variables, loops, conditionals, recursion, and string operations as first-class constructs
- **Pratt parser grammar rules** with declarative prefix/infix/statement patterns and full imperative constructs for complex parsing
- **IR builder code generation** producing structured C++23 through typed builders
- **Automatic C++ passthrough** so your language can interoperate with C/C++ without any `.mor` configuration
- **Modular imports** for splitting large language definitions across multiple `.mor` files
- **Native binary output** for Win64 and Linux64 via Zig/Clang, with cross-compilation through WSL2

## How It Works

Metamorf reads your `.mor` file, populates its internal dispatch tables (token definitions, grammar rules, semantic handlers, emitter handlers), then uses those tables to lex, parse, analyze, and generate C++23 from your source file. The generated C++ is compiled to a native binary via Zig/Clang.

```
  ┌─────────────┐     ┌──────────────┐     ┌──────────────────┐
  │ mylang.mor  │────►│ .mor parser  │────►│ dispatch tables  │
  └─────────────┘     └──────────────┘     └────────┬─────────┘
                                                    │
  ┌─────────────────┐                               │
  │ myprogram.src   │───┐                           │
  └─────────────────┘   │                           │
                        ▼                           ▼
                  ┌─────────────────────────────────────┐
                  │ lex ──► parse ──► analyze ──► C++23 │
                  └──────────────────┬──────────────────┘
                                     │
                               ┌─────┴─────┐
                               │ Zig/Clang │
                               └─────┬─────┘
                                     │
                             ┌───────┴───────┐
                             │ native binary │
                             └───────────────┘
```

See the [Metamorf Manual](docs/Metamorf.md) for the complete guide: architecture, grammar rules, semantic analysis, code emission, type inference, worked examples, and a checklist for building a new language.

## Getting Started

Metamorf ships as a self-contained release with everything included. No separate toolchain download, no configuration.

1. Download the latest release from [GitHub Releases](https://github.com/tinyBigGAMES/Metamorf/releases)
2. Extract the archive to any directory
3. Write a `.mor` language definition and a source file, then compile:

```bash
Metamorf -l mylang.mor -s hello.src
```

To build and run in one step:

```bash
Metamorf -l mylang.mor -s hello.src -r
```

To target Linux from Windows, install WSL2 with Ubuntu:

```bash
wsl --install -d Ubuntu
```

### Getting the Source

```bash
git clone https://github.com/tinyBigGAMES/Metamorf.git
```

```
Metamorf/repo/
  src/              <- Metamorf core sources
  tests/            <- Test files including pascal.mor, lua.mor, scheme.mor
  docs/             <- Reference documentation
  bin/              <- Executables run from here
```

## System Requirements

| | Requirement |
|---|---|
| **Host OS** | Windows 10/11 x64 |
| **Linux target** | WSL2 + Ubuntu (`wsl --install -d Ubuntu`) |
| **Building from source** | Delphi 12 or higher |

## Building from Source

Each release includes the full source alongside the binaries. No separate download required.

1. Download the latest release from [GitHub Releases](https://github.com/tinyBigGAMES/Metamorf/releases) and extract it
2. Open `src\Metamorf - Language Engineering Platform.groupproj` in Delphi 12 or higher
3. Build the project

> [!IMPORTANT]
> This repository is under active development. Language surfaces may change without notice. Each release aims to be stable and usable as we work toward v1.0. Follow the repo or join the [Discord](https://discord.gg/Wb6z8Wam7p) to track progress.

## Contributing

Metamorf is an open project. Whether you are fixing a bug, improving documentation, adding a new showcase language, or proposing a feature, contributions are welcome.

- **Report bugs**: Open an issue with a minimal reproduction. The smaller the example, the faster the fix.
- **Suggest features**: Describe the use case first. Features that emerge from real problems get traction fastest.
- **Submit pull requests**: Bug fixes, documentation improvements, new language examples, and well-scoped features are all welcome. Keep changes focused.

Join the [Discord](https://discord.gg/Wb6z8Wam7p) to discuss development, ask questions, and share what you are building.

## Support the Project

Metamorf is built in the open. If it saves you time or sparks something useful:

- ⭐ **Star the repo**: it costs nothing and helps others find the project
- 🗣️ **Spread the word**: write a post, mention it in a community you are part of
- 💬 **[Join us on Discord](https://discord.gg/Wb6z8Wam7p)**: share what you are building and help shape what comes next
- 💖 **[Become a sponsor](https://github.com/sponsors/tinyBigGAMES)**: sponsorship directly funds development and documentation
- 🦋 **[Follow on Bluesky](https://bsky.app/profile/tinybiggames.com)**: stay in the loop on releases and development

## License

Metamorf is licensed under the **Apache License 2.0**. See [LICENSE](https://github.com/tinyBigGAMES/Metamorf/tree/main?tab=License-1-ov-file#readme) for details.

Apache 2.0 is a permissive open source license that lets you use, modify, and distribute Metamorf freely in both open source and commercial projects. You are not required to release your own source code. The license includes an explicit patent grant. Attribution is required; keep the copyright notice and license file in place.

## Links

- [metamorf.dev](https://metamorf.dev)
- [Discord](https://discord.gg/Wb6z8Wam7p)
- [Bluesky](https://bsky.app/profile/tinybiggames.com)
- [tinyBigGAMES](https://tinybiggames.com)

<div align="center">

**Metamorf™** - Define It. Compile It. Ship It.

Copyright &copy; 2025-present tinyBigGAMES™ LLC<br/>All Rights Reserved.

</div>
