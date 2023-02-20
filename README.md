# [sqlc](https://github.com/kyleconroy/sqlc) rules for [Bazel](https://bazel.build)

This repository contains rules for Bazel that allow you to compile your SQL
files into a Go package that can be used for type-safe database code.

## Table of Contents
1. [Setup](#setup)
2. [Usage](#usage)
3. [Documentation](#documentation)

## Setup
The first thing you need to do is load the rules in your WORKSPACE file to make
them available in your Bazel repository.

```Starlark
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

http_archive(
    name = "com_plezentek_rules_sqlc",
    sha256 = "ac0c69ad3f3f49a2f5c068a7ac946a52ce0d8389927f279eff2dca00f2631df1",
    urls = [
        "https://github.com/plezentek/rules_sqlc/releases/download/v0.9.1/rules_sqlc-v0.9.1.tar.gz"
    ],
)

load("@com_plezentek_rules_sqlc//sqlc:deps.bzl", "sqlc_register_toolchains", "sqlc_rules_dependencies")

sqlc_rules_dependencies()

sqlc_register_toolchains()
```

Pass in a version to `sqlc_register_toolchains` if your code depends on an
older version of the compiler:

```Starlark
sqlc_register_toolchains(version="1.5.0")
```

If you'd like to use the development version of these rules, you can fetch them
with `git_repository` by setting the `commit` parameter to a recent commit hash.

```Starlark
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "com_plezentek_rules_sqlc",
    commit = "<RECENT_COMMIT>",
    remote = "https://github.com/plezentek/rules_sqlc",
)

load("@com_plezentek_rules_sqlc//sqlc:deps.bzl", "sqlc_register_toolchains", "sqlc_rules_dependencies")

sqlc_rules_dependencies()

sqlc_register_toolchains()
```

## Usage
In order to generate a Go/Python package called `database`, use the following
`sql_package` rule.

```Starlark
load("@com_plezentek_rules_sqlc//sqlc:def.bzl", "sqlc_package")

sqlc_package(
    name = "product_database",
    package = "database",
    queries = ["query.sql"],
    schema = ["schema.sql"],
    gen_lang = "python" or "go", # default is "go"
)
```

You can combine this with [rules_go](https://github.com/bazelbuild/rules_go) in
order to compile a Go library. Notice how the `package` and the `importpath`
coincide.

```Starlark
load("@com_plezentek_rules_sqlc//sqlc:def.bzl", "sqlc_package")
load("@io_bazel_rules_go//go:def.bzl", "go_library")

sqlc_package(
    name = "product_database",
    package = "database",
    queries = ["query.sql"],
    schema = ["schema.sql"],
)

go_library(
    name = "product_library",
    srcs = [":product_database"],
    importpath = "example.com/owner/repo/database",
)
```

# Documentation
Full details on the use of the sqlc_package rule can be found in the [rules
documentation](docs/rules.md).

The `SQLCRelease` bazel provider (for writers of further bazel rules) can be
found in the [provider documentation](docs/providers.md).
