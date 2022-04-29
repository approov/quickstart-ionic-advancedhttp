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

import android.util.Log;

import com.criticalblue.approovsdk.Approov;

import javax.net.ssl.HostnameVerifier;
import javax.net.ssl.SSLSession;
import javax.net.ssl.SSLException;

import java.security.cert.Certificate;
import java.security.cert.X509Certificate;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import okio.ByteString;

/**
 * This implementation of HostnameVerifier is intended to enhance the HostnameVerifier your SSL
 * implementation normally uses. The HostnameVerifier passed into the constructor continues to be
 * executed when verify is called. This verifier is only applied if the usual HostnameVerifier
 * first passes (so this implementation can only be more secure). This pins to the SHA256 of the
 * public key hash of any certificate in the trust chain for the host (so technically this is public
 * key rather than certificate pinning). Note that this uses the current live Approov pins so is
 * immediately updated if there is a configuration update to the app.
 */
public final class ApproovPinningVerifier implements HostnameVerifier {

    /** The HostnameVerifier you would normally be using. */
    private final HostnameVerifier delegate;

    /** Tag for log messages */
    private static final String TAG = "ApproovPinningVerifier";

    /**
     * Construct a CordovaApproovPinningVerifier which delegates the initial verify to a user
     * defined HostnameVerifier before applying public key pinning on top.
     *
     * @param delegate the HostnameVerifier to apply before the custom pinning
     */
    public ApproovPinningVerifier(HostnameVerifier delegate) {
        this.delegate = delegate;
    }

    @Override
    public boolean verify(String hostname, SSLSession session) {
        // check the delegate function first and only proceed if it passes
        if ((delegate == null) || delegate.verify(hostname, session)) try {
            // extract the set of valid pins for the hostname
            Set<String> hostPins = new HashSet<>();
            Map<String, List<String>> allPins = Approov.getPins("public-key-sha256");
            List<String> pins = allPins.get(hostname);
            if ((pins != null) && pins.isEmpty())
                // if there are no pins associated with the hostname domain then we use any pins
                // associated with the "*" domain for managed trust roots (note we do not
                // apply this to domains that do not have a map entry at all)
                pins = allPins.get("*");
            if (pins != null) {
                // convert the list of pins into a set
                for (String pin: pins)
                    hostPins.add(pin);
            }

            // if there are no pins then we accept any certificate / public key
            if (hostPins.isEmpty())
                return true;

            // check to see if any of the pins are in the certificate chain
            for (Certificate cert: session.getPeerCertificates()) {
                if (cert instanceof X509Certificate) {
                    X509Certificate x509Cert = (X509Certificate)cert;
                    ByteString digest = ByteString.of(x509Cert.getPublicKey().getEncoded()).sha256();
                    String hash = digest.base64();
                    if (hostPins.contains(hash))
                        return true;
                }
                else
                    Log.e(TAG, "Certificate not X.509");
            }

            // the connection is rejected
            return false;
        } catch (SSLException e) {
            throw new RuntimeException(e);
        }
        return false;
    }
}
