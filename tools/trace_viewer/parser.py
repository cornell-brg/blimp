"""
Trace file parser. Supports JSON format (primary) and legacy text format (fallback).
"""

import json
import re


def load_trace(path: str) -> list[dict]:
    """Load a trace file, auto-detecting format.

    Returns a list of cycle data dicts. For JSON format, each dict is the
    parsed JSON object. For text format, each dict is constructed from
    parsing the fixed-column text line.
    """
    with open(path, "r") as f:
        lines = [line.rstrip("\n") for line in f if line.strip()]

    if not lines:
        return []

    # Auto-detect: JSON lines start with '{'
    if lines[0].lstrip().startswith("{"):
        return _parse_json_lines(lines)
    else:
        return _parse_text_lines(lines)


def _parse_json_lines(lines: list[str]) -> list[dict]:
    """Parse JSON-line format (one JSON object per line)."""
    results = []
    for i, line in enumerate(lines):
        try:
            data = json.loads(line)
            results.append(data)
        except json.JSONDecodeError:
            # Skip malformed lines
            pass
    return results


# ======================================================================
# Legacy text format parser
# ======================================================================

def _parse_text_lines(lines: list[str]) -> list[dict]:
    """Parse legacy text trace format from BlimpV11_sim.v output."""
    results = []
    for cycle_num, line in enumerate(lines):
        data = _parse_text_line(line, cycle_num)
        results.append(data)
    return results


def _parse_text_line(line: str, cycle_num: int) -> dict:
    """Parse a single text trace line into a cycle data dict.

    Format: fl_imem || fl_dmem || dut_trace || inst_trace
    DUT trace: FU | DIU_0 | DIU_1 | DIU_2 | DIU_3 | ALU0 | ALU1 | ALU2 | ALU3 | MUL0 | MUL1 | MEM | CTRL | WCU
    """
    data = {"cycle": cycle_num}

    # Split on ' || ' for major sections
    major = line.split(" || ")
    if len(major) < 3:
        return data

    imem_str = major[0]
    dmem_str = major[1]
    dut_str = major[2]
    inst_str = major[3] if len(major) > 3 else ""

    # Parse memory interfaces
    _parse_mem_text(data, imem_str, "imem")
    _parse_mem_text(data, dmem_str, "dmem")

    # Split DUT trace on ' | ' — 14 subsections
    # FU, DIU_0, DIU_1, DIU_2, DIU_3, ALU0, ALU1, ALU2, ALU3, MUL0, MUL1, MEM, CTRL, WCU
    dut_parts = dut_str.split(" | ")

    if len(dut_parts) >= 14:
        data["fu"] = _parse_fu_text(dut_parts[0])

        for i in range(4):
            data[f"diu_{i}"] = _parse_diu_text(dut_parts[1 + i])

        for i in range(4):
            data[f"alu_{i}"] = _parse_alu_text(dut_parts[5 + i])

        for i in range(2):
            data[f"mul_{i}"] = _parse_mul_text(dut_parts[9 + i])

        data["mem_xu"] = _parse_mem_xu_text(dut_parts[11])
        data["ctrl"] = _parse_ctrl_text(dut_parts[12])

        # WCU: last part may contain multiple lanes separated by double-space
        _parse_wcu_text(data, dut_parts[13])

    # Parse committed instructions
    data["commit"] = _parse_commit_text(inst_str)

    return data


def _is_blank(s: str) -> bool:
    return s.strip() == ""


def _parse_mem_text(data: dict, s: str, prefix: str):
    """Parse 'op:opaq:addr:data > op:opaq:addr:data' format."""
    parts = s.split(" > ")
    for i, side in enumerate(["req", "resp"]):
        key = f"{prefix}_{side}"
        if i < len(parts) and not _is_blank(parts[i]):
            fields = parts[i].strip().split(":")
            if len(fields) >= 3:
                data[key] = {
                    "op": fields[0],
                    "addr": fields[2] if len(fields) > 2 else None,
                    "data": fields[3] if len(fields) > 3 else None,
                }
            else:
                data[key] = None
        else:
            data[key] = None


def _parse_fu_text(s: str) -> dict | None:
    """Parse 'req_addr > resp_addr squash seqs' format."""
    if _is_blank(s):
        return None
    parts = s.split(" > ")
    result = {}
    if len(parts) >= 1 and not _is_blank(parts[0]):
        result["req_addr"] = parts[0].strip()
    else:
        result["req_addr"] = None

    if len(parts) >= 2:
        rest = parts[1].strip()
        tokens = rest.split()
        if tokens:
            result["resp_addr"] = tokens[0]
            result["squash"] = len(tokens) > 1 and tokens[1] == "X"
            result["seqs"] = tokens[-1] if len(tokens) > 1 else None
        else:
            result["resp_addr"] = None
            result["squash"] = False
            result["seqs"] = None
    else:
        result["resp_addr"] = None
        result["squash"] = False
        result["seqs"] = None

    return result if any(v is not None and v is not False for v in result.values()) else None


def _parse_diu_text(s: str) -> dict | None:
    """Parse 'seq: disassembled_inst' format."""
    if _is_blank(s):
        return None
    s = s.strip()
    match = re.match(r'([0-9a-fA-F]+):\s*(.*)', s)
    if match:
        return {"seq": match.group(1), "inst": match.group(2).strip()}
    return None


def _parse_alu_text(s: str) -> dict | None:
    """Parse 'seq: UOP:waddr:op1:op2:wdata' format."""
    if _is_blank(s):
        return None
    s = s.strip()
    match = re.match(r'([0-9a-fA-F]+):\s*(.*)', s)
    if not match:
        return None
    seq = match.group(1)
    rest = match.group(2)
    fields = rest.split(":")
    if len(fields) >= 5:
        return {
            "seq": seq,
            "uop": fields[0].strip(),
            "waddr": fields[1],
            "op1": fields[2],
            "op2": fields[3],
            "wdata": fields[4],
        }
    return {"seq": seq}


def _parse_mul_text(s: str) -> dict | None:
    """Parse 'seq: state:sign:waddr:opa:opb:result' format."""
    if _is_blank(s):
        return None
    s = s.strip()
    match = re.match(r'([0-9a-fA-F]+):\s*(.*)', s)
    if not match:
        return None
    seq = match.group(1)
    rest = match.group(2)
    fields = rest.split(":")
    if len(fields) >= 6:
        return {
            "seq": seq,
            "state": fields[0].strip(),
            "sign_restore": fields[1],
            "waddr": fields[2],
            "opa": fields[3],
            "opb": fields[4],
            "result": fields[5],
        }
    elif len(fields) >= 1:
        return {"seq": seq, "state": fields[0].strip()}
    return {"seq": seq}


def _parse_mem_xu_text(s: str) -> dict | None:
    """Parse 'UOP:seq:addr:data > UOP:seq:addr:data' format."""
    if _is_blank(s):
        return None
    parts = s.split(" > ")
    result = {}
    for i, (side, prefix) in enumerate([("req", "req_"), ("resp", "resp_")]):
        if i < len(parts) and not _is_blank(parts[i]):
            fields = parts[i].strip().split(":")
            if len(fields) >= 4:
                result[f"{prefix}uop"] = fields[0].strip()
                result[f"{prefix}seq"] = fields[1]
                result[f"{prefix}addr"] = fields[2]
                result[f"{prefix}data"] = fields[3]
            else:
                for k in ["uop", "seq", "addr", "data"]:
                    result[f"{prefix}{k}"] = None
        else:
            for k in ["uop", "seq", "addr", "data"]:
                result[f"{prefix}{k}"] = None

    return result if any(v is not None for v in result.values()) else None


def _parse_ctrl_text(s: str) -> dict | None:
    """Parse 'UOP:seq:waddr:wdata' format."""
    if _is_blank(s):
        return None
    fields = s.strip().split(":")
    if len(fields) >= 4:
        return {
            "uop": fields[0].strip(),
            "seq": fields[1],
            "waddr": fields[2],
            "wdata": fields[3],
        }
    return None


def _parse_wcu_text(data: dict, s: str):
    """Parse 'seq:wen:waddr:wdata  seq:wen:waddr:wdata ...' format."""
    if _is_blank(s):
        for i in range(4):
            data[f"wcu_{i}"] = None
        return

    lanes = re.split(r'\s{2,}', s.strip())
    for i in range(4):
        if i < len(lanes) and not _is_blank(lanes[i]):
            fields = lanes[i].split(":")
            if len(fields) >= 4:
                data[f"wcu_{i}"] = {
                    "seq": fields[0],
                    "wen": fields[1],
                    "waddr": fields[2],
                    "wdata": fields[3],
                }
            else:
                data[f"wcu_{i}"] = None
        else:
            data[f"wcu_{i}"] = None


def _parse_commit_text(s: str) -> list[dict]:
    """Parse '0xPC: 0xDATA -> R[N]' entries."""
    if _is_blank(s):
        return []
    entries = []
    for match in re.finditer(r'0x([0-9a-fA-F]+):\s*(?:0x([0-9a-fA-F]+)\s*->\s*R\[(\d+)\])?', s):
        entry = {"pc": match.group(1)}
        if match.group(2):
            entry["wdata"] = match.group(2)
            entry["waddr"] = match.group(3)
        else:
            entry["wdata"] = None
            entry["waddr"] = None
        entries.append(entry)
    return entries
