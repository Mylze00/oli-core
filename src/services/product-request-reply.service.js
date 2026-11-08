/**
 * Livraison des réponses aux demandes de produit dans Market Chat.
 * Les messages sont signés par le compte « Équipe Oli » : ce compte n'a pas de
 * numéro valide, personne ne peut donc s'y connecter.
 */
const TEAM_PHONE = 'oli_team';
const TEAM_NAME = 'Équipe Oli';
const TEAM_ID_OLI = 'OLI-TEAM-0001';

async function getTeamAccountId(client) {
    const found = await client.query('SELECT id FROM users WHERE phone = $1', [TEAM_PHONE]);
    if (found.rows.length) return found.rows[0].id;
    const created = await client.query(
        `INSERT INTO users (phone, id_oli, name, is_verified, created_at, updated_at)
         VALUES ($1, $2, $3, true, NOW(), NOW()) RETURNING id`,
        [TEAM_PHONE, TEAM_ID_OLI, TEAM_NAME]
    );
    return created.rows[0].id;
}

/** Retrouve le compte du client : par son identifiant, sinon par son numéro. */
async function findCustomerId(client, request) {
    if (request.user_id > 0) {
        const { rows } = await client.query(
            'SELECT id FROM users WHERE id = $1 AND deleted_at IS NULL',
            [request.user_id]
        );
        if (rows.length) return rows[0].id;
    }
    if (request.user_phone) {
        const { rows } = await client.query(
            'SELECT id FROM users WHERE phone = $1 AND deleted_at IS NULL',
            [request.user_phone]
        );
        if (rows.length) return rows[0].id;
    }
    return null;
}

/** Une seule conversation Market Chat par client avec l'équipe. */
async function getTeamConversationId(client, teamId, customerId) {
    const found = await client.query(
        `SELECT c.id FROM conversations c
         JOIN conversation_participants a ON a.conversation_id = c.id AND a.user_id = $1
         JOIN conversation_participants b ON b.conversation_id = c.id AND b.user_id = $2
         WHERE c.is_market = TRUE LIMIT 1`,
        [teamId, customerId]
    );
    if (found.rows.length) return found.rows[0].id;

    const created = await client.query(
        `INSERT INTO conversations (type, is_market, created_at, updated_at)
         VALUES ('private', TRUE, NOW(), NOW()) RETURNING id`
    );
    const conversationId = created.rows[0].id;
    await client.query(
        `INSERT INTO conversation_participants (conversation_id, user_id, joined_at)
         VALUES ($1, $2, NOW()), ($1, $3, NOW())`,
        [conversationId, teamId, customerId]
    );
    return conversationId;
}

function buildMessage(request, response) {
    const description = (request.description || '').trim();
    if (!description) return `Réponse à votre demande :\n\n${response}`;
    const excerpt = description.length > 120 ? `${description.slice(0, 120)}…` : description;
    return `Votre demande : « ${excerpt} »\n\n${response}`;
}

/**
 * Écrit la réponse dans Market Chat, dans la transaction de l'appelant.
 * Renvoie null si le demandeur n'a pas de compte Oli.
 */
async function deliverReply(client, request, response) {
    const customerId = await findCustomerId(client, request);
    if (!customerId) return null;

    // Évite deux conversations si deux administrateurs répondent en même temps.
    await client.query(`SELECT pg_advisory_xact_lock(hashtext('oli_team_market'), $1)`, [customerId]);

    const teamId = await getTeamAccountId(client);
    const conversationId = await getTeamConversationId(client, teamId, customerId);
    const { rows } = await client.query(
        `INSERT INTO messages (conversation_id, sender_id, content, type, metadata)
         VALUES ($1, $2, $3, 'text', $4) RETURNING *`,
        [conversationId, teamId, buildMessage(request, response), JSON.stringify({ product_request_id: request.id })]
    );
    await client.query('UPDATE conversations SET updated_at = NOW() WHERE id = $1', [conversationId]);

    return { customerId, teamId, conversationId, message: rows[0] };
}

/** Prévient le client en direct. Appelé après validation de la transaction. */
function notifyCustomer(io, delivery) {
    const { customerId, teamId, conversationId, message } = delivery;
    if (io) {
        io.to(`user_${customerId}`).emit('new_message', {
            ...message,
            conversation_id: conversationId,
            sender_id: teamId,
            sender_name: TEAM_NAME,
        });
    }
    require('./notification.service')
        .sendMessageNotification(customerId, TEAM_NAME, 'Réponse à votre demande de produit', io)
        .catch((err) => console.warn('⚠️ Notification de réponse non envoyée:', err.message));
}

module.exports = { deliverReply, notifyCustomer };
