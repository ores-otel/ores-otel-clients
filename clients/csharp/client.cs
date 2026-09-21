namespace Client;

public sealed class ApiClient
{
    public required string BaseUrl { get; init; }

    public string HealthUrl() => $"{BaseUrl.TrimEnd('/')}/v1/health";
}
