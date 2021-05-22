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

package com.silkimen.approov;

import android.content.Context;
import android.util.Log;

import com.criticalblue.approovsdk.Approov;

import com.silkimen.cordovahttp.CordovaHttpPlugin;

import com.silkimen.http.HttpRequest;
import com.silkimen.http.HttpRequest.HttpRequestException;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.PrintStream;

import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;

public class ApproovHttpPlugin {

  // Tag for logging
  private static final String TAG = "CordovaApproovPlugin";

  // header that will be added to Approov enabled requests
  private static final String APPROOV_HEADER = "Approov-Token";

  // any prefix to be added before the Approov token, such as "Bearer "
  private static final String APPROOV_TOKEN_PREFIX = "";

  public static CordovaInterface cordovaStatic;

  // any header to be used for binding in Approov tokens or null if not set
  private static String bindingHeader;

  // Flag indicating whether the Approov SDK has been initialized. This can only be done once.
  private static boolean isApproovInitialized = false;

  // Determine whether the Approov library has been initialized
  private static synchronized boolean isApproovInitialized() {
    return isApproovInitialized;
  }

  // Set the flag that indicates whether the Approov library has been initialized
  private static synchronized void setApproovInitialized() {
    isApproovInitialized = true;
  }

  // Ensure the Approov library has been initialized
  public static void initializeApproov() throws IllegalArgumentException {
    if (!isApproovInitialized()) {
      // Initialize Approov
      // read the initial configuration for the Approov SDK
      String initialConfig;
      try {
        InputStream stream = cordovaStatic.getActivity().getAssets().open("approov-initial.config");
        BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8));
        initialConfig = reader.readLine();
        reader.close();
      } catch (IOException e) {
        // this should be fatal if the SDK cannot read an initial configuration
        Log.e(TAG, "Approov initial configuration read failed: " + e.getMessage());
        throw new IllegalStateException("Approov initial configuration cannot be read");
      }

      // read any dynamic configuration for the SDK from local storage
      String dynamicConfig = null;
      try {
        FileInputStream stream = cordovaStatic.getContext().openFileInput("approov-update.config");
        BufferedReader reader = new BufferedReader(new InputStreamReader(stream, StandardCharsets.UTF_8));
        dynamicConfig = reader.readLine();
        reader.close();
      } catch (IOException e) {
        // we log this but it is not fatal as the app will receive a new update if the
        // stored one is corrupted in some way
        Log.i(TAG, "Approov dynamic configuration read failed: " + e.getMessage());
      }

      // initialize the Approov SDK
      try {
        Approov.initialize(cordovaStatic.getContext(), initialConfig, dynamicConfig, null);
      } catch (IllegalArgumentException e) {
        // this should be fatal if the SDK cannot be initialized as all subsequent attempts
        // to use the SDK will fail
        Log.e(TAG, "Approov initialization failed: " + e.getMessage());
        throw new IllegalStateException("Cannot initialize the Approov SDK");
      }

      // if we didn't have a dynamic configuration (after the first launch of the app) then
      // we write it to local storage now
      if (dynamicConfig == null)
        saveApproovConfigUpdate();

      setApproovInitialized();
    }
  }

  /**
   * Saves a dynamic update to the Approov configuration. This should be called after every Approov
   * token fetch where isConfigChanged() is set. It saves a new configuration received from the
   * Approov server to the local app storage so that it is available on app startup on the next launch.
   * <p>
   * NOTE: The new configuration may change the results from getPins if new certificate pins
   * have been transmitted to the app from the Approov cloud. If the config is simply saved then
   * these updated pins will not be made available to the app until the next time it is restarted
   * and the Approov SDK is initialized. Where possible you should also update the pins immediately
   * here on the http clients being used by the app.
   */
  private static synchronized void saveApproovConfigUpdate() {
    String dynamicConfig = Approov.fetchConfig();
    if (dynamicConfig == null)
      Log.e(TAG, "Could not get Approov dynamic configuration");
    else {
      try {
        FileOutputStream outputStream = cordovaStatic.getContext().openFileOutput("approov-dynamic.config",
          Context.MODE_PRIVATE);
        PrintStream printStream = new PrintStream(outputStream);
        printStream.print(dynamicConfig);
        printStream.close();
      } catch (IOException e) {
        // we log this but it is not fatal as the app will receive a new update if the
        // stored one is corrupted in some way
        Log.e(TAG, "Cannot write Approov dynamic configuration: " + e.getMessage());
        return;
      }
      Log.i(TAG, "Wrote Approov dynamic configuration");
    }
  }

  // Sets a binding header that must be present on all requests using the Approov service
  public synchronized void setBindingHeader(String header) {
    bindingHeader = header;
  }

  // Set up Approov certificate pinning
  public static void setupApproovCertPinning(HttpRequest request) throws HttpRequestException {
    // Set the hostname verifier on the connection (must be HTTPS)
    final HttpURLConnection connection = request.getConnection();
    if (!(connection instanceof HttpsURLConnection)) {
      IOException e = new IOException("Approov protected connection must be HTTPS");
      throw new HttpRequestException(e);
    }
    final HttpsURLConnection httpsConnection = ((HttpsURLConnection) connection);

    HostnameVerifier currentVerifier = httpsConnection.getHostnameVerifier();
    if (currentVerifier instanceof ApproovHttpPinningVerifier) {
      IOException e = new IOException("There can only be one Approov certificate pinner for a connection");
      throw new HttpRequestException(e);
    }
    // Create a hostname verifier that uses Approov's dynamic pinning approach and set it on the connection
    ApproovHttpPinningVerifier verifier = new ApproovHttpPinningVerifier(currentVerifier);
    httpsConnection.setHostnameVerifier(verifier);
  }

  // Consumer (operates via side-effects) that sets up Approov protection for a request
  public static CordovaHttpPlugin.IHttpRequestInterceptor approovProtect =
    new CordovaHttpPlugin.IHttpRequestInterceptor() {
      @Override
      public void accept(HttpRequest request) {
        // update the data hash based on any token binding header
        if (bindingHeader != null) {
          String headerValue = request.getConnection().getRequestProperty(bindingHeader);
          if (headerValue == null)
            throw new RuntimeException("Approov missing token binding header: " + bindingHeader);
          Approov.setDataHashInToken(headerValue);
        }

        // request an Approov token for the domain
        URL url = request.url();
        String host = url.getHost();
        Approov.TokenFetchResult approovResults = Approov.fetchApproovTokenAndWait(host);

        // provide information about the obtained token or error (note "approov token -check" can
        // be used to check the validity of the token and if you use token annotations they
        // will appear here to determine why a request is being rejected)
        Log.i(TAG, "Approov Token for " + host + ": " + approovResults.getLoggableToken());

        // update any dynamic configuration
        if (approovResults.isConfigChanged()) {
          // Save the updated Approov configuration
          saveApproovConfigUpdate();
        }

        // check the status of the Approov token fetch
        switch (approovResults.getStatus()) {
          case SUCCESS:
            // Token was successfully received - add Approov header containing the token to the request
            request.header(APPROOV_HEADER, APPROOV_TOKEN_PREFIX + approovResults.getToken());
            break;
          case UNKNOWN_URL:
            // provided URL is not one that is configured for Approov
            break;
          case UNPROTECTED_URL:
            // provided URL does not need an Approov token
            break;
          case NO_APPROOV_SERVICE:
            // no token could be obtained, perhaps because Approov services are down
            break;
          default:
            // A fail here means that the SDK could not get an Approov token. Throw an exception containing the
            // state error
            throw new RuntimeException("Approov token fetch failed: " + approovResults.getStatus().toString());
        }
        // ensure the connection is pinned
        setupApproovCertPinning(request);
      }
    };

  /**
   * Sets a hash of the given data value into any future Approov tokens obtained in the 'pay'
   * claim. If the data values is transmitted to the API backend along with the
   * Approov token then this allows the backend to check that the data value was indeed
   * known to the app at the time of the token fetch and hasn't been spoofed. If the
   * data is the same as any previous one set then the token does not need to be updated.
   * Otherwise the next token fetch causes a new attestation to fetch a new token. Note that
   * this should not be done frequently due to the additional latency on token fetching that
   * will be caused. The hash appears in the 'pay' claim of the Approov token as a base64
   * encoded string of the SHA256 hash of the data. Note that the data is hashed locally and
   * never sent to the CriticalBlue cloud service.
   *
   * @param data is the data whose SHA256 hash is to be included in future Approov tokens
   */
  public void setDataHashInToken(String data, final CallbackContext callbackContext) {
    try {
      Approov.setDataHashInToken(data);
      callbackContext.success();
    } catch (IllegalArgumentException e) {
      // Thrown by setDataHashInToken()
      callbackContext.error("Error setting data hash to include in token (invalid string): " + e.getMessage());
    } catch (IllegalStateException e) {
      // Thrown by setDataHashInToken()
      callbackContext.error("Error setting data hash to include in token (uninitialized): " + e.getMessage());
    } catch (Exception e) {
      // Pass on any other exceptions
      callbackContext.error("Error setting data hash to include in token: " + e.getMessage());
    }
  }

  /**
   * Sets a binding header that must be present on all requests using the Approov service. A
   * header should be chosen whose value is unchanging for most requests (such as an
   * Authorization header). A hash of the header value is included in the issued Approov tokens
   * to bind them to the value. This may then be verified by the backend API integration. This
   * method should typically only be called once.
   *
   * @param header is the header to use for Approov token binding
   */
  public void setBindingHeader(String header, final CallbackContext callbackContext) {
    try {
      setBindingHeader(header);
      callbackContext.success();
    } catch (Exception e) {
      // Pass on any exception
      callbackContext.error("Error setting binding header: " + e.getMessage());
    }
  }

  /**
   * Gets a loggable version of the result Approov token. This provides the decoded JSON payload
   * along with the first six characters of the base64 encoded signature as an additional
   * "sip" claim. This can be safely logged as it cannot be transformed into a valid token
   * since the full signature is not provided, but it can be subsequently checked for validity
   * if the shared secret is known, with a very high probability. The loggable token is always
   * valid JSON. If there is an error then the type is given with the key "error". Note that
   * this is not applicable to JWE tokens.
   *
   * https://www.approov.io/docs/v2.7/approov-usage-documentation/#approov-tokens
   *
   * @return Loggable Approov token string
   */
  public String getLoggableToken(String host) {
    Approov.TokenFetchResult tokenFetchResult = Approov.fetchApproovTokenAndWait(host);

    return tokenFetchResult.getLoggableToken();
  }
}
