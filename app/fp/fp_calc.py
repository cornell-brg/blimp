# fp_calc.py
# IEEE-754 single precision hex calculator

import struct

def hex_to_float(h):
    h = h.lower().replace("0x", "")
    return struct.unpack('!f', bytes.fromhex(h))[0]

def float_to_hex(f):
    return hex(struct.unpack('!I', struct.pack('!f', f))[0])

print("Floating-Point Hex Calculator (IEEE-754 Single Precision)")
print("Type 'exit' to quit.\n")

while True:
    op = input("Enter operation (FADD/FSUB): ").strip().upper()
    if op == "EXIT":
        break

    if op not in ["FADD", "FSUB"]:
        print("Invalid op! Use FADD or FSUB.\n")
        continue

    a_hex = input("Enter operand A (in hex): ").strip()
    if a_hex.lower() == "exit":
        break

    b_hex = input("Enter operand B (in hex): ").strip()
    if b_hex.lower() == "exit":
        break

    try:
        a_val = hex_to_float(a_hex)
        b_val = hex_to_float(b_hex)
    except:
        print("Error: invalid hex input!\n")
        continue

    result_val = a_val + b_val if op == "FADD" else a_val - b_val
    result_hex = float_to_hex(result_val)

    print(f"\nResult:")
    print(f"  A         = {a_hex} ({a_val})")
    print(f"  B         = {b_hex} ({b_val})")
    print(f"  Operation = {op}")
    print(f"  Float     = {result_val}")
    print(f"  Hex       = {result_hex}\n")