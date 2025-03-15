##
## top level rules
##

load("@bazel_skylib//lib:dicts.bzl", _dicts = "dicts")
load(
    "@rules_scala3//rules:jvm.bzl",
    _labeled_jars = "labeled_jars",
)
load(
    "@rules_scala3//rules:providers.bzl",
    _ScalaConfiguration = "ScalaConfiguration",
    _ScalaRulePhase = "ScalaRulePhase",
    _ZincConfiguration = "ZincConfiguration",
)
load(
    "@rules_scala3//rules/private:coverage_replacements_provider.bzl",
    _coverage_replacements_provider = "coverage_replacements_provider",
)
load(
    "//rules/private:phases.bzl",
    _phase_binary_deployjar = "phase_binary_deployjar",
    _phase_binary_launcher = "phase_binary_launcher",
    _phase_classpaths = "phase_classpaths",
    _phase_coda = "phase_coda",
    _phase_coverage_jacoco = "phase_coverage_jacoco",
    _phase_javainfo = "phase_javainfo",
    _phase_library_defaultinfo = "phase_library_defaultinfo",
    _phase_noop = "phase_noop",
    _phase_resources = "phase_resources",
    _phase_singlejar = "phase_singlejar",
    _phase_test_launcher = "phase_test_launcher",
    _run_phases = "run_phases",
)
load(
    "//rules/scala:private/doc.bzl",
    _scaladoc_implementation = "scaladoc_implementation",
    _scaladoc_private_attributes = "scaladoc_private_attributes",
)
load(
    "//rules/scala:private/import.bzl",
    _scala_import_implementation = "scala_import_implementation",
    _scala_import_private_attributes = "scala_import_private_attributes",
)
load(
    "//rules/scala:private/provider.bzl",
    _configure_bootstrap_scala_implementation = "configure_bootstrap_scala_implementation",
    _configure_zinc_scala_implementation = "configure_zinc_scala_implementation",
)
load(
    "//rules/scala:private/repl.bzl",
    _scala_repl_implementation = "scala_repl_implementation",
)

_compile_private_attributes = {
    "_java_toolchain": attr.label(
        default = "@bazel_tools//tools/jdk:current_java_toolchain",
        providers = [java_common.JavaToolchainInfo],
    ),
    "_singlejar": attr.label(
        cfg = "exec",
        default = "@remote_java_tools//:singlejar_cc_bin",
        executable = True,
    ),
    "_jdk": attr.label(
        default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
        providers = [java_common.JavaRuntimeInfo],
        cfg = "exec",
    ),
    "_jar_creator": attr.label(
        default = Label("@remote_java_tools//:ijar_cc_binary"),
        executable = True,
        cfg = "exec",
    ),
}

_compile_attributes = {
    "srcs": attr.label_list(
        doc = "The source Scala and Java files (and `.srcjar` files of those).",
        allow_files = [
            ".scala",
            ".java",
            ".srcjar",
        ],
    ),
    "data": attr.label_list(
        doc = "The additional runtime files needed by this library.",
        allow_files = True,
    ),
    "deps": attr.label_list(
        aspects = [
            _labeled_jars,
            _coverage_replacements_provider.aspect,
        ],
        doc = "The JVM library dependencies.",
        providers = [JavaInfo],
    ),
    "deps_used_whitelist": attr.label_list(
        doc = "The JVM library dependencies to always consider used for `scala_deps_used` checks.",
        providers = [JavaInfo],
    ),
    "deps_unused_whitelist": attr.label_list(
        doc = "The JVM library dependencies to always consider unused for `scala_deps_direct` checks.",
        providers = [JavaInfo],
    ),
    "runtime_deps": attr.label_list(
        doc = "The JVM runtime-only library dependencies.",
        providers = [JavaInfo],
    ),
    "javacopts": attr.string_list(
        doc = "The Javac options.",
    ),
    "plugins": attr.label_list(
        doc = "The Scalac plugins.",
        providers = [JavaInfo],
    ),
    "resource_strip_prefix": attr.string(
        doc = "The path prefix to strip from classpath resources.",
    ),
    "resources": attr.label_list(
        allow_files = True,
        doc = "The files to include as classpath resources.",
    ),
    "resource_jars": attr.label_list(
        allow_files = [".jar"],
        doc = "The JARs to merge into the output JAR.",
    ),
    "scala": attr.label(
        doc = "Specify the scala compiler. If not specified, the toolchain will be used.",
        providers = [
            _ScalaConfiguration,
        ],
    ),
    "scalacopts": attr.string_list(
        doc = "The Scalac options.",
    ),
}

_library_attributes = {
    "exports": attr.label_list(
        aspects = [
            _coverage_replacements_provider.aspect,
        ],
        doc = "The JVM libraries to add as dependencies to any libraries dependent on this one.",
        providers = [JavaInfo],
    ),
    "macro": attr.bool(
        default = False,
        doc = "Whether this library provides macros.",
    ),
    "neverlink": attr.bool(
        default = False,
        doc = "Whether this library should be excluded at runtime.",
    ),
}

_runtime_attributes = {
    "jvm_flags": attr.string_list(
        doc = "The JVM runtime flags.",
    ),
    "runtime_deps": attr.label_list(
        doc = "The JVM runtime-only library dependencies.",
        providers = [JavaInfo],
    ),
}

_runtime_private_attributes = {
    "_target_jdk": attr.label(
        default = Label("@bazel_tools//tools/jdk:current_java_runtime"),
        providers = [java_common.JavaRuntimeInfo],
    ),
    "_java_stub_template": attr.label(
        default = Label("@bazel_tools//tools/java:java_stub_template.txt"),
        allow_single_file = True,
    ),
}

_testing_private_attributes = {
    # Mandated by Bazel, with values set according to the java rules
    # in https://github.com/bazelbuild/bazel/blob/0.22.0/src/main/java/com/google/devtools/build/lib/bazel/rules/java/BazelJavaTestRule.java#L69-L76
    "_jacocorunner": attr.label(
        default = Label("@bazel_tools//tools/jdk:JacocoCoverage"),
        cfg = "exec",
    ),
    "_lcov_merger": attr.label(
        default = Label("@bazel_tools//tools/test/CoverageOutputGenerator/java/com/google/devtools/coverageoutputgenerator:Main"),
        cfg = "exec",
    ),
}

def _extras_attributes(extras):
    return {
        "_phase_providers": attr.label_list(
            default = [pp for extra in extras for pp in extra["phase_providers"]],
            providers = [_ScalaRulePhase],
        ),
    }

def _scala_library_implementation(ctx):
    return _run_phases(ctx, [
        ("resources", _phase_resources),
        ("classpaths", _phase_classpaths),
        ("javainfo", _phase_javainfo),
        ("compile", _phase_noop),
        ("singlejar", _phase_singlejar),
        ("coverage", _phase_coverage_jacoco),
        ("library_defaultinfo", _phase_library_defaultinfo),
        ("coda", _phase_coda),
    ]).coda

def _scala_binary_implementation(ctx):
    return _run_phases(ctx, [
        ("resources", _phase_resources),
        ("classpaths", _phase_classpaths),
        ("javainfo", _phase_javainfo),
        ("compile", _phase_noop),
        ("singlejar", _phase_singlejar),
        ("coverage", _phase_coverage_jacoco),
        ("binary_deployjar", _phase_binary_deployjar),
        ("binary_launcher", _phase_binary_launcher),
        ("coda", _phase_coda),
    ]).coda

def _scala_test_implementation(ctx):
    return _run_phases(ctx, [
        ("resources", _phase_resources),
        ("classpaths", _phase_classpaths),
        ("javainfo", _phase_javainfo),
        ("compile", _phase_noop),
        ("singlejar", _phase_singlejar),
        ("coverage", _phase_coverage_jacoco),
        ("test_launcher", _phase_test_launcher),
        ("coda", _phase_coda),
    ]).coda

def make_scala_library(*extras):
    return rule(
        attrs = _dicts.add(
            _compile_attributes,
            _compile_private_attributes,
            _library_attributes,
            _extras_attributes(extras),
            *[extra["attrs"] for extra in extras]
        ),
        doc = "Compiles a Scala JVM library.",
        outputs = _dicts.add(
            {
                "jar": "%{name}.jar",
                "src_jar": "%{name}-src.jar",
            },
            *[extra["outputs"] for extra in extras]
        ),
        implementation = _scala_library_implementation,
        toolchains = [
            "@rules_scala3//scala3:toolchain_type",
            "@bazel_tools//tools/jdk:toolchain_type",
        ],
    )

scala_library = make_scala_library()

def make_scala_binary(*extras):
    return rule(
        attrs = _dicts.add(
            _compile_attributes,
            _compile_private_attributes,
            _runtime_attributes,
            _runtime_private_attributes,
            {
                "main_class": attr.string(
                    doc = "The main class. If not provided, it will be inferred by its type signature.",
                ),
            },
            _extras_attributes(extras),
            *[extra["attrs"] for extra in extras]
        ),
        doc = """
Compiles and links a Scala JVM executable.

Produces the following implicit outputs:

  - `<name>_deploy.jar`: a single jar that contains all the necessary information to run the program
  - `<name>.jar`: a jar file that contains the class files produced from the sources
  - `<name>-bin`: the script that's used to run the program in conjunction with the generated runfiles

To run the program: `bazel run <target>`
""",
        executable = True,
        outputs = _dicts.add(
            {
                "bin": "%{name}-bin",
                "jar": "%{name}.jar",
                "src_jar": "%{name}-src.jar",
                "deploy_jar": "%{name}_deploy.jar",
            },
            *[extra["outputs"] for extra in extras]
        ),
        implementation = _scala_binary_implementation,
        toolchains = [
            "@rules_scala3//scala3:toolchain_type",
            "@bazel_tools//tools/jdk:toolchain_type",
        ],
    )

scala_binary = make_scala_binary()

def make_scala_test(*extras):
    return rule(
        attrs = _dicts.add(
            _compile_attributes,
            _compile_private_attributes,
            _runtime_attributes,
            _runtime_private_attributes,
            _testing_private_attributes,
            {
                "isolation": attr.string(
                    default = "none",
                    doc = "The isolation level to apply",
                    values = [
                        "classloader",
                        "none",
                        "process",
                    ],
                ),
                "scalacopts": attr.string_list(),
                "shared_deps": attr.label_list(
                    doc = "If isolation is \"classloader\", the list of deps to keep loaded between tests",
                    providers = [JavaInfo],
                ),
                "frameworks": attr.string_list(
                    default = [
                        "com.novocode.junit.JUnitFramework",
                        "hedgehog.sbt.Framework",
                        "minitest.runner.Framework",
                        "munit.Framework",
                        "org.scalacheck.ScalaCheckFramework",
                        "org.scalatest.tools.Framework",
                        "utest.runner.Framework",
                    ],
                ),
                "runner": attr.label(default = "@rules_scala3//scala/workers/zinc/test"),
                "parallel": attr.bool(default = True),
                "parallel_n": attr.int(),
                "subprocess_runner": attr.label(default = "@rules_scala3//scala/common/sbt-testing:subprocess"),
                "_agent": attr.label(
                    default = "@rules_scala3//scala/common/worker:BlockSystemExitAgent.jar",
                    allow_files = True,
                ),
            },
            _extras_attributes(extras),
            *[extra["attrs"] for extra in extras]
        ),
        doc = """
Compiles and links a collection of Scala tests.

To buid and run all tests: `bazel test <target>`

To build and run a specific test: `bazel test <target> --test_filter=<filter_expression>`
<br>(Note: the syntax of the `<filter_expression>` varies by test framework, and not all test frameworks support the `test_filter` option at this time.)

[More Info](/docs/scala.md#tests)
""",
        executable = True,
        outputs = _dicts.add(
            {
                "bin": "%{name}-bin",
                "jar": "%{name}.jar",
                "src_jar": "%{name}-src.jar",
            },
            *[extra["outputs"] for extra in extras]
        ),
        test = True,
        implementation = _scala_test_implementation,
        toolchains = [
            "@rules_scala3//scala3:toolchain_type",
            "@bazel_tools//tools/jdk:toolchain_type",
        ],
    )

scala_test = make_scala_test()

# scala_repl

_scala_repl_private_attributes = _dicts.add(
    _runtime_private_attributes,
    {
        "_runner": attr.label(
            cfg = "exec",
            executable = True,
            default = "@rules_scala3//scala/workers/zinc/repl",
        ),
    },
)

scala_repl = rule(
    attrs = _dicts.add(
        _scala_repl_private_attributes,
        {
            "data": attr.label_list(
                doc = "The additional runtime files needed by this REPL.",
                allow_files = True,
            ),
            "deps": attr.label_list(providers = [JavaInfo]),
            "jvm_flags": attr.string_list(
                doc = "The JVM runtime flags.",
            ),
            "scala": attr.label(
                doc = "Specify the scala compiler. If not specified, the toolchain will be used.",
                providers = [
                    _ScalaConfiguration,
                    _ZincConfiguration,
                ],
            ),
            "scalacopts": attr.string_list(
                doc = "The Scalac options.",
            ),
            "initial_commands": attr.string(
                doc = "Initial commands",
            ),
            "cleanup_commands": attr.string(
                doc = "Cleanup commands",
            ),
        },
    ),
    doc = """
Launches a REPL with all given dependencies available.

To run: `bazel run <target>`
""",
    executable = True,
    outputs = {
        "bin": "%{name}-bin",
    },
    implementation = _scala_repl_implementation,
    toolchains = [
        "@rules_scala3//scala3:toolchain_type",
    ],
)

scala_import = rule(
    attrs = _dicts.add(
        _scala_import_private_attributes,
        {
            "deps": attr.label_list(providers = [JavaInfo]),
            "exports": attr.label_list(providers = [JavaInfo]),
            "jars": attr.label_list(allow_files = True),
            "neverlink": attr.bool(default = False),
            "runtime_deps": attr.label_list(providers = [JavaInfo]),
            "srcjar": attr.label(allow_single_file = True),
        },
    ),
    doc = """
Creates a Scala JVM library.

Use this only for libraries with macros. Otherwise, use `java_import`.
""",
    implementation = _scala_import_implementation,
    toolchains = [
        "@bazel_tools//tools/jdk:toolchain_type",
    ],
)

scaladoc = rule(
    attrs = _dicts.add(
        _scaladoc_private_attributes,
        {
            "compiler_deps": attr.label_list(providers = [JavaInfo]),
            "deps": attr.label_list(providers = [JavaInfo]),
            "srcs": attr.label_list(allow_files = [
                ".java",
                ".scala",
                ".srcjar",
            ]),
            "scala": attr.label(
                doc = "Specify the scala compiler. If not specified, the toolchain will be used.",
                providers = [
                    _ScalaConfiguration,
                    _ZincConfiguration,
                ],
            ),
            "scalacopts": attr.string_list(),
            "title": attr.string(),
        },
    ),
    doc = """
Generates Scaladocs.
""",
    implementation = _scaladoc_implementation,
    toolchains = [
        "@rules_scala3//scala3:toolchain_type",
    ],
)

##
## core/underlying rules and configuration ##
##

configure_bootstrap_scala = rule(
    attrs = {
        "version": attr.string(mandatory = True),
        "compiler_classpath": attr.label_list(
            mandatory = True,
            providers = [JavaInfo],
        ),
        "runtime_classpath": attr.label_list(
            mandatory = True,
            providers = [JavaInfo],
        ),
        "global_plugins": attr.label_list(
            doc = "Scalac plugins that will always be enabled.",
            providers = [JavaInfo],
        ),
        "global_scalacopts": attr.string_list(
            doc = "Scalac options that will always be enabled.",
        ),
        "global_jvm_flags": attr.string_list(
            doc = "JVM flags that will always be passed.",
        ),
    },
    implementation = _configure_bootstrap_scala_implementation,
)

_configure_zinc_scala = rule(
    attrs = {
        "version": attr.string(mandatory = True),
        "runtime_classpath": attr.label_list(
            mandatory = True,
            providers = [JavaInfo],
        ),
        "compiler_classpath": attr.label_list(
            mandatory = True,
            providers = [JavaInfo],
        ),
        "compiler_bridge": attr.label(
            allow_single_file = True,
            mandatory = True,
        ),
        "global_plugins": attr.label_list(
            doc = "Scalac plugins that will always be enabled.",
            providers = [JavaInfo],
        ),
        "global_scalacopts": attr.string_list(
            doc = "Scalac options that will always be enabled.",
        ),
        "global_jvm_flags": attr.string_list(
            doc = "JVM flags that will always be passed.",
        ),
        "log_level": attr.string(
            doc = "Compiler log level",
            default = "warn",
        ),
        "deps_direct": attr.string(default = "error"),
        "deps_used": attr.string(default = "error"),
        "_compile_worker": attr.label(
            default = "@rules_scala3//scala/workers/zinc/compile",
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
        "_deps_worker": attr.label(
            default = "@rules_scala3//scala/workers/deps",
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
        "_code_coverage_instrumentation_worker": attr.label(
            default = "@rules_scala3//scala/workers/jacoco/instrumenter",
            allow_files = True,
            executable = True,
            cfg = "exec",
        ),
    },
    implementation = _configure_zinc_scala_implementation,
)

def configure_zinc_scala(**kwargs):
    _configure_zinc_scala(
        deps_direct = select({
            "@rules_scala3//scala:deps_direct_off": "off",
            "//conditions:default": "error",
        }),
        deps_used = select({
            "@rules_scala3//scala:deps_used_off": "off",
            "//conditions:default": "error",
        }),
        **kwargs
    )
