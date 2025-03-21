# AsyncProcess

**AsyncProcess** is a lightweight Swift package for running Terminal commands with full support for `async/await`.

## Installation

To install via the Swift Package Manager add the following line to your `Package.swift` file's `dependencies`:

```swift
.package(url: "https://github.com/SomeRandomiOSDev/async-process.git", from: "0.0.1")
```

## Usage

First import **AsyncProcess** at the top of your Swift file:

```swift
import AsyncProcess
```

After importing, you can initialize an instance of `AsyncProcess` to configure it, then eventually run. 

```swift
let process = AsyncProcess(executable: .zsh)

process.currentDirectory = ...
process.arguments = ...

try await process.run()
```

There are a number of convenience methods that can be used to perform a given command and capture its output using different shells:

```swift
let output = try await AsyncProcess.zsh(
    command: "ls",
    arguments: ["-ali", "$HOME"],
    captureOutput: true
)
```

## Notes

This library is still a work in progress, primarily in terms of structuring around the repo itself as well as comprehensive unit testing. Although possible, the interface of this library is unlikely to significantly change between releases until the first "stable" release of this library.

## Author

Joe Newton, somerandomiosdev@gmail.com

## License

**AsyncProcess** is available under the MIT license. See the `LICENSE` file for more info.
