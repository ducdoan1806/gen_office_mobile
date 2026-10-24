package com.example.gen_office_mobile

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONObject
import java.math.BigInteger
import java.net.URL
import java.security.KeyFactory
import java.security.KeyStore
import java.security.Signature
import java.security.spec.RSAPublicKeySpec
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.net.ssl.HttpsURLConnection

/** Platform-only helpers. Never logs tokens or accepts arbitrary browse URLs. */
internal class ChatGptPlatform(private val context: Context) {
    private val prefs = context.getSharedPreferences("chatgpt_credentials", Context.MODE_PRIVATE)
    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("vpic1.chatgpt", null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder("vpic1.chatgpt", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    private fun encode(bytes: ByteArray) = Base64.encodeToString(bytes, Base64.NO_WRAP)
    private fun decode(value: String) = Base64.decode(value, Base64.NO_WRAP)
    fun read(): String? {
        val value = prefs.getString("value", null) ?: return null
        return try {
            val parts = value.split(".")
            require(parts.size == 2)
            Cipher.getInstance("AES/GCM/NoPadding").run {
                init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, decode(parts[0])))
                String(doFinal(decode(parts[1])), Charsets.UTF_8)
            }
        } catch (_: Exception) {
            prefs.edit().remove("value").commit()
            null
        }
    }
    fun write(value: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        check(prefs.edit().putString("value", encode(cipher.iv) + "." + encode(encrypted)).commit())
    }

    private fun json(url: String): JSONObject {
        val parsed = URL(url)
        require(parsed.protocol == "https" && parsed.host == "auth.openai.com" && parsed.port in listOf(-1, 443))
        val connection = parsed.openConnection() as HttpsURLConnection
        connection.instanceFollowRedirects = false
        connection.connectTimeout = 20000
        connection.readTimeout = 20000
        return try {
            check(connection.responseCode == 200)
            JSONObject(connection.inputStream.bufferedReader().use { it.readText() })
        } finally { connection.disconnect() }
    }
    fun verify(token: String, clientId: String, nonce: String): Map<String, Any> {
        val parts = token.split(".")
        require(parts.size == 3 && token.length < 32768)
        fun bytes(value: String) = Base64.decode(value, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
        val header = JSONObject(String(bytes(parts[0]), Charsets.UTF_8))
        require(header.getString("alg") == "RS256")
        val discovery = json("https://auth.openai.com/.well-known/openid-configuration")
        require(discovery.getString("issuer") == "https://auth.openai.com")
        val keys = json(discovery.getString("jwks_uri")).getJSONArray("keys")
        val jwk = (0 until keys.length()).map { keys.getJSONObject(it) }.first {
            it.optString("kid") == header.getString("kid") && it.optString("kty") == "RSA"
        }
        require(!jwk.has("alg") || jwk.getString("alg") == "RS256")
        require(!jwk.has("use") || jwk.getString("use") == "sig")
        val key = KeyFactory.getInstance("RSA").generatePublic(RSAPublicKeySpec(
            BigInteger(1, bytes(jwk.getString("n"))), BigInteger(1, bytes(jwk.getString("e")))))
        val verifier = Signature.getInstance("SHA256withRSA")
        verifier.initVerify(key)
        verifier.update((parts[0] + "." + parts[1]).toByteArray(Charsets.US_ASCII))
        require(verifier.verify(bytes(parts[2])))
        val claims = JSONObject(String(bytes(parts[1]), Charsets.UTF_8))
        require(claims.getString("iss") == "https://auth.openai.com")
        val audience = claims.get("aud")
        if (audience is org.json.JSONArray) {
            require((0 until audience.length()).any { audience.getString(it) == clientId })
            if (audience.length() > 1) require(claims.getString("azp") == clientId)
        } else require(audience == clientId)
        val now = System.currentTimeMillis() / 1000
        require(claims.getLong("exp") > now && claims.optLong("iat", now) <= now + 60)
        require(!claims.has("nbf") || claims.getLong("nbf") <= now + 60)
        require(claims.getString("nonce") == nonce)
        val subject = claims.getString("sub")
        require(subject.isNotBlank())
        return mapOf("sub" to subject, "email" to claims.optString("email", ""))
    }
}
