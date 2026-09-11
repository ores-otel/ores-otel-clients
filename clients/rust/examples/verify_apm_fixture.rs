#![forbid(unsafe_code)]

use std::env;
use std::fs;

use ores_otel_client::{Client, ClientConfig};

fn main() {
    let path = env::args().nth(1).expect("usage: verify_apm_fixture <fixture.json>");
    let body = fs::read(&path).expect("read canonical APM fixture");
    let client = Client::new(ClientConfig {
        base_url: "https://example.invalid".to_owned(),
        bearer_token: None,
        max_response_bytes: 2 * 1024 * 1024,
    })
    .expect("valid client config");
    let snapshot = client
        .decode_apm_snapshot(&body)
        .expect("canonical APM fixture must decode");

    assert_eq!(snapshot.schema_version, 1);
    assert!(!snapshot.service_name.is_empty());
    assert!(!snapshot.service_instance_id.is_empty());
    assert!(!snapshot.process.memory_usage_bytes.is_empty());
    assert!(!snapshot.process.disk_read_bytes.is_empty());
    assert!(!snapshot.filesystems.is_empty());
    assert!(!snapshot.service.latency_seconds.buckets.is_empty());
    assert!(!snapshot.capabilities.profiling.is_empty());
}
