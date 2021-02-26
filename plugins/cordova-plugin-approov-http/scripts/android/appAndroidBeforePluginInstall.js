const path = require('path');
const utils = require('../utils');

module.exports = function (context) {
    return new Promise(async (resolve, reject) => {
        const plugin = context.opts.plugin;
        const pluginPath = path.resolve(plugin.dir);
        const approovSDKDir = path.join(pluginPath, 'approov-sdk');

        utils.ensureDir(approovSDKDir);

        /* Checks if approov cli is setup or not */
        await utils.ensureApproovExists(reject);

        try {
            await utils.executeCommand('approov', 'sdk', '-getConfig', `${approovSDKDir}/approov-initial.config`);
            console.log('Successfully added approov config.');
        } catch (e) {
            reject('Unable to add Approov Initial Config.');
        }

        try {
            await utils.executeCommand('approov', 'sdk', '-getLibrary', `${approovSDKDir}/approov-sdk.aar`);
            console.log('Successfully Added Approov SDK for android');
        } catch (e) {
            console.log('Add Approov SDK error => ', e);
            reject('Unable to add Approov SDK for android..');
        }

        resolve('Approov SDK setup for Android complete');
    });
}


