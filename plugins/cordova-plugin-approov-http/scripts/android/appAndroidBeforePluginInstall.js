const path = require('path');
const utils = require('../utils');

module.exports = function (context) {
    return new Promise(async (resolve, reject) => {
        const plugin = context.opts.plugin;
        const pluginPath = path.resolve(plugin.dir);
        const approovSDKDir = path.join(pluginPath, 'approov-sdk');

        utils.ensureDir(approovSDKDir);

        /* Checks if approov cli is setup or not */
        await utils.addInitialConfig(approovSDKDir, reject);
        await utils.addAndroidSdk(approovSDKDir, reject);

        resolve('Approov SDK setup for Android complete');
    });
}


