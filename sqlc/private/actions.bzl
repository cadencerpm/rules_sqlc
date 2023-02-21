# Copyright 2020 Plezentek, Inc. All rights reserved
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load("@bazel_skylib//lib:versions.bzl", "versions")

def sqlc_configure(ctx, params, queries, schemas, out, config_path_depth):
    """Output a JSON file used to control the execution of the SQLC binary"""

    # The following hackery is because our toolchain executable needs to be run
    # from the same directory as the config file, which means we need to do
    # path smashing to make all paths relative to this location.
    # TODO(Windows) Figure out path handling for windows
    back_to_root = "/".join([".."] * config_path_depth)

    # We check the version of the toolchain we're using so that we support the
    # proper features.
    toolchain = ctx.toolchains["@com_plezentek_rules_sqlc//sqlc:toolchain"]
    toolchain_version = toolchain.release.version

    # Here we convert our overrides attribute to something that sqlc can
    # understand
    overrides = []
    for type_, override in params.overrides.items():
        nullable = type_.endswith(":nullable")
        if nullable:
            # Nullable overrides are ignored for older versions, since they
            # aren't supported
            if versions.is_at_least("1.5.0", toolchain_version):
                type_ = type_.split(":")[0]
                if "." in type_:
                    overrides.append(struct(
                        go_type = override.split(":")[0],
                        column = type_,
                        nullable = nullable,
                    ))
                else:
                    overrides.append(struct(
                        go_type = override.split(":")[0],
                        db_type = type_,
                        nullable = nullable,
                    ))
        else:
            type_ = type_.split(":")[0]
            if "." in type_:
                overrides.append(struct(
                    go_type = override.split(":")[0],
                    column = type_,
                ))
            else:
                overrides.append(struct(
                    go_type = override.split(":")[0],
                    db_type = type_,
                ))

    if versions.is_at_least("1.17.0", toolchain_version):
        if params.gen_lang == "python":
            config = struct(
                version = "2",
                plugins = [struct(
                    name = "py",
                    wasm = struct(
                        url = "file://{}/{}".format(back_to_root, ctx.files.py_wasm_plugin[0].path),
                        sha256 = "aca83e1f59f8ffdc604774c2f6f9eb321a2b23e07dc83fc12289d25305fa065b"
                    ),
                )],
                sql = [struct(
                    queries = ["{}/{}".format(back_to_root, p) for p in queries],
                    schema = ["{}/{}".format(back_to_root, p) for p in schemas],
                    engine = params.engine,
                    codegen = [struct(
                        out = '.',
                        plugin = "py",
                        options = struct(
                            package = params.package or ctx.label.name,
                            emit_exact_table_names = params.emit_exact_table_names,
                            emit_async_querier = True,
                            emit_sync_querier = True,
                            emit_pydantic_models = True,
                        )
                    )]
                )]
            ).to_json()
        if params.gen_lang == "go":
            config = struct(
                version = "2",
                sql = [struct(
                    queries = ["{}/{}".format(back_to_root, p) for p in queries],
                    schema = ["{}/{}".format(back_to_root, p) for p in schemas],
                    engine = params.engine,
                    gen = struct(
                        go = struct(
                            out = '.',
                            package = params.package or ctx.label.name,
                            emit_empty_slices = params.emit_empty_slices,
                            emit_result_struct_pointers = params.emit_result_struct_pointers,
                            emit_exact_table_names = params.emit_exact_table_names,
                            emit_interface = params.emit_interface,
                            emit_json_tags = params.emit_json_tags,
                            emit_prepared_queries = params.emit_prepared_queries,
                        )
                    )
                )]
            ).to_json()

    ctx.actions.write(out, config)

def sqlc_compile(ctx, config_file, config_path_depth, srcs, out):
    """Compile a database library from SQLC config and sources"""

    toolchain = ctx.toolchains["@com_plezentek_rules_sqlc//sqlc:toolchain"]

    # The following hackery is because our toolchain executable needs to be run
    # from the same directory as the config file, which means we need to do
    # path smashing to make all paths relative to this location.
    # TODO(Windows) Figure out path handling for windows
    back_to_root = "/".join([".."] * config_path_depth)

    ctx.actions.run_shell(
        tools = [toolchain.release.sqlc, ctx.files.py_wasm_plugin[0]],
        # TODO(Windows) Figure out path handling for windows
        command = "cd {} && HOME=$(pwd) {}/{} generate".format(
            config_file.dirname,
            back_to_root,
            toolchain.release.sqlc.path,
        ),
        inputs = srcs,
        outputs = out,
        mnemonic = "SQLCGenerate",
    )
