# macos-harness

Test harness for verifying [react-native-enriched-markdown](https://github.com/workspace-sh/react-native-enriched-markdown) on macOS via [react-native-macos](https://github.com/nicklockwood/react-native-macos).

Lives at `examples/macos-harness/` inside the library repo — Metro and CocoaPods resolve the library from `../..`.

## Prerequisites

- Node >= 20
- Ruby (with bundler) for CocoaPods
- Xcode with macOS SDK

## Setup

```sh
npm install --ignore-scripts
cd macos && LANG=en_US.UTF-8 pod install && cd ..
```

If the library needs codegen:

```sh
cd ../..
npm install
npx bob build
cd examples/macos-harness/macos && LANG=en_US.UTF-8 pod install && cd ..
```

## running

```sh
# terminal 1
npx react-native start

# terminal 2
npx react-native run-macos
```

If port 8081 is busy:

```sh
npx react-native start --port 8083
RCT_METRO_PORT=8083 npx react-native run-macos
```

Alternatively, open `macos/workspace.xcworkspace` in Xcode and run the `workspace-macOS` scheme directly.

> **Note:** If you launch from Xcode, `RCT_METRO_PORT` has no effect — the app will always connect to port 8081. Make sure Metro is running on 8081 if using Xcode, or use the CLI approach above for alternate ports.

## Metro configuration for local libraries

The `metro.config.js` is configured to resolve the locally-linked library correctly:

- **`watchFolders`** — tells Metro to watch the library source directory for changes
- **`extraNodeModules`** — maps `react-native-enriched-markdown` to the local path (Metro doesn't follow symlinks by default)
- **`nodeModulesPaths`** — ensures the library's imports (e.g. `react`, `@babel/runtime`) resolve from the workspace's `node_modules`
- **`blockList`** — prevents the library's own `node_modules/react` and `node_modules/react-native` from being bundled (avoids the "Invalid hook call" duplicate React error)

If Metro shows stale cache issues after config changes:

```sh
watchman watch-del-all && npx react-native start --reset-cache
```

## libraries under test

- **react-native-enriched-markdown** — linked locally from `../..` (the library repo root)
  - fork: [workspace-sh/react-native-enriched-markdown](https://github.com/workspace-sh/react-native-enriched-markdown)

## development notes

See [docs/dev.md](docs/dev.md) for library integration quirks, `md4cFlags` configuration, style overrides, and GFM feature support status.
