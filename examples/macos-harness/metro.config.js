const path = require('path');
const { getDefaultConfig } = require('@react-native/metro-config');

const root = path.resolve(__dirname, '../..');
const rnMacosDir = path.dirname(
  require.resolve('react-native-macos/package.json', { paths: [__dirname] })
);
// Pin react to this workspace to avoid duplicate-instance dispatcher errors.
const reactMainPath = require.resolve('react', { paths: [__dirname] });

/** @type {import('metro-config').MetroConfig} */
const config = getDefaultConfig(__dirname);

config.projectRoot = __dirname;
// Watch the library source so changes hot-reload into the harness.
config.watchFolders = [root];

config.transformer = {
  ...config.transformer,
  // .md/.markdown imports go through md-transformer.js (returns string content).
  babelTransformerPath: require.resolve('./md-transformer'),
};

config.resolver = {
  ...config.resolver,
  platforms: [...(config.resolver.platforms || []), 'macos'],
  sourceExts: [...(config.resolver.sourceExts || []), 'md', 'markdown'],
  // Resolve the library from src/index.tsx (via exports.source) rather than
  // the compiled lib/module/ output, which pulls in codegen .ts files that
  // can't resolve react-native types under this monorepo layout.
  resolverMainFields: ['source', 'react-native', 'browser', 'main'],
  unstable_conditionNames: ['source', 'react-native', 'browser', 'require'],
  nodeModulesPaths: [path.join(__dirname, 'node_modules')],
};

// Redirect react-native → react-native-macos.
// Deep subpath imports (react-native/Libraries/…) resolve relative to the
// react-native-macos package root so Metro handles platform variants correctly.
const fakeOrigin = path.join(rnMacosDir, '_resolver_shim.js');

config.resolver.resolveRequest = (context, moduleName, platform) => {
  if (moduleName === 'react') {
    return { filePath: reactMainPath, type: 'sourceFile' };
  }

  if (moduleName === 'react-native') {
    return context.resolveRequest(context, 'react-native-macos', platform);
  }

  if (moduleName.startsWith('react-native/')) {
    const subPath = './' + moduleName.slice('react-native/'.length);
    return context.resolveRequest(
      { ...context, originModulePath: fakeOrigin },
      subPath,
      platform
    );
  }

  return context.resolveRequest(context, moduleName, platform);
};

module.exports = config;
