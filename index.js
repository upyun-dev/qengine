if (!require.extensions['.coffee'])
  require('coffeescript/register');

module.exports = require('./src/ooq');