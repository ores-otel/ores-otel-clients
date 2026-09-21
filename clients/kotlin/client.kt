package dev.client

class Client(val baseUrl: String) {
    fun healthUrl(): String = "${baseUrl.trimEnd('/')}/v1/health"
}
