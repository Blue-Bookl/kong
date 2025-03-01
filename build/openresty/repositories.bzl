"""A module defining the third party dependency OpenResty"""

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")
load("@kong_bindings//:variables.bzl", "KONG_VAR")
load("//build/openresty/pcre:pcre_repositories.bzl", "pcre_repositories")
load("//build/openresty/openssl:openssl_repositories.bzl", "openssl_repositories")
load("//build/openresty/atc_router:atc_router_repositories.bzl", "atc_router_repositories")

# This is a dummy file to export the module's repository.
_NGINX_MODULE_DUMMY_FILE = """
filegroup(
    name = "all_srcs",
    srcs = glob(["**"]),
    visibility = ["//visibility:public"],
)
"""

def openresty_repositories():
    pcre_repositories()
    openssl_repositories()
    atc_router_repositories()

    openresty_version = KONG_VAR["RESTY_VERSION"]

    maybe(
        openresty_http_archive_wrapper,
        name = "openresty",
        build_file = "//build/openresty:BUILD.openresty.bazel",
        sha256 = "0c5093b64f7821e85065c99e5d4e6cc31820cfd7f37b9a0dec84209d87a2af99",
        strip_prefix = "openresty-" + openresty_version,
        urls = [
            "https://openresty.org/download/openresty-" + openresty_version + ".tar.gz",
        ],
        patches = KONG_VAR["OPENRESTY_PATCHES"],
        patch_args = ["-p1"],
    )

    maybe(
        new_git_repository,
        name = "lua-kong-nginx-module",
        branch = KONG_VAR["KONG_NGINX_MODULE_BRANCH"],
        remote = "https://github.com/Kong/lua-kong-nginx-module",
        build_file_content = _NGINX_MODULE_DUMMY_FILE,
        recursive_init_submodules = True,
    )

    maybe(
        new_git_repository,
        name = "lua-resty-lmdb",
        branch = KONG_VAR["RESTY_LMDB_VERSION"],
        remote = "https://github.com/Kong/lua-resty-lmdb",
        build_file_content = _NGINX_MODULE_DUMMY_FILE,
        recursive_init_submodules = True,
        patches = ["//build/openresty:lua-resty-lmdb-cross.patch"],
        patch_args = ["-p1", "-l"],  # -l: ignore whitespace
    )

    maybe(
        new_git_repository,
        name = "lua-resty-events",
        branch = KONG_VAR["RESTY_EVENTS_VERSION"],
        remote = "https://github.com/Kong/lua-resty-events",
        build_file_content = _NGINX_MODULE_DUMMY_FILE,
        recursive_init_submodules = True,
    )

def _openresty_binding_impl(ctx):
    ctx.file("BUILD.bazel", _NGINX_MODULE_DUMMY_FILE)
    ctx.file("WORKSPACE", "workspace(name = \"openresty_patch\")")

    version = "LuaJIT\\\\ 2.1.0-"
    for path in ctx.path("../openresty/bundle").readdir():
        if path.basename.startswith("LuaJIT-2.1-"):
            version = version + path.basename.replace("LuaJIT-2.1-", "")
            break

    ctx.file("variables.bzl", 'LUAJIT_VERSION = "%s"' % version)

openresty_binding = repository_rule(
    implementation = _openresty_binding_impl,
)

def openresty_http_archive_wrapper(name, **kwargs):
    http_archive(name = name, **kwargs)
    openresty_binding(name = name + "_binding")
