# Laboratório
GlusterFS Volume (/docker)
Nó 01 (MASTER)
DOCKER SWARM
BRICK 01

Nó 02 (BACKUP)
DOCKER SWARM
BRICK 02

Nó 03 (BACKUP)
DOCKER SWARM
BRICK 03

- Cluster Inicializado: O ambiente está pronto para operação. Use o botão abaixo para iniciar o fluxo de replicação de dados.
- PASSO 1: DISTRIBUIÇÃO SWARM. As réplicas (1 por nó) estão operando em estado ideal (High Availability).
- PASSO 2: ESCRITA NO VOLUME. As réplicas escrevem no diretório montado (/docker). O GlusterFS intercepta a chamada.
- PASSO 3: REPLICAÇÃO SÍNCRONA. O arquivo é gravado simultaneamente nos bricks locais de cada servidor. Redundância Tripla confirmada.
- PASSO 4: FALHA DO NÓ 2. O Docker Swarm detectou a queda e moveu graficamente a instância para o Nó 1. Estado: 2-0-1.
- PASSO 5: PERDA DE QUORUM (1/3). O Nó 3 caiu. Todas as instâncias estão no Nó 1. GlusterFS bloqueia escritas por segurança.
- PASSO 6: RECUPERAÇÃO. Os nós voltaram, mas as instâncias permanecem concentradas no Nó 1. Veja os alertas de OCIOSO.
- REBALANCEAR, PASSO 7: REBALANCEAMENTO MANUAL. Executando `update --force`. O Swarm redistribui instâncias para que haja exatamente uma em cada nó.
- ALTA DISPONIBILIDADE RESTAURADA. Cluster balanceado (1-1-1) e dados sincronizados. Ambiente 100% operacional.
SIMULAÇÃO CONCLUÍDA


<!-- ================================================== -->
# Guia técnico consolidado para o deploy de uma infraestrutura HA com replicação tripla de armazenamento usando GlusterFS.
<!-- ================================================== -->

### Pré-requisitos
- Três nós com Linux instalado (Ubuntu, CentOS, etc.)
- Três nós com Docker instalado
- Três nós com GlusterFS instalado

### Configuração de rede entre os nós
Para permitir que os nós se comuniquem através de nomes amigáveis em vez de IPs dinâmicos, adicione o mapeamento de hosts em cada um dos servidores no arquivo `/etc/hosts`:

```bash
# TODO Mapeamento de IPs locais para resolução de nomes dos nós do cluster
192.168.1.11 no01
192.168.1.12 no02
192.168.1.13 no03
```

<!-- ================================================== -->
### Fase 1: Preparação da Infraestrutura Base
<!-- ================================================== -->
<!-- Instale os pacotes essenciais em todos os três nós para garantir que a pilha de software esteja sincronizada. -->

## Executar em todos os nós
```bash
# TODO Atualizar repositórios e instalar Keepalived, GlusterFS e Docker
sudo apt update
sudo apt install keepalived glusterfs-server -y
curl -fsSL https://get.docker.com | bash
```

<!-- Fase 2: Camada de Armazenamento (GlusterFS) -->
<!-- 1. Formação do Cluster e Peer Probe -->
## Em todos os nós:
```bash
# TODO Iniciar e habilitar o daemon do GlusterFS no boot
sudo systemctl enable --now glusterd
```

## Apenas no Nó 1 (no01):
```bash
# TODO Registrar os outros dois nós no pool do GlusterFS a partir do Nó 1
sudo gluster peer probe no02
sudo gluster peer probe no03
```

<!-- 2. Criação do Volume Replicado -->
## Em todos os nós:
```bash
# TODO Criar o diretório de brick local em cada um dos servidores
sudo mkdir -p /data/brick1/docker
```

## Apenas no Nó 1 (no01):
```bash
# TODO Criar o volume replicado GlusterFS (Replicação Tripla)
sudo gluster volume create docker-volume replica 3 transport tcp \
  no01:/data/brick1/docker \
  no02:/data/brick1/docker \
  no03:/data/brick1/docker \
  force

# TODO Iniciar o volume do GlusterFS
sudo gluster volume start docker-volume
```

## Em todos os nós:
```bash
# TODO Criar o diretório local de montagem (/docker)
sudo mkdir -p /docker

# TODO Montar o volume localmente
sudo mount -t glusterfs localhost:/docker-volume /docker

# TODO Configurar montagem persistente após reinicializações
echo "localhost:/docker-volume /docker glusterfs defaults,_netdev 0 0" | sudo tee -a /etc/fstab
```

<!-- ================================================== -->
<!-- Fase 3: Orquestração (Docker Swarm) -->
<!-- ================================================== -->
<!-- Inicialize o swarm e garanta que os volumes GlusterFS estejam montados no caminho onde o Docker persistirá os dados dos serviços. -->

## No MASTER (no01):
```bash
# TODO Inicializar o Docker Swarm apontando para a interface de rede local
docker swarm init --advertise-addr 192.168.1.11
```

## Nos BACKUPS (no02 e no03 - usando o token retornado no MASTER):
```bash
# TODO Associar os nós de backup como workers no cluster Swarm
docker swarm join --token [TOKEN_SWARM] 192.168.1.11:2377
```

## No MASTER (no01) - Deploy do Serviço com Replicação e Armazenamento:
```bash
# TODO Criar o serviço com 3 réplicas (1 por nó) utilizando o volume de persistência do GlusterFS
docker service create \
  --name webapp \
  --replicas 3 \
  --mount type=bind,source=/docker,target=/var/www/html \
  --publish published=80,target=80 \
  php:apache
```

<!-- ================================================== -->
<!-- Fase 4: Alta Disponibilidade de Rede (VIP) -->
<!-- ================================================== -->
<!-- Configuração do Keepalived para gerenciar o IP Flutuante (VIP). -->

### /etc/keepalived/keepalived.conf (Exemplo MASTER - no01)
```conf
# TODO Configuração do Keepalived no Nó MASTER
vrrp_instance VI_1 {
    state MASTER
    interface eth0
    virtual_router_id 51
    priority 101
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass unimed123
    }
    virtual_ipaddress {
        192.168.1.100/24
    }
}
```

### /etc/keepalived/keepalived.conf (Exemplo BACKUP 1 - no02)
```conf
# TODO Configuração do Keepalived no BACKUP 1
vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 100
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass unimed123
    }
    virtual_ipaddress {
        192.168.1.100/24
    }
}
```

### /etc/keepalived/keepalived.conf (Exemplo BACKUP 2 - no03)
```conf
# TODO Configuração do Keepalived no BACKUP 2
vrrp_instance VI_1 {
    state BACKUP
    interface eth0
    virtual_router_id 51
    priority 99
    advert_int 1
    authentication {
        auth_type PASS
        auth_pass unimed123
    }
    virtual_ipaddress {
        192.168.1.100/24
    }
}
```

## Em todos os nós:
```bash
# TODO Iniciar e ativar o serviço Keepalived no boot
sudo systemctl enable --now keepalived
```

<!-- ================================================== -->
<!-- Fase 5: Deploy e NAT -->
<!-- ================================================== -->
<!-- No seu firewall de borda, crie uma regra NAT que redirecione o tráfego do seu IP público (portas 80, 443) para o VIP interno do cluster. -->

```bash
# TODO Redirecionar tráfego externo de portas públicas para o VIP interno (192.168.1.100)
iptables -t nat -A PREROUTING -p tcp --dport 80 -j DNAT --to-destination 192.168.1.100:80
iptables -t nat -A PREROUTING -p tcp --dport 443 -j DNAT --to-destination 192.168.1.100:443

# TODO Copiar dados antigos para o novo volume montado do GlusterFS
sudo cp -rp /pasta/antiga/* /docker/
```

<!-- ================================================== -->
<!-- Fase 6: Validação de Alta Disponibilidade -->
<!-- ================================================== -->

### Teste de Rede e Failover do Keepalived (VIP)
- **Ação**: Pare o serviço keepalived no MASTER (no01):
  ```bash
  # TODO Simular falha no keepalived MASTER
  sudo systemctl stop keepalived
  ```
- **Resultado esperado**: O IP Virtual (`192.168.1.100`) deve migrar de forma transparente para o nó de backup ativo de maior prioridade (`no02`).

### Teste de Armazenamento e Replicação Síncrona (Passos 2 e 3)
- **Ação**: Crie um arquivo em um nó no diretório montado `/docker`:
  ```bash
  # TODO Criar arquivo de teste no volume compartilhado
  echo "Olá do volume compartilhado" > /docker/test-file.txt
  ```
- **Resultado esperado**: O arquivo será interceptado pelo GlusterFS e gravado simultaneamente nos bricks locais de cada servidor (`/data/brick1/docker`). Confirmando Redundância Tripla.

### Teste de Failover de Nó Único - Docker Swarm (Passo 4)
- **Ação**: Pare o Docker no Nó 2 (`no02`) para simular uma queda inesperada:
  ```bash
  # TODO Simular desligamento do Nó 2
  sudo systemctl stop docker
  ```
- **Resultado esperado**: O Docker Swarm detecta o nó inativo e redistribui a réplica deste nó para o Nó 1 ou Nó 3 (novo estado do cluster: 2-0-1). O tráfego continuará sendo servido.

### Teste de Perda de Quorum (Passo 5)
- **Ação**: Simule a queda do Nó 3 (`no03`), deixando apenas o Nó 1 (`no01`) operacional (1/3 dos nós ativos):
  ```bash
  # TODO Simular desligamento do Nó 3
  sudo systemctl stop docker
  ```
- **Resultado esperado**: Como o cluster possui apenas 1 nó ativo dos 3 originais, ocorre perda de quorum. O GlusterFS bloqueará as operações de escrita no volume `/docker` por segurança para evitar inconsistências nos dados.

### Teste de Recuperação e Rebalanceamento Manual (Passos 6 e 7)
- **Ação**: Inicie os serviços novamente nos nós 2 e 3 para recuperá-los:
  ```bash
  # TODO Iniciar docker nos nós recuperados
  sudo systemctl start docker
  ```
- **Resultado esperado**: Os nós voltam a estar ativos e os dados são ressincronizados pelo GlusterFS. Porém, as instâncias de contêineres do Swarm podem permanecer concentradas no Nó 1 (os outros nós ficam ociosos).
- **Ação de Rebalanceamento**: No MASTER (no01), force a redistribuição equilibrada dos contêineres:
  ```bash
  # TODO Executar rebalanceamento manual de réplicas do Swarm
  docker service update --force webapp
  ```
- **Resultado esperado final**: O cluster retorna ao estado ideal balanceado (1-1-1), com exatamente um contêiner operando por nó e dados sincronizados. Alta disponibilidade restaurada com sucesso!
