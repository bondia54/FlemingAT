"""
Script standalone — NÃO é uma Firebase Function, roda uma vez localmente.

Configura os custom claims dos 3 usuários de teste já criados por Rafael/Josué.
Sem isso, validar_token() nunca retorna tipo_usuario, e nenhum teste de fluxo
completo funciona — é bloqueador para tudo em Julho S1.

Uso:
    python configurar_custom_claims.py

Depois de rodar: cada usuário precisa fazer logout e login de novo no Flutter —
token antigo não atualiza sozinho.
"""

import firebase_admin
from firebase_admin import auth, credentials

# Precisa de um arquivo de credencial de conta de serviço —
# pedir para o Josué gerar em IAM → Contas de serviço → Chaves
cred = credentials.Certificate(
    "/home/layslabeatrizmachadoguimaraes/flemingcore-config/credencial-flemingcore-53272.json"
)
firebase_admin.initialize_app(cred)

auth.set_custom_user_claims(
    "751goQMXzVPTrGaswdOYrSZLMzQ2",  # eurofarma@flemingcore.com
    {"tipo_usuario": "EUROFARMA"}
)

auth.set_custom_user_claims(
    "fw34yzY8pCeDZqR4e8UMLJzSPPv2",  # farmaceutico1@flemingcore.com
    {"tipo_usuario": "FARMACEUTICO", "farmacia_id": 1}
)

auth.set_custom_user_claims(
    "dD8xb1TIxOMxz8FN3hLw6goaC2I3",  # farmaceutico2@flemingcore.com
    {"tipo_usuario": "FARMACEUTICO", "farmacia_id": 1}
)

print("Custom claims configurados.")
