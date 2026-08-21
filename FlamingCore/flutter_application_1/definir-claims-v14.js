// Script para definir os custom claims (tipo_usuario, farmacia_id) dos
// usuários de teste do FlemingCore. Roda uma única vez, localmente.
//
// Compatível com firebase-admin v13+ (API modular).
//
// COMO USAR:
// 1. npm install firebase-admin
// 2. Coloca o arquivo da chave de serviço na mesma pasta desse script,
//    renomeado para: service-account.json
// 3. node definir-claims.js

const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const serviceAccount = require('./service-account.json');

initializeApp({
  credential: cert(serviceAccount),
});

const auth = getAuth();

// Ajuste os emails abaixo para bater exatamente com os que aparecem
// no console (Authentication > Users) — copie o email completo de lá,
// não confie no que está truncado com "...".
const usuarios = [
  {
    email: 'farmaceutico1@flemingcore.com', // TROCAR pelo email completo real
    tipo_usuario: 'FARMACEUTICO',
    farmacia_id: 'farm_001',
  },
  {
    email: 'farmaceutico2@flemingcore.com', // TROCAR pelo email completo real
    tipo_usuario: 'FARMACEUTICO',
    farmacia_id: 'farm_002',
  },
  {
    email: 'eurofarma@flemingcore.com', // TROCAR pelo email completo real
    tipo_usuario: 'EUROFARMA',
  },
  // O usuário "distribuidor" está desativado no console (Ideia 22 não
  // vai ser implementada por enquanto) — não precisa de claim.
];

async function definirClaims() {
  for (const u of usuarios) {
    try {
      const user = await auth.getUserByEmail(u.email);

      const claims = { tipo_usuario: u.tipo_usuario };
      if (u.farmacia_id) claims.farmacia_id = u.farmacia_id;

      await auth.setCustomUserClaims(user.uid, claims);
      console.log(`✅ Claims definidos para ${u.email}:`, claims);
    } catch (e) {
      console.error(`❌ Erro ao definir claims para ${u.email}:`, e.message);
    }
  }

  console.log('\nConcluído. Se algum usuário deu erro, confirme o email exato no console do Firebase.');
  process.exit(0);
}

definirClaims();
