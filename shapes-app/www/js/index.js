/*
 * Copyright (c) 2018-2022 CriticalBlue Ltd.
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

var HELLO_URL = "https://shapes.approov.io/v1/hello";

// COMMENT THE LINE BELOW IF USING APPROOV WITH TOKEN PROTECTION
var SHAPE_URL = "https://shapes.approov.io/v1/shapes";

// UNCOMMENT THE LINE BELOW IF USING APPROOV WITH TOKEN PROTECTION
//var SHAPE_URL = "https://shapes.approov.io/v3/shapes";

// COMMENT THE LINE BELOW IF USING APPROOV WITH SECRET PROTECTION
var API_KEY = "yXClypapWNHIifHUWmBIyPFAm";

// UNCOMMENT THE LINE BELOW IF USING APPROOV WITH SECRET PROTECTION
//var API_KEY = "shapes_api_key_placeholder";

// Tag for logging
var TAG = "CordovaApproovShapes";

// Main initialization for the app
function initialize() {
    document.addEventListener('deviceready', onDeviceReady, false);
}

// Setup when the Cordova environment is fully loaded
function onDeviceReady() {
    // UNCOMMENT THE LINES BELOW TO ADD APPROOV
    /*cordova.plugin.http.approovInitialize("<enter-your-config-string-here>",
        () => {},
        (err) => {
            console.log(TAG + ": Approov initialization error: " + err.message);
        });*/

    // UNCOMMENT IF USING APPROOV WITH SECRET PROTECTION
    //cordova.plugin.http.approovAddSubstitutionHeader("Api-Key", "");

    document.getElementById("helloButton").onclick = requestHello;
    document.getElementById("shapeButton").onclick = requestShape;
    console.log(TAG + ": Ready");
}

// Check connectivity
function requestHello() {
    console.log(TAG + ": Hello button pressed. Attempting to get a hello response from the Approov shapes server...");
    updateDisplay("Checking connectivity...", "approov.png");
    cordova.plugin.http.get(HELLO_URL, {}, {},
        (response) => {
            try {
                var hello = JSON.parse(response.data).text;
                console.log(TAG + ": Received a hello response from the Approov shapes server: " + hello);
                updateDisplay("200: OK", "hello.png");
            } catch(e) {
                console.error(TAG + ": Malformed hello response, error: " + e.message);
                console.error(TAG + ": in: " + JSON.stringify(response));
                updateDisplay(e.message, "confused.png");
            }
        },
        (response) => {
            console.log(TAG + ": Error on hello request: " + response.status);
            updateDisplay("" + response.status + ": " + response.error, "confused.png");
        });
}

// Request shape
function requestShape() {
    console.log(TAG + ": Shape button pressed. Attempting to get a shape response from the Approov shapes server...");
    updateDisplay("Checking app authenticity...", "approov.png");
    cordova.plugin.http.get(SHAPE_URL, {}, {"Api-Key": API_KEY},
        (response) => {
            try {
                var shape = JSON.parse(response.data).shape.toLowerCase();
                console.log(TAG + ": Received a shape response from the Approov shapes server: " + shape);
                updateDisplay("200: OK", shape + ".png");
            } catch(e) {
                console.error(TAG + ": Malformed shape response, error: " + e.message);
                console.error(TAG + ": in: " + JSON.stringify(response));
                updateDisplay(e.message, "confused.png");
            }
        },
        (response) => {
            console.log(TAG + ": Error on shape request: " + response.status);
            updateDisplay("" + response.status + ": " + response.error, "confused.png");
        });
}

// Update the displayed text and image
function updateDisplay(text, image) {
    if (text != null) {
        var display = document.getElementById("text");
        display.innerHTML = text;
    }
    if (image != null) {
        var display = document.getElementById("image");
        if (image == "") {
            display.src = ""
        } else {
            var newImage = new Image;
            newImage.onload = function () {
                display.src = this.src;
            }
            newImage.src = "img/" + image;
        }
    }
}
