use std::convert::Infallible;
use warp::hyper::{Body, Request};
use tower_service::Service;
use warp::{self, path, filters, Filter};
use anyhow::Result;
use tracing_futures::Instrument;
use std::env;
use dotenv::{dotenv, var};

// compile time include
// const LANDING_PAGE: &'static str = include_str!("../client/dist/index.html");

refinery::embed_migrations!("migrations");

#[tokio::main]
async fn main() -> Result<()> {
    dotenv()?;

    let subscriber = tracing_subscriber::FmtSubscriber::builder()
        .with_env_filter("workerlist=debug,warp=debug,info")
        .finish();

    tracing::subscriber::set_global_default(subscriber)
        .expect("setting default subscriber failed");

    tracing_log::LogTracer::init()
        .expect("setting log tracer failed");

    {
        use tokio_postgres::NoTls;
        let (mut client, conn) = tokio_postgres::connect(&var("DATABASE_URL")?, NoTls).await?;
        tokio::spawn(async move {
            if let Err(e) = conn.await {
                eprintln!("connection error: {}", e);
            }
        });
        migrations::runner().run_async(&mut client).await?;
    }

    let pool = sqlx::PgPool::new("postgres://localhost/database").await?;

    let hello = path!("hello" / String)
        .map(|name| format!("Howdy {}", name));

    let landing = filters::method::get()
        .and(filters::path::end())
        .and(filters::fs::file("client/dist/index.html"));

    let asset = filters::fs::dir("client/dist");

    let routes = landing
        .or(hello)
        .or(asset);

    let warp_svc = warp::service(routes);
    let make_svc = hyper::service::make_service_fn(move |_| {
        let warp_svc = warp_svc.clone();
        async move {
            let svc = hyper::service::service_fn(move |req: Request<Body>| {
                let mut warp_svc = warp_svc.clone();
                async move {
                    let span = tracing::info_span!(
                        "request",
                        method = ?req.method(),
                        uri = ?req.uri()
                    );
                    let _guard = span.enter();
                    tracing::info!("processing request");
                    let resp = warp_svc.call(req).in_current_span().await;
                    tracing::info!(status = ?resp.as_ref().unwrap().status().as_u16(), "processed request");
                    resp
                }
            });
            Ok::<_, Infallible>(svc)
        }
    });


    let port: u16 = var("PORT")
        .unwrap_or("80".to_string())
        .parse()?;
    hyper::Server::bind(&([127, 0, 0, 1], port).into())
        .serve(make_svc)
        .await?;
    Ok(())
}
