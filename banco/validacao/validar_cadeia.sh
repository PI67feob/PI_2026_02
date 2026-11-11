#!/bin/bash
# =====================================================================
# validar_cadeia.sh  -  roda a cadeia de scripts deste pacote num MySQL 8 DESCARTAVEL e confere
# cada resultado contra o valor esperado (OK / FALHA).
#
# ATENCAO - LEIA ANTES DE RODAR
#   * Este script APAGA e RECRIA o banco caderno_fazenda varias vezes (DROP DATABASE). Use SO num
#     MySQL de teste, no seu computador. NUNCA aponte para o RDS da equipe.
#   * Por seguranca ele recusa qualquer servidor que nao seja local (socket, 127.0.0.1 ou localhost)
#     e recusa servidor que pareca RDS. Mesmo assim, so rode se tiver certeza de onde esta conectado.
#   * Senha nunca vai em arquivo: use a variavel MYSQL_PWD no terminal (o cliente mysql le sozinho).
#     A senha do usuario agrogestor_app de teste e gerada na hora, ao acaso, e nao e gravada.
#
# COMO RODAR (exemplo com um MySQL privado, so por socket; veja validacao/LEIAME_VALIDACAO.md):
#   export MYSQL_SOCKET=/caminho/do/mysql.sock
#   export CONFIRMO_APAGAR_CADERNO_FAZENDA_LOCAL=sim
#   bash validacao/validar_cadeia.sh
#
# VARIAVEIS (todas opcionais, menos as duas acima):
#   MYSQL_USER   usuario administrador do MySQL de teste (padrao: root)
#   MYSQL_PWD    senha desse usuario, se tiver (o cliente mysql le esta variavel)
#   MYSQL_HOST / MYSQL_PORT   em vez do socket: MYSQL_HOST=127.0.0.1 (porta padrao 3306)
#   SAIDA        pasta onde ficam as saidas brutas (padrao: validacao/saida)
#
# O script termina com codigo 0 se todas as conferencias deram OK, e com o numero de FALHAs se nao.
# Requer: bash, mysql (cliente 8.0), python3 (so no teste U5), MySQL servidor 8.0.16 ou mais novo.
# =====================================================================
set -u

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAC="$(cd "$AQUI/.." && pwd)"
# Dois layouts possiveis: o do pacote (scripts/01_..., 02_...) e o do repositorio (banco/schema.sql, banco/seeds...).
if [ -d "$PAC/scripts/01_banco_do_zero" ]; then
  S="$PAC/scripts"
  TUDO="$S/01_banco_do_zero/tudo_em_um.sql"
  CONF="$S/01_banco_do_zero/testes/conferencia.sql"
  AUD="$S/01_banco_do_zero/testes/auditoria.sql"
  USRAPP="$S/01_banco_do_zero/testes/usuario_app_LOCAL.sql"
  ALT="$S/02_alter_reaplicacao/alter_aplicacao_reaplicacao.sql"
  V7="$S/04_povoamento_v7/povoamento_caderno_de_campo.sql"
  V6="$S/05_povoamento_v6_executado_no_rds/povoamento_caderno_de_campo.sql"
  CORR="$S/06_corrigir_ids/corrigir_ids.sql"
  DESF="$S/07_desfazer/desfazer_dados_ficticios.sql"
  APAG="$S/07_desfazer/apagar_so_os_exemplos.sql"
elif [ -f "$PAC/schema.sql" ]; then
  TUDO="$PAC/recriar_do_zero/tudo_em_um.sql"
  CONF="$PAC/testes/conferencia.sql"
  AUD="$PAC/testes/auditoria.sql"
  USRAPP="$PAC/testes/usuario_app_LOCAL.sql"
  ALT="$PAC/alter_aplicacao_reaplicacao.sql"
  V7="$PAC/povoamento/povoamento_caderno_de_campo.sql"
  V6="$PAC/povoamento/historico/povoamento_v6_executado_no_rds.sql"
  CORR="$PAC/povoamento/corrigir_ids.sql"
  DESF="$PAC/povoamento/desfazer_dados_ficticios.sql"
  APAG="$PAC/povoamento/apagar_so_os_exemplos.sql"
else
  echo "Nao reconheci a pasta: rode este script de dentro de validacao/ (pacote) ou de banco/validacao/ (repositorio)."; exit 2
fi
for f in "$TUDO" "$CONF" "$AUD" "$USRAPP" "$ALT" "$V7" "$V6" "$CORR" "$DESF" "$APAG"; do
  [ -f "$f" ] || { echo "Arquivo nao encontrado: $f"; exit 2; }
done
OUT="${SAIDA:-$AQUI/saida}"

# ---------- travas de seguranca ----------
if [ "${CONFIRMO_APAGAR_CADERNO_FAZENDA_LOCAL:-}" != "sim" ]; then
  echo "Recusado: este script apaga e recria o banco caderno_fazenda. Para confirmar que o servidor e um MySQL"
  echo "de TESTE local, rode:  export CONFIRMO_APAGAR_CADERNO_FAZENDA_LOCAL=sim"; exit 2
fi
USUARIO="${MYSQL_USER:-root}"
if [ -n "${MYSQL_SOCKET:-}" ]; then
  CONN=(-S "$MYSQL_SOCKET")
elif [ "${MYSQL_HOST:-}" = "127.0.0.1" ] || [ "${MYSQL_HOST:-}" = "localhost" ]; then
  CONN=(-h "$MYSQL_HOST" -P "${MYSQL_PORT:-3306}" --protocol=TCP)
else
  echo "Recusado: defina MYSQL_SOCKET (socket do MySQL local) ou MYSQL_HOST=127.0.0.1. Servidor remoto nao e aceito."; exit 2
fi
MB() { mysql "${CONN[@]}" -u"$USUARIO" --default-character-set=utf8mb4 "$@"; }
M()  { MB --table caderno_fazenda "$@"; }
Q()  { MB -N caderno_fazenda -e "$1" | tr '\t' ' '; }
UL() { MYSQL_PWD="$SENHA_APP" mysql "${CONN[@]}" -uagrogestor_app --default-character-set=utf8mb4 --table caderno_fazenda "$@"; }

if ! MB -N -e "select 1" >/dev/null 2>&1; then echo "Nao consegui conectar no MySQL de teste (confira MYSQL_SOCKET, MYSQL_USER e MYSQL_PWD)."; exit 2; fi
EH_RDS=$(MB -N -e "select (@@basedir like '%rdsdbbin%') + (select count(1) from information_schema.routines where routine_schema='mysql' and routine_name like 'rds\\_%')" 2>/dev/null)
if [ "${EH_RDS:-1}" != "0" ]; then echo "Recusado: o servidor parece ser um RDS/AWS. Este script so roda em MySQL de teste local."; exit 2; fi
VERSAO=$(MB -N -e "select version()")
MAJOR=$(MB -N -e "select (substring_index(version(),'.',1) + 0) * 1000000 + (substring_index(substring_index(version(),'.',2),'.',-1) + 0) * 1000 + (substring_index(substring_index(version(),'-',1),'.',-1) + 0)")
if [ "${MAJOR:-0}" -lt 8000016 ]; then echo "MySQL $VERSAO e antigo demais (precisa de 8.0.16 ou mais novo, para os CHECK valerem)."; exit 2; fi
case "$VERSAO" in *MariaDB*) echo "MariaDB nao vale: use MySQL 8."; exit 2;; esac

rm -rf "$OUT"; mkdir -p "$OUT"
SENHA_APP="$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 20)"
FALHAS=0; TOTAL=0
say() { echo; echo "######## $*"; }
confere() { # $1 = o que esta sendo conferido; $2 = obtido; $3 = esperado
  TOTAL=$((TOTAL+1))
  if [ "$2" == "$3" ]; then printf '   OK     %s\n' "$1"
  else printf '   FALHA  %s\n          obtido  : %s\n          esperado: %s\n' "$1" "$2" "$3"; FALHAS=$((FALHAS+1)); fi
}
CNT="select (select count(1) from area),(select count(1) from talhao),(select count(1) from operacao),(select count(1) from aplicador),(select count(1) from insumo),(select count(1) from compra),(select count(1) from item_compra),(select count(1) from aplicacao),(select count(1) from aplicacao_talhao),(select count(1) from aplicacao_insumo),(select count(1) from historico_alteracoes)"
NEXT="set session information_schema_stats_expiry=0; select auto_increment from information_schema.tables where table_schema='caderno_fazenda' and table_name='aplicacao'"
IDS="select min(id_aplicacao), max(id_aplicacao), count(1) from aplicacao"
novo_banco_vazio() { MB -e "drop database if exists caderno_fazenda; create database caderno_fazenda character set utf8mb4 collate utf8mb4_0900_ai_ci"; }
restaura() { novo_banco_vazio && MB caderno_fazenda < "$OUT/_base_tabelas_triggers_alter_seeds.sql"; }   # tudo_em_um + ALTER + seeds, sem aplicacoes
queima_ids() { MB caderno_fazenda -e "insert into aplicacao (id_operacao,id_aplicador,data_aplicacao,observacao) values (1,1,'2026-01-01','x'),(1,1,'2026-01-01','y'); delete from aplicacao"; }
manual() { MB caderno_fazenda -e "insert into aplicacao (id_operacao,id_aplicador,data_aplicacao,observacao) values (2,1,'2026-11-10','cadastro manual pelo terminal')"; }

echo "Servidor de teste: $VERSAO   |   pacote: $PAC"

# ============================================================================================
say "T1  banco do zero: tudo_em_um.sql + testes/conferencia.sql"
MB < "$TUDO" > "$OUT/t1_tudo_em_um.txt" 2>&1; SAI=$?
confere "tudo_em_um.sql terminou sem erro" "$SAI" "0"
confere "contagens (area talhao operacao aplicador insumo compra item_compra aplicacao ap_talhao ap_insumo historico)" "$(Q "$CNT")" "4 5 2 11 43 18 43 0 0 0 0"
M < "$CONF" > "$OUT/t1_conferencia.txt" 2>&1
confere "conferencia.sql: linhas OK" "$(grep -c '| OK ' "$OUT/t1_conferencia.txt")" "19"
confere "conferencia.sql: linhas DIFERENTE" "$(grep -c 'DIFERENTE' "$OUT/t1_conferencia.txt")" "0"
confere "14 triggers no schema" "$(Q "select count(1) from information_schema.triggers where trigger_schema='caderno_fazenda'")" "14"
confere "collation do banco" "$(Q "select default_collation_name from information_schema.schemata where schema_name='caderno_fazenda'")" "utf8mb4_0900_ai_ci"
confere "11 tabelas" "$(Q "select count(1) from information_schema.tables where table_schema='caderno_fazenda' and table_type='BASE TABLE'")" "11"
mysqldump "${CONN[@]}" -u"$USUARIO" --no-tablespaces --routines --triggers caderno_fazenda > "$OUT/_pure_sem_alter.sql" 2>/dev/null

# ============================================================================================
say "T2  alter_aplicacao_reaplicacao.sql"
MB caderno_fazenda < "$ALT" > "$OUT/t2_alter.txt" 2>&1; SAI=$?
confere "ALTER terminou sem erro" "$SAI" "0"
confere "colunas novas em aplicacao" "$(Q "select group_concat(column_name,':',column_type,':',is_nullable order by ordinal_position) from information_schema.columns where table_schema='caderno_fazenda' and table_name='aplicacao' and column_name in ('horas_ate_chuva','motivo_reaplicacao')")" "horas_ate_chuva:decimal(6,2):YES,motivo_reaplicacao:varchar(20):YES"
MB caderno_fazenda < "$ALT" > "$OUT/t2_alter_de_novo.txt" 2>&1; SAI=$?
confere "ALTER rodado de novo NAO e repetivel (erro 3822: nome de CHECK duplicado)" "$(grep -o 'ERROR [0-9]*' "$OUT/t2_alter_de_novo.txt" | head -1)" "ERROR 3822"
confere "CHECK de motivo recusa valor fora da lista" "$(MB caderno_fazenda -e "insert into aplicacao (id_operacao,id_aplicador,data_aplicacao,motivo_reaplicacao) values (1,1,'2026-01-01','granizo')" 2>&1 | grep -o 'ERROR [0-9]*' | head -1)" "ERROR 3819"
# monta a base de referencia: banco do zero + ALTER (e guarda para restaurar nos proximos testes)
mysqldump "${CONN[@]}" -u"$USUARIO" --no-tablespaces --routines --triggers caderno_fazenda > "$OUT/_base_tabelas_triggers_alter_seeds.sql" 2>/dev/null

# ============================================================================================
say "T3  testes/auditoria.sql (prova dos 12 triggers + imutabilidade) como administrador"
restaura
M < "$AUD" > "$OUT/t3_auditoria.txt" 2>&1; SAI=$?
EU="$(MB -N -e 'select user()')"
confere "auditoria.sql terminou sem erro" "$SAI" "0"
confere "12 linhas de resumo (1 por tabela e acao), todas com o usuario conectado" "$(grep -c -E "^\| (aplicacao|aplicacao_insumo|aplicacao_talhao|insumo) +\| (INSERT|UPDATE|DELETE) +\| +1 \| $EU" "$OUT/t3_auditoria.txt")" "12"
confere "depois do ROLLBACK nao sobrou historico" "$(Q 'select count(1) from historico_alteracoes')" "0"
confere "contadores ficam em 9002 (talhao 9003): o ROLLBACK nao devolve ids" "$(Q "set session information_schema_stats_expiry=0; select group_concat(table_name,'=',auto_increment order by table_name) from information_schema.tables where table_schema='caderno_fazenda' and table_name in ('area','talhao','operacao','aplicador','insumo','aplicacao')")" "aplicacao=9002,aplicador=9002,area=9002,insumo=9002,operacao=9002,talhao=9003"
MB caderno_fazenda -e "insert into insumo (nome,tipo) values ('X','x');" 2>/dev/null
confere "UPDATE no historico e recusado (1644)" "$(MB caderno_fazenda -e "update historico_alteracoes set usuario='fraude' where id_historico=(select m from (select max(id_historico) m from historico_alteracoes) t)" 2>&1 | grep -o 'ERROR [0-9]*' | head -1)" "ERROR 1644"
confere "DELETE no historico e recusado (1644)" "$(MB caderno_fazenda -e "delete from historico_alteracoes limit 1" 2>&1 | grep -o 'ERROR [0-9]*' | head -1)" "ERROR 1644"

# ============================================================================================
say "T4  cenario do RDS: ids 1-2 queimados + povoamento v6 + 1 cadastro manual + corrigir_ids"
restaura; queima_ids
confere "proximo id de aplicacao antes do povoamento" "$(Q "$NEXT")" "3"
M < "$V6" > "$OUT/t4_povoamento_v6.txt" 2>&1; SAI=$?
confere "povoamento v6 terminou sem erro" "$SAI" "0"
confere "resultado" "$(grep -o 'CARGA COMPLETA' "$OUT/t4_povoamento_v6.txt" | head -1)" "CARGA COMPLETA"
confere "contagens" "$(Q "$CNT")" "4 29 2 16 45 28 69 70 329 111 535"
confere "ids das aplicacoes (min max qtd): comecam no 3" "$(Q "$IDS")" "3 72 70"
confere "proximo id depois do INSERT ... SELECT de 70 linhas (127 ids gastos)" "$(Q "$NEXT")" "130"
manual
confere "cadastro manual recebe o id 130 (pulo de 72 para 130)" "$(Q 'select max(id_aplicacao) from aplicacao')" "130"
M < "$CORR" > "$OUT/t4_corrigir_ids.txt" 2>&1; SAI=$?
confere "corrigir_ids terminou sem erro" "$SAI" "0"
confere "ids depois (min max qtd)" "$(Q "$IDS")" "1 71 71"
confere "proximo id depois" "$(Q "$NEXT")" "72"
confere "linhas DIFERENTE/ERRO/VERIFICAR no relatorio" "$(grep -c -E 'DIFERENTE|ERRO|VERIFICAR' "$OUT/t4_corrigir_ids.txt")" "0"
confere "resultado da conferencia" "$(grep -o 'NUMERACAO CORRIGIDA' "$OUT/t4_corrigir_ids.txt" | head -1)" "NUMERACAO CORRIGIDA"
H1="$(Q 'select count(1) from historico_alteracoes')"
M < "$CORR" > "$OUT/t4_corrigir_ids_2.txt" 2>&1; SAI=$?
confere "2a execucao: sem erro" "$SAI" "0"
confere "2a execucao: nada a trocar" "$(grep -o 'NUMERACAO JA ESTAVA CERTA' "$OUT/t4_corrigir_ids_2.txt" | head -1)" "NUMERACAO JA ESTAVA CERTA"
confere "2a execucao: historico nao cresceu" "$(Q 'select count(1) from historico_alteracoes')" "$H1"

# ============================================================================================
say "T5  banco novo + povoamento v7 (ids em sequencia)"
restaura
M < "$V7" > "$OUT/t5_povoamento_v7.txt" 2>&1; SAI=$?
confere "povoamento v7 terminou sem erro" "$SAI" "0"
confere "resultado" "$(grep -o 'CARGA COMPLETA' "$OUT/t5_povoamento_v7.txt" | head -1)" "CARGA COMPLETA"
confere "contagens" "$(Q "$CNT")" "4 29 2 16 45 28 69 70 329 111 531"
confere "ids (min max qtd)" "$(Q "$IDS")" "1 70 70"
confere "proximo id" "$(Q "$NEXT")" "71"
manual
confere "cadastro manual recebe o id 71 (sem pulo)" "$(Q 'select max(id_aplicacao) from aplicacao')" "71"
M < "$CORR" > "$OUT/t5_corrigir_ids.txt" 2>&1
confere "corrigir_ids num banco ja certo: nada a trocar" "$(grep -o 'NUMERACAO JA ESTAVA CERTA' "$OUT/t5_corrigir_ids.txt" | head -1)" "NUMERACAO JA ESTAVA CERTA"
M < "$V7" > "$OUT/t5_povoamento_v7_2.txt" 2>&1; SAI=$?
confere "povoamento v7 de novo (idempotencia): sem erro" "$SAI" "0"
confere "povoamento v7 de novo: nada duplicou (so o historico do cadastro manual)" "$(Q "$CNT")" "4 29 2 16 45 28 69 71 329 111 532"

# ============================================================================================
say "T6  desfazer_dados_ficticios.sql e apagar_so_os_exemplos.sql (continua do T5)"
M < "$DESF" > "$OUT/t6_desfazer.txt" 2>&1; SAI=$?
confere "desfazer terminou sem erro" "$SAI" "0"
confere "contagens depois do desfazer (a base real e o cadastro manual ficam)" "$(Q "$CNT")" "4 29 2 11 43 18 43 1 0 0 1051"
confere "tabela de controle vazia" "$(Q 'select count(1) from registro_dados_ficticios')" "0"
M < "$APAG" > "$OUT/t6_apagar.txt" 2>&1; SAI=$?
confere "apagar_so_os_exemplos terminou sem erro" "$SAI" "0"

# ============================================================================================
say "T7  povoamento v7 por cima de um banco que ja tem a carga v6 (sem corrigir antes)"
restaura; queima_ids
M < "$V6" > /dev/null 2>&1
M < "$V7" > "$OUT/t7_v7_sobre_v6.txt" 2>&1; SAI=$?
confere "sem erro" "$SAI" "0"
confere "nada duplicou (o historico traz as 4 linhas da queima de ids + as 531 da carga)" "$(Q "$CNT")" "4 29 2 16 45 28 69 70 329 111 535"
confere "o v7 NAO renumera: ids continuam 3..72" "$(Q "$IDS")" "3 72 70"

# ============================================================================================
say "U0/U1  usuario da aplicacao (usuario_app_LOCAL.sql com senha gerada na hora) e auditoria.sql como agrogestor_app"
MB -e "drop user if exists 'agrogestor_app'@'localhost'"
sed "s/<SENHA_QUE_VOCE_ESCOLHER>/$SENHA_APP/" "$USRAPP" | MB; SAI=$?
confere "usuario_app_LOCAL.sql rodou" "$SAI" "0"
confere "privilegios do agrogestor_app (so SELECT, INSERT, UPDATE, DELETE; sem DROP nem TRIGGER)" "$(MB -N -e "show grants for 'agrogestor_app'@'localhost'" | grep -v 'USAGE' | sed 's/ TO .*//' | tr -d '\n')" "GRANT SELECT, INSERT, UPDATE, DELETE ON \`caderno_fazenda\`.*"
restaura
UL < "$AUD" > "$OUT/u1_auditoria_app.txt" 2>&1; SAI=$?
confere "auditoria.sql como agrogestor_app: sem erro" "$SAI" "0"
confere "coluna usuario mostra agrogestor_app@localhost, e nunca root (USER(), nao CURRENT_USER())" "$( [ "$(grep -c 'root@' "$OUT/u1_auditoria_app.txt")" = "0" ] && [ "$(grep -c 'agrogestor_app@localhost' "$OUT/u1_auditoria_app.txt")" -ge 12 ] && echo sim || echo nao )" "sim"

# ============================================================================================
say "U2/U3  o que o usuario da aplicacao (sem ALTER/CREATE) NAO consegue rodar: o script para e nada muda"
restaura; queima_ids; M < "$V6" > /dev/null 2>&1
ANTES="$(Q "$IDS")"
UL < "$CORR" > "$OUT/u2_corrigir_app.txt" 2>&1; SAI=$?
confere "corrigir_ids como agrogestor_app: para com erro" "$([ "$SAI" != "0" ] && echo sim || echo nao)" "sim"
confere "mensagem: ALTER command denied (erro 1142, na linha do teste de permissao)" "$(grep -c 'ALTER command denied' "$OUT/u2_corrigir_app.txt")" "1"
confere "nada mudou" "$(Q "$IDS")" "$ANTES"
restaura
ANTES="$(Q "$CNT")"
UL < "$V7" > "$OUT/u3_povoamento_app.txt" 2>&1; SAI=$?
confere "povoamento v7 como agrogestor_app: para com erro" "$([ "$SAI" != "0" ] && echo sim || echo nao)" "sim"
confere "mensagem: CREATE command denied (tabela de controle)" "$(grep -c 'CREATE command denied' "$OUT/u3_povoamento_app.txt")" "1"
confere "nada foi gravado" "$(Q "$CNT")" "$ANTES"

# ============================================================================================
say "U4/U5  base incompleta: item FORA do conjunto usado e banco so com tabelas"
restaura
MB caderno_fazenda -e "update insumo set nome='Renomeado por engano' where id_insumo=1"   # id 1 = BioKiller (o povoamento nao usa)
M < "$V7" > "$OUT/u4_item_fora_do_conjunto.txt" 2>&1; SAI=$?
confere "BioKiller renomeado (nao e usado pelo povoamento): NAO para" "$SAI" "0"
confere "o script recriou o BioKiller (insumo 43+1+2 = 46)" "$(Q 'select count(1) from insumo')" "46"
novo_banco_vazio
python3 -I - "$TUDO" > "$OUT/so_tabelas.sql" <<'EOF'
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
partes = re.split(r"-- >>>>>>>>>> PASSO: (.+?) <<<<<<<<<<\n", t)
corpo = {partes[i]: partes[i+1] for i in range(1, len(partes)-1, 2)}
ddl = corpo["scripts_separados/criar_banco.sql"]
ddl = re.sub(r"DROP DATABASE IF EXISTS caderno_fazenda;\n", "", ddl)
ddl = re.sub(r"CREATE DATABASE caderno_fazenda[^;]*;\n", "", ddl)
print(ddl)
print(corpo["scripts_separados/triggers.sql"])
EOF
MB caderno_fazenda < "$OUT/so_tabelas.sql"
confere "banco so com tabelas e triggers (sem seeds): tudo vazio" "$(Q "$CNT")" "0 0 0 0 0 0 0 0 0 0 0"
M < "$V7" > "$OUT/u5_sem_base.txt" 2>&1; SAI=$?
confere "povoamento v7 sem a base do Diogo: sem erro" "$SAI" "0"
confere "resultado" "$(grep -o 'CARGA COMPLETA' "$OUT/u5_sem_base.txt" | head -1)" "CARGA COMPLETA"
confere "contagens (a base do Diogo + dados reais + ficticios)" "$(Q "$CNT")" "4 29 2 16 45 28 69 70 329 111 574"
confere "o proprio script criou as 2 colunas de reaplicacao" "$(Q "select count(1) from information_schema.columns where table_schema='caderno_fazenda' and table_name='aplicacao' and column_name in ('horas_ate_chuva','motivo_reaplicacao')")" "2"
confere "tabela de controle criada, com 87 linhas" "$(Q 'select count(1) from registro_dados_ficticios')" "87"
confere "controle por tabela (aplicacao aplicador compra insumo)" "$(Q "select group_concat(tabela,'=',n order by tabela) from (select tabela, count(1) n from registro_dados_ficticios group by tabela) x")" "aplicacao=70,aplicador=5,compra=10,insumo=2"
confere "ids das aplicacoes" "$(Q "$IDS")" "1 70 70"

# ============================================================================================
say "V1-V5  a trava PARE do povoamento (grupos parciais, nomes repetidos, clientes que continuam apos erro)"
restaura; MB caderno_fazenda -e "insert into area (nome) values ('Sede')"; ANTES="$(Q "$CNT")"
M < "$V7" > "$OUT/v1_pare_duplicada.txt" 2>&1; SAI=$?
confere "V1 area 'Sede' duplicada: para com erro" "$([ "$SAI" != "0" ] && echo sim || echo nao)" "sim"
confere "V1 mensagem PARE" "$(grep -o 'PARE: faltam repetidos: 1' "$OUT/v1_pare_duplicada.txt" | head -1)" "PARE: faltam repetidos: 1"
confere "V1 nada foi gravado" "$(Q "$CNT")" "$ANTES"

restaura; MB caderno_fazenda -e "delete from aplicador where id_aplicador=2"; ANTES="$(Q "$CNT")"   # id 2 = Bomba costal Jacto 1 (usada pelo povoamento)
M < "$V7" > "$OUT/v4_pare_aplicador.txt" 2>&1; SAI=$?
confere "V4 aplicador usado pelo povoamento faltando (grupo parcial, 7 de 8): para" "$(grep -o 'PARE: faltam aplicadores: 1' "$OUT/v4_pare_aplicador.txt" | head -1)" "PARE: faltam aplicadores: 1"
confere "V4 nada foi gravado" "$(Q "$CNT")" "$ANTES"

restaura; MB caderno_fazenda -e "update insumo set nome='Spirit renomeado' where nome='Spirit'"; ANTES="$(Q "$CNT")"
M < "$V7" > "$OUT/v5_pare_insumo.txt" 2>&1; SAI=$?
confere "V5 insumo usado pelo povoamento renomeado (14 de 15): para" "$(grep -o 'PARE: faltam insumos: 1' "$OUT/v5_pare_insumo.txt" | head -1)" "PARE: faltam insumos: 1"
confere "V5 nada foi gravado (alem do UPDATE do teste)" "$(Q "$CNT")" "$ANTES"

restaura; MB caderno_fazenda -e "delete from aplicador where id_aplicador=11"   # Jacto 10: o povoamento nao usa
M < "$V7" > "$OUT/v2_aplicador_fora.txt" 2>&1; SAI=$?
confere "V2 aplicador FORA do conjunto usado (Jacto 10) apagado: NAO para" "$SAI" "0"
confere "V2 o script recriou o Jacto 10 (aplicador 10+1+5 = 16)" "$(Q 'select count(1) from aplicador')" "16"

restaura; MB caderno_fazenda -e "insert into area (nome) values ('Sede')"; ANTES="$(Q "$CNT")"
MB --force caderno_fazenda < "$V7" > "$OUT/v3_force.txt" 2>&1
confere "V3 cliente que continua apos o erro (mysql --force): nada gravado, sessao ficou so-leitura" "$(Q "$CNT")" "$ANTES"
confere "V3 os comandos seguintes falharam com 1792 (modo so-leitura)" "$([ "$(grep -c 'ERROR 1792' "$OUT/v3_force.txt")" -gt 10 ] && echo sim || echo nao)" "sim"

# ============================================================================================
say "W1-W3  as travas do corrigir_ids.sql"
restaura; queima_ids; M < "$V6" > /dev/null 2>&1
MB caderno_fazenda -e "set foreign_key_checks=0; insert into aplicacao_talhao values (999, 1)"; ANTES="$(Q "$IDS")"
M < "$CORR" > "$OUT/w1_orfa.txt" 2>&1
confere "W1 linha de talhao sem aplicacao: PARE" "$(grep -o 'PARE: 1 linha(s) de talhao/insumo sem aplicacao' "$OUT/w1_orfa.txt" | head -1)" "PARE: 1 linha(s) de talhao/insumo sem aplicacao"
confere "W1 nada mudou" "$(Q "$IDS")" "$ANTES"
restaura; queima_ids; M < "$V6" > /dev/null 2>&1
MB caderno_fazenda -e "create table ligada_teste (id int primary key, id_aplicacao int not null, foreign key (id_aplicacao) references aplicacao(id_aplicacao))"; ANTES="$(Q "$IDS")"
M < "$CORR" > "$OUT/w2_ligada.txt" 2>&1
confere "W2 outra tabela ligada a aplicacao: PARE" "$(grep -o 'PARE: 1 tabela(s) ligada(s) a aplicacao' "$OUT/w2_ligada.txt" | head -1)" "PARE: 1 tabela(s) ligada(s) a aplicacao"
confere "W2 nada mudou" "$(Q "$IDS")" "$ANTES"
restaura
M < "$CORR" > "$OUT/w3_sem_aplicacoes.txt" 2>&1; SAI=$?
confere "W3 banco sem nenhuma aplicacao: sem erro e nada a trocar" "$SAI $(grep -o 'NUMERACAO JA ESTAVA CERTA' "$OUT/w3_sem_aplicacoes.txt" | head -1)" "0 NUMERACAO JA ESTAVA CERTA"

# ============================================================================================
say "X1-X2  DELETE em cascata (ON DELETE CASCADE) x DELETE explicito das filhas: o que a auditoria registra"
restaura
HIST_DE() { Q "select group_concat(concat(tabela_afetada,':',acao,':',n) order by tabela_afetada, cast(acao as char) separator ',') from (select tabela_afetada, acao, count(1) n from historico_alteracoes where chave_registro = '$1' group by tabela_afetada, acao) x"; }
MB caderno_fazenda -e "insert into aplicacao (id_aplicacao,id_operacao,id_aplicador,data_aplicacao,observacao) values (9101,1,1,'2026-11-10','x'); insert into aplicacao_talhao (id_aplicacao,id_talhao) values (9101,1); insert into aplicacao_insumo (id_aplicacao,id_insumo,dose_prevista,unidade_dose) values (9101,1,1.5,'L/ha'); delete from aplicacao where id_aplicacao = 9101"
confere "X1 DELETE so na aplicacao: as filhas somem por CASCADE" "$(Q "select (select count(1) from aplicacao_talhao where id_aplicacao=9101)+(select count(1) from aplicacao_insumo where id_aplicacao=9101)")" "0"
confere "X1 ...mas a auditoria so registra o DELETE da aplicacao (o CASCADE nao dispara os triggers das filhas)" "$(HIST_DE 9101)" "aplicacao:DELETE:1,aplicacao:INSERT:1,aplicacao_insumo:INSERT:1,aplicacao_talhao:INSERT:1"
MB caderno_fazenda -e "insert into aplicacao (id_aplicacao,id_operacao,id_aplicador,data_aplicacao,observacao) values (9102,1,1,'2026-11-10','x'); insert into aplicacao_talhao (id_aplicacao,id_talhao) values (9102,1); insert into aplicacao_insumo (id_aplicacao,id_insumo,dose_prevista,unidade_dose) values (9102,1,1.5,'L/ha'); delete from aplicacao_insumo where id_aplicacao = 9102; delete from aplicacao_talhao where id_aplicacao = 9102; delete from aplicacao where id_aplicacao = 9102"
confere "X2 filhas apagadas antes da aplicacao (como faz o programa e os scripts de desfazer): tudo auditado" "$(HIST_DE 9102)" "aplicacao:DELETE:1,aplicacao:INSERT:1,aplicacao_insumo:DELETE:1,aplicacao_insumo:INSERT:1,aplicacao_talhao:DELETE:1,aplicacao_talhao:INSERT:1"

# ---------- limpeza ----------
MB -e "drop user if exists 'agrogestor_app'@'localhost'; drop database if exists caderno_fazenda" 2>/dev/null
rm -f "$OUT/_pure_sem_alter.sql" "$OUT/_base_tabelas_triggers_alter_seeds.sql"

echo
echo "================================================================"
echo "RESULTADO: $((TOTAL-FALHAS)) de $TOTAL conferencias OK   |   MySQL $VERSAO"
if [ "$FALHAS" -eq 0 ]; then echo "TUDO OK."; else echo "ATENCAO: $FALHAS FALHA(S). Veja as linhas FALHA acima e as saidas em $OUT"; fi
echo "================================================================"
exit "$FALHAS"
