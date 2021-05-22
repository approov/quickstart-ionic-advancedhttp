package com.silkimen.cordovahttp;

import java.util.Deque;
import java.util.LinkedList;
import com.silkimen.http.HttpRequest;

class CordovaHttpRequestInterceptors {

  // List of request interceptors
  private static Deque<IHttpRequestInterceptor> requestInterceptors =
    new LinkedList<IHttpRequestInterceptor>();

  // Interface type for request interceptors
  public interface IHttpRequestInterceptor {
    public void accept(HttpRequest request);
  }

  // Add a request interceptor to the list of request interceptors
  public static synchronized void addRequestInterceptor(IHttpRequestInterceptor requestInterceptor) {
    if (requestInterceptor == null) {
      throw new NullPointerException("Request interceptor must not be null");
    }
    requestInterceptors.addFirst(requestInterceptor);
  }

  // Apply all request interceptors
  public static synchronized void applyRequestInterceptors(HttpRequest request) {
    for (IHttpRequestInterceptor requestInterceptor : requestInterceptors) {
      requestInterceptor.accept(request);
    }
  }

}
