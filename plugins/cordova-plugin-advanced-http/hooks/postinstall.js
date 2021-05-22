const path = require('path');
const utils = require('./utils');

const approovSdkPath = path.resolve(__dirname, '..', 'approov-sdk');

utils.ensureDir(approovSdkPath.toString());
utils.addInitialConfig(approovSdkPath, console.error);
utils.addAndroidSdk(approovSdkPath, console.error);
utils.addIosSdk(approovSdkPath, console.error);
