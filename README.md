# Workspace — react-native-macos test harness

Test app for verifying react-native library ports to macOS via [react-native-macos](https://github.com/nicklockwood/react-native-macos).

## Prerequisites

- Node >= 20
- Ruby (with bundler) for CocoaPods
- Xcode with macOS SDK

## Setup

```sh
npm install --ignore-scripts
cd macos && LANG=en_US.UTF-8 pod install && cd ..
```

If the library needs codegen (e.g. react-native-enriched-markdown):

```sh
cd ../react-native-enriched-markdown-macos
npm install
npx bob build
cd ../workspace/macos && LANG=en_US.UTF-8 pod install && cd ..
```

## Running (macOS)

**If port 8081 is already in use** (e.g. by another Metro instance), use a different port:

```sh
# Terminal 1 — start Metro on an alternate port
npx react-native start --port 8082

# Terminal 2 — build and run the macOS app
RCT_METRO_PORT=8082 npx react-native run-macos
```

If port 8081 is free, the default works:

```sh
# Terminal 1
npx react-native start

# Terminal 2
npx react-native run-macos
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

## Libraries under test

- **react-native-enriched-markdown** — linked locally from `../react-native-enriched-markdown-macos`
