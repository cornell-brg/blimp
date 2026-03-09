"""
Section registry for the trace viewer.

To add a new module trace to the viewer:
1. Add trace_json() to the SV module
2. Add one concatenation line in BlimpV11.v
3. Add one SectionDef(...) entry to SECTION_REGISTRY below
"""

from dataclasses import dataclass, field


@dataclass
class FieldDef:
    """Definition of a single field within a trace section."""
    key: str            # JSON field name
    label: str          # Display label
    style: str = "default"  # "addr", "data", "seq", "op", "inst", "bool"


@dataclass
class SectionDef:
    """Definition of a trace section (one card in the GUI)."""
    key: str                    # JSON key in cycle data
    label: str                  # Display name
    group: str                  # Layout group name
    fields: list[FieldDef]      # Ordered list of fields
    group_order: int = 0        # Ordering within the group


# ======================================================================
# Section Registry
# ======================================================================
# Add new sections here. The GUI auto-generates cards from this list.

SECTION_REGISTRY: list[SectionDef] = [

    # ------------------------------------------------------------------
    # Memory Interfaces
    # ------------------------------------------------------------------

    SectionDef("imem_req", "IMEM Req", "Memory Interfaces", [
        FieldDef("op",   "Op",   style="op"),
        FieldDef("addr", "Addr", style="addr"),
        FieldDef("data", "Data", style="data"),
    ], group_order=0),

    SectionDef("imem_resp", "IMEM Resp", "Memory Interfaces", [
        FieldDef("op",   "Op",   style="op"),
        FieldDef("addr", "Addr", style="addr"),
        FieldDef("data", "Data", style="data"),
    ], group_order=1),

    SectionDef("dmem_req", "DMEM Req", "Memory Interfaces", [
        FieldDef("op",   "Op",   style="op"),
        FieldDef("addr", "Addr", style="addr"),
        FieldDef("data", "Data", style="data"),
    ], group_order=2),

    SectionDef("dmem_resp", "DMEM Resp", "Memory Interfaces", [
        FieldDef("op",   "Op",   style="op"),
        FieldDef("addr", "Addr", style="addr"),
        FieldDef("data", "Data", style="data"),
    ], group_order=3),

    # ------------------------------------------------------------------
    # Fetch Unit
    # ------------------------------------------------------------------

    SectionDef("fu", "Fetch Unit", "Fetch", [
        FieldDef("req_addr",  "Req Addr",  style="addr"),
        FieldDef("resp_addr", "Resp Addr", style="addr"),
        FieldDef("seqs",      "Seq Nums",  style="seq"),
        FieldDef("squash",    "Squash",    style="bool"),
        FieldDef("in_flight", "In Flight", style="data"),
    ]),

    # ------------------------------------------------------------------
    # Decode / Issue Unit (one per frontend lane)
    # ------------------------------------------------------------------

    SectionDef("diu_0", "DIU Lane 0", "Decode / Issue", [
        FieldDef("seq",        "Seq",       style="seq"),
        FieldDef("inst",       "Inst",      style="inst"),
        FieldDef("dispatched", "Dispatched", style="bool"),
        FieldDef("inst_valid", "Inst Valid", style="bool"),
    ], group_order=0),

    SectionDef("diu_1", "DIU Lane 1", "Decode / Issue", [
        FieldDef("seq",        "Seq",       style="seq"),
        FieldDef("inst",       "Inst",      style="inst"),
        FieldDef("dispatched", "Dispatched", style="bool"),
        FieldDef("inst_valid", "Inst Valid", style="bool"),
    ], group_order=1),

    SectionDef("diu_2", "DIU Lane 2", "Decode / Issue", [
        FieldDef("seq",        "Seq",       style="seq"),
        FieldDef("inst",       "Inst",      style="inst"),
        FieldDef("dispatched", "Dispatched", style="bool"),
        FieldDef("inst_valid", "Inst Valid", style="bool"),
    ], group_order=2),

    SectionDef("diu_3", "DIU Lane 3", "Decode / Issue", [
        FieldDef("seq",        "Seq",       style="seq"),
        FieldDef("inst",       "Inst",      style="inst"),
        FieldDef("dispatched", "Dispatched", style="bool"),
        FieldDef("inst_valid", "Inst Valid", style="bool"),
    ], group_order=3),

    # ------------------------------------------------------------------
    # Execute Units - ALU
    # ------------------------------------------------------------------

    SectionDef("alu_0", "ALU 0", "Execute", [
        FieldDef("seq",   "Seq",   style="seq"),
        FieldDef("uop",   "UOp",   style="op"),
        FieldDef("waddr", "WAddr", style="addr"),
        FieldDef("op1",   "Op1",   style="data"),
        FieldDef("op2",   "Op2",   style="data"),
        FieldDef("wdata", "WData", style="data"),
    ], group_order=0),

    SectionDef("alu_1", "ALU 1", "Execute", [
        FieldDef("seq",   "Seq",   style="seq"),
        FieldDef("uop",   "UOp",   style="op"),
        FieldDef("waddr", "WAddr", style="addr"),
        FieldDef("op1",   "Op1",   style="data"),
        FieldDef("op2",   "Op2",   style="data"),
        FieldDef("wdata", "WData", style="data"),
    ], group_order=1),

    SectionDef("alu_2", "ALU 2", "Execute", [
        FieldDef("seq",   "Seq",   style="seq"),
        FieldDef("uop",   "UOp",   style="op"),
        FieldDef("waddr", "WAddr", style="addr"),
        FieldDef("op1",   "Op1",   style="data"),
        FieldDef("op2",   "Op2",   style="data"),
        FieldDef("wdata", "WData", style="data"),
    ], group_order=2),

    SectionDef("alu_3", "ALU 3", "Execute", [
        FieldDef("seq",   "Seq",   style="seq"),
        FieldDef("uop",   "UOp",   style="op"),
        FieldDef("waddr", "WAddr", style="addr"),
        FieldDef("op1",   "Op1",   style="data"),
        FieldDef("op2",   "Op2",   style="data"),
        FieldDef("wdata", "WData", style="data"),
    ], group_order=3),

    # ------------------------------------------------------------------
    # Execute Units - Multiplier / Divider
    # ------------------------------------------------------------------

    SectionDef("mul_0", "MUL 0", "Execute", [
        FieldDef("seq",          "Seq",     style="seq"),
        FieldDef("state",        "State",   style="op"),
        FieldDef("sign_restore", "SignRes", style="data"),
        FieldDef("waddr",        "WAddr",   style="addr"),
        FieldDef("opa",          "OpA",     style="data"),
        FieldDef("opb",          "OpB",     style="data"),
        FieldDef("result",       "Result",  style="data"),
    ], group_order=4),

    SectionDef("mul_1", "MUL 1", "Execute", [
        FieldDef("seq",          "Seq",     style="seq"),
        FieldDef("state",        "State",   style="op"),
        FieldDef("sign_restore", "SignRes", style="data"),
        FieldDef("waddr",        "WAddr",   style="addr"),
        FieldDef("opa",          "OpA",     style="data"),
        FieldDef("opb",          "OpB",     style="data"),
        FieldDef("result",       "Result",  style="data"),
    ], group_order=5),

    # ------------------------------------------------------------------
    # Execute Units - Memory
    # ------------------------------------------------------------------

    SectionDef("mem_xu", "Memory Unit", "Execute", [
        FieldDef("req_uop",   "Req UOp",   style="op"),
        FieldDef("req_seq",   "Req Seq",   style="seq"),
        FieldDef("req_addr",  "Req Addr",  style="addr"),
        FieldDef("req_data",  "Req Data",  style="data"),
        FieldDef("resp_uop",  "Resp UOp",  style="op"),
        FieldDef("resp_seq",  "Resp Seq",  style="seq"),
        FieldDef("resp_addr", "Resp Addr", style="addr"),
        FieldDef("resp_data", "Resp Data", style="data"),
    ], group_order=6),

    # ------------------------------------------------------------------
    # Execute Units - Control Flow
    # ------------------------------------------------------------------

    SectionDef("ctrl", "Control Flow", "Execute", [
        FieldDef("uop",    "UOp",    style="op"),
        FieldDef("seq",    "Seq",    style="seq"),
        FieldDef("waddr",  "WAddr",  style="addr"),
        FieldDef("wdata",  "WData",  style="data"),
        FieldDef("branch", "Branch", style="bool"),
        FieldDef("target", "Target", style="addr"),
    ], group_order=7),

    # ------------------------------------------------------------------
    # Squash Unit
    # ------------------------------------------------------------------

    SectionDef("squash", "Squash Unit", "Squash", [
        FieldDef("seq",    "Seq",    style="seq"),
        FieldDef("target", "Target", style="addr"),
    ]),

    # ------------------------------------------------------------------
    # Writeback / Commit Unit (one per backend lane)
    # ------------------------------------------------------------------

    SectionDef("wcu_0", "WCU Lane 0", "Writeback / Commit", [
        FieldDef("seq",   "Seq",   style="seq"),
        FieldDef("wen",   "WEn",   style="bool"),
        FieldDef("waddr", "WAddr", style="addr"),
        FieldDef("wdata", "WData", style="data"),
    ], group_order=0),

    SectionDef("wcu_1", "WCU Lane 1", "Writeback / Commit", [
        FieldDef("seq",   "Seq",   style="seq"),
        FieldDef("wen",   "WEn",   style="bool"),
        FieldDef("waddr", "WAddr", style="addr"),
        FieldDef("wdata", "WData", style="data"),
    ], group_order=1),

    SectionDef("wcu_2", "WCU Lane 2", "Writeback / Commit", [
        FieldDef("seq",   "Seq",   style="seq"),
        FieldDef("wen",   "WEn",   style="bool"),
        FieldDef("waddr", "WAddr", style="addr"),
        FieldDef("wdata", "WData", style="data"),
    ], group_order=2),

    SectionDef("wcu_3", "WCU Lane 3", "Writeback / Commit", [
        FieldDef("seq",   "Seq",   style="seq"),
        FieldDef("wen",   "WEn",   style="bool"),
        FieldDef("waddr", "WAddr", style="addr"),
        FieldDef("wdata", "WData", style="data"),
    ], group_order=3),

    # ------------------------------------------------------------------
    # Committed Instructions
    # ------------------------------------------------------------------

    SectionDef("commit", "Committed", "Committed Instructions", [
        FieldDef("entries", "Entries", style="inst"),
    ]),
]

# Group layout configuration: how many columns per group
GROUP_COLUMNS: dict[str, int] = {
    "Memory Interfaces":    4,
    "Fetch":                1,
    "Decode / Issue":       4,
    "Execute":              4,
    "Squash":               1,
    "Writeback / Commit":   4,
    "Committed Instructions": 1,
}

# Ordered list of groups for layout
GROUP_ORDER: list[str] = [
    "Memory Interfaces",
    "Fetch",
    "Decode / Issue",
    "Execute",
    "Squash",
    "Writeback / Commit",
    "Committed Instructions",
]
