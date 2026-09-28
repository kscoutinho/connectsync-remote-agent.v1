# ConnectSync Remote Agent

## Versão 1.0.0

Cliente Windows x64 personalizado para suporte remoto ConnectSync, baseado no RustDesk OSS 1.4.9.

### Configuração incorporada

- ID Server: `relay.connectsync.com.br:21116`
- Relay Server: `relay.connectsync.com.br:21117`
- API Server: não configurado
- Chave pública do servidor: incorporada ao binário
- Aplicativo, diretório de configuração e serviço: `ConnectSync`
- Produto MSI: `ConnectSync Remote Agent`

A chave privada permanece exclusivamente no servidor e não integra o código-fonte ou os instaladores.

### Escopo validado

- Windows x64
- Logo, ícones e metadados ConnectSync
- MSI permanente com serviço automático
- Executável portátil para suporte assistido
- Servidor próprio obrigatório, sem fallback para os servidores públicos
- Instalação limpa com apenas um serviço `ConnectSync`
- Conexão externa e persistência após reinicialização validadas em laboratório

### Publicação

A release estável usa a tag `connectsync-v1.0.0`. O workflow define explicitamente o commit de destino da tag, garantindo que o código-fonte publicado corresponda aos binários.

Arquivos oficiais:

- `ConnectSync-Remote-Agent-v1.0.0-x86_64.msi`
- `ConnectSync-Remote-Agent-v1.0.0-x86_64.exe`

O arquivo legado `rustdesk-1.4.9-x86_64.msi`, presente na release de laboratório, não deve ser distribuído.

### Assinatura digital

A V1 operacional ainda é compilada sem assinatura Authenticode. Para distribuição ampla, adquirir um certificado de assinatura de código para a ConnectSync e cadastrar os segredos de assinatura no GitHub Actions.

### Licença e atribuição

Este derivado permanece sob GNU AGPL-3.0. A atribuição ao RustDesk e os arquivos de licença originais devem ser preservados. O repositório deve continuar público para disponibilizar o código correspondente aos binários distribuídos.
