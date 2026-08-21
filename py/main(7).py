"""
FlemingCore — Firebase Functions Backend
Responsável: Laysla

Organização:
- Imports + Config
- Funções Auxiliares
- Functions HTTP
- Functions Pub/Sub
- Prometheus Wrapper

REGRAS QUE NUNCA PODEM SER QUEBRADAS:
✋ Nunca hardcodar senha, API key ou credencial no código — sempre via get_secret
✋ Sempre validar token antes de qualquer operação — sem exceção exceto receber_lote_sap
✋ Sempre filtrar por farmacia_id — farmácia A nunca vê dado da farmácia B
✋ EUROFARMA e DISTRIBUIDOR recebem 403 em qualquer Function de dado individual de farmácia
✋ FCM: nunca usar Server Key — API morta desde junho/2024 — sempre messaging.send() do firebase-admin
✋ Gemini: nunca hardcodar nome do modelo no código: MODEL_NAME = os.environ.get("GEMINI_MODEL", "gemini-flash-latest")
✋ EVA nunca acessa banco diretamente — só via contexto montado pela Function
✋ EVA nunca decide, só comunica dado já calculado
"""

import os
import json
import logging
import firebase_admin
from firebase_admin import auth, db as rtdb, messaging
from google.cloud import secretmanager, pubsub_v1
import psycopg2
from datetime import date
import base64
import time
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from firebase_functions import https_fn, pubsub_fn, options
import google.generativeai as genai

options.set_global_options(
    region="southamerica-east1",
    service_account="firebase-functions@flemingcore-53272.iam.gserviceaccount.com"
)

# ============================================================================
# INICIALIZAÇÃO E CONFIGURAÇÃO
# ============================================================================

# databaseURL é obrigatório aqui — sem ele, rtdb.reference(...).set() falha
# silenciosamente ou trava. Não dá erro visível, só não grava nada.
DATABASE_URL = os.environ.get(
    "FIREBASE_DATABASE_URL",
    "https://flemingcore-53272-default-rtdb.firebaseio.com"
)

if not firebase_admin._apps:
    firebase_admin.initialize_app(options={"databaseURL": DATABASE_URL})

logging.basicConfig(level=os.environ.get("LOG_LEVEL", "INFO"))
logger = logging.getLogger("flemingcore")

PROJECT_ID = os.environ.get("GCP_PROJECT", "flemingcore-53272")

# gemini-2.0-flash foi desativado em 01/06/2026 — usa o alias "latest" para
# nunca depender de uma versão específica que pode ser descontinuada.
MODEL_NAME = os.environ.get("GEMINI_MODEL", "gemini-flash-latest")

# Conexão com banco — todos os campos vêm de env var.
# Conexão via IP público (decisão de custo, sem VPC Connector).
# Se testar localmente, seu IP precisa estar autorizado no Cloud SQL em "Redes autorizadas".
DB_HOST = os.environ.get("DB_HOST", "34.39.149.248")
DB_PORT = int(os.environ.get("DB_PORT", "5432"))
DB_NAME = os.environ.get("DB_NAME", "farmastock")
DB_USER = os.environ.get("DB_USER", "postgres")

# Nomes dos tópicos Pub/Sub — configuráveis via env var (bate com o .env.example)
PUBSUB_TOPIC_EMAIL = os.environ.get("PUBSUB_TOPIC_EMAIL", "alertas-email")
PUBSUB_TOPIC_FCM = os.environ.get("PUBSUB_TOPIC_FCM", "alertas-fcm")

# Prometheus Metrics
requisicoes = Counter(
    "flemingcore_requisicoes_total",
    "Total de requisicoes por Function",
    ["function_name"]
)

latencia = Histogram(
    "flemingcore_latencia_segundos",
    "Latencia das Functions em segundos",
    ["function_name"]
)


def log_erro(function_name: str, e: Exception):
    """Loga erro estruturado — sem isso, falhas em produção são invisíveis fora do response HTTP."""
    logger.error(f"[{function_name}] {type(e).__name__}: {e}")

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

def get_secret(secret_name: str) -> str:
    """
    Busca credencial no Secret Manager.
    Nunca hardcodar senha no código — toda credencial passa por aqui.
    Depende de: Josué criar os secrets no Secret Manager.
    """
    client = secretmanager.SecretManagerServiceClient()
    name = f"projects/{PROJECT_ID}/secrets/{secret_name}/versions/latest"
    response = client.access_secret_version(request={"name": name})
    return response.payload.data.decode("UTF-8")


def get_db_connection():
    """
    Abre conexão com PostgreSQL via IP público autorizado
    (VPC Connector foi cancelado por decisão de custo).
    Depende de: Rafael importar o schema no banco.
    """
    password = get_secret("db-password")
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=password
    )


def validar_token(token: str) -> dict:
    """
    Decodifica JWT do Firebase.
    Retorna farmacia_id, tipo_usuario, distribuidor_id e uid.
    farmacia_id é None para EUROFARMA, DISTRIBUIDOR e ADMIN.
    Depende de: Josué configurar custom claims no Firebase Authentication.
    """
    decoded = auth.verify_id_token(token)
    tipo_usuario = decoded.get("tipo_usuario")
    if not tipo_usuario:
        raise ValueError("Token sem tipo_usuario — Josué precisa configurar custom claims")
    return {
        "farmacia_id": decoded.get("farmacia_id"),
        "distribuidor_id": decoded.get("distribuidor_id"),
        "tipo_usuario": tipo_usuario,
        "uid": decoded["uid"]
    }


# ============================================================================
# FUNÇÃO TESTE
# ============================================================================

@https_fn.on_request()
def hello_flemingcore(req: https_fn.Request) -> https_fn.Response:
    """Confirma que o ambiente funciona."""
    requisicoes.labels(function_name="hello_flemingcore").inc()
    return https_fn.Response("FlemingCore funcionando.")


@https_fn.on_request()
def metrics(req: https_fn.Request) -> https_fn.Response:
    """
    Expõe métricas Prometheus em formato texto.
    Sem esta Function, os Counter/Histogram definidos acima nunca saem da memória —
    Grafana e Prometheus não têm o que coletar.
    Configurar no Prometheus/Grafana como scrape target desta URL.
    """
    return https_fn.Response(generate_latest(), content_type=CONTENT_TYPE_LATEST)


# ============================================================================
# FUNCTIONS DO FARMACÊUTICO
# ============================================================================

@https_fn.on_request()
def buscar_medicamento(req: https_fn.Request) -> https_fn.Response:
    """Busca medicamento pelo código de barras."""
    inicio = time.time()
    try:
        token = req.headers.get("Authorization", "").replace("Bearer ", "")
        validar_token(token)
        codigo_barras = req.args.get("codigo_barras")
        if not codigo_barras:
            requisicoes.labels(function_name="buscar_medicamento").inc()
            return https_fn.Response("codigo_barras obrigatorio", status=400)
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            """SELECT id_medicamento, nome, fabricante, categoria
            FROM medicamento WHERE codigo_barras = %s""",
            (codigo_barras,)
        )
        row = cur.fetchone()
        conn.close()
        requisicoes.labels(function_name="buscar_medicamento").inc()
        latencia.labels(function_name="buscar_medicamento").observe(time.time() - inicio)
        if not row:
            return https_fn.Response(json.dumps({"encontrado": False}), content_type="application/json")
        return https_fn.Response(
            json.dumps({
                "encontrado": True,
                "id_medicamento": row[0],
                "nome": row[1],
                "fabricante": row[2],
                "categoria": row[3]
            }),
            content_type="application/json"
        )
    except Exception as e:
        requisicoes.labels(function_name="buscar_medicamento").inc()
        log_erro("buscar_medicamento", e)
        return https_fn.Response(json.dumps({"erro": str(e)}), status=500, content_type="application/json")


@https_fn.on_request()
def cadastrar_lote(req: https_fn.Request) -> https_fn.Response:
    """Cadastra novo lote de medicamento. Apenas FARMACÊUTICO pode chamar."""
    inicio = time.time()
    try:
        token = req.headers.get("Authorization", "").replace("Bearer ", "")
        claims = validar_token(token)
        if claims["tipo_usuario"] != "FARMACEUTICO":
            requisicoes.labels(function_name="cadastrar_lote").inc()
            return https_fn.Response("Acesso negado", status=403)
        farmacia_id = claims["farmacia_id"]
        data = req.get_json()
        conn = get_db_connection()
        cur = conn.cursor()

        # Busca o id_usuario interno (integer) a partir do firebase_uid
        cur.execute(
            "SELECT id_usuario FROM usuario WHERE firebase_uid = %s",
            (claims["uid"],)
        )
        row_usuario = cur.fetchone()
        if not row_usuario:
            conn.close()
            return https_fn.Response("Usuário não encontrado no banco", status=404)
        id_usuario_interno = row_usuario[0]

        cur.execute(
            """INSERT INTO lote
            (numero_lote, validade, quantidade, origem, preco_unitario, id_medicamento, id_farmacia, data_ultima_movimentacao)
            VALUES (%s, %s, %s, %s, %s, %s, %s, CURRENT_DATE) RETURNING id_lote""",
            (data["numero_lote"], data["validade"], data["quantidade"], data.get("origem", "MANUAL"),
             data.get("preco_unitario"), data["id_medicamento"], farmacia_id)
        )
        id_lote = cur.fetchone()[0]
        cur.execute(
            """INSERT INTO historico_atividades (id_farmacia, id_usuario, tipo_acao, descricao)
            VALUES (%s, %s, %s, %s)""",
            (farmacia_id, id_usuario_interno, "cadastro_lote", f"Lote {data['numero_lote']} cadastrado")
        )
        conn.commit()
        conn.close()
        requisicoes.labels(function_name="cadastrar_lote").inc()
        latencia.labels(function_name="cadastrar_lote").observe(time.time() - inicio)
        return https_fn.Response(json.dumps({"id_lote": id_lote}), content_type="application/json", status=201)
    except Exception as e:
        requisicoes.labels(function_name="cadastrar_lote").inc()
        log_erro("cadastrar_lote", e)
        return https_fn.Response(json.dumps({"erro": str(e)}), status=500, content_type="application/json")


@https_fn.on_request()
def buscar_alertas(req: https_fn.Request) -> https_fn.Response:
    """Busca alertas abertos da farmácia. EUROFARMA e DISTRIBUIDOR recebem 403."""
    inicio = time.time()
    try:
        token = req.headers.get("Authorization", "").replace("Bearer ", "")
        claims = validar_token(token)
        if claims["tipo_usuario"] in ("EUROFARMA", "DISTRIBUIDOR"):
            requisicoes.labels(function_name="buscar_alertas").inc()
            return https_fn.Response("Acesso negado", status=403)
        farmacia_id = claims["farmacia_id"]
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            """SELECT a.id_alerta, m.nome, a.score, a.tipo, a.recomendacao, a.valor_financeiro_risco,
            a.sobra_projetada, a.status, l.validade, l.quantidade
            FROM alerta a JOIN lote l ON a.id_lote = l.id_lote
            JOIN medicamento m ON l.id_medicamento = m.id_medicamento
            WHERE a.id_farmacia = %s AND a.status = 'ABERTO' ORDER BY a.score DESC""",
            (farmacia_id,)
        )
        rows = cur.fetchall()
        conn.close()
        requisicoes.labels(function_name="buscar_alertas").inc()
        latencia.labels(function_name="buscar_alertas").observe(time.time() - inicio)
        return https_fn.Response(
            json.dumps({"alertas": [{
                "id_alerta": r[0], "medicamento": r[1], "score": float(r[2]) if r[2] else 0,
                "tipo": r[3], "recomendacao": r[4], "valor_financeiro_risco": float(r[5]) if r[5] else 0,
                "sobra_projetada": r[6], "status": r[7], "validade": str(r[8]), "quantidade": r[9]
            } for r in rows]}),
            content_type="application/json"
        )
    except Exception as e:
        requisicoes.labels(function_name="buscar_alertas").inc()
        log_erro("buscar_alertas", e)
        return https_fn.Response(json.dumps({"erro": str(e)}), status=500, content_type="application/json")


@https_fn.on_request()
def resolver_alerta(req: https_fn.Request) -> https_fn.Response:
    """Resolve um alerta com ação tomada: promocao | devolucao | monitoramento"""
    inicio = time.time()
    try:
        token = req.headers.get("Authorization", "").replace("Bearer ", "")
        claims = validar_token(token)
        if claims["tipo_usuario"] != "FARMACEUTICO":
            requisicoes.labels(function_name="resolver_alerta").inc()
            return https_fn.Response("Acesso negado", status=403)
        farmacia_id = claims["farmacia_id"]
        data = req.get_json()
        id_alerta = data["id_alerta"]
        acao_tomada = data["acao_tomada"]
        conn = get_db_connection()
        cur = conn.cursor()

        # Busca o id_usuario interno (integer) a partir do firebase_uid
        cur.execute(
            "SELECT id_usuario FROM usuario WHERE firebase_uid = %s",
            (claims["uid"],)
        )
        row_usuario = cur.fetchone()
        if not row_usuario:
            conn.close()
            return https_fn.Response("Usuário não encontrado no banco", status=404)
        id_usuario_interno = row_usuario[0]

        cur.execute("SELECT valor_financeiro_risco, sobra_projetada FROM alerta WHERE id_alerta = %s AND id_farmacia = %s",
            (id_alerta, farmacia_id))
        alerta = cur.fetchone()
        if not alerta:
            conn.close()
            requisicoes.labels(function_name="resolver_alerta").inc()
            return https_fn.Response("Alerta nao encontrado", status=404)
        valor_risco, sobra = alerta[0] or 0, alerta[1] or 0
        cur.execute("UPDATE alerta SET status = 'RESOLVIDO', acao_tomada = %s, data_resolucao = CURRENT_TIMESTAMP WHERE id_alerta = %s AND id_farmacia = %s",
            (acao_tomada, id_alerta, farmacia_id))
        cur.execute("UPDATE farmacia SET total_desperdicio_evitado = total_desperdicio_evitado + %s, total_medicamentos_preservados = total_medicamentos_preservados + %s WHERE id_farmacia = %s",
            (valor_risco, sobra, farmacia_id))
        if acao_tomada == "devolucao":
            cur.execute("SELECT id_lote FROM alerta WHERE id_alerta = %s", (id_alerta,))
            id_lote = cur.fetchone()[0]
            cur.execute("INSERT INTO solicitacoes_devolucao (id_lote, id_farmacia, id_usuario, quantidade, motivo) SELECT %s, %s, %s, l.quantidade, 'Risco de vencimento — alerta resolvido' FROM lote l WHERE l.id_lote = %s",
                (id_lote, farmacia_id, id_usuario_interno, id_lote))
        cur.execute("INSERT INTO historico_atividades (id_farmacia, id_usuario, tipo_acao, descricao) VALUES (%s, %s, %s, %s)",
            (farmacia_id, id_usuario_interno, "alerta_resolvido", f"Alerta {id_alerta} resolvido com acao: {acao_tomada}"))
        # Popular id_usuario_resolucao
        cur.execute(
            "UPDATE alerta SET id_usuario_resolucao = %s WHERE id_alerta = %s",
            (id_usuario_interno, id_alerta)
        )
        conn.commit()
        conn.close()
        requisicoes.labels(function_name="resolver_alerta").inc()
        latencia.labels(function_name="resolver_alerta").observe(time.time() - inicio)
        return https_fn.Response(json.dumps({"ok": True}), content_type="application/json")
    except Exception as e:
        requisicoes.labels(function_name="resolver_alerta").inc()
        log_erro("resolver_alerta", e)
        return https_fn.Response(json.dumps({"erro": str(e)}), status=500, content_type="application/json")


# ============================================================================
# FUNCTIONS AVANÇADAS
# ============================================================================

@https_fn.on_request()
def buscar_historico(req: https_fn.Request) -> https_fn.Response:
    """Busca histórico de atividades da farmácia."""
    inicio = time.time()
    try:
        token = req.headers.get("Authorization", "").replace("Bearer ", "")
        claims = validar_token(token)
        if claims["tipo_usuario"] in ("EUROFARMA", "DISTRIBUIDOR"):
            requisicoes.labels(function_name="buscar_historico").inc()
            return https_fn.Response("Acesso negado", status=403)
        farmacia_id = claims["farmacia_id"]
        dias = int(req.args.get("dias", 30))
        tipo_acao = req.args.get("tipo_acao")
        conn = get_db_connection()
        cur = conn.cursor()
        query = "SELECT h.id_historico, u.nome, h.tipo_acao, h.descricao, h.data_hora FROM historico_atividades h LEFT JOIN usuario u ON h.id_usuario = u.id_usuario WHERE h.id_farmacia = %s AND h.data_hora >= NOW() - INTERVAL '%s days'"
        params = [farmacia_id, dias]
        if tipo_acao:
            query += " AND h.tipo_acao = %s"
            params.append(tipo_acao)
        query += " ORDER BY h.data_hora DESC"
        cur.execute(query, params)
        rows = cur.fetchall()
        conn.close()
        requisicoes.labels(function_name="buscar_historico").inc()
        latencia.labels(function_name="buscar_historico").observe(time.time() - inicio)
        return https_fn.Response(json.dumps({"historico": [{"id": r[0], "farmaceutico": r[1], "tipo_acao": r[2], "descricao": r[3], "data_hora": str(r[4])} for r in rows]}), content_type="application/json")
    except Exception as e:
        requisicoes.labels(function_name="buscar_historico").inc()
        log_erro("buscar_historico", e)
        return https_fn.Response(json.dumps({"erro": str(e)}), status=500, content_type="application/json")


@https_fn.on_request()
def salvar_token_fcm(req: https_fn.Request) -> https_fn.Response:
    """Salva token FCM do usuário para push notifications."""
    inicio = time.time()
    try:
        token = req.headers.get("Authorization", "").replace("Bearer ", "")
        claims = validar_token(token)
        if claims["tipo_usuario"] != "FARMACEUTICO":
            requisicoes.labels(function_name="salvar_token_fcm").inc()
            return https_fn.Response("Acesso negado", status=403)
        data = req.get_json()
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("UPDATE usuario SET token_fcm = %s WHERE firebase_uid = %s", (data["token_fcm"], claims["uid"]))
        conn.commit()
        conn.close()
        requisicoes.labels(function_name="salvar_token_fcm").inc()
        latencia.labels(function_name="salvar_token_fcm").observe(time.time() - inicio)
        return https_fn.Response(json.dumps({"ok": True}), content_type="application/json")
    except Exception as e:
        requisicoes.labels(function_name="salvar_token_fcm").inc()
        log_erro("salvar_token_fcm", e)
        return https_fn.Response(json.dumps({"erro": str(e)}), status=500, content_type="application/json")


@https_fn.on_request()
def projecao_diaria(req: https_fn.Request) -> https_fn.Response:
    """Calcula alertas para todos os lotes."""
    inicio = time.time()
    try:
        conn = get_db_connection()
        cur = conn.cursor()
        publisher = pubsub_v1.PublisherClient()
        hoje = date.today()
        cur.execute("SELECT l.id_lote, l.id_farmacia, l.validade, l.quantidade, l.preco_unitario, m.nome FROM lote l JOIN medicamento m ON l.id_medicamento = m.id_medicamento WHERE l.quantidade > 0 AND l.validade >= CURRENT_DATE")
        lotes = cur.fetchall()
        for lote in lotes:
            id_lote, id_farmacia, validade, quantidade, preco, nome = lote
            dias_restantes = (validade - hoje).days
            cur.execute("SELECT COALESCE(SUM(v.quantidade), 0) FROM venda v WHERE v.id_lote = %s AND v.data_venda >= NOW() - INTERVAL '90 days'", (id_lote,))
            total_vendas_90d = cur.fetchone()[0]
            media_diaria = total_vendas_90d / 90 if total_vendas_90d > 0 else 0.1
            sobra_projetada = max(0, quantidade - int(media_diaria * dias_restantes))
            valor_risco = round(sobra_projetada * (preco or 0), 2)
            urgencia = max(0, 1 - (dias_restantes / 90))
            proporcao = sobra_projetada / quantidade if quantidade > 0 else 0
            financeiro = min(1, valor_risco / 10000) if valor_risco > 0 else 0
            score = round((urgencia + proporcao + financeiro) / 3 * 100, 2)
            if score >= 70:
                recomendacao = "Considere devolucao ao distribuidor" if dias_restantes < 15 else "Considere promocao para acelerar saida"
                cur.execute("INSERT INTO alerta (tipo, severidade, mensagem, status, score, recomendacao, valor_financeiro_risco, sobra_projetada, id_lote, id_farmacia) VALUES (%s,%s,%s,'ABERTO',%s,%s,%s,%s,%s,%s) RETURNING id_alerta",
                    ("vencimento", "CRITICA" if score >= 85 else "ALTA", f"{nome} com score {score} — vence em {dias_restantes} dias", score, recomendacao, valor_risco, sobra_projetada, id_lote, id_farmacia))
                id_alerta = cur.fetchone()[0]
                payload = json.dumps({"id_alerta": id_alerta, "id_farmacia": id_farmacia, "medicamento": nome, "score": score, "dias_restantes": dias_restantes, "recomendacao": recomendacao}).encode()
                publisher.publish(f"projects/{PROJECT_ID}/topics/{PUBSUB_TOPIC_EMAIL}", payload)
                publisher.publish(f"projects/{PROJECT_ID}/topics/{PUBSUB_TOPIC_FCM}", payload)
                rtdb.reference(f"farmacias/{id_farmacia}/alertas/{id_alerta}").set({"medicamento": nome, "score": score, "dias_restantes": dias_restantes, "recomendacao": recomendacao, "status": "ABERTO"})
        conn.commit()
        conn.close()
        requisicoes.labels(function_name="projecao_diaria").inc()
        latencia.labels(function_name="projecao_diaria").observe(time.time() - inicio)
        return https_fn.Response(json.dumps({"ok": True}), content_type="application/json")
    except Exception as e:
        requisicoes.labels(function_name="projecao_diaria").inc()
        log_erro("projecao_diaria", e)
        return https_fn.Response(json.dumps({"erro": str(e)}), status=500, content_type="application/json")


@https_fn.on_request()
def buscar_dashboard_eurofarma(req: https_fn.Request) -> https_fn.Response:
    """Dashboard agregado para EUROFARMA. Sem dados individuais."""
    inicio = time.time()
    try:
        token = req.headers.get("Authorization", "").replace("Bearer ", "")
        claims = validar_token(token)
        if claims["tipo_usuario"] != "EUROFARMA":
            requisicoes.labels(function_name="buscar_dashboard_eurofarma").inc()
            return https_fn.Response("Acesso negado", status=403)
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT COALESCE(SUM(total_desperdicio_evitado), 0), COALESCE(SUM(total_medicamentos_preservados), 0), COALESCE(AVG(ivf_atual), 0), COUNT(*) FILTER (WHERE indice_anvisa_ready >= 80), COUNT(*) FROM farmacia")
        row = cur.fetchone()
        cur.execute("SELECT m.fabricante, ROUND(AVG(a.score)::numeric, 2) as score_medio, COUNT(l.id_lote) as total_lotes FROM lote l JOIN medicamento m ON l.id_medicamento = m.id_medicamento LEFT JOIN alerta a ON a.id_lote = l.id_lote AND a.status = 'ABERTO' WHERE m.fabricante IS NOT NULL GROUP BY m.fabricante ORDER BY score_medio DESC NULLS LAST")
        fabricantes = [{"fabricante": r[0], "score_medio": float(r[1] or 0), "total_lotes": r[2]} for r in cur.fetchall()]
        conn.close()
        requisicoes.labels(function_name="buscar_dashboard_eurofarma").inc()
        latencia.labels(function_name="buscar_dashboard_eurofarma").observe(time.time() - inicio)
        return https_fn.Response(json.dumps({"total_desperdicio_evitado": float(row[0]), "total_medicamentos_preservados": int(row[1]), "ivf_medio": float(row[2]), "farmacias_anvisa_ready": int(row[3]), "total_farmacias": int(row[4]), "termometro_fabricantes": fabricantes}), content_type="application/json")
    except Exception as e:
        requisicoes.labels(function_name="buscar_dashboard_eurofarma").inc()
        log_erro("buscar_dashboard_eurofarma", e)
        return https_fn.Response(json.dumps({"erro": str(e)}), status=500, content_type="application/json")


@https_fn.on_request()
def buscar_dashboard_distribuidor(req: https_fn.Request) -> https_fn.Response:
    """Dashboard logístico para DISTRIBUIDOR."""
    inicio = time.time()
    try:
        token = req.headers.get("Authorization", "").replace("Bearer ", "")
        claims = validar_token(token)
        if claims["tipo_usuario"] != "DISTRIBUIDOR":
            requisicoes.labels(function_name="buscar_dashboard_distribuidor").inc()
            return https_fn.Response("Acesso negado", status=403)
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT COUNT(*) FROM solicitacoes_devolucao WHERE status = 'PENDENTE'")
        devolucoes_pendentes = cur.fetchone()[0]
        cur.execute("SELECT m.nome, m.fabricante, COUNT(a.id_alerta) as total_alertas, ROUND(AVG(a.score)::numeric, 2) as score_medio FROM alerta a JOIN lote l ON a.id_lote = l.id_lote JOIN medicamento m ON l.id_medicamento = m.id_medicamento WHERE a.status = 'ABERTO' AND a.score >= 70 GROUP BY m.nome, m.fabricante ORDER BY total_alertas DESC LIMIT 10")
        alertas_criticos = [{"medicamento": r[0], "fabricante": r[1], "total_alertas": r[2], "score_medio": float(r[3] or 0)} for r in cur.fetchall()]
        cur.execute("SELECT m.nome, COUNT(l.id_lote) as lotes_parados FROM lote l JOIN medicamento m ON l.id_medicamento = m.id_medicamento WHERE l.data_ultima_movimentacao < CURRENT_DATE - INTERVAL '90 days' OR l.data_ultima_movimentacao IS NULL GROUP BY m.nome ORDER BY lotes_parados DESC LIMIT 10")
        lotes_parados = [{"medicamento": r[0], "lotes_parados": r[1]} for r in cur.fetchall()]
        conn.close()
        requisicoes.labels(function_name="buscar_dashboard_distribuidor").inc()
        latencia.labels(function_name="buscar_dashboard_distribuidor").observe(time.time() - inicio)
        return https_fn.Response(json.dumps({"devolucoes_pendentes": devolucoes_pendentes, "alertas_criticos_por_produto": alertas_criticos, "produtos_parados": lotes_parados}), content_type="application/json")
    except Exception as e:
        requisicoes.labels(function_name="buscar_dashboard_distribuidor").inc()
        log_erro("buscar_dashboard_distribuidor", e)
        return https_fn.Response(json.dumps({"erro": str(e)}), status=500, content_type="application/json")


@pubsub_fn.on_message_published(topic=PUBSUB_TOPIC_FCM)
def enviar_notificacoes(event: pubsub_fn.CloudEvent) -> None:
    """Envia notificação push via FCM. NUNCA usar Server Key."""
    try:
        payload = json.loads(base64.b64decode(event.data.message.data).decode())
        id_farmacia = payload["id_farmacia"]
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute("SELECT token_fcm FROM usuario WHERE id_farmacia = %s AND token_fcm IS NOT NULL AND tipo_usuario = 'FARMACEUTICO'", (id_farmacia,))
        tokens = [r[0] for r in cur.fetchall()]
        conn.close()
        for token in tokens:
            message = messaging.Message(notification=messaging.Notification(title="Alerta FlemingCore", body=f"{payload['medicamento']} — Score {payload['score']}"), token=token)
            messaging.send(message)
        requisicoes.labels(function_name="enviar_notificacoes").inc()
    except Exception as e:
        log_erro("enviar_notificacoes", e)


# ============================================================================
# ENVIAR_EMAIL_ALERTA
# ============================================================================

@pubsub_fn.on_message_published(topic=PUBSUB_TOPIC_EMAIL)
def enviar_email_alerta(event: pubsub_fn.CloudEvent) -> None:
    """
    Envia email de alerta via Gmail API.
    Enquanto gmail-oauth-credentials for placeholder, loga em vez de enviar de verdade —
    sem esse tratamento, a Function quebraria todo teste até a credencial real chegar.
    """
    inicio = time.time()
    try:
        payload = json.loads(base64.b64decode(event.data.message.data).decode())
        id_farmacia = payload["id_farmacia"]

        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            """SELECT email FROM usuario
            WHERE id_farmacia = %s AND tipo_usuario = 'FARMACEUTICO'""",
            (id_farmacia,)
        )
        emails = [r[0] for r in cur.fetchall()]
        conn.close()

        gmail_creds_raw = get_secret("gmail-oauth-credentials")

        if gmail_creds_raw == "placeholder":
            logger.info(
                f"[TESTE] Email seria enviado para {emails}: "
                f"{payload['medicamento']} — score {payload['score']}"
            )
        else:
            from google.oauth2.credentials import Credentials
            from googleapiclient.discovery import build
            from email.mime.text import MIMEText

            gmail_creds_json = json.loads(gmail_creds_raw)
            creds = Credentials(
                token=None,
                refresh_token=gmail_creds_json["refresh_token"],
                client_id=gmail_creds_json["client_id"],
                client_secret=gmail_creds_json["client_secret"],
                token_uri="https://oauth2.googleapis.com/token"
            )
            service = build("gmail", "v1", credentials=creds)

            for email in emails:
                mensagem = MIMEText(
                    f"Alerta: {payload['medicamento']} — score {payload['score']}, "
                    f"{payload['dias_restantes']} dias restantes.\n\n{payload['recomendacao']}"
                )
                mensagem["to"] = email
                mensagem["subject"] = f"FlemingCore — Alerta: {payload['medicamento']}"
                corpo_codificado = {"raw": base64.urlsafe_b64encode(mensagem.as_bytes()).decode()}
                service.users().messages().send(userId="me", body=corpo_codificado).execute()

        requisicoes.labels(function_name="enviar_email_alerta").inc()
        latencia.labels(function_name="enviar_email_alerta").observe(time.time() - inicio)
    except Exception as e:
        requisicoes.labels(function_name="enviar_email_alerta").inc()
        log_erro("enviar_email_alerta", e)


# ============================================================================
# RECEBER_LOTE_SAP
# ============================================================================

@https_fn.on_request()
def receber_lote_sap(req: https_fn.Request) -> https_fn.Response:
    """
    Recebe lote do mock SAP via API key no cabeçalho.
    Nunca usa token Firebase — sistemas externos não fazem login.
    """
    inicio = time.time()
    try:
        api_key_recebida = req.headers.get("X-API-Key", "")
        api_key_correta = get_secret("sap-api-key")

        if api_key_recebida != api_key_correta:
            requisicoes.labels(function_name="receber_lote_sap").inc()
            return https_fn.Response("API key invalida", status=401)

        data = req.get_json()
        codigo_barras = data.get("codigo_barras")
        numero_lote = data.get("numero_lote")
        quantidade = data.get("quantidade")
        validade = data.get("data_validade")
        farmacia_id = data.get("farmacia_id")

        # Validações — cenários 3 e 4 do mock do Rafael
        if not quantidade or quantidade <= 0:
            requisicoes.labels(function_name="receber_lote_sap").inc()
            return https_fn.Response("Quantidade invalida", status=400)

        try:
            data_validade = date.fromisoformat(validade)
        except (ValueError, TypeError):
            requisicoes.labels(function_name="receber_lote_sap").inc()
            return https_fn.Response("Data de validade invalida", status=400)

        if data_validade < date.today():
            requisicoes.labels(function_name="receber_lote_sap").inc()
            return https_fn.Response("Data de validade no passado", status=400)

        conn = get_db_connection()
        cur = conn.cursor()

        # Cenário 2: medicamento não cadastrado — cria automaticamente
        cur.execute(
            "SELECT id_medicamento FROM medicamento WHERE codigo_barras = %s",
            (codigo_barras,)
        )
        row = cur.fetchone()
        if row:
            id_medicamento = row[0]
        else:
            cur.execute(
                """INSERT INTO medicamento (nome, codigo_barras)
                VALUES (%s, %s) RETURNING id_medicamento""",
                (f"Medicamento SAP {codigo_barras}", codigo_barras)
            )
            id_medicamento = cur.fetchone()[0]

        cur.execute(
            """INSERT INTO lote
            (numero_lote, validade, quantidade, origem,
            data_ultima_movimentacao, id_medicamento, id_farmacia)
            VALUES (%s, %s, %s, 'SAP', CURRENT_DATE, %s, %s)
            RETURNING id_lote""",
            (numero_lote, validade, quantidade, id_medicamento, farmacia_id)
        )
        id_lote = cur.fetchone()[0]

        conn.commit()
        conn.close()

        requisicoes.labels(function_name="receber_lote_sap").inc()
        latencia.labels(function_name="receber_lote_sap").observe(time.time() - inicio)

        return https_fn.Response(
            json.dumps({"id_lote": id_lote, "origem": "SAP"}),
            content_type="application/json",
            status=201
        )
    except Exception as e:
        requisicoes.labels(function_name="receber_lote_sap").inc()
        log_erro("receber_lote_sap", e)
        return https_fn.Response(json.dumps({"erro": str(e)}), status=500, content_type="application/json")


# ============================================================================
# EVA_CHAT
# ============================================================================

# PROVISÓRIO — escrito por Laysla só para o app não subir com o placeholder
# vazio. Depende do Vinicius e do Lucas: eles entregam o prompt final e
# quem for aplicar troca este bloco inteiro pelo deles antes da entrega.
SYSTEM_PROMPT = """
Você é a Flora, assistente de estoque do FlemingCore. Você conversa com
farmacêuticos sobre os alertas de vencimento e risco financeiro do
estoque da farmácia deles.

Regras:
- Use apenas os dados fornecidos no contexto abaixo. Nunca invente
  números, medicamentos ou recomendações que não estejam lá.
- Seja direta e objetiva — o farmacêutico está ocupado.
- Se não houver alertas no contexto, diga isso claramente, sem
  inventar um cenário de risco.
- Você não decide o que fazer com um lote — só comunica os dados e a
  recomendação já calculados. Se perguntarem "o que eu faço", responda
  com a recomendação que já está no dado, sem opinião própria.
- Responda em português, tom profissional e direto.
"""


def montar_contexto(farmacia_id: int, conn) -> str:
    """
    Monta o contexto real do estoque para enviar ao Gemini.
    EVA nunca acessa banco diretamente — só recebe este contexto já pronto.
    """
    cur = conn.cursor()
    cur.execute(
        """SELECT m.nome, a.score, a.recomendacao, l.validade,
        a.valor_financeiro_risco
        FROM alerta a
        JOIN lote l ON a.id_lote = l.id_lote
        JOIN medicamento m ON l.id_medicamento = m.id_medicamento
        WHERE a.id_farmacia = %s AND a.status = 'ABERTO'
        ORDER BY a.score DESC""",
        (farmacia_id,)
    )
    alertas = cur.fetchall()

    if not alertas:
        return "Não há alertas críticos no momento. Estoque controlado."

    linhas = ["Dados do estoque em tempo real:", ""]
    for i, (nome, score, rec, validade, valor_risco) in enumerate(alertas, 1):
        dias = (validade - date.today()).days
        linhas.append(
            f"- Alerta {i}: {nome}, score {score}, "
            f"{dias} dias até vencer, recomendação: {rec}, "
            f"valor em risco: R$ {valor_risco or 0}"
        )
    return "\n".join(linhas)


@https_fn.on_request()
def eva_chat(req: https_fn.Request) -> https_fn.Response:
    """
    Recebe pergunta do farmacêutico e retorna resposta da EVA.
    EVA nunca decide, só comunica dado já calculado — todo o cálculo (score,
    recomendação, valor de risco) já foi feito por projecao_diaria antes disso.
    """
    inicio = time.time()
    try:
        token = req.headers.get("Authorization", "").replace("Bearer ", "")
        claims = validar_token(token)

        if claims["tipo_usuario"] != "FARMACEUTICO":
            requisicoes.labels(function_name="eva_chat").inc()
            return https_fn.Response("Acesso negado", status=403)

        farmacia_id = claims["farmacia_id"]
        data = req.get_json()
        pergunta = data.get("pergunta", "").strip()

        if not pergunta:
            requisicoes.labels(function_name="eva_chat").inc()
            return https_fn.Response("Pergunta obrigatoria", status=400)

        api_key = get_secret("gemini-api-key")
        if api_key == "placeholder":
            requisicoes.labels(function_name="eva_chat").inc()
            return https_fn.Response(
                json.dumps({
                    "resposta": "Flora ainda não configurada — "
                    "aguardando chave real da API Gemini."
                }),
                content_type="application/json"
            )

        conn = get_db_connection()
        contexto = montar_contexto(farmacia_id, conn)
        conn.close()

        genai.configure(api_key=api_key)
        model = genai.GenerativeModel(
            model_name=MODEL_NAME,
            system_instruction=SYSTEM_PROMPT
        )

        prompt_completo = f"{contexto}\n\nPergunta do farmacêutico: {pergunta}"
        response = model.generate_content(prompt_completo)

        # Registrar a pergunta no histórico
        conn = get_db_connection()
        cur = conn.cursor()
        cur.execute(
            "SELECT id_usuario FROM usuario WHERE firebase_uid = %s",
            (claims["uid"],)
        )
        row_usuario = cur.fetchone()
        id_usuario_interno = row_usuario[0] if row_usuario else None
        cur.execute(
            """INSERT INTO historico_atividades
            (id_farmacia, id_usuario, tipo_acao, descricao)
            VALUES (%s, %s, %s, %s)""",
            (farmacia_id, id_usuario_interno, "pergunta_eva", pergunta)
        )
        conn.commit()
        conn.close()

        requisicoes.labels(function_name="eva_chat").inc()
        latencia.labels(function_name="eva_chat").observe(time.time() - inicio)

        return https_fn.Response(
            json.dumps({"resposta": response.text}),
            content_type="application/json"
        )
    except Exception as e:
        requisicoes.labels(function_name="eva_chat").inc()
        log_erro("eva_chat", e)
        return https_fn.Response(json.dumps({"erro": str(e)}), status=500, content_type="application/json")
