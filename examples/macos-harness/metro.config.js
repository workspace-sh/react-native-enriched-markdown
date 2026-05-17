const path = require('path');
const { getDefaultConfig, mergeConfig } = require('@react-native/metro-config');

const root = path.resolve(__dirname, '../..');

/**
 * Metro configuration
 * https://reactnative.dev/docs/metro
 *
 * @type {import('@react-native/metro-config').MetroConfig}
 */
const config = {
  // Watch the library source so changes hot-reload into the harness.
  watchFolders: [root],
  transformer: {
    babelTransformerPath: require.resolve('./md-transformer'),
  },
  resolver: {
    sourceExts: ['js', 'jsx', 'ts', 'tsx', 'json', 'md', 'markdown'],
    // Resolve from TypeScript source rather than stale compiled lib/.
    resolverMainFields: ['source', 'react-native', 'browser', 'main'],
  },
};

module.exports = mergeConfig(getDefaultConfig(__dirname), config);
