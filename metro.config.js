const path = require('path');
const escape = require('escape-string-regexp');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

const enrichedMarkdownPath = path.resolve(__dirname, '../react-native-enriched-markdown-macos');
const workspaceNodeModules = path.resolve(__dirname, 'node_modules');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const config = {
  watchFolders: [enrichedMarkdownPath],
  resolver: {
    // When resolving from the library, also look in the workspace's node_modules
    nodeModulesPaths: [workspaceNodeModules],
    extraNodeModules: {
      'react-native-enriched-markdown': enrichedMarkdownPath,
    },
    // Only block the specific packages that cause duplicate-instance issues
    blockList: [
      new RegExp(`${escape(enrichedMarkdownPath)}/node_modules/react/.*`),
      new RegExp(`${escape(enrichedMarkdownPath)}/node_modules/react-native/.*`),
    ],
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
