public import ArgumentParser

struct Options: ParsableArguments {
  @Option(name: .long, help: "Path to the .xcresult bundle")
  var xcresult: String
}
