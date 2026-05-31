const pool = require('./src/config/db');
const oliBank = require('./src/services/oli_bank.service');

async function fix() {
    try {
        const orderId = 'DEP-122-1780123731523';
        console.log('🔄 Récupération de la transaction...');
        
        const res = await pool.query('SELECT * FROM unipesa_operations WHERE oli_order_id = $1', [orderId]);
        if (res.rows.length === 0) {
            console.log('❌ Transaction introuvable !');
            process.exit(1);
        }
        
        const op = res.rows[0];
        if (op.status === 'success') {
            console.log('✅ Cette transaction a déjà été créditée.');
            process.exit(0);
        }

        console.log(`💰 Crédit du wallet pour user #${op.user_id} - Montant brut: ${op.amount_fc} FC`);
        
        const grossAmount = parseFloat(op.amount_fc);
        const totalFee = Math.round(grossAmount * 0.06);
        const netAmount = grossAmount - totalFee;

        await oliBank.processDeposit(op.user_id, netAmount, {
            phone: op.phone,
            provider: op.provider || 'Airtel',
            orderId: op.oli_order_id,
            description: `Recharge Mobile Money (Récupération) — ${grossAmount} FC`,
            metadata: { grossAmountFC: grossAmount, totalFeeFC: totalFee, netAmountFC: netAmount }
        });

        await pool.query('UPDATE unipesa_operations SET status = $1, confirmed_at = NOW() WHERE id = $2', ['success', op.id]);
        
        console.log('🎉 Portefeuille rechargé avec succès !');
    } catch (err) {
        console.error('Erreur:', err);
    } finally {
        await pool.end();
        process.exit(0);
    }
}
fix();
