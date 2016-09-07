if (!require.extensions['.coffee'])
  require('coffee-script/register');

module.exports = require('./ooq');