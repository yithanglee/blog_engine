# ESP32 A7670C HTTP Integration Test Guide

## Overview
This guide helps you test the A7670C cellular module integration with your Phoenix backend.

## Prerequisites
1. ESP32 with A7670C module connected (pins 16/17)
2. Active SIM card with data plan (Celcom recommended)
3. Phoenix server running with new A7670C endpoints
4. Device registered in your database

## Testing Steps

### 1. Backend Server Test
First, verify your Phoenix server has the new endpoints:

```bash
# Start your Phoenix server
cd blog_engine
mix phx.server

# Check server logs for:
# [info] A7670C endpoints loaded
```

### 2. Manual API Testing
Test the endpoints manually using curl:

```bash
# Test device join
curl -X POST http://localhost:4060/iot/a7670c/join \
  -H "Content-Type: application/json" \
  -d '{"device_id":"00000000-0000-0000-1234-567890abcdef"}'

# Expected response:
# {"status":"ok","device_id":"...","settings":{...}}

# Test polling
curl http://localhost:4060/iot/a7670c/poll/00000000-0000-0000-1234-567890abcdef

# Expected response:
# {"device_id":"...","tasks":[],"commands":[],"timestamp":...}

# Test ping
curl -X POST http://localhost:4060/iot/a7670c/ping/00000000-0000-0000-1234-567890abcdef \
  -H "Content-Type: application/json" \
  -d '{}'

# Expected response:
# {"status":"pong","device_id":"...","timestamp":...}
```

### 3. ESP32 Configuration
Upload the modified `main3.ino` with these settings:

```cpp
// Enable A7670C mode
const bool SKIP_WIFI = true;

// Verify A7670C pins
const int A7670C_RX_PIN = 16;
const int A7670C_TX_PIN = 17;
```

### 4. Serial Monitor Testing
Monitor the ESP32 serial output for:

```
=== Device Starting Up ===
Skip WiFi Mode: Enabled (Using A7670C)

=== A7670C Mode Enabled ===
=== Initializing A7670C Module ===
🎯 Target Network: Celcom (50219)
📡 Technology: E-UTRAN (LTE)
🔗 APN: celcom3g

🔍 Checking A7670C module status...
✅ A7670C module responding
✅ SIM card ready
📡 Signal strength: XX/31

🎯 Selecting Celcom network...
✅ Successfully registered to Celcom network

🔗 Configuring APN settings...
✅ APN configured: celcom3g

🌐 Connecting to internet via A7670C...
✅ Internet connected! Local IP: XXX.XXX.XXX.XXX

=== A7670C HTTP Connection Details ===
Device ID: 00000000-0000-0000-XXXX-XXXXXXXXXXXX
A7670C Status: Connected

🔌 Connecting HTTP via A7670C...
✅ Device joined successfully
✅ HTTP connection established via A7670C
```

### 5. End-to-End Test
1. Send a command from your admin panel
2. Watch for HTTP polling in serial monitor:
```
📥 Received task via A7670C: start, reps: 5, pin: 5
📤 Task completion sent via A7670C
```

3. Check Phoenix logs for:
```
[info] A7670C device joined: 00000000-0000-0000-XXXX-XXXXXXXXXXXX
[info] Reading from A7670C device 00000000-0000-0000-XXXX-XXXXXXXXXXXX: %{...}
```

## Troubleshooting

### A7670C Not Responding
- Check power supply (3.3V-4.2V)
- Verify serial connections (pins 16/17)
- Ensure SIM card is inserted properly
- Check antenna connection

### Network Registration Failed
- Verify SIM card has active data plan
- Check signal strength (should be > 10)
- Try manual network scan
- Verify APN settings for your carrier

### HTTP Requests Failing
- Check internet connectivity with AT+HTTPINIT
- Verify server URL is accessible
- Check firewall settings
- Ensure Phoenix server is running on correct port

### Common AT Commands for Debugging
```
AT+CSQ          // Check signal strength
AT+COPS?        // Check current network
AT+CGPADDR=1    // Check IP address
AT+HTTPINIT     // Test HTTP initialization
```

## Performance Notes
- HTTP polling every 5 seconds (configurable)
- Ping every 30 seconds
- Expect 2-5 second response times over cellular
- Data usage: ~1KB per poll cycle

## Integration Benefits
✅ **Dual Connectivity**: Supports both WiFi (WebSocket) and Cellular (HTTP)
✅ **Automatic Fallback**: Uses HTTP polling when WebSocket fails
✅ **Unified API**: Same backend handles both connection types
✅ **Device Tracking**: Monitors connection status and last seen
✅ **Task Queuing**: Queues commands for offline devices 