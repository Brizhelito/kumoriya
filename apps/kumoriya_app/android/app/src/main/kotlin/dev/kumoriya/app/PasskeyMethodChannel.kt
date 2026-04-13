package dev.kumoriya.app

import android.app.Activity
import android.util.Log
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.PublicKeyCredential
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Platform channel handler for FIDO2/WebAuthn passkey operations via
 * Android Credential Manager API.
 *
 * Channel name: `dev.kumoriya.app/passkey`
 *
 * Methods:
 * - `create` : Calls CredentialManager.createCredential with the server's
 *              CredentialCreation JSON. Returns the attestation response JSON.
 * - `get`    : Calls CredentialManager.getCredential with the server's
 *              CredentialAssertion JSON. Returns the assertion response JSON.
 */
class PasskeyMethodChannel(private val activity: Activity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "dev.kumoriya.app/passkey"
        private const val TAG = "PasskeyChannel"
    }

    private val scope = CoroutineScope(Dispatchers.Main + SupervisorJob())
    private val credentialManager: CredentialManager by lazy {
        CredentialManager.create(activity)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "create" -> handleCreate(call, result)
            "get" -> handleGet(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleCreate(call: MethodCall, result: MethodChannel.Result) {
        val json = call.argument<String>("options")
        if (json.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "Missing 'options' argument", null)
            return
        }

        scope.launch {
            try {
                val request = CreatePublicKeyCredentialRequest(json)
                val response = credentialManager.createCredential(activity, request)
                val credential = response.data.getString("androidx.credentials.BUNDLE_KEY_REGISTRATION_RESPONSE_JSON")
                if (credential != null) {
                    result.success(credential)
                } else {
                    result.error("NO_RESPONSE", "No attestation response in result", null)
                }
            } catch (e: CreateCredentialCancellationException) {
                Log.d(TAG, "Passkey creation cancelled by user")
                result.error("CANCELLED", "User cancelled passkey creation", null)
            } catch (e: CreateCredentialException) {
                Log.e(TAG, "Passkey creation failed: ${e.type} - ${e.message}")
                result.error("CREATE_FAILED", e.message ?: "Passkey creation failed", e.type)
            } catch (e: Exception) {
                Log.e(TAG, "Unexpected passkey creation error", e)
                result.error("UNKNOWN", e.message ?: "Unknown error", null)
            }
        }
    }

    private fun handleGet(call: MethodCall, result: MethodChannel.Result) {
        val json = call.argument<String>("options")
        if (json.isNullOrEmpty()) {
            result.error("INVALID_ARGS", "Missing 'options' argument", null)
            return
        }

        scope.launch {
            try {
                val option = GetPublicKeyCredentialOption(json)
                val request = GetCredentialRequest(listOf(option))
                val response = credentialManager.getCredential(activity, request)
                val credential = response.credential
                if (credential is PublicKeyCredential) {
                    result.success(credential.authenticationResponseJson)
                } else {
                    result.error("WRONG_TYPE", "Unexpected credential type: ${credential.type}", null)
                }
            } catch (e: GetCredentialCancellationException) {
                Log.d(TAG, "Passkey auth cancelled by user")
                result.error("CANCELLED", "User cancelled passkey authentication", null)
            } catch (e: GetCredentialException) {
                Log.e(TAG, "Passkey auth failed: ${e.type} - ${e.message}")
                result.error("GET_FAILED", e.message ?: "Passkey authentication failed", e.type)
            } catch (e: Exception) {
                Log.e(TAG, "Unexpected passkey auth error", e)
                result.error("UNKNOWN", e.message ?: "Unknown error", null)
            }
        }
    }

    fun dispose() {
        scope.cancel()
    }
}
