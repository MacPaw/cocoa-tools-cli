// swift-format-ignore-file
#if os(Linux)
  // Glibc import must be the first import.
  // Issue: https://github.com/swiftlang/swift/issues/77866
  #if canImport(Glibc)
  @preconcurrency import Glibc
  #elseif canImport(Musl)
  @preconcurrency import Musl
  #endif
#endif

import Foundation
import SharedLogger
import protocol ArgumentParser.AsyncParsableCommand

// Making sure that output will be shown immediately, as it comes in the script
#if os(macOS)
  setbuf(__stdoutp, nil)
#elseif os(Linux)
  setbuf(stdout, nil)
#endif

if ProcessInfo.processInfo.arguments.contains("--verbose") {
  Logger.setLogLevel(.debug)
}

_ = await Task {
  await MPCT.main()
}.result
