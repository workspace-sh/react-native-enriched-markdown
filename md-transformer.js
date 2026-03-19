/**
 * Metro transformer that converts .md/.markdown files into JS modules
 * exporting the raw text content as a default string.
 */
const upstreamTransformer = require('@react-native/metro-babel-transformer');

module.exports.transform = async ({src, filename, options}) => {
  if (filename.endsWith('.md') || filename.endsWith('.markdown')) {
    // Convert the raw markdown into a JS module that exports the string
    const escaped = JSON.stringify(src);
    const jsSource = `module.exports = ${escaped};`;
    return upstreamTransformer.transform({
      src: jsSource,
      filename,
      options,
    });
  }
  return upstreamTransformer.transform({src, filename, options});
};
