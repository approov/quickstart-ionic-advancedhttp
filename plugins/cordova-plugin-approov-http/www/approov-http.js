/*
 * Copyright (c) 2018-2020 CriticalBlue Ltd.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 * documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
 * WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
 * OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

var cordova = require('cordova');

function handleMissingCallbacks(successFn, failFn) {
    if (Object.prototype.toString.call(successFn) !== '[object Function]') {
        throw new Error('approov-http: missing mandatory "onSuccess" callback function');
    }

    if (Object.prototype.toString.call(failFn) !== '[object Function]') {
        throw new Error('approov-http: missing mandatory "onFail" callback function');
    }
}

var approovHttp = {
    approovSetDataHashInToken: function (data, success, failure) {
        handleMissingCallbacks(success, failure);
        data = data || null;

        return cordova.exec(success, failure, "CordovaApproovHttpPlugin", 'approovSetDataHashInToken', [data]);
    },
    approovSetBindingHeader: function (header, success, failure) {
        handleMissingCallbacks(success, failure);
        header = header || null;

        return cordova.exec(success, failure, "CordovaApproovHttpPlugin", 'approovSetBindingHeader', [header]);
    }
}

module.exports = approovHttp;
