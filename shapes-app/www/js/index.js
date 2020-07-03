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

// Shapes server URLs
var HELLO_URL = "https://shapes.approov.io/v1/hello";
var SHAPE_URL = "https://shapes.approov.io/v1/shapes";

// Tag for logging
var TAG = "APPROOV SHAPES CORDOVA";

var app = {
    // Application Constructor
    initialize: function() {
        this.bindEvents();
    },
    // Bind Event Listeners
    //
    // Bind any events that are required on startup. Common events are:
    // 'load', 'deviceready', 'offline', and 'online'.
    bindEvents: function() {
        document.addEventListener('deviceready', this.onDeviceReady, false);
    },
    // deviceready Event Handler
    //
    // The scope of 'this' is the event. In order to call the 'receivedEvent'
    // function, we must explicitly call 'app.receivedEvent(...);'
    onDeviceReady: function() {
        app.receivedEvent('deviceready');
    },
    // Update DOM on a Received Event
    receivedEvent: function(id) {
        if ("deviceready" == id) {
            // Activate request functions
            document.getElementById("helloButton").onclick = requestHello;
            document.getElementById("shapeButton").onclick = requestShape;
            console.log(TAG + ": Ready");
        }
    }
};

// Request hello
function requestHello() {
    console.log(TAG + ": Hello button pressed. Attempting to get a hello response from the Approov shapes server...");
    updateDisplay("Checking connectivity...", "approov.png");
    // cordova.plugin.http.get(url, params, headers, success, failure)
    cordova.plugin.http.get(HELLO_URL, {}, {},
        function(response) {
            // If success, response data contains hello world string
            if (response.status == 200) {
                try {
                    var hello = JSON.parse(response.data).text;
                    console.log(TAG + ": Received a hello response from the Approov shapes server: " + hello);
                    updateDisplay("200: OK", "hello.png");
                } catch(e) {
                    console.error(TAG + ": Malformed hello response, error: " + e.message);
                    console.error(TAG + ": in: " + JSON.stringify(response));
                    updateDisplay(e.message, "confused.png");
                }
            }
        },
        function(response) {
            if (response.status != 200) {
                // If failure, response error contains cause
                console.log(TAG + ": Error on hello request: " + response.status);
                updateDisplay("" + response.status + ": " + response.error, "confused.png");
            }
        });
}

// Request shape (Approov-protected)
function requestShape() {
    console.log(TAG + ": Shape button pressed. Attempting to get a shape response from the Approov shapes server...");
    updateDisplay("Checking app authenticity...", "approov.png");
    // cordova.plugin.http.get(url, params, headers, success, failure)
    cordova.plugin.http.get(SHAPE_URL, {}, {},
        function(response) {
            // If success, response data contains shape name
            if (response.status == 200) {
                try {
                    var shape = JSON.parse(response.data).shape.toLowerCase();
                    console.log(TAG + ": Received a shape response from the Approov shapes server: " + shape);
                    updateDisplay("200: OK", shape + ".png");
                } catch(e) {
                    console.error(TAG + ": Malformed shape response, error: " + e.message);
                    console.error(TAG + ": in: " + JSON.stringify(response));
                    updateDisplay(e.message, "confused.png");
                }
            }
        },
        function(response) {
            if (response.status != 200) {
                // If failure, response error contains cause
                console.log(TAG + ": Error on shape request: " + response.status);
                updateDisplay("" + response.status + ": " + response.error, "confused.png");
            }
        });
}

// Update the displayed text and image
function updateDisplay(text, image) {
    if (text != null) {
        var display = document.getElementById("text");
        // set text
        display.innerHTML = text;
    }
    if (image != null) {
        var display = document.getElementById("image");
        if (image == "") {
            display.src = ""
        } else {
            var newImage = new Image;

            // Replace display image when ready
            newImage.onload = function () {
                display.src = this.src;
            }
            newImage.src = "img/" + image;
        }
    }
}
