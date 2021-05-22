package com.silkimen.cordovahttp;

import java.security.KeyStore;

import com.silkimen.approov.ApproovHttpPlugin;
import com.silkimen.http.TLSConfiguration;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.util.Log;
import android.util.Base64;

import javax.net.ssl.TrustManagerFactory;

public class CordovaHttpPlugin extends CordovaPlugin {
  private static final String TAG = "Cordova-Plugin-HTTP";

  private TLSConfiguration tlsConfiguration;
  private ApproovHttpPlugin approovPlugin;

  @Override
  public void initialize(CordovaInterface cordova, CordovaWebView webView) {
    super.initialize(cordova, webView);
    ApproovHttpPlugin.cordovaStatic = cordova;

    this.tlsConfiguration = new TLSConfiguration();
    this.approovPlugin = new ApproovHttpPlugin();

    try {
      KeyStore store = KeyStore.getInstance("AndroidCAStore");
      String tmfAlgorithm = TrustManagerFactory.getDefaultAlgorithm();
      TrustManagerFactory tmf = TrustManagerFactory.getInstance(tmfAlgorithm);

      store.load(null);
      tmf.init(store);

      this.tlsConfiguration.setHostnameVerifier(null);
      this.tlsConfiguration.setTrustManagers(tmf.getTrustManagers());
    } catch (Exception e) {
      Log.e(TAG, "An error occured while loading system's CA certificates", e);
    }
  }

  @Override
  public boolean execute(String action, final JSONArray args, final CallbackContext callbackContext)
      throws JSONException {

    if (action == null) {
      return false;
    }

    if ("get".equals(action)) {
      return this.executeHttpRequestWithoutData(action, args, callbackContext);
    } else if ("head".equals(action)) {
      return this.executeHttpRequestWithoutData(action, args, callbackContext);
    } else if ("initializeApproov".equals(action)) {
      return this.initializeApproov();
    } else if ("getLoggableApproovToken".equals(action)) {
      return false; // this.getLoggableApproovToken(action, args, callbackContext);
    } else if ("approovSetDataHashInToken".equals(action)) {
      return this.approovSetDataHashInToken(args.getString(0), callbackContext);
    } else if ("approovSetBindingHeader".equals(action)) {
      return this.approovSetBindingHeader(args.getString(0), callbackContext);
    } else if ("delete".equals(action)) {
      return this.executeHttpRequestWithoutData(action, args, callbackContext);
    } else if ("options".equals(action)) {
      return this.executeHttpRequestWithoutData(action, args, callbackContext);
    } else if ("post".equals(action)) {
      return this.executeHttpRequestWithData(action, args, callbackContext);
    } else if ("put".equals(action)) {
      return this.executeHttpRequestWithData(action, args, callbackContext);
    } else if ("patch".equals(action)) {
      return this.executeHttpRequestWithData(action, args, callbackContext);
    } else if ("uploadFiles".equals(action)) {
      return this.uploadFiles(args, callbackContext);
    } else if ("downloadFile".equals(action)) {
      return this.downloadFile(args, callbackContext);
    } else if ("setServerTrustMode".equals(action)) {
      return this.setServerTrustMode(args, callbackContext);
    } else if ("setClientAuthMode".equals(action)) {
      return this.setClientAuthMode(args, callbackContext);
    } else {
      return false;
    }
  }

  public boolean initializeApproov() {
    ApproovHttpPlugin.initializeApproov();
    CordovaHttpPlugin.addRequestInterceptor(ApproovHttpPlugin.approovProtect);
    return true;
  }

  public boolean approovSetDataHashInToken(String data, CallbackContext callbackContext) {
    this.approovPlugin.setDataHashInToken(data, callbackContext);
    return true;
  }

  public boolean approovSetBindingHeader(String header, CallbackContext callbackContext) {
    this.approovPlugin.setBindingHeader(header, callbackContext);
    return true;
  }

  // Public interface type for request interceptors
  public interface IHttpRequestInterceptor extends CordovaHttpRequestInterceptors.IHttpRequestInterceptor {};

  // Add a request interceptor to the list of request interceptors
  public static final void addRequestInterceptor(IHttpRequestInterceptor requestInteceptor) {
    CordovaHttpRequestInterceptors.addRequestInterceptor(requestInteceptor);
  };

  private boolean executeHttpRequestWithoutData(final String method, final JSONArray args,
      final CallbackContext callbackContext) throws JSONException {

    String url = args.getString(0);
    JSONObject headers = args.getJSONObject(1);
    int timeout = args.getInt(2) * 1000;
    boolean followRedirect = args.getBoolean(3);
    String responseType = args.getString(4);

    CordovaHttpOperation request = new CordovaHttpOperation(method.toUpperCase(), url, headers, timeout, followRedirect,
        responseType, this.tlsConfiguration, callbackContext);

    cordova.getThreadPool().execute(request);

    return true;
  }

  private boolean executeHttpRequestWithData(final String method, final JSONArray args,
      final CallbackContext callbackContext) throws JSONException {

    String url = args.getString(0);
    Object data = args.get(1);
    String serializer = args.getString(2);
    JSONObject headers = args.getJSONObject(3);
    int timeout = args.getInt(4) * 1000;
    boolean followRedirect = args.getBoolean(5);
    String responseType = args.getString(6);

    CordovaHttpOperation request = new CordovaHttpOperation(method.toUpperCase(), url, serializer, data, headers,
        timeout, followRedirect, responseType, this.tlsConfiguration, callbackContext);

    cordova.getThreadPool().execute(request);

    return true;
  }

  private boolean uploadFiles(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    String url = args.getString(0);
    JSONObject headers = args.getJSONObject(1);
    JSONArray filePaths = args.getJSONArray(2);
    JSONArray uploadNames = args.getJSONArray(3);
    int timeout = args.getInt(4) * 1000;
    boolean followRedirect = args.getBoolean(5);
    String responseType = args.getString(6);

    CordovaHttpUpload upload = new CordovaHttpUpload(url, headers, filePaths, uploadNames, timeout, followRedirect,
        responseType, this.tlsConfiguration, this.cordova.getActivity().getApplicationContext(), callbackContext);

    cordova.getThreadPool().execute(upload);

    return true;
  }

  private boolean downloadFile(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    String url = args.getString(0);
    JSONObject headers = args.getJSONObject(1);
    String filePath = args.getString(2);
    int timeout = args.getInt(3) * 1000;
    boolean followRedirect = args.getBoolean(4);

    CordovaHttpDownload download = new CordovaHttpDownload(url, headers, filePath, timeout, followRedirect,
        this.tlsConfiguration, callbackContext);

    cordova.getThreadPool().execute(download);

    return true;
  }

  private boolean setServerTrustMode(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    CordovaServerTrust runnable = new CordovaServerTrust(args.getString(0), this.cordova.getActivity(),
        this.tlsConfiguration, callbackContext);

    cordova.getThreadPool().execute(runnable);

    return true;
  }

  private boolean setClientAuthMode(final JSONArray args, final CallbackContext callbackContext) throws JSONException {
    byte[] pkcs = args.isNull(2) ? null : Base64.decode(args.getString(2), Base64.DEFAULT);

    CordovaClientAuth runnable = new CordovaClientAuth(args.getString(0), args.isNull(1) ? null : args.getString(1),
        pkcs, args.getString(3), this.cordova.getActivity(), this.cordova.getActivity().getApplicationContext(),
        this.tlsConfiguration, callbackContext);

    cordova.getThreadPool().execute(runnable);

    return true;
  }
}
