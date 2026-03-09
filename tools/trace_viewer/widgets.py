"""
GUI widgets for the trace viewer.

StageCard: Renders a single trace section from its SectionDef.
PipelineView: Arranges StageCards by group using the section registry.
"""

import tkinter as tk
from tkinter import ttk

from sections import SectionDef, FieldDef, SECTION_REGISTRY, GROUP_COLUMNS, GROUP_ORDER
from theme import COLORS, FIELD_STYLES, FONTS


class StageCard(tk.LabelFrame):
    """A card that displays one trace section's fields."""

    def __init__(self, parent, section_def: SectionDef, on_seq_click=None):
        super().__init__(parent, text=section_def.label,
                         bg=COLORS["card_active"], fg=COLORS["header"],
                         font=FONTS["header"], bd=1, relief="groove",
                         padx=6, pady=4)
        self.section_def = section_def
        self.on_seq_click = on_seq_click
        self.value_labels: dict[str, tk.Label] = {}
        self._active = False

        for row, field in enumerate(section_def.fields):
            lbl = tk.Label(self, text=f"{field.label}:",
                           bg=COLORS["card_active"], fg=COLORS["label"],
                           font=FONTS["label"], anchor="w")
            lbl.grid(row=row, column=0, sticky="w", padx=(4, 8), pady=1)

            val = tk.Label(self, text="--",
                           bg=COLORS["card_active"],
                           fg=FIELD_STYLES.get(field.style, FIELD_STYLES["default"]),
                           font=FONTS["value"], anchor="w")
            val.grid(row=row, column=1, sticky="w", padx=(0, 4), pady=1)

            # Make seq fields clickable
            if field.style == "seq" and on_seq_click:
                val.configure(cursor="hand2")
                val.bind("<Button-1>", lambda e, f=field: self._handle_seq_click(f))

            self.value_labels[field.key] = val

        self.columnconfigure(1, weight=1)

    def _handle_seq_click(self, field: FieldDef):
        val = self.value_labels[field.key].cget("text")
        if val and val != "--" and self.on_seq_click:
            self.on_seq_click(val)

    def _pick_bg(self, data: dict) -> str:
        """Pick background color based on card state.

        - Red tint for DIU lanes when dispatched=1 or inst_valid=0
        """
        if self.section_def.key.startswith("diu_"):
            dispatched = data.get("dispatched")
            inst_valid = data.get("inst_valid")
            if dispatched == "1" or inst_valid == "0":
                return COLORS["card_diu_alert"]

        return COLORS["card_active"]

    def update(self, data: dict | None):
        """Update the card with new data. None means inactive."""
        self._active = data is not None

        if data is None:
            self._bg = COLORS["card_inactive"]
            self.configure(bg=self._bg, fg=COLORS["label"])
            for field in self.section_def.fields:
                lbl = self.value_labels[field.key]
                lbl.configure(text="--", bg=self._bg, fg=COLORS["label"])
            for widget in self.winfo_children():
                if isinstance(widget, tk.Label):
                    widget.configure(bg=self._bg)
        else:
            self._bg = self._pick_bg(data)
            self.configure(bg=self._bg, fg=COLORS["header"])
            for field in self.section_def.fields:
                lbl = self.value_labels[field.key]
                raw_val = data.get(field.key)
                if raw_val is None:
                    display = "--"
                    fg = COLORS["label"]
                else:
                    display = str(raw_val)
                    fg = FIELD_STYLES.get(field.style, FIELD_STYLES["default"])
                lbl.configure(text=display, bg=self._bg, fg=fg)
            for widget in self.winfo_children():
                if isinstance(widget, tk.Label) and widget not in self.value_labels.values():
                    widget.configure(bg=self._bg)

    def highlight_seq(self, seq_val: str | None):
        """Highlight fields that match the given seq value."""
        parent_bg = getattr(self, "_bg", COLORS["card_active"] if self._active else COLORS["card_inactive"])
        for field in self.section_def.fields:
            lbl = self.value_labels[field.key]
            if field.style == "seq" and seq_val and lbl.cget("text") == seq_val:
                lbl.configure(bg=COLORS["highlight"])
            else:
                lbl.configure(bg=parent_bg)


class CommitCard(tk.LabelFrame):
    """Special card for committed instructions (variable number of entries)."""

    def __init__(self, parent):
        super().__init__(parent, text="Committed Instructions",
                         bg=COLORS["card_active"], fg=COLORS["header"],
                         font=FONTS["header"], bd=1, relief="groove",
                         padx=6, pady=4)
        self.entries_label = tk.Label(self, text="--",
                                      bg=COLORS["card_active"],
                                      fg=FIELD_STYLES["inst"],
                                      font=FONTS["value"],
                                      anchor="w", justify="left")
        self.entries_label.pack(fill="x", expand=True)

    def update(self, commit_data: list[dict] | None):
        if not commit_data:
            self.entries_label.configure(text="(none)", fg=COLORS["label"])
            self.configure(bg=COLORS["card_inactive"])
            self.entries_label.configure(bg=COLORS["card_inactive"])
            return

        self.configure(bg=COLORS["card_active"])
        self.entries_label.configure(bg=COLORS["card_active"])

        lines = []
        for entry in commit_data:
            pc = entry.get("pc", "?")
            seq = entry.get("seq", "?")
            wdata = entry.get("wdata")
            waddr = entry.get("waddr")
            if wdata and waddr is not None:
                lines.append(f"[{seq}] 0x{pc}: 0x{wdata} -> R[{waddr}]")
            else:
                lines.append(f"[{seq}] 0x{pc}:")
        self.entries_label.configure(text="\n".join(lines),
                                     fg=FIELD_STYLES["inst"])


class PipelineView(ttk.Frame):
    """Arranges StageCards by group, auto-generated from the section registry."""

    def __init__(self, parent, on_seq_click=None):
        super().__init__(parent, style="TFrame")
        self.cards: dict[str, StageCard] = {}
        self.commit_card: CommitCard | None = None
        self.on_seq_click = on_seq_click

        # Build groups from registry
        groups: dict[str, list[SectionDef]] = {}
        for sec in SECTION_REGISTRY:
            groups.setdefault(sec.group, []).append(sec)

        # Sort sections within each group
        for g in groups:
            groups[g].sort(key=lambda s: s.group_order)

        # Create scrollable canvas
        self.canvas = tk.Canvas(self, bg=COLORS["bg"], highlightthickness=0)
        self.scrollbar = ttk.Scrollbar(self, orient="vertical",
                                        command=self.canvas.yview)
        self.scroll_frame = ttk.Frame(self.canvas, style="TFrame")

        self.scroll_frame.bind("<Configure>",
            lambda e: self.canvas.configure(scrollregion=self.canvas.bbox("all")))

        self.canvas_window = self.canvas.create_window((0, 0),
            window=self.scroll_frame, anchor="nw")

        self.canvas.configure(yscrollcommand=self.scrollbar.set)

        self.canvas.pack(side="left", fill="both", expand=True)
        self.scrollbar.pack(side="right", fill="y")

        # Bind canvas resize to stretch the inner frame
        self.canvas.bind("<Configure>", self._on_canvas_configure)

        # Bind mousewheel
        self.canvas.bind_all("<MouseWheel>",
            lambda e: self.canvas.yview_scroll(int(-1*(e.delta/120)), "units"))
        self.canvas.bind_all("<Button-4>",
            lambda e: self.canvas.yview_scroll(-1, "units"))
        self.canvas.bind_all("<Button-5>",
            lambda e: self.canvas.yview_scroll(1, "units"))

        # Create group frames
        group_row = 0
        for group_name in GROUP_ORDER:
            if group_name not in groups:
                continue

            sections = groups[group_name]
            cols = GROUP_COLUMNS.get(group_name, 2)

            # Group header
            header = tk.Label(self.scroll_frame, text=group_name,
                              bg=COLORS["bg"], fg=COLORS["header"],
                              font=FONTS["title"], anchor="w")
            header.grid(row=group_row, column=0, columnspan=cols,
                       sticky="w", padx=8, pady=(12, 4))
            group_row += 1

            # Special case: commit section
            if group_name == "Committed Instructions":
                self.commit_card = CommitCard(self.scroll_frame)
                self.commit_card.grid(row=group_row, column=0, columnspan=cols,
                                      sticky="ew", padx=8, pady=2)
                group_row += 1
                continue

            # Create cards in grid
            for i, sec in enumerate(sections):
                row = group_row + i // cols
                col = i % cols

                card = StageCard(self.scroll_frame, sec,
                                on_seq_click=on_seq_click)
                card.grid(row=row, column=col, sticky="nsew",
                         padx=4, pady=2)
                self.cards[sec.key] = card

            # Configure column weights
            for c in range(cols):
                self.scroll_frame.columnconfigure(c, weight=1)

            rows_used = (len(sections) + cols - 1) // cols
            group_row += rows_used

    def _on_canvas_configure(self, event):
        self.canvas.itemconfig(self.canvas_window, width=event.width)

    def update(self, cycle_data: dict):
        """Update all cards with the given cycle data."""
        for key, card in self.cards.items():
            card.update(cycle_data.get(key))

        if self.commit_card:
            self.commit_card.update(cycle_data.get("commit"))

    def highlight_seq(self, seq_val: str | None):
        """Highlight a seq num across all cards."""
        for card in self.cards.values():
            card.highlight_seq(seq_val)
