// Verifica os custom claims atuais de um usuário, direto no servidor.
// Uso: node verificar.js farmaceutico1@flemingcore.com

const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const serviceAccount = require('./service-account.json');

initializeApp({
  credential: cert(serviceAccount),
});

const auth = getAuth();

const email = process.argv[2];

if (!email) {
  console.error('Uso: node verificar.js <email>');
  process.exit(1);
}

auth.getUserByEmail(email)
  .then((user) => {
    console.log('UID:', user.uid);
    console.log('Email:', user.email);
    console.log('Custom claims:', user.customClaims);
    process.exit(0);
  })
  .catch((e) => {
    console.error('Erro:', e.message);
    process.exit(1);
  });
