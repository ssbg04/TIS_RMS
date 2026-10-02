const { Server } = require('socket.io');
const jwt = require('jsonwebtoken');

let io = null;

/**
 * Initializes Socket.IO on the given HTTP server.
 * Supports both WebSocket and polling transports with open CORS for LAN and Cloudflare tunnel clients.
 */
function initSocket(httpServer) {
    io = new Server(httpServer, {
        cors: {
            origin: '*',
            methods: ['GET', 'POST'],
            credentials: true,
        },
        transports: ['websocket', 'polling'],
        allowEIO3: true,
    });

    // Optional auth middleware: verifies JWT if supplied, but does not block connection
    io.use((socket, next) => {
        const token =
            socket.handshake.auth?.token ||
            socket.handshake.headers?.authorization?.replace(/^Bearer\s+/i, '');

        if (token) {
            try {
                const secret = process.env.JWT_SECRET || 'tis-rms-jwt-secret-key-development';
                const decoded = jwt.verify(token, secret);
                socket.user = decoded;
            } catch (err) {
                console.warn(`[Socket.IO] Token verification notice for socket ${socket.id}: ${err.message}`);
            }
        }
        next();
    });

    io.on('connection', (socket) => {
        const userDesc = socket.user ? `@${socket.user.username} (${socket.user.role})` : 'client';
        console.log(`[Socket.IO] Client connected: ${socket.id} [${userDesc}]`);

        socket.on('disconnect', (reason) => {
            console.log(`[Socket.IO] Client disconnected: ${socket.id} [${reason}]`);
        });
    });

    console.log('[Socket.IO] Real-time WebSocket server initialized successfully.');
    return io;
}

function getIO() {
    return io;
}

function broadcastEvent(eventName, payload) {
    if (!io) return;
    try {
        io.emit(eventName, payload);
    } catch (err) {
        console.error(`[Socket.IO] Failed to emit "${eventName}":`, err.message);
    }
}

// Real-Time Student Event Emitters
function emitStudentAdded(data) {
    broadcastEvent('student_added', data);
}

function emitStudentUpdated(data) {
    broadcastEvent('student_updated', data);
}

function emitStudentDeleted(data) {
    broadcastEvent('student_deleted', data);
}

// Real-Time Notification & Document Emitters
function emitNotificationCreated(data) {
    broadcastEvent('notification_created', data);
}

function emitDocumentChanged(data) {
    broadcastEvent('document_changed', data);
}

module.exports = {
    initSocket,
    getIO,
    broadcastEvent,
    emitStudentAdded,
    emitStudentUpdated,
    emitStudentDeleted,
    emitNotificationCreated,
    emitDocumentChanged,
};
