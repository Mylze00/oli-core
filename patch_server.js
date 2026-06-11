const fs = require('fs');
const file = './src/server.js';
let content = fs.readFileSync(file, 'utf8');

content = content.replace(
  'const chatRoutes = require("./routes/chat.routes");\nconst shopsRoutes = require("./routes/shops.routes");',
  'const chatRoutes = require("./routes/chat.routes");\nconst callRoutes = require("./routes/call.routes");\nconst shopsRoutes = require("./routes/shops.routes");'
);

content = content.replace(
  'const oliSessionMiddleware = require("./middlewares/oli_session.middleware"); // 📊 Session Tracking\n\nconst app = express();',
  'const oliSessionMiddleware = require("./middlewares/oli_session.middleware"); // 📊 Session Tracking\nconst pool = require("./config/db");\n\nconst app = express();'
);

content = content.replace(
  'app.use("/chat", requireAuth, chatRoutes);\napp.use("/shops", shopsRoutes);',
  'app.use("/chat", requireAuth, chatRoutes);\napp.use("/calls", requireAuth, callRoutes);\napp.use("/shops", shopsRoutes);'
);

const newSocketHandlers = `    // ── 5. WEBRTC CALL SIGNALING ─────────────────────────────────────────
    socket.on('webrtc_call_initiate', async (data) => {
        const { toId, callerName, callerAvatar, type, conversationId } = data;
        if (!userId || !toId) return;
        const targetRoom = 'user_' + toId;

        try {
            await pool.query(
                \`INSERT INTO call_logs (caller_id, receiver_id, call_type, status, created_at) 
                 VALUES ($1, $2, $3, 'missed', NOW())\`,
                [userId, toId, type || 'audio']
            );
        } catch (e) {
            console.error('[CALL LOG] Insert error:', e.message);
        }

        // 1. Relayer via Socket.IO (si User B connecte)
        socket.to(targetRoom).emit('webrtc_call_incoming', {
            fromId: userId,
            callerName: callerName || 'Utilisateur OLI',
            callerAvatar: callerAvatar || '',
            type: type || 'audio',
            conversationId: conversationId || '',
        });

        // 2. FCM push si hors-ligne ou app fermee
        try {
            const fcmService = require('./services/fcm.service');
            await fcmService.sendCallNotification(parseInt(toId), {
                callerId: String(userId),
                callerName: callerName || 'Utilisateur OLI',
                callerAvatar: callerAvatar || '',
                callType: type || 'audio',
                conversationId: String(conversationId || ''),
            });
        } catch (fcmErr) {
            console.warn('[CALL FCM] Push ignore:', fcmErr.message);
        }
    });

    // ── 5.1 WEBRTC SIGNALING (SDP & ICE) ─────────────────────────────────
    socket.on('webrtc_offer', (data) => {
        if (!userId || !data.toId) return;
        socket.to('user_' + data.toId).emit('webrtc_offer', { fromId: userId, sdp: data.sdp });
    });

    socket.on('webrtc_answer', (data) => {
        if (!userId || !data.toId) return;
        socket.to('user_' + data.toId).emit('webrtc_answer', { fromId: userId, sdp: data.sdp });
    });

    socket.on('webrtc_ice_candidate', (data) => {
        if (!userId || !data.toId) return;
        socket.to('user_' + data.toId).emit('webrtc_ice_candidate', { fromId: userId, candidate: data.candidate });
    });

    async function updateCallStatus(callerId, receiverId, status, isEnded = false) {
        try {
            let setClause = \`status = $3\`;
            if (isEnded) {
                setClause += \`, ended_at = NOW()\`;
                if (status === 'answered') {
                   setClause += \`, duration_seconds = EXTRACT(EPOCH FROM (NOW() - created_at))\`;
                }
            }
            await pool.query(\`
                UPDATE call_logs 
                SET \${setClause}
                WHERE id = (
                    SELECT id FROM call_logs 
                    WHERE caller_id = $1 AND receiver_id = $2 
                    ORDER BY created_at DESC LIMIT 1
                )
            \`, [callerId, receiverId, status]);
        } catch (e) {
            console.error('[CALL LOG] Update error:', e.message);
        }
    }

    // Accepter l'appel
    socket.on('webrtc_call_accept', async (data) => {
        if (!userId || !data.callerId) return;
        await updateCallStatus(data.callerId, userId, 'answered', false);
        socket.to('user_' + data.callerId).emit('webrtc_call_accepted', { fromId: userId });
    });

    socket.on('webrtc_call_reject', async (data) => {
        if (!userId || !data.callerId) return;
        await updateCallStatus(data.callerId, userId, 'rejected', true);
        socket.to('user_' + data.callerId).emit('webrtc_call_rejected', { fromId: userId });
    });

    socket.on('webrtc_call_cancel', async (data) => {
        if (!userId || !data.toId) return;
        await updateCallStatus(userId, data.toId, 'cancelled', true);
        socket.to('user_' + data.toId).emit('webrtc_call_cancelled', { fromId: userId });
    });

    socket.on('webrtc_call_ended', async (data) => {
        if (!userId || !data.toId) return;
        await updateCallStatus(userId, data.toId, 'answered', true);
        await updateCallStatus(data.toId, userId, 'answered', true);
        socket.to('user_' + data.toId).emit('webrtc_call_ended', { fromId: userId });
    });`;

const oldSocketHandlers = content.substring(
    content.indexOf("    // ── 5. WEBRTC CALL SIGNALING ─────────────────────────────────────────"),
    content.indexOf("    socket.on('webrtc_call_missed', async (data) => {")
);

if (oldSocketHandlers && oldSocketHandlers.length > 100) {
    content = content.replace(oldSocketHandlers, newSocketHandlers + "\n\n");
    fs.writeFileSync(file, content);
    console.log("Patched server.js successfully");
} else {
    console.error("Could not find socket handlers block");
}
