const dgram = require('dgram');

/**
 * TIS RMS UDP LAN Discovery Beacon Service
 * Listens on UDP port 18485 for incoming client broadcast queries ('TIS_RMS_DISCOVER').
 * Immediately responds with server identification and HTTP API port so clients
 * on the same local network (LAN / Wi-Fi) discover the server in <50ms without manual scanning.
 */

let socket = null;
const DEFAULT_DISCOVERY_PORT = 18485;

function startDiscoveryBeacon(apiPort = 18484) {
    if (socket) {
        return;
    }

    const discoveryPort = parseInt(process.env.DISCOVERY_PORT || DEFAULT_DISCOVERY_PORT, 10);

    try {
        socket = dgram.createSocket({ type: 'udp4', reuseAddr: true });

        socket.on('error', (err) => {
            console.warn(`[Discovery] UDP beacon socket error: ${err.message}`);
            try {
                socket.close();
            } catch (_) {}
            socket = null;
        });

        socket.on('message', (msg, rinfo) => {
            try {
                const messageStr = msg.toString().trim();
                if (messageStr.includes('TIS_RMS_DISCOVER')) {
                    const payload = JSON.stringify({
                        service: 'TIS_RMS_SERVER',
                        port: apiPort,
                        version: '1.0.0',
                        name: 'TIS RMS Server'
                    });

                    socket.send(payload, rinfo.port, rinfo.address, (err) => {
                        if (err) {
                            console.warn(`[Discovery] Failed to respond to ${rinfo.address}:${rinfo.port}: ${err.message}`);
                        } else {
                            console.log(`[Discovery] Responded to discovery probe from ${rinfo.address}:${rinfo.port}`);
                        }
                    });
                }
            } catch (err) {
                console.warn(`[Discovery] Error handling message: ${err.message}`);
            }
        });

        socket.bind(discoveryPort, '0.0.0.0', () => {
            try {
                socket.setBroadcast(true);
            } catch (_) {}
            console.log(`[Discovery] LAN UDP discovery beacon active on port ${discoveryPort} (0.0.0.0)`);
        });
    } catch (err) {
        console.warn(`[Discovery] Could not initialize UDP discovery beacon: ${err.message}`);
        socket = null;
    }
}

function stopDiscoveryBeacon() {
    if (socket) {
        try {
            socket.close();
        } catch (_) {}
        socket = null;
    }
}

module.exports = {
    startDiscoveryBeacon,
    stopDiscoveryBeacon
};
