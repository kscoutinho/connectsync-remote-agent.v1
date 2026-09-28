<p align="center">
  <img src="flutter/assets/logo.png" alt="ConnectSync Remote Agent" width="420">
</p>

# ConnectSync Remote Agent V1

Cliente Windows x64 de acesso e suporte remoto da ConnectSync, integrado à infraestrutura própria de rendezvous e relay. Esta versão é baseada no RustDesk OSS 1.4.9 e mantém o código-fonte correspondente disponível sob a licença AGPL-3.0.

## Downloads oficiais

- [Instalador permanente MSI](https://github.com/kscoutinho/connectsync-remote-agent.v1/releases/download/connectsync-v1.0.0/ConnectSync-Remote-Agent-v1.0.0-x86_64.msi)
- [Executável portátil](https://github.com/kscoutinho/connectsync-remote-agent.v1/releases/download/connectsync-v1.0.0/ConnectSync-Remote-Agent-v1.0.0-x86_64.exe)
- [Release e somas SHA-256](https://github.com/kscoutinho/connectsync-remote-agent.v1/releases/tag/connectsync-v1.0.0)

## Infraestrutura incorporada

- Servidor ID: `relay.connectsync.com.br:21116`
- Servidor Relay: `relay.connectsync.com.br:21117`
- Servidor API: não configurado (servidor OSS)
- Nome do aplicativo e serviço Windows: `ConnectSync`
- Produto instalado: `ConnectSync Remote Agent`

A chave pública do servidor está incorporada ao cliente. A chave privada do servidor nunca é incluída no aplicativo nem neste repositório.

## Instalação permanente

1. Remova instalações antigas do RustDesk usadas nos testes.
2. Execute o arquivo MSI como administrador.
3. Reinicie o Windows após a primeira instalação.
4. Confirme que o serviço `ConnectSync` está em execução e com inicialização automática.
5. Valide uma conexão sem abrir manualmente o aplicativo na máquina controlada.

Não instale o MSI antigo chamado `rustdesk-1.4.9-x86_64.msi`; ele pertence somente à fase de laboratório.

## Estado da V1

- Branding, ícone e metadados ConnectSync
- Instalação MSI com uma única identidade e um único serviço
- Inicialização automática antes do logon
- Configuração do servidor ConnectSync aplicada em tempo de execução
- Teste de conexão e persistência após reinicialização concluídos
- Binários ainda sem assinatura digital Authenticode

## Segurança e uso autorizado

Este software deve ser instalado somente em equipamentos autorizados pelo proprietário ou responsável. Cada acesso deve respeitar as políticas da ConnectSync e do cliente atendido.

Antes de distribuir em escala, verifique a soma SHA-256 publicada na release. A assinatura digital será adicionada quando a ConnectSync disponibilizar um certificado de assinatura de código.

## Código-fonte e licença

Este projeto é um derivado do [RustDesk](https://github.com/rustdesk/rustdesk). O código modificado é distribuído sob a [GNU Affero General Public License v3.0](LICENCE). A tag de cada release deve apontar para o mesmo código utilizado na geração dos binários.

Detalhes técnicos adicionais estão em [CONNECTSYNC.md](CONNECTSYNC.md).
