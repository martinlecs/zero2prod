use std::net::TcpListener;
use zero2prod::run;

#[actix_web::test]
async fn health_check_works() {
    let address = spawn_app();

    let client = reqwest::Client::new();

    println!("{}", &address);

    let response = client
        .get(&format!("{}/health_check", &address))
        .send()
        .await
        .expect("Failed to execute request");

    assert!(response.status().is_success());
    assert_eq!(Some(0), response.content_length());
}

fn spawn_app() -> String {
    // trying to bind port 0 will trigger an OS scan for an available port
    let listener = TcpListener::bind("127.0.0.1:0").expect("Failed to bind to random port");
    let port = listener.local_addr().unwrap().port();
    let server = run(listener).expect("Failed to bind address");
    let _ = actix_web::rt::spawn(server);

    format!("http://127.0.0.1:{}", port)
}
