const fs = require("fs");
const path = require("path");
// const AdmZip = require('adm-zip');
const { execSync } = require("child_process");

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
      console.log(path, "Dir Exists");
      return;
    }

    console.log(path, "Creating Directory");
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
      await this.executeCommand("approov", "whoami");
    } catch (e) {
      rejectCallback(
        "Please setup Approov CLI before installing this plugin.",
        e
      );
    }
  },

  /**
   * Fetches the approov initial config file in the approov-sdk directory
   *
   * @param {string} path
   * @param {Function} rejectCallback
   * @returns {Promise<void>}
   */
  async addInitialConfig(path, rejectCallback) {
    await this.ensureApproovExists(rejectCallback);

    try {
      await this.executeCommand(
        "approov",
        "sdk",
        "-getConfig",
        `${path}/approov-initial.config`
      );
      console.log("Successfully added approov config.");
    } catch (e) {
      rejectCallback("Unable to add Approov Initial Config.");
    }
  },

  /**
   * Fetches the approov.aar library and saves it in the approov-sdk directory
   *
   * @param {string} path
   * @param {Function} rejectCallback
   *
   * @returns {Promise<void>}
   */
  async addAndroidSdk(path, rejectCallback) {
    await this.ensureApproovExists(rejectCallback);

    try {
      await this.executeCommand(
        "approov",
        "sdk",
        "-getLibrary",
        `${path}/approov-sdk.aar`
      );
      console.log("Successfully Added Approov SDK for android");
    } catch (e) {
      console.log("Add Approov SDK error => ", e);
      rejectCallback("Unable to add Approov SDK for android..");
    }
  },

  /**
   *
   * @param {string} path
   * @param {Function} rejectCallback
   *
   * @returns {Promise<void>}
   */
  async addIosSdk(path, rejectCallback) {
    await this.ensureApproovExists(rejectCallback);
    try {
      await this.executeCommand(
        "approov",
        "sdk",
        "-getLibrary",
        `${path}/approov-sdk.zip`
      );
      const zip = new AdmZip(`${path}/approov-sdk.zip`);
      zip.extractAllTo(`${path}/`, true);
      console.log("Installed IOS Approov SDK");
    } catch (e) {
      console.log("Add Approov SDK error => ", e);
      rejectCallback("Unable to add Approov SDK for IOS..");
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
      const platformRoot = path.join(projectRoot, "platforms/android");
      const apkFileLocation = path.join(
        platformRoot,
        "app/build/outputs/apk/debug/app-debug.apk"
      );
      try {
        await this.executeCommand(
          "approov",
          "registration",
          "-add",
          apkFileLocation
        );
        console.log("APK registered with Approov.");
      } catch (e) {
        console.log(
          "Unable to automatically register the application please do it manually. Error => ",
          e
        );
        resolve(
          "Unable to automatically register the application please do it manually."
        );
      }

      resolve("APK registered with Approov.");
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
        const processResult = execSync(`${command} ${args.join(" ")}`, {
          encoding: "utf-8",
        });
        resolve(processResult);
      } catch (e) {
        reject(e);
      }
    });
  },
};
