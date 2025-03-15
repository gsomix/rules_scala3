package rules_scala3
package common.sbt_testing

import java.net.{URL, URLClassLoader}

import scala.language.unsafeNulls

object ClassLoaders:
  def withContextClassLoader[A](classLoader: ClassLoader)(f: => A) =
    val thread = Thread.currentThread
    val previous = thread.getContextClassLoader
    thread.setContextClassLoader(classLoader)
    try f
    finally thread.setContextClassLoader(previous)

  def sbtTestClassLoader(urls: Seq[URL]) =
    new URLClassLoader(urls.toArray, ClassLoader.getPlatformClassLoader()):
      private val current = getClass.getClassLoader()
      override protected def findClass(className: String): Class[?] =
        if className.startsWith("sbt.testing.") then current.loadClass(className)
        else if className.startsWith("org.jacoco.agent.rt.") then current.loadClass(className)
        else super.findClass(className)
