import serial
import struct
import time

# ============================================================================
# CẤU HÌNH
# ============================================================================
COM_PORT = 'COM6'
BAUD_RATE = 115200

# ============================================================================
# 6 FEATURES - Mỗi feature là 64-bit (8 bytes) double precision
# ============================================================================
# Feature order: arb_id_dec, data_length, first_byte, last_byte, byte_sum, time_delta
features = {
    'arb_id_dec': 844.0,       # Arbitration ID (decimal)
    'data_length': 8.0,        # Data length
    'first_byte': 0xF2,        # First byte of data (242)
    'last_byte': 0xA0,         # Last byte of data (160)
    'byte_sum': 879.0,         # Sum of all bytes
    'time_delta': 0.0          # Time delta (0 microseconds)
}

# ============================================================================
# VÍ DỤ: TẠO FEATURES TỪ BINARY STRING (NẾU CẦN)
# ============================================================================
# Nếu bạn có binary string cho tất cả 6 features (384 bits = 48 bytes):
# binary_str = "..." # 384 bits
# binary_str = binary_str.ljust(384, '0')
# 
# # Chuyển sang bytes
# data_bytes = bytearray()
# for i in range(0, 384, 8):
#     byte_str = binary_str[i:i+8]
#     data_bytes.append(int(byte_str, 2))

# ============================================================================
# CHUYỂN FEATURES SANG 48 BYTES (6 features × 8 bytes)
# ============================================================================
def features_to_bytes(feat_dict):
    """
    Convert 6 features to 48 bytes
    Each feature is 64-bit double (big-endian)
    """
    data_bytes = bytearray()
    
    # Order must match FPGA: arb_id_dec, data_length, first_byte, last_byte, byte_sum, time_delta
    feature_order = [
        'arb_id_dec',
        'data_length', 
        'first_byte',
        'last_byte',
        'byte_sum',
        'time_delta'
    ]
    
    for feature_name in feature_order:
        value = feat_dict[feature_name]
        # Pack as 64-bit double, big-endian ('>d')
        byte_data = struct.pack('>d', value)
        data_bytes.extend(byte_data)
    
    return bytes(data_bytes)

# ============================================================================
# TẠO DATA 48 BYTES
# ============================================================================
data_bytes = features_to_bytes(features)

print("=" * 70)
print(f"UART SENDER - 6 Features (48 Bytes)")
print("=" * 70)
print(f"\nFeature values:")
for name, value in features.items():
    print(f"  {name:15s} = {value}")

print(f"\nTotal bytes: {len(data_bytes)}")
print("\nHex data (48 bytes):")
for i in range(0, len(data_bytes), 8):
    chunk = data_bytes[i:i+8]
    hex_str = ' '.join(f'{b:02X}' for b in chunk)
    print(f"  [{i:2d}-{i+7:2d}]: {hex_str}")

# ============================================================================
# GỬI QUA UART
# ============================================================================
try:
    print(f"\n{'=' * 70}")
    print(f"Opening {COM_PORT} @ {BAUD_RATE} baud...")
    ser = serial.Serial(COM_PORT, BAUD_RATE, timeout=1)
    time.sleep(0.1)  # Wait for port to stabilize
    
    # Gửi START marker
    print("\n[1] Sending START marker...")
    ser.write(b'START\n')
    time.sleep(0.05)
    
    # Gửi 48 bytes data
    print("[2] Sending 48 bytes of feature data...")
    ser.write(data_bytes)
    time.sleep(0.1)
    
    print("\n✅ Data sent successfully!")
    print(f"{'=' * 70}\n")
    
    ser.close()
    
except serial.SerialException as e:
    print(f"\n❌ Error: {e}")
    print(f"Make sure {COM_PORT} is available and not in use.\n")

except Exception as e:
    print(f"\n❌ Unexpected error: {e}\n")

# ============================================================================
# VÍ DỤ SỬ DỤNG VỚI BINARY STRING (OPTIONAL)
# ============================================================================
def send_from_binary_string(binary_str):
    """
    Alternative: Send data from a 384-bit binary string
    """
    # Pad to 384 bits (48 bytes)
    binary_str = binary_str.ljust(384, '0')
    
    # Convert to bytes
    data_bytes = bytearray()
    for i in range(0, 384, 8):
        byte_str = binary_str[i:i+8]
        data_bytes.append(int(byte_str, 2))
    
    return bytes(data_bytes)

# Example usage:
# binary_data = "00000000..." # Your 384-bit string
# data_bytes = send_from_binary_string(binary_data)
# ser.write(data_bytes)

# ============================================================================
# VÍ DỤ ĐỌC DỮ LIỆU TỪ FILE CSV/JSON (OPTIONAL)
# ============================================================================
def load_features_from_csv(filename):
    """
    Load features from CSV file
    CSV format: arb_id_dec,data_length,first_byte,last_byte,byte_sum,time_delta
    """
    import csv
    
    with open(filename, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            features = {
                'arb_id_dec': float(row['arb_id_dec']),
                'data_length': float(row['data_length']),
                'first_byte': float(row['first_byte']),
                'last_byte': float(row['last_byte']),
                'byte_sum': float(row['byte_sum']),
                'time_delta': float(row['time_delta'])
            }
            yield features

# Example:
# for feature_set in load_features_from_csv('test_data.csv'):
#     data = features_to_bytes(feature_set)
#     ser.write(b'START\n')
#     ser.write(data)
#     time.sleep(1)  # Wait for processing