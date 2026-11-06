const { Pool } = require('pg');

const config = {
  host: process.env.DB_HOST || 'localhost',
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || 'loja',
  database: process.env.DB_NAME || 'loja',
  max: Number(process.env.DB_POOL_MAX || 10),
};

const pool = new Pool(config);

// Um erro em conexão ociosa do pool não deve derrubar o processo.
pool.on('error', (erro) => {
  console.error('erro em conexao ociosa do pool', erro);
});

async function consultar(sql, parametros = []) {
  const resultado = await pool.query(sql, parametros);
  return resultado.rows;
}

module.exports = { consultar };
