# 🛠️ Comandos Úteis de Administração de Sistemas (Linux, Docker & Redes)

Este documento reúne comandos rápidos e eficientes para tarefas cotidianas de infraestrutura, como análise de espaço em disco, limpeza de logs e montagem de compartilhamentos de rede.

---

## 🔍 1. Pesquisa de Arquivos Grandes

Use este comando para localizar arquivos grandes que possam estar consumindo muito espaço em disco.

### Comando Padrão
Busca arquivos maiores que 1 GB a partir da raiz `/`, exibindo detalhes legíveis e ocultando mensagens de erro de permissão:
```bash
find / -type f -size +1G -exec ls -lh {} + 2>/dev/null
```

### 💡 Alternativas e Dicas:
*   **Limitar a busca a um diretório específico** (mais rápido, ex: `/var`):
    ```bash
    find /var -type f -size +500M -exec ls -lh {} + 2>/dev/null
    ```
*   **Listar os 20 maiores arquivos ordenados por tamanho**:
    ```bash
    find / -type f -size +100M -exec du -sh {} + 2>/dev/null | sort -rh | head -n 20
    ```

---

## 🧹 2. Limpar Log Mantendo os Últimos Registros (In-place)

Ao limpar arquivos de log de processos ativos (como Nginx, Apache ou serviços em geral), é importante **não deletar ou mover o arquivo**, pois isso altera o inode e quebra a escrita do processo. O truque é reescrever o arquivo mantendo o descritor aberto.

### Comando Padrão
Extrai as últimas 100 linhas do log de acesso do Nginx para um arquivo temporário, sobrescreve o arquivo original mantendo o inode intacto e apaga o temporário:
```bash
sh -c 'tail -n 100 /nginx/logs/access.log > /tmp/docker_log_temp && cat /tmp/docker_log_temp > /nginx/logs/access.log && rm /tmp/docker_log_temp'
```

### 💡 Dica Técnica:
*   Sempre use `cat temp > original` ou `>` (redirecionamento de saída) em vez de `mv temp original`. O comando `mv` substitui o arquivo e cria um novo inode, fazendo com que o serviço pare de registrar logs até ser reiniciado.

---

## 📁 3. Montar Compartilhamento de Rede (Samba / CIFS)

Comando para montar um diretório compartilhado do Windows ou NAS no servidor Linux local.

### Comando Padrão
```bash
sudo mount -t cifs -o username=admin,iocharset=utf8 "//[IP_ADDRESS]/Aplicações/API/Logs" /mnt/api
```

### 💡 Dicas de Configuração:
*   **Instalação dos pacotes necessários** (caso ocorra erro de mount/cifs):
    *   *Debian/Ubuntu:* `sudo apt install cifs-utils`
    *   *CentOS/RHEL:* `sudo yum install cifs-utils`
*   **Montar com permissões explícitas de leitura/escrita para o usuário local**:
    Se você precisar que usuários comuns locais editem/leiam a pasta montada, defina o UID e o GID:
    ```bash
    sudo mount -t cifs -o username=admin,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,iocharset=utf8 "//[IP_ADDRESS]/Aplicações/API/Logs" /mnt/api
    ```
*   **Montagem Persistente no Boot (`/etc/fstab`)**:
    Para manter a montagem após reiniciar o servidor, adicione ao final do arquivo `/etc/fstab`:
    ```text
    //[IP_ADDRESS]/Aplicações/API/Logs  /mnt/api  cifs  username=admin,password=SUA_SENHA,iocharset=utf8,nofail  0  0
    ```

---

## 🐳 4. Limpar Logs de Containers Docker sem Corromper/Parar o Serviço

Os arquivos de log do Docker (`*-json.log`) podem crescer infinitamente se não houver rotação configurada, consumindo todo o disco. Apagar o arquivo com `rm` causará mau funcionamento no daemon do Docker.

### Comando Padrão
Zera o tamanho do log de um container específico (`xpto`) sem interromper a execução do container:
```bash
truncate -s 0 /var/lib/docker/containers/xpto/xpto-json.log
```

### 💡 Alternativas de Alta Produtividade:
*   **Zerar os logs de TODOS os containers de uma vez**:
    ```bash
    sudo sh -c 'truncate -s 0 /var/lib/docker/containers/*/*-json.log'
    ```
*   **Prevenção: Configurar Rotação de Logs no Docker**:
    Para evitar que os logs cresçam indefinidamente no futuro, configure o Docker para rotacionar automaticamente. Crie ou edite `/etc/docker/daemon.json` e defina limites:
    ```json
    {
      "log-driver": "json-file",
      "log-opts": {
        "max-size": "10m",
        "max-file": "3"
      }
    }
    ```
    Depois, reinicie o serviço do Docker para aplicar a regra (apenas novos containers serão afetados):
    ```bash
    sudo systemctl restart docker
    ```
