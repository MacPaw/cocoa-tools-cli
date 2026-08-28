public import ArgumentParser

struct Options: ParsableArguments {
  #if os(macOS)
    @Option(name: .long, help: "Path to the .xcresult bundle")
    var xcresult: String?
  #endif
}
