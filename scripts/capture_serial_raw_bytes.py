import serial
import sys

port = sys.argv[1]
n = int(sys.argv[2])
with serial.Serial(port, 115200, timeout=5) as s:
  data = s.read(n)
open(sys.argv[3], "wb").write(data)
print(f"Wrote {len(data)} bytes to {sys.argv[3]}")
