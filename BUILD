load("@rules_scala3//deps:scala_deps.bzl", "scala_deps")
load("@rules_scala3//rules:scala.bzl", "configure_zinc_scala")

filegroup(
    name = "dependencies",
    srcs = ["Dependencies.scala"],
    visibility = ["//visibility:public"],
)

scala_deps(
    name = "scala_deps",
    src = "//:dependencies",
    dependencies = "rules_scala3.Dependencies",
)

runtime_classpath_3 = [
    "@scala3_library//jar",
    "@scala_library_2_13//jar",
]

compiler_classpath_3 = runtime_classpath_3 + [
    "@scala3_compiler//jar",
    "@scala3_interfaces//jar",
    "@scala_tasty_core_3//jar",
    "@scala_asm//jar",
]

configure_zinc_scala(
    name = "zinc_3",
    compiler_bridge = "@scala3_sbt_bridge//jar",
    compiler_classpath = compiler_classpath_3,
    runtime_classpath = runtime_classpath_3,
    version = "3.6.4",
    visibility = ["//visibility:public"],
)
