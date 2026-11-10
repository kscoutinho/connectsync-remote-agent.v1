use std::{
    sync::atomic::{AtomicBool, Ordering},
    time::Duration,
};

use hbb_common::{config::Config, log, message_proto::LoginRequest};
use serde::Deserialize;

pub(crate) const DEVICE_TOKEN_OPTION: &str = "connectsync-managed-device-token";
pub(crate) const GRANT_PEER_OPTION: &str = "connectsync-managed-grant";

const PORTAL_API: &str = "https://remoto.connectsync.com.br/api/managed-agent";
const LOGIN_MARKER: &str = "__connectsync_managed_v1__";
const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(15);
const REQUEST_TIMEOUT: Duration = Duration::from_secs(10);

static HEARTBEAT_STARTED: AtomicBool = AtomicBool::new(false);

#[derive(Debug)]
pub(crate) struct RedeemedGrant {
    pub id: String,
    pub technician_name: String,
}

#[derive(Deserialize)]
struct RedeemResponse {
    authorized: bool,
    #[serde(rename = "grantId")]
    grant_id: String,
    technician: RedeemTechnician,
}

#[derive(Deserialize)]
struct RedeemTechnician {
    name: String,
}

pub(crate) fn is_grant_token(value: &str) -> bool {
    (40..=80).contains(&value.len())
        && value
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || byte == b'_' || byte == b'-')
}

pub(crate) fn embed_grant_in_login(login: &mut LoginRequest, grant: &str) -> bool {
    if !is_grant_token(grant) {
        return false;
    }
    let Some(os_login) = login.os_login.as_mut() else {
        return false;
    };
    if !os_login.username.is_empty() || !os_login.password.is_empty() {
        return false;
    }
    os_login.username = LOGIN_MARKER.to_owned();
    os_login.password = grant.to_owned();
    true
}

pub(crate) fn take_grant_from_login(login: &mut LoginRequest) -> Option<String> {
    let os_login = login.os_login.as_mut()?;
    if os_login.username != LOGIN_MARKER || !is_grant_token(&os_login.password) {
        return None;
    }
    let grant = std::mem::take(&mut os_login.password);
    os_login.username.clear();
    Some(grant)
}

pub(crate) fn start_heartbeat() {
    if HEARTBEAT_STARTED.swap(true, Ordering::SeqCst) {
        return;
    }
    hbb_common::tokio::spawn(async {
        loop {
            if let Err(error) = heartbeat_once().await {
                log::debug!("ConnectSync managed heartbeat unavailable: {}", error);
            }
            hbb_common::tokio::time::sleep(HEARTBEAT_INTERVAL).await;
        }
    });
}

async fn heartbeat_once() -> Result<(), String> {
    let token = Config::get_option(DEVICE_TOKEN_OPTION);
    if !is_grant_token(&token) {
        return Ok(());
    }
    let remote_id = Config::get_id().trim().to_owned();
    if remote_id.len() < 6 || !remote_id.bytes().all(|byte| byte.is_ascii_digit()) {
        return Err("ConnectSync ID is not ready".to_owned());
    }

    let url = format!("{PORTAL_API}/heartbeat");
    let client = crate::hbbs_http::create_http_client_async_with_url(&url).await;
    let response = client
        .post(&url)
        .timeout(REQUEST_TIMEOUT)
        .header("x-connectsync-device-token", token)
        .json(&serde_json::json!({
            "remoteId": remote_id,
            "hostname": crate::whoami_hostname(),
            "platform": hbb_common::whoami::platform().to_string(),
            "agentVersion": crate::VERSION,
        }))
        .send()
        .await
        .map_err(|_| "portal request failed".to_owned())?;
    if !response.status().is_success() {
        return Err(format!("portal returned HTTP {}", response.status().as_u16()));
    }
    Ok(())
}

pub(crate) async fn redeem_grant(
    grant_token: &str,
    technician_peer_id: &str,
) -> Result<RedeemedGrant, String> {
    let device_token = Config::get_option(DEVICE_TOKEN_OPTION);
    if !is_grant_token(&device_token)
        || !is_grant_token(grant_token)
        || technician_peer_id.len() < 6
        || !technician_peer_id.bytes().all(|byte| byte.is_ascii_digit())
    {
        return Err("managed authorization is not configured".to_owned());
    }

    let url = format!("{PORTAL_API}/grants/redeem");
    let client = crate::hbbs_http::create_http_client_async_with_url(&url).await;
    let response = client
        .post(&url)
        .timeout(REQUEST_TIMEOUT)
        .header("x-connectsync-device-token", device_token)
        .json(&serde_json::json!({
            "grantToken": grant_token,
            "technicianPeerId": technician_peer_id,
        }))
        .send()
        .await
        .map_err(|_| "portal request failed".to_owned())?;
    if !response.status().is_success() {
        return Err(format!("portal returned HTTP {}", response.status().as_u16()));
    }
    let body = response
        .json::<RedeemResponse>()
        .await
        .map_err(|_| "portal response was invalid".to_owned())?;
    let technician_name = body.technician.name.trim().to_owned();
    if !body.authorized || body.grant_id.is_empty() || technician_name.is_empty() {
        return Err("portal denied managed authorization".to_owned());
    }
    Ok(RedeemedGrant {
        id: body.grant_id,
        technician_name,
    })
}

pub(crate) async fn end_grant(grant_id: String) {
    let device_token = Config::get_option(DEVICE_TOKEN_OPTION);
    if !is_grant_token(&device_token) || grant_id.is_empty() {
        return;
    }
    let url = format!("{PORTAL_API}/grants/end");
    let client = crate::hbbs_http::create_http_client_async_with_url(&url).await;
    let _ = client
        .post(&url)
        .timeout(REQUEST_TIMEOUT)
        .header("x-connectsync-device-token", device_token)
        .json(&serde_json::json!({ "grantId": grant_id }))
        .send()
        .await;
}

#[cfg(test)]
mod tests {
    use super::*;
    use hbb_common::message_proto::OSLogin;

    fn login_request() -> LoginRequest {
        LoginRequest {
            os_login: Some(OSLogin::default()).into(),
            ..Default::default()
        }
    }

    #[test]
    fn managed_grant_is_hidden_in_os_login_envelope() {
        let token = "A".repeat(43);
        let mut login = login_request();
        assert!(embed_grant_in_login(&mut login, &token));
        assert_eq!(take_grant_from_login(&mut login), Some(token));
        assert!(login.os_login.username.is_empty());
        assert!(login.os_login.password.is_empty());
    }

    #[test]
    fn malformed_grant_is_rejected() {
        let mut login = login_request();
        assert!(!embed_grant_in_login(&mut login, "short"));
        assert_eq!(take_grant_from_login(&mut login), None);
    }
}
