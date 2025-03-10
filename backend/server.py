import asyncio
import websockets
import sys
import json
from collections import deque

# Set Windows-specific event loop policy if needed
if sys.platform.startswith('win'):
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

# Buffers with a fixed max length to prevent memory overflow
sensor1_values = deque(maxlen=30)
sensor2_values = deque(maxlen=30)

# Function to handle incoming WebSocket connections
async def data_stream(websocket, path):
    print("Client connected")
    try:
        async for message in websocket:
            print(f"Received: {message}")  # Debugging
            
            # Process JSON data safely
            try:
                data = json.loads(message)
                sensor1 = data.get("sensor1", 600)  # Default to 600 if missing
                sensor2 = data.get("sensor2", 600)

                sensor1_values.append(sensor1)
                sensor2_values.append(sensor2)

                response = f"{sensor1},{sensor2}"
                await websocket.send(response)

            except json.JSONDecodeError:
                print("Received malformed JSON data")
                continue  # Ignore and keep listening

    except websockets.ConnectionClosedError:
        print("WebSocket connection closed unexpectedly. Reconnecting...")

    except asyncio.CancelledError:
        print("Server task was cancelled")
        raise  # Allow clean shutdown

    finally:
        print("Client disconnected")


# Start the WebSocket server
async def start_server():
    server = await websockets.serve(data_stream, "0.0.0.0", 8000)
    print("Server started on ws://0.0.0.0:8000")
    await server.wait_closed()

if __name__ == "__main__":
    asyncio.run(start_server())
