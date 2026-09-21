package dev.client;

public final class Client {
    private final String baseUrl;

    public Client(String baseUrl) {
        this.baseUrl = baseUrl;
    }

    public String healthUrl() {
        return baseUrl.replaceAll("/+$", "") + "/v1/health";
    }
}
