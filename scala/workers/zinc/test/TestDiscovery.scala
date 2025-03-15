package rules_scala3
package workers.zinc.test

import scala.collection.mutable
import scala.language.unsafeNulls

import sbt.testing.{AnnotatedFingerprint, Framework, SubclassFingerprint}
import xsbt.api.Discovery
import xsbti.api.{AnalyzedClass, ClassLike, Definition}

import common.sbt_testing.{TestAnnotatedFingerprint, TestDefinition, TestSubclassFingerprint}

final class TestDiscovery(framework: Framework):
  private val (annotatedPrints, subclassPrints) =
    val annotatedSet = mutable.HashSet.empty[TestAnnotatedFingerprint]
    val subclassSet = mutable.HashSet.empty[TestSubclassFingerprint]

    framework.fingerprints.foreach {
      case fingerprint: AnnotatedFingerprint => annotatedSet += TestAnnotatedFingerprint(fingerprint)
      case fingerprint: SubclassFingerprint  => subclassSet += TestSubclassFingerprint(fingerprint)
    }

    (annotatedSet.toSet, subclassSet.toSet)

  private def definitions(classes: Set[AnalyzedClass]) =
    classes.toSeq
      .flatMap(`class` => Seq(`class`.api.classApi, `class`.api.objectApi))
      .flatMap(api => Seq(api, api.structure.declared, api.structure.inherited))
      .collect { case cl: ClassLike if cl.topLevel => cl }

  private def discover(definitions: Seq[Definition]) =
    Discovery(subclassPrints.map(_.superclassName), annotatedPrints.map(_.annotationName))(definitions)

  def apply(classes: Set[AnalyzedClass]) =
    for
      (definition, discovered) <- discover(definitions(classes))
      fingerprint <-
        subclassPrints.collect {
          case print if discovered.baseClasses(print.superclassName) && discovered.isModule == print.isModule => print
        } ++
          annotatedPrints.collect {
            case print if discovered.annotations(print.annotationName) && discovered.isModule == print.isModule => print
          }
    yield new TestDefinition(definition.name, fingerprint)
