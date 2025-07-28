# ESP32 HTTP Polling Implementation for 2G GSM

## Overview
This document shows how to implement HTTP polling on the ESP32 side to replace WebSocket connections for 2G GSM networks.

## Arduino Code Implementation

### 1. HTTP Polling Function (Replace WebSocket)

```cpp
// Replace WebSocket connection with HTTP polling
void startHTTPPolling() {
  Serial.println("📡 Starting HTTP polling for 2G GSM connection");
  
  // Set polling interval (3-5 seconds for 2G)
  unsigned long pollingInterval = 3000; // 3 seconds
  unsigned long lastPollTime = 0;
  
  while (true) {
    unsigned long currentTime = millis();
    
    if (currentTime - lastPollTime >= pollingInterval) {
      // Poll for tasks
      String response = pollForTasks();
      
      if (response.length() > 0) {
        processTaskResponse(response);
      }
      
      lastPollTime = currentTime;
    }
    
    // Handle other tasks (PWM readings, etc.)
    handleOtherTasks();
    
    delay(100); // Small delay to prevent tight loop
  }
}

// HTTP polling function
String pollForTasks() {
  String url = serverUrl + "/iot/poll/" + deviceName;
  
  // For simple polling
  String response = sendGSMHTTPRequest(url, "", "GET");
  
  if (response.length() > 0) {
    Serial.println("📨 Received tasks: " + response);
    return response;
  }
  
  return "";
}

// Alternative: Server-Sent Events (SSE) style streaming
void startSSEPolling() {
  Serial.println("📡 Starting SSE-style HTTP streaming");
  
  String url = serverUrl + "/iot/stream/" + deviceName;
  
  // Long-polling request (30 seconds timeout)
  String response = sendGSMHTTPRequest(url, "", "GET", 30000);
  
  if (response.length() > 0) {
    processSSEResponse(response);
  }
  
  // Restart polling after response or timeout
  startSSEPolling();
}

// Process task response
void processTaskResponse(String response) {
  // Parse JSON response
  StaticJsonDocument<1024> doc;
  DeserializationError error = deserializeJson(doc, response);
  
  if (error) {
    Serial.println("❌ JSON parsing failed");
    return;
  }
  
  // Check if tasks exist
  if (doc["tasks"].size() > 0) {
    Serial.println("🎯 Processing " + String(doc["tasks"].size()) + " tasks");
    
    // Process each task
    for (JsonVariant task : doc["tasks"].as<JsonArray>()) {
      String action = task["action"];
      String format = task["format"];
      int reps = task["reps"];
      float delay = task["delay"];
      int pin = task["pin"];
      String uuid = task["uuid"];
      
      Serial.println("▶️ Executing task: " + action + " with " + String(reps) + " reps");
      
      // Execute the task
      if (action == "start") {
        if (format == "pwm") {
          executePWMTask(pin, reps, delay, uuid);
        } else if (format == "motor") {
          executeMotorTask(pin, reps, delay, uuid);
        }
      }
      
      // Send completion notification
      sendTaskCompletion(uuid, action);
    }
  }
}

// Send task completion notification
void sendTaskCompletion(String uuid, String taskType) {
  String url = serverUrl + "/iot/complete/" + deviceName;
  
  StaticJsonDocument<200> doc;
  doc["uuid"] = uuid;
  doc["task_type"] = taskType;
  doc["status"] = "completed";
  doc["timestamp"] = millis();
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  String response = sendGSMHTTPRequest(url, jsonString, "POST");
  
  if (response.length() > 0) {
    Serial.println("✅ Task completion sent: " + uuid);
  }
}

// Enhanced HTTP request function for GSM
String sendGSMHTTPRequest(String url, String data, String method, int timeout = 10000) {
  String response = "";
  
  // Initialize HTTP service
  if (sendATCommand("AT+HTTPINIT").indexOf("OK") == -1) {
    Serial.println("❌ HTTP init failed");
    return response;
  }
  
  // Set HTTP parameters
  sendATCommand("AT+HTTPPARA=\"CID\",1");
  sendATCommand("AT+HTTPPARA=\"URL\",\"" + url + "\"");
  
  if (method == "POST") {
    sendATCommand("AT+HTTPPARA=\"CONTENT\",\"application/json\"");
    
    // Set data
    sendATCommand("AT+HTTPDATA=" + String(data.length()) + ",10000");
    delay(100);
    Serial.println(data);
    
    // Wait for DOWNLOAD response
    String downloadResponse = "";
    unsigned long startTime = millis();
    while (millis() - startTime < 10000) {
      if (Serial.available()) {
        downloadResponse += Serial.readString();
        if (downloadResponse.indexOf("DOWNLOAD") != -1) {
          break;
        }
      }
    }
    
    // Send POST request
    String postResponse = sendATCommand("AT+HTTPACTION=1", timeout);
    
    if (postResponse.indexOf("200") != -1) {
      // Get response
      String readResponse = sendATCommand("AT+HTTPREAD");
      
      // Parse response content
      int startIndex = readResponse.indexOf("\n") + 1;
      int endIndex = readResponse.indexOf("OK");
      
      if (startIndex > 0 && endIndex > startIndex) {
        response = readResponse.substring(startIndex, endIndex);
        response.trim();
      }
    }
  } else if (method == "GET") {
    // Send GET request
    String getResponse = sendATCommand("AT+HTTPACTION=0", timeout);
    
    if (getResponse.indexOf("200") != -1) {
      // Get response
      String readResponse = sendATCommand("AT+HTTPREAD");
      
      // Parse response content
      int startIndex = readResponse.indexOf("\n") + 1;
      int endIndex = readResponse.indexOf("OK");
      
      if (startIndex > 0 && endIndex > startIndex) {
        response = readResponse.substring(startIndex, endIndex);
        response.trim();
      }
    }
  }
  
  // Cleanup
  sendATCommand("AT+HTTPTERM");
  
  return response;
}
```

### 2. Main Loop Integration

```cpp
void loop() {
  // Handle serial commands
  if (Serial.available()) {
    handleSerialCommands();
  }
  
  // Manage connections
  manageConnections();
  
  // Use HTTP polling instead of WebSocket for GSM
  if (connectionManager.activeConnection == CONNECTION_GSM) {
    // HTTP polling for 2G GSM
    static unsigned long lastPollTime = 0;
    unsigned long currentTime = millis();
    
    if (currentTime - lastPollTime >= 3000) { // Poll every 3 seconds
      String response = pollForTasks();
      
      if (response.length() > 0) {
        processTaskResponse(response);
      }
      
      lastPollTime = currentTime;
    }
  } else {
    // WebSocket for WiFi (existing logic)
    webSocket.loop();
  }
  
  // Handle PWM readings and other tasks
  handlePWMReadings();
  handleBillAcceptor();
  
  delay(100);
}
```

### 3. Configuration Updates

```cpp
// Update configuration for HTTP polling
struct GSMConfig {
  String apn;
  String username;
  String password;
  String serverUrl;
  String deviceName;
  bool useHTTPPolling = true;  // Enable HTTP polling for 2G
  int pollingInterval = 3000;  // 3 seconds
  int httpTimeout = 10000;     // 10 seconds
  // ... other existing fields
};

// Update server URL configuration
void updateServerConfig() {
  if (connectionManager.activeConnection == CONNECTION_GSM) {
    // Use HTTP polling endpoints for GSM
    gsmConfig.serverUrl = "http://your-server.com";
  } else {
    // Use WebSocket endpoints for WiFi
    webSocketConfig.serverUrl = "ws://your-server.com";
  }
}
```

## Server-Side Endpoints

### 1. Simple Polling
- **GET** `/iot/poll/{device_id}` - Returns JSON with pending tasks
- **Response**: `{"device_id": "...", "tasks": [...], "timestamp": 123456}`

### 2. SSE-Style Streaming
- **GET** `/iot/stream/{device_id}` - Long-polling with chunked response
- **Response**: Server-Sent Events format with tasks

### 3. Task Completion
- **POST** `/iot/complete/{device_id}` - Mark tasks as completed
- **Body**: `{"uuid": "...", "task_type": "...", "status": "completed"}`

## Benefits of This Approach

1. **🔄 Reliability**: HTTP requests are more reliable on 2G networks
2. **📱 Compatibility**: Works with all GSM modules and networks
3. **🔋 Power Efficient**: Configurable polling intervals
4. **🛡️ Fallback**: Graceful degradation from WebSocket to HTTP
5. **📊 Logging**: Full task tracking and completion notifications

## Performance Characteristics

| Metric | HTTP Polling | WebSocket |
|--------|-------------|-----------|
| Latency | 3-5 seconds | 50-200ms |
| Reliability | High | Medium (2G) |
| Bandwidth | Low | Very Low |
| Battery | Medium | Low |
| Complexity | Low | High |

## Testing Commands

```bash
# Test polling endpoint
curl "http://your-server.com/iot/poll/device123"

# Test task completion
curl -X POST "http://your-server.com/iot/complete/device123" \
  -H "Content-Type: application/json" \
  -d '{"uuid":"abc123","task_type":"pwm","status":"completed"}'

# Test SSE streaming
curl "http://your-server.com/iot/stream/device123"
```

This implementation provides a robust HTTP polling solution that works reliably with 2G GSM connections while maintaining compatibility with existing WebSocket infrastructure for WiFi connections. 