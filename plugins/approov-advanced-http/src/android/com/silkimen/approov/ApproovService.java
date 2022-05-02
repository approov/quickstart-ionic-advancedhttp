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

package com.silkimen.approov;

import android.content.Context;
import android.util.Log;

import com.criticalblue.approovsdk.Approov;

import com.silkimen.http.HttpRequest;
import com.silkimen.http.HttpRequest.HttpRequestException;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.IOException;
import java.io.PrintStream;
import java.util.Map;
import java.util.HashMap;
import java.util.Iterator;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.HttpsURLConnection;

// ApproovService provides a mediation layer to the Approov SDK itself
public class ApproovService {
  // tag for logging
  private static final String TAG = "ApproovService";

  // header that will be added to Approov enabled requests
  private static final String APPROOV_TOKEN_HEADER = "Approov-Token";

  // any prefix to be added before the Approov token, such as "Bearer "
  private static final String APPROOV_TOKEN_PREFIX = "";

  // the application context
  private Context applicationContext;

  // flag indicating whether the Approov SDK has been initialized - if not then no Approov functionality is enabled
  private boolean isInitialized;

  // true if the interceptor should proceed on network failures and not add an Approov token
  private boolean proceedOnNetworkFail;

  // any initial configuration used in order to detect a difference
  private String initialConfig;

  // header to be used to send Approov tokens
  private String approovTokenHeader;

  // any prefix String to be added before the transmitted Approov token
  private String approovTokenPrefix;

  // any header to be used for binding in Approov tokens or null if not set
  private String bindingHeader;

  // map of headers that should have their values substituted for secure strings, mapped to their
  // required prefixes
  private Map<String, String> substitutionHeaders;

  // set of query parameters that may be substituted, specified by the key name, mapped to their regex patterns
  private Map<String, Pattern> substitutionQueryParams;

  // set of URL regexs that should be excluded from any Approov protection, mapped to the compiled Pattern
  private Map<String, Pattern> exclusionURLRegexs;

  /**
   * Creates an Approov service.
   *
   * @param context the Application context
   */
  public ApproovService(Context context) {
    applicationContext = context;
    isInitialized = false;
    proceedOnNetworkFail = false;
    initialConfig = null;
    approovTokenHeader = APPROOV_TOKEN_HEADER;
    approovTokenPrefix = APPROOV_TOKEN_PREFIX;
    bindingHeader = null;
    substitutionHeaders = new HashMap<>();
    substitutionQueryParams = new HashMap<>();
    exclusionURLRegexs = new HashMap<>();
  }

  /**
   * Initializes the Approov SDK and thus enables the Approov features. This will generate
   * an error if a second attempt is made at initialization with a different config.
   * 
   * @param config is the initial configuration to be used, or empty string for no initialization
   * @return ApproovResult the result of the initialization
   */
  public ApproovResult initialize(String config) {
    if (isInitialized) {
        // if the SDK is previously initialized then the config must be the same
        if (!config.equals(initialConfig))
          return new ApproovResult("attempt to reinitialize with a different config", false);
    }
    else {
      // initialize the Approov SDK
      try {
        if (config.length() != 0)
          Approov.initialize(applicationContext, config, "auto", null);
        Approov.setUserProperty("approov-advanced-http");
        isInitialized = true;
        Log.d(TAG, "initialized");
      } catch (IllegalArgumentException e) {
        Log.e(TAG, "initialization failed IllegalArgument: " + e.getMessage());;
        return new ApproovResult("initialization failed IllegalArgument: "+ e.getMessage(), false);
      } catch (IllegalStateException e) {
        Log.e(TAG, "initialization failed IllegalState: " + e.getMessage());;
        return new ApproovResult("initialization failed IllegalState: "+ e.getMessage(), false);
      }
      initialConfig = config;
    }
    return new ApproovResult(null);
  }

  /**
   * Indicates that requests should proceed anyway if it is not possible to obtain an Approov token
   * due to a networking failure. If this is called then the backend API can receive calls without the
   * expected Approov token header being added, or without header/query parameter substitutions being
   * made. Note that this should be used with caution because it may allow a connection to be established
   * before any dynamic pins have been received via Approov, thus potentially opening the channel to a MitM.
   */
  public synchronized void setProceedOnNetworkFail() {
    Log.d(TAG, "setProceedOnNetworkFail");
    proceedOnNetworkFail = true;
  }

  /**
   * Sets the header that the Approov token is added on, as well as an optional
   * prefix String (such as "Bearer "). By default the token is provided on
   * "Approov-Token" with no prefix.
   *
   * @param header is the header to place the Approov token on
   * @param prefix is any prefix String for the Approov token header
   */
  public synchronized void setTokenHeader(String header, String prefix) {
    Log.d(TAG, "setTokenHeader " + header + ", " + prefix);
    approovTokenHeader = header;
    approovTokenPrefix = prefix;
  }

  /**
   * Sets a binding header that may be present on requests being made. A header should be
   * chosen whose value is unchanging for most requests (such as an Authorization header).
   * If the header is present, then a hash of the header value is included in the issued Approov
   * tokens to bind them to the value. This may then be verified by the backend API integration.
   *
   * @param header is the header to use for Approov token binding
   */
  public synchronized void setBindingHeader(String header) {
      Log.d(TAG, "setBindingHeader " + header);
      bindingHeader = header;
  }

  /**
   * Adds the name of a header which should be subject to secure strings substitution. This
   * means that if the header is present then the value will be used as a key to look up a
   * secure string value which will be substituted into the header value instead. This allows
   * easy migration to the use of secure strings. A required prefix may be specified to deal
   * with cases such as the use of "Bearer " prefixed before values in an authorization header.
   *
   * @param header is the header to be marked for substitution
   * @param requiredPrefix is any required prefix to the value being substituted or null if not required
   */
  public synchronized void addSubstitutionHeader(String header, String requiredPrefix) {
    if (requiredPrefix == null) {
        Log.d(TAG, "addSubtitutionHeader " + header);
        substitutionHeaders.put(header, "");
    }
    else {
        Log.d(TAG, "addSubtitutionHeader " + header + ", " + requiredPrefix);
        substitutionHeaders.put(header, requiredPrefix);
    }
  }

  /**
   * Removes a header previously added using addSubstitutionHeader.
   *
   * @param header is the header to be removed for substitution
   */
  public synchronized void removeSubstitutionHeader(String header) {
    Log.d(TAG, "removeSubtitutionHeader " + header);
    substitutionHeaders.remove(header);
  }

  /**
   * Gets all of the substitution headers that are currently setup in a new map.
   * 
   * @return Map<String, String> of the substitution headers mapped to their required prefix
   */
  private synchronized Map<String, String> getSubstitutionHeaders() {
    return new HashMap<>(substitutionHeaders);
  }

  /**
   * Adds a key name for a query parameter that should be subject to secure strings substitution.
   * This means that if the query parameter is present in a URL then the value will be used as a
   * key to look up a secure string value which will be substituted as the query parameter value
   * instead. This allows easy migration to the use of secure strings.
   *
   * @param key is the query parameter key name to be added for substitution
   */
  public synchronized void addSubstitutionQueryParam(String key) {
    try {
      Pattern pattern = Pattern.compile("[\\?&]"+key+"=([^&;]+)");
      substitutionQueryParams.put(key, pattern);
      Log.d(TAG, "addSubtitutionQueryParam " + key);
    }
    catch (PatternSyntaxException e) {
      Log.e(TAG, "addSubtitutionQueryParam " + key + " error: " + e.getMessage());
    }
  }

  /**
   * Removes a query parameter key name previously added using addSubstitutionQueryParam.
   *
   * @param key is the query parameter key name to be removed for substitution
   */
  public synchronized void removeSubstitutionQueryParam(String key) {
    Log.d(TAG, "removeSubtitutionQueryParam " + key);
    substitutionQueryParams.remove(key);
  }

  /**
   * Gets all of the substitution query parameters that are currently setup in a new map.
   * 
   * @return Map<String, Pattern> of the substitution query parameters mapped to their regex patterns
   */
  private synchronized Map<String, Pattern> getSubstitutionQueryParams() {
    return new HashMap<>(substitutionQueryParams);
  }

  /**
   * Adds an exclusion URL regular expression. If a URL for a request matches this regular expression
   * then it will not be subject to any Approov protection. Note that this facility must be used with
   * EXTREME CAUTION due to the impact of dynamic pinning. Pinning may be applied to all domains added
   * using Approov, and updates to the pins are received when an Approov fetch is performed. If you
   * exclude some URLs on domains that are protected with Approov, then these will be protected with
   * Approov pins but without a path to update the pins until a URL is used that is not excluded. Thus
   * you are responsible for ensuring that there is always a possibility of calling a non-excluded
   * URL, or you should make an explicit call to fetchToken if there are persistent pinning failures.
   * Conversely, use of those option may allow a connection to be established before any dynamic pins
   * have been received via Approov, thus potentially opening the channel to a MitM.
   *
   * @param urlRegex is the regular expression that will be compared against URLs to exclude them
   */
  public synchronized void addExclusionURLRegex(String urlRegex) {
    try {
      Pattern pattern = Pattern.compile(urlRegex);
      exclusionURLRegexs.put(urlRegex, pattern);
      Log.d(TAG, "addExclusionURLRegex " + urlRegex);
    }
    catch (PatternSyntaxException e) {
      Log.e(TAG, "addExclusionURLRegex " + urlRegex + " error: " + e.getMessage());
    }
  }

  /**
   * Removes an exclusion URL regular expression previously added using addExclusionURLRegex.
   *
   * @param urlRegex is the regular expression that will be compared against URLs to exclude them
   */
  public synchronized void removeExclusionURLRegex(String urlRegex) {
    Log.d(TAG, "removeExclusionURLRegex " + urlRegex);
    exclusionURLRegexs.remove(urlRegex);
  }

  /**
   * Gets all of the exclusion URL regexs that are currently setup in a new map.
   * 
   * @return Map<String, Pattern> of the exclusion URL regexs mapped to their regex patterns
   */
  private synchronized Map<String, Pattern> getExclusionURLRegexs() {
    return new HashMap<>(exclusionURLRegexs);
  }

  /**
   * Performs a fetch to lower the effective latency of a subsequent token fetch or
   * secure string fetch by starting the operation earlier so the subsequent fetch may be able to
   * use cached data.
   * 
   * @return ApproovResult showing if there was a problem
   */
  public ApproovResult prefetch() {
    Approov.TokenFetchResult approovResults;
    try {
      approovResults = Approov.fetchApproovTokenAndWait("approov.io");
      Log.d(TAG, "prefetch: " + approovResults.getStatus().toString());
    }
    catch (IllegalStateException e) {
        return new ApproovResult("IllegalState: " + e.getMessage(), false);
    }
    if ((approovResults.getStatus() == Approov.TokenFetchStatus.SUCCESS) ||
        (approovResults.getStatus() == Approov.TokenFetchStatus.UNKNOWN_URL))
        // prefetch completed successfully
        return new ApproovResult(null);
    else if ((approovResults.getStatus() == Approov.TokenFetchStatus.NO_NETWORK) ||
             (approovResults.getStatus() == Approov.TokenFetchStatus.POOR_NETWORK) ||
             (approovResults.getStatus() == Approov.TokenFetchStatus.MITM_DETECTED))
      // we are unable to complete the prefetch due to network conditions
      return new ApproovResult("prefetch: " + approovResults.getStatus().toString(), true);
    else
      // we are unable to complete the prefetch due to a more permanent error
      return new ApproovResult("prefetch: " + approovResults.getStatus().toString(), false);
  }

  /**
   * Performs a precheck to determine if the app will pass attestation. This requires secure
   * strings to be enabled for the account, although no strings need to be set up. This will
   * likely require network access so may take some time to complete. It may return an error
   * if the precheck fails or if there is some other problem. The error type will be "rejection"
   * if the app has failed Approov checks or "network" for networking issues where a
   * user initiated retry of the operation should be allowed. A "rejection" may provide
   * additional information about the cause of the rejection.
   * 
   * @return ApproovResult showing if there was a problem
   */
  public ApproovResult precheck() {
    // try and fetch a non-existent secure string in order to check for a rejection
    Approov.TokenFetchResult approovResults;
    try {
        approovResults = Approov.fetchSecureStringAndWait("precheck-dummy-key", null);
        Log.d(TAG, "precheck: " + approovResults.getStatus().toString());
    }
    catch (IllegalStateException e) {
        return new ApproovResult("IllegalState: " + e.getMessage(), false);
    }
    catch (IllegalArgumentException e) {
        return new ApproovResult("IllegalArgument: " + e.getMessage(), false);
    }

    // process the returned Approov status
    if (approovResults.getStatus() == Approov.TokenFetchStatus.REJECTED)
        // if the request is rejected then we provide a special exception with additional information
        return new ApproovResult("precheck: " + approovResults.getStatus().toString() + ": " +
                approovResults.getARC() + " " + approovResults.getRejectionReasons(),
                approovResults.getARC(), approovResults.getRejectionReasons());
    else if ((approovResults.getStatus() == Approov.TokenFetchStatus.NO_NETWORK) ||
             (approovResults.getStatus() == Approov.TokenFetchStatus.POOR_NETWORK) ||
             (approovResults.getStatus() == Approov.TokenFetchStatus.MITM_DETECTED))
        // we are unable to get the secure string due to network conditions so the request can
        // be retried by the user later
        return new ApproovResult("precheck: " + approovResults.getStatus().toString(), true);
    else if ((approovResults.getStatus() != Approov.TokenFetchStatus.SUCCESS) &&
             (approovResults.getStatus() != Approov.TokenFetchStatus.UNKNOWN_KEY))
        // we are unable to get the secure string due to a more permanent error
        return new ApproovResult("precheck: " + approovResults.getStatus().toString(), false);
    return new ApproovResult(null);
  }

  /**
   * Gets the device ID used by Approov to identify the particular device that the SDK is running on. Note
   * that different Approov apps on the same device will return a different ID. Moreover, the ID may be
   * changed by an uninstall and reinstall of the app.
   * 
   * @return ApproovResult with the device ID or any error
   */
  public ApproovResult getDeviceID() {
    try {
      String deviceID = Approov.getDeviceID();
      Log.d(TAG, "getDeviceID: " + deviceID);
      return new ApproovResult(deviceID);
    }
    catch (IllegalStateException e) {
      return new ApproovResult("IllegalState: " + e.getMessage(), false);
    }
  }

  /**
   * Directly sets the data hash to be included in subsequently fetched Approov tokens. If the hash is
   * different from any previously set value then this will cause the next token fetch operation to
   * fetch a new token with the correct payload data hash. The hash appears in the
   * 'pay' claim of the Approov token as a base64 encoded string of the SHA256 hash of the
   * data. Note that the data is hashed locally and never sent to the Approov cloud service.
   * 
   * @param data is the data to be hashed and set in the token
   * @return ApproovResult to indicate any errors
   */
  public ApproovResult setDataHashInToken(String data) {
    try {
      Approov.setDataHashInToken(data);
      Log.d(TAG, "setDataHashInToken");
    }
    catch (IllegalStateException e) {
      return new ApproovResult("IllegalState: " + e.getMessage(), false);
    }
    catch (IllegalArgumentException e) {
      return new ApproovResult("IllegalArgument: " + e.getMessage(), false);
    }
    return new ApproovResult(null);
  }

  /**
   * Performs an Approov token fetch for the given URL. This should be used in situations where it
   * is not possible to use the networking interception to add the token. This will
   * likely require network access so may take some time to complete. It may return an error
   * if there is some problem. The error type "network" is for networking issues where a
   * user initiated retry of the operation should be allowed.
   * 
   * @param url is the URL giving the domain for the token fetch
   * @return ApproovResult providing the token or showing if there was a problem
   */
  public ApproovResult fetchToken(String url) {
    // fetch the Approov token
    Approov.TokenFetchResult approovResults;
    try {
      approovResults = Approov.fetchApproovTokenAndWait(url);
      Log.d(TAG, "fetchToken: " + approovResults.getStatus().toString());
    }
    catch (IllegalStateException e) {
        return new ApproovResult("IllegalState: " + e.getMessage(), false);
    }
    catch (IllegalArgumentException e) {
      return new ApproovResult("IllegalArgument: " + e.getMessage(), false);
    }

    // process the status
    if ((approovResults.getStatus() == Approov.TokenFetchStatus.NO_NETWORK) ||
        (approovResults.getStatus() == Approov.TokenFetchStatus.POOR_NETWORK) ||
        (approovResults.getStatus() == Approov.TokenFetchStatus.MITM_DETECTED))
      // we are unable to get the token due to network conditions
      return new ApproovResult("fetchToken: " + approovResults.getStatus().toString(), true);
    else if (approovResults.getStatus() != Approov.TokenFetchStatus.SUCCESS)
      // we are unable to get the token due to a more permanent error
      return new ApproovResult("fetchToken: " + approovResults.getStatus().toString(), false);
    else
      // provide the Approov token result
      return new ApproovResult(approovResults.getToken());
  }

  /**
   * Gets the signature for the given message. This uses an account specific message signing key that is
   * transmitted to the SDK after a successful fetch if the facility is enabled for the account. Note
   * that if the attestation failed then the signing key provided is actually random so that the
   * signature will be incorrect. An Approov token should always be included in the message
   * being signed and sent alongside this signature to prevent replay attacks.
   *
   * @param message is the message whose content is to be signed
   * @return ApproovResult with base64 encoded signature of the message, or an error otherwise
   */
  public ApproovResult getMessageSignature(String message) {
    try {
      String signature = Approov.getMessageSignature(message);
      Log.d(TAG, "getMessageSignature");
      if (signature == null)
        return new ApproovResult("no signature available", false);
      else
        return new ApproovResult(signature);
    }
    catch (IllegalStateException e) {
        return new ApproovResult("IllegalState: " + e.getMessage(), false);
    }
    catch (IllegalArgumentException e) {
      return new ApproovResult("IllegalArgument: " + e.getMessage(), false);
    }
  }

  /**
   * Fetches a secure string with the given key. If newDef is not null then a
   * secure string for the particular app instance may be defined. In this case the
   * new value is returned as the secure string. Use of an empty string for newDef removes
   * the string entry. Note that this call may require network transaction and thus may block
   * for some time, so should not be called from the UI thread. If the attestation fails
   * for any reason then an ApproovResult error is provided. The error type will be "rejection"
   * if the app has failed Approov checks or "network" for networking issues where
   * a user initiated retry of the operation should be allowed. Note that the returned string
   * should NEVER be cached by your app, you should call this function when it is needed.
   *
   * @param key is the secure string key to be looked up
   * @param newDef is any new definition for the secure string, or null for lookup only
   * @return ApproovResult with secure string (should not be cached by your app) or an error
   */
  public ApproovResult fetchSecureString(String key, String newDef) {
    // determine the type of operation as the values themselves cannot be logged
    String type = "lookup";
    if (newDef != null)
        type = "definition";

    // fetch any secure string keyed by the value, catching any exceptions the SDK might throw
    Approov.TokenFetchResult approovResults;
    try {
        approovResults = Approov.fetchSecureStringAndWait(key, newDef);
        Log.d(TAG, "fetchSecureString " + type + " for " + key + ": " + approovResults.getStatus().toString());
    }
    catch (IllegalStateException e) {
       return new ApproovResult("fetchSecureString IllegalState: " + e.getMessage(), false);
    }
    catch (IllegalArgumentException e) {
        return new ApproovResult("fetchSecureString IllegalArgument: " + e.getMessage(), false);
    }

    // process the returned Approov status
    if (approovResults.getStatus() == Approov.TokenFetchStatus.REJECTED)
        // if the request is rejected then we provide a special exception with additional information
        return new ApproovResult("fetchSecureString " + type + " for " + key + ": " +
                approovResults.getStatus().toString() + ": " + approovResults.getARC() +
                " " + approovResults.getRejectionReasons(),
                approovResults.getARC(), approovResults.getRejectionReasons());
    else if ((approovResults.getStatus() == Approov.TokenFetchStatus.NO_NETWORK) ||
             (approovResults.getStatus() == Approov.TokenFetchStatus.POOR_NETWORK) ||
             (approovResults.getStatus() == Approov.TokenFetchStatus.MITM_DETECTED))
        // we are unable to get the secure string due to network conditions so the request can
        // be retried by the user later
        return new ApproovResult("fetchSecureString " + type + " for " + key + ":" +
                approovResults.getStatus().toString(), true);
    else if ((approovResults.getStatus() != Approov.TokenFetchStatus.SUCCESS) &&
            (approovResults.getStatus() != Approov.TokenFetchStatus.UNKNOWN_KEY))
        // we are unable to get the secure string due to a more permanent error
        return new ApproovResult("fetchSecureString " + type + " for " + key + ":" +
                approovResults.getStatus().toString(), false);
    return new ApproovResult(approovResults.getSecureString());
  }

  /**
   * Fetches a custom JWT with the given payload. Note that this call will require network
   * transaction and thus will block for some time, so should not be called from the UI thread.
   * If the attestation fails for any reason then this is reflected in the returned ApproovResult.
   * This error type will be "rejection" if the app has failed Approov checks or "network""
   * for networking issues where a user initiated retry of the operation should be allowed.
   *
   * @param payload is the marshaled JSON object for the claims to be included
   * @return ApproovResult with a custom JWT string or an error
   */
  public ApproovResult fetchCustomJWT(String payload) {
    // fetch the custom JWT catching any exceptions the SDK might throw
    Approov.TokenFetchResult approovResults;
    try {
        approovResults = Approov.fetchCustomJWTAndWait(payload);
        Log.d(TAG, "fetchCustomJWT: " + approovResults.getStatus().toString());
    }
    catch (IllegalStateException e) {
        return new ApproovResult("fetchCustomJWT IllegalState: " + e.getMessage(), false);
    }
    catch (IllegalArgumentException e) {
        return new ApproovResult("fetchCustomJWT IllegalArgument: " + e.getMessage(), false);
    }

    // process the returned Approov status
    if (approovResults.getStatus() == Approov.TokenFetchStatus.REJECTED)
        // if the request is rejected then we provide a special exception with additional information
        return new ApproovResult("fetchCustomJWT: "+ approovResults.getStatus().toString() + ": " +
                approovResults.getARC() +  " " + approovResults.getRejectionReasons(),
                approovResults.getARC(), approovResults.getRejectionReasons());
    else if ((approovResults.getStatus() == Approov.TokenFetchStatus.NO_NETWORK) ||
             (approovResults.getStatus() == Approov.TokenFetchStatus.POOR_NETWORK) ||
             (approovResults.getStatus() == Approov.TokenFetchStatus.MITM_DETECTED))
        // we are unable to get the custom JWT due to network conditions so the request can
        // be retried by the user later
        return new ApproovResult("fetchCustomJWT: " + approovResults.getStatus().toString(), true);
    else if (approovResults.getStatus() != Approov.TokenFetchStatus.SUCCESS)
        // we are unable to get the custom JWT due to a more permanent error
        return new ApproovResult("fetchCustomJWT: " + approovResults.getStatus().toString(), false);
    return new ApproovResult(approovResults.getToken());
  }

  /**
   * Setup the Approov pinning verifier for the given request. Note that this means that the "nocheck"
   * server trust mode does not work. The user must also disable Approov dynamic pinning for a particular
   * device.
   * 
   * @param request is the request whose connection needs to be secured
   * @throws IOException if there was a problem with the setup
   */
  public void setupApproovCertPinning(HttpRequest request) throws IOException {
    // set the hostname verifier on the connection (must be HTTPS)
    final HttpURLConnection connection = request.getConnection();
    if (!(connection instanceof HttpsURLConnection)) {
      throw new IOException("Approov protected connection must be HTTPS");
    }
    HttpsURLConnection httpsConnection = ((HttpsURLConnection) connection);

    // get the current hostname verifier for the request
    HostnameVerifier currentVerifier = httpsConnection.getHostnameVerifier();
    if (currentVerifier instanceof ApproovPinningVerifier) {
        throw new IOException("There can only be one Approov certificate pinner for a connection");
    }

    // create a hostname verifier that uses Approov's dynamic pinning approach and set it on the connection
    ApproovPinningVerifier verifier = new ApproovPinningVerifier(currentVerifier);
    httpsConnection.setHostnameVerifier(verifier);
  }

  /**
   * Performs any query parameter substitutions, which may require Approov fetches. This may convert
   * query parameters to map from their original values to a new value using a secure secret fetched
   * from the Approov cloud. Note that this does not specifically check that the domain being remapped
   * is added to Approov, so managed trust roots should always be enabled if using a non Approov added
   * domain to ensure the modified query parameter cannot be intercepted.
   * 
   * @param url is the URL being accessed that may contain query parameters
   * @return String the updated URL
   * @throws IOException if there is a problem, including due to an attestation failure
   */
  public String substituteQueryParams(String url) throws IOException {
    String currentURL = url;
    if (isInitialized) {
      // check if the URL matches one of the exclusion regexs and just return the original URL if so
      Map<String, Pattern> exclusionURLs = getExclusionURLRegexs();
      for (Pattern pattern: exclusionURLs.values()) {
        Matcher matcher = pattern.matcher(url);
        if (matcher.find())
          return url;
      }

      // query parameter processing is only performed if the Approov SDK is initialized
      Map<String, Pattern> subsQueryParams = getSubstitutionQueryParams();
      for (Map.Entry<String, Pattern> entry: subsQueryParams.entrySet()) {
          String queryKey = entry.getKey();
          Pattern pattern = entry.getValue();
          Matcher matcher = pattern.matcher(currentURL);
          if (matcher.find()) {
              // we have found an occurrence of the query parameter to be replaced so we look up the existing
              // value as a key for a secure string
              String queryValue = matcher.group(1);
              Approov.TokenFetchResult approovResults = Approov.fetchSecureStringAndWait(queryValue, null);
              Log.d(TAG, "substituting query parameter: " + queryKey + ", " + approovResults.getStatus().toString());
              if (approovResults.getStatus() == Approov.TokenFetchStatus.SUCCESS) {
                  // we have a successful lookup so update the URL with the secret value
                  currentURL = new StringBuilder(currentURL).replace(matcher.start(1),
                          matcher.end(1), approovResults.getSecureString()).toString();
              }
              else if (approovResults.getStatus() == Approov.TokenFetchStatus.REJECTED)
                  // if the request is rejected then we provide an exception with the information
                  throw new IOException("Approov query parameter substitution for " + queryKey + ": " +
                          approovResults.getStatus().toString() + ": " + approovResults.getARC() +
                          " " + approovResults.getRejectionReasons());
              else if ((approovResults.getStatus() == Approov.TokenFetchStatus.NO_NETWORK) ||
                       (approovResults.getStatus() == Approov.TokenFetchStatus.POOR_NETWORK) ||
                       (approovResults.getStatus() == Approov.TokenFetchStatus.MITM_DETECTED)) {
                  // we are unable to get the secure string due to network conditions so the request can
                  // be retried by the user later - unless this is overridden
                  if (!proceedOnNetworkFail)
                      throw new IOException("Approov query parameter substitution for " + queryKey + ": " +
                          approovResults.getStatus().toString());
              }
              else if (approovResults.getStatus() != Approov.TokenFetchStatus.UNKNOWN_KEY)
                  // we have failed to get a secure string with a more serious permanent error
                  throw new IOException("Approov query parameter substitution for " + queryKey + ": " +
                          approovResults.getStatus().toString());
          }
      }
    }
    return currentURL;
  }

  /**
   * Updates a request with Approov. This involves fetching an Approov token for the domain
   * being accessed and adding an Approov token to the outgoing header. This may also update
   * the token if token binding is being used. Header values may also be substituted if this
   * feature is enabled and they are present in the request.
   * 
   * @param request is the request that is being modified
   * @throws IOException if there was a problem fetching Approov tokens or secure strings
   */
  public void updateRequestWithApproov(HttpRequest request) throws IOException {
    // just return if Approov has not been initialized
    if (!isInitialized)
      return;


    // ensure the connection is pinned even for excluded URLs since we need to ensure that if the same
    // connection is used for protected requests then it will have been properly pinned
    setupApproovCertPinning(request);

    // check if the URL matches one of the exclusion regexs and just return if so
    URL url = request.url();
    String urlString = url.toString();
    Map<String, Pattern> exclusionURLs = getExclusionURLRegexs();
    for (Pattern pattern: exclusionURLs.values()) {
      Matcher matcher = pattern.matcher(urlString);
      if (matcher.find())
        return;
    }

    // update the data hash based on any token binding header
    if (bindingHeader != null) {
      String headerValue = request.getConnection().getRequestProperty(bindingHeader);
      if (headerValue != null)
        Approov.setDataHashInToken(headerValue);
    }

    // request an Approov token for the domain
    String host = url.getHost();
    Approov.TokenFetchResult approovResults = Approov.fetchApproovTokenAndWait(host);
    Log.d(TAG, "token for " + host + ": " + approovResults.getLoggableToken());

    // log if a configuration update is received and call fetchConfig to clear the update state
    if (approovResults.isConfigChanged()) {
      Approov.fetchConfig();
      Log.d(TAG, "dynamic configuration update received");
    }

    // check the status of Approov token fetch
    if (approovResults.getStatus() == Approov.TokenFetchStatus.SUCCESS)
      // we successfully obtained a token so add it to the header for the request
      request.header(approovTokenHeader, approovTokenPrefix + approovResults.getToken());
    else if ((approovResults.getStatus() == Approov.TokenFetchStatus.NO_NETWORK) ||
             (approovResults.getStatus() == Approov.TokenFetchStatus.POOR_NETWORK) ||
             (approovResults.getStatus() == Approov.TokenFetchStatus.MITM_DETECTED)) {
      // we are unable to get an Approov token due to network conditions so the request can
      // be retried by the user later - unless this is overridden
      if (!proceedOnNetworkFail)
          throw new IOException("Approov token fetch for " + host + ": " + approovResults.getStatus().toString());
    }
    else if ((approovResults.getStatus() != Approov.TokenFetchStatus.NO_APPROOV_SERVICE) &&
             (approovResults.getStatus() != Approov.TokenFetchStatus.UNKNOWN_URL) &&
             (approovResults.getStatus() != Approov.TokenFetchStatus.UNPROTECTED_URL))
      // we have failed to get an Approov token with a more serious permanent error
      throw new IOException("Approov token fetch for " + host + ": " + approovResults.getStatus().toString());

    // we only continue additional processing if we had a valid status from Approov, to prevent additional delays
    // by trying to fetch from Approov again and this also protects against header substiutions in domains not
    // protected by Approov and therefore potential subject to a MitM
    if ((approovResults.getStatus() == Approov.TokenFetchStatus.SUCCESS) ||
        (approovResults.getStatus() == Approov.TokenFetchStatus.UNPROTECTED_URL)) {
      // we now deal with any header substitutions, which may require further fetches but these
      // should be using cached results
      Map<String, String> subsHeaders = getSubstitutionHeaders();
      for (Map.Entry<String, String> entry: subsHeaders.entrySet()) {
        String header = entry.getKey();
        String prefix = entry.getValue();
        String value = request.getConnection().getRequestProperty(header);
        if ((value != null) && value.startsWith(prefix) && (value.length() > prefix.length())) {
            approovResults = Approov.fetchSecureStringAndWait(value.substring(prefix.length()), null);
            Log.d(TAG, "substituting header " + header + ": " + approovResults.getStatus().toString());
            if (approovResults.getStatus() == Approov.TokenFetchStatus.SUCCESS) {
                // update the header with the actual secret
                request.header(header, prefix + approovResults.getSecureString());
            }
            else if (approovResults.getStatus() == Approov.TokenFetchStatus.REJECTED)
                // if the request is rejected then we provide the information about the rejection
                throw new IOException("Approov header substitution for " + header + ": " +
                        approovResults.getStatus().toString() + ": " + approovResults.getARC() +
                        " " + approovResults.getRejectionReasons());
            else if ((approovResults.getStatus() == Approov.TokenFetchStatus.NO_NETWORK) ||
                     (approovResults.getStatus() == Approov.TokenFetchStatus.POOR_NETWORK) ||
                     (approovResults.getStatus() == Approov.TokenFetchStatus.MITM_DETECTED)) {
                // we are unable to get the secure string due to network conditions so the request can
                // be retried by the user later - unless this is overridden
                if (!proceedOnNetworkFail)
                    throw new IOException("Approov header substitution for " + header + ": " +
                        approovResults.getStatus().toString());
            }
            else if (approovResults.getStatus() != Approov.TokenFetchStatus.UNKNOWN_KEY)
                // we have failed to get a secure string with a more serious permanent error
                throw new IOException("Approov header substitution for " + header + ": " +
                        approovResults.getStatus().toString());
        }
      }
    }
  }
}
