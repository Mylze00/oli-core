const pool = require('./src/config/db');

pool.query('ALTER TABLE order_items ADD COLUMN origin_video_id INTEGER REFERENCES video_sales(id);')
  .then(() => {
    console.log('Colonne origin_video_id ajoutée avec succès.');
    process.exit(0);
  })
  .catch(err => {
    console.log('Erreur (ou colonne existe déjà):', err.message);
    process.exit(0);
  });
