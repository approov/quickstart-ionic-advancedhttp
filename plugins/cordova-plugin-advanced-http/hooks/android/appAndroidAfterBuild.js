const util = require('../utils');

module.exports = function (context) {
    return util.registerApk(context.opts.projectRoot);
}
