// swift-format-ignore-file
#if os(Linux)
  // Glibc import must be the first import.
  // Issue: https://github.com/swiftlang/swift/issues/77866
  @preconcurrency import Glibc
#endif

import Foundation

import protocol ArgumentParser.AsyncParsableCommand

// Making sure that output will be shown immediately, as it comes in the script
#if os(macOS)
  setbuf(__stdoutp, nil)
#elseif os(Linux)
  setbuf(stdout, nil)
#endif

_ = await Task { await MPCT.main() }.result
