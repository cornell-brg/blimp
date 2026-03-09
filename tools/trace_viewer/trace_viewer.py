#!/usr/bin/env python3
"""
Blimp Processor Trace Viewer

Usage:
    python trace_viewer.py [trace_file]

Supports both JSON trace format (+trace-json output) and legacy text format.
"""

import os
import sys
import tkinter as tk
from tkinter import ttk, filedialog, simpledialog

# Add script directory to path for local imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from parser import load_trace
from widgets import PipelineView
from theme import COLORS, FONTS, configure_styles


class TraceViewer(tk.Tk):
    """Main application window."""

    def __init__(self, trace_file: str | None = None):
        super().__init__()

        self.title("Blimp Trace Viewer")
        self.geometry("1400x900")
        self.configure(bg=COLORS["bg"])
        self.minsize(800, 600)

        # State
        self.cycles: list[dict] = []
        self.current_cycle: int = 0
        self.highlighted_seq: str | None = None
        self.trace_path: str = ""

        # Configure styles
        style = ttk.Style(self)
        configure_styles(style)

        # Build UI
        self._build_toolbar()
        self._build_pipeline_view()
        self._build_status_bar()
        self._bind_keys()

        # Load file if provided
        if trace_file:
            self._load_file(trace_file)

    # ------------------------------------------------------------------
    # UI Construction
    # ------------------------------------------------------------------

    def _build_toolbar(self):
        toolbar = tk.Frame(self, bg=COLORS["toolbar_bg"], pady=6, padx=8)
        toolbar.pack(fill="x", side="top")

        # Open button
        open_btn = tk.Button(toolbar, text="Open", command=self._open_file,
                             bg=COLORS["button_bg"], fg=COLORS["button_fg"],
                             font=FONTS["toolbar"], relief="flat", padx=8)
        open_btn.pack(side="left", padx=(0, 4))

        # Reload button
        reload_btn = tk.Button(toolbar, text="Reload", command=self._reload_file,
                               bg=COLORS["button_bg"], fg=COLORS["button_fg"],
                               font=FONTS["toolbar"], relief="flat", padx=8)
        reload_btn.pack(side="left", padx=(0, 12))

        # Cycle label
        cycle_label = tk.Label(toolbar, text="Cycle:",
                               bg=COLORS["toolbar_bg"], fg=COLORS["text"],
                               font=FONTS["toolbar"])
        cycle_label.pack(side="left")

        # Cycle entry
        self.cycle_var = tk.StringVar(value="0")
        self.cycle_entry = tk.Entry(toolbar, textvariable=self.cycle_var,
                                     width=8, bg=COLORS["entry_bg"],
                                     fg=COLORS["entry_fg"], font=FONTS["toolbar"],
                                     insertbackground=COLORS["text"],
                                     relief="flat", bd=2)
        self.cycle_entry.pack(side="left", padx=(4, 4))
        self.cycle_entry.bind("<Return>", self._on_cycle_entry)

        # Total label
        self.total_label = tk.Label(toolbar, text="/ 0",
                                     bg=COLORS["toolbar_bg"], fg=COLORS["label"],
                                     font=FONTS["toolbar"])
        self.total_label.pack(side="left", padx=(0, 12))

        # Navigation buttons
        nav_btns = [
            ("|<", lambda: self._go_prev(10)),
            ("<", self._go_prev),
            (">", self._go_next),
            (">|", lambda: self._go_next(10)),
        ]
        for text, cmd in nav_btns:
            btn = tk.Button(toolbar, text=text, command=cmd,
                           bg=COLORS["button_bg"], fg=COLORS["button_fg"],
                           font=FONTS["toolbar"], relief="flat",
                           width=3, padx=4)
            btn.pack(side="left", padx=1)

        # Slider
        self.slider_var = tk.IntVar(value=0)
        self.slider = tk.Scale(toolbar, from_=0, to=0,
                               orient="horizontal",
                               variable=self.slider_var,
                               command=self._on_slider,
                               bg=COLORS["toolbar_bg"],
                               fg=COLORS["text"],
                               troughcolor=COLORS["slider_trough"],
                               highlightthickness=0,
                               showvalue=False,
                               length=300)
        self.slider.pack(side="left", fill="x", expand=True, padx=12)

        # Search button
        search_btn = tk.Button(toolbar, text="Search", command=self._search,
                               bg=COLORS["button_bg"], fg=COLORS["button_fg"],
                               font=FONTS["toolbar"], relief="flat", padx=8)
        search_btn.pack(side="right")

    def _build_pipeline_view(self):
        self.pipeline_view = PipelineView(self,
                                           on_seq_click=self._on_seq_click)
        self.pipeline_view.pack(fill="both", expand=True, padx=4, pady=4)

    def _build_status_bar(self):
        self.status_bar = tk.Label(self, text="No file loaded",
                                    bg=COLORS["toolbar_bg"],
                                    fg=COLORS["label"],
                                    font=FONTS["toolbar"],
                                    anchor="w", padx=8, pady=4)
        self.status_bar.pack(fill="x", side="bottom")

    # ------------------------------------------------------------------
    # Key Bindings
    # ------------------------------------------------------------------

    def _bind_keys(self):
        self.bind("<Left>", lambda e: self._go_prev())
        self.bind("<Right>", lambda e: self._go_next())
        self.bind("<Prior>", lambda e: self._go_prev(10))  # Page Up
        self.bind("<Next>", lambda e: self._go_next(10))   # Page Down
        self.bind("<Home>", lambda e: self._go_first())
        self.bind("<End>", lambda e: self._go_last())
        self.bind("<Control-g>", lambda e: self._goto_cycle())
        self.bind("<Control-f>", lambda e: self._search())
        self.bind("<Control-o>", lambda e: self._open_file())
        self.bind("<Control-r>", lambda e: self._reload_file())
        self.bind("<Escape>", lambda e: self._clear_highlight())

    # ------------------------------------------------------------------
    # File Loading
    # ------------------------------------------------------------------

    def _open_file(self):
        path = filedialog.askopenfilename(
            title="Open Trace File",
            filetypes=[
                ("JSON traces", "*.json"),
                ("Text traces", "*.txt"),
                ("All files", "*.*"),
            ])
        if path:
            self._load_file(path)

    def _load_file(self, path: str):
        self.trace_path = path
        self.status_bar.configure(text=f"Loading {path}...")
        self.update_idletasks()

        try:
            self.cycles = load_trace(path)
        except Exception as e:
            self.status_bar.configure(text=f"Error: {e}")
            return

        if not self.cycles:
            self.status_bar.configure(text="No cycles found in file")
            return

        self.current_cycle = 0
        self.slider.configure(to=len(self.cycles) - 1)
        self.total_label.configure(text=f"/ {len(self.cycles) - 1}")
        self.title(f"Blimp Trace Viewer - {os.path.basename(path)}")
        self._update_display()

    def _reload_file(self):
        if self.trace_path:
            saved_cycle = self.current_cycle
            self._load_file(self.trace_path)
            self._go_to(saved_cycle)
            self.status_bar.configure(text=f"Reloaded {os.path.basename(self.trace_path)}")

    # ------------------------------------------------------------------
    # Navigation
    # ------------------------------------------------------------------

    def _go_to(self, idx: int):
        if not self.cycles:
            return
        self.current_cycle = max(0, min(idx, len(self.cycles) - 1))
        self._update_display()

    def _go_prev(self, n: int = 1):
        self._go_to(self.current_cycle - n)

    def _go_next(self, n: int = 1):
        self._go_to(self.current_cycle + n)

    def _go_first(self):
        self._go_to(0)

    def _go_last(self):
        self._go_to(len(self.cycles) - 1)

    def _on_cycle_entry(self, event=None):
        try:
            idx = int(self.cycle_var.get())
            self._go_to(idx)
        except ValueError:
            pass

    def _on_slider(self, value):
        self._go_to(int(value))

    def _goto_cycle(self):
        result = simpledialog.askinteger("Go to Cycle",
                                          "Enter cycle number:",
                                          parent=self,
                                          minvalue=0,
                                          maxvalue=len(self.cycles) - 1)
        if result is not None:
            self._go_to(result)

    # ------------------------------------------------------------------
    # Search
    # ------------------------------------------------------------------

    def _search(self):
        query = simpledialog.askstring("Search", "Search for value:",
                                        parent=self)
        if not query:
            return

        query_lower = query.lower()
        # Search forward from current cycle
        start = self.current_cycle + 1
        for offset in range(len(self.cycles)):
            idx = (start + offset) % len(self.cycles)
            cycle_data = self.cycles[idx]
            if self._cycle_contains(cycle_data, query_lower):
                self._go_to(idx)
                self.status_bar.configure(
                    text=f"Found '{query}' at cycle {idx}")
                return

        self.status_bar.configure(text=f"'{query}' not found")

    def _cycle_contains(self, data: dict, query: str) -> bool:
        """Recursively search all string values in the cycle data."""
        for key, val in data.items():
            if isinstance(val, str) and query in val.lower():
                return True
            if isinstance(val, dict) and self._cycle_contains(val, query):
                return True
            if isinstance(val, list):
                for item in val:
                    if isinstance(item, dict) and self._cycle_contains(item, query):
                        return True
                    if isinstance(item, str) and query in item.lower():
                        return True
        return False

    # ------------------------------------------------------------------
    # Seq Num Highlighting
    # ------------------------------------------------------------------

    def _on_seq_click(self, seq_val: str):
        if self.highlighted_seq == seq_val:
            self._clear_highlight()
        else:
            self.highlighted_seq = seq_val
            self.pipeline_view.highlight_seq(seq_val)
            self.status_bar.configure(text=f"Highlighting seq={seq_val}")

    def _clear_highlight(self):
        self.highlighted_seq = None
        self.pipeline_view.highlight_seq(None)
        self._update_status()

    # ------------------------------------------------------------------
    # Display Update
    # ------------------------------------------------------------------

    def _update_display(self):
        if not self.cycles:
            return

        cycle_data = self.cycles[self.current_cycle]
        self.pipeline_view.update(cycle_data)

        # Re-apply highlight if active
        if self.highlighted_seq:
            self.pipeline_view.highlight_seq(self.highlighted_seq)

        # Update controls
        self.cycle_var.set(str(self.current_cycle))
        self.slider_var.set(self.current_cycle)
        self._update_status()

    def _update_status(self):
        cycle_num = self.cycles[self.current_cycle].get("cycle", self.current_cycle)
        fname = os.path.basename(self.trace_path) if self.trace_path else ""
        self.status_bar.configure(
            text=f"Cycle {cycle_num} (line {self.current_cycle}/{len(self.cycles)-1}) | {fname}")


def main():
    trace_file = sys.argv[1] if len(sys.argv) > 1 else None
    app = TraceViewer(trace_file)
    app.mainloop()


if __name__ == "__main__":
    main()
