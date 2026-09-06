# ConnectSync Remote Agent

ConnectSync Remote Agent V1 is a branded Windows x64 remote-support client
based on RustDesk 1.4.9. It is built for ConnectSync's self-hosted
infrastructure and does not use the public RustDesk rendezvous servers.

## Embedded infrastructure

- ID server: `relay.connectsync.com.br:21116`
- Relay server: `relay.connectsync.com.br:21117`
- API server: not configured (OSS server)
- Server public key: compiled into the client
- Runtime application and service name: `ConnectSync`
- Windows product name: `ConnectSync Remote Agent`

The server private key is not present in this repository or in the client.

## V1 scope

- Windows x64
- ConnectSync name, product metadata, logo and application icons
- ConnectSync server configuration enforced at runtime
- Upstream public-server fallback disabled
- RustDesk attribution retained in the About screen and source distribution
- Unsigned laboratory build until a ConnectSync code-signing certificate is
  provisioned

## Versioning

ConnectSync V1 is based on upstream RustDesk `1.4.9`. The internal technical
version is `1.4.9-connectsync.1`; public installer artifacts use the
`ConnectSync-Remote-Agent-v1.0.0` name.

## Build

The GitHub Actions workflow builds the Windows x64 Flutter client on a Windows
runner using the upstream pinned toolchains. Trigger the tag workflow with a
V1 semantic tag after reviewing the source changes.

## License and source availability

This derivative is distributed under the GNU Affero General Public License
version 3. The corresponding source for every distributed binary must remain
available to its recipients. Keep the upstream copyright and license files,
and publish the exact tagged source used for each ConnectSync release.

See `LICENCE` and `README.md` for upstream project notices.
