const fs = require('fs');
const path = require('path');
const {execSync} = require('child_process');

module.exports = {
    /**
     * Retrieves if the directory exists at path
     *
     * @param {string} path
     * @returns {boolean}
     */
    dirExists(path) {
        return fs.existsSync(path);
    },

    /**
     * Ensures if the directory exists
     *
     * @param {string} path
     */
    ensureDir(path) {
        if (this.dirExists(path)) {
            console.log(path, 'Dir Exists');
            return;
        }

        console.log(path, 'Creating Directory');
        fs.mkdirSync(path);
    },

    /**
     * Calls the reject callback if approov cli is not setup
     *
     * @param {Function} rejectCallback
     *
     * @return {Promise<void>}
     */
    async ensureApproovExists(rejectCallback) {
        try {
            await this.executeCommand('approov', 'whoami');
        } catch (e) {
            rejectCallback('Please setup Approov CLI before installing this plugin.', e);
        }
    },

    /**
     * Registers the android application
     *
     * @param {string} projectRoot
     *
     * @return {Promise<string>}
     */
    async registerApk(projectRoot) {
        return new Promise(async (resolve) => {
            const platformRoot = path.join(projectRoot, 'platforms/android');
            const apkFileLocation = path.join(platformRoot, 'app/build/outputs/apk/debug/app-debug.apk');
            try {
                await this.executeCommand('approov', 'registration', '-add', apkFileLocation);
                console.log('APK registered with Approov.');
            } catch (e) {
                console.log('Unable to automatically register the application please do it manually. Error => ', e);
                resolve('Unable to automatically register the application please do it manually.');
            }

            resolve('APK registered with Approov.');
        });
    },

    /**
     * Executes a shell command
     *
     * @param {string} command
     * @param {string} args
     * @returns {Promise<string>}
     */
    executeCommand(command, ...args) {
        return new Promise((resolve, reject) => {
            try {
                const processResult = execSync(`${command} ${args.join(' ')}`, {encoding: 'utf-8'});
                resolve(processResult);
            } catch (e) {
                reject(e);
            }
        });
    }
}
