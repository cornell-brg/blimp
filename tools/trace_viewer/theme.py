"""
Dark theme configuration for the trace viewer.
"""

# Window and card colors
COLORS = {
    "bg":             "#1e1e1e",
    "card_active":    "#2d2d2d",
    "card_inactive":  "#1a1a1a",
    "header":         "#d4843e",
    "text":           "#e0e0e0",
    "label":          "#808080",
    "border":         "#3e3e3e",
    "highlight":      "#3a3a5c",
    "card_xfer":      "#1e3a1e",
    "card_diu_alert": "#3a1e1e",
    "toolbar_bg":     "#252526",
    "button_bg":      "#3c3c3c",
    "button_fg":      "#e0e0e0",
    "entry_bg":       "#3c3c3c",
    "entry_fg":       "#e0e0e0",
    "slider_trough":  "#3c3c3c",
}

# Per-field-style colors
FIELD_STYLES = {
    "addr":    "#4ec9b0",
    "data":    "#e0e0e0",
    "seq":     "#569cd6",
    "op":      "#dcdcaa",
    "inst":    "#ce9178",
    "bool":    "#9cdcfe",
    "default": "#e0e0e0",
}

# Font configuration
FONTS = {
    "header":  ("Consolas", 11, "bold"),
    "label":   ("Consolas", 10),
    "value":   ("Consolas", 10),
    "toolbar": ("Consolas", 10),
    "title":   ("Consolas", 12, "bold"),
}


def configure_styles(style):
    """Configure ttk styles for the dark theme."""
    style.theme_use("clam")

    style.configure(".", background=COLORS["bg"], foreground=COLORS["text"])

    style.configure("TFrame", background=COLORS["bg"])

    style.configure("Toolbar.TFrame", background=COLORS["toolbar_bg"])

    style.configure("TLabel",
                     background=COLORS["bg"],
                     foreground=COLORS["text"],
                     font=FONTS["value"])

    style.configure("Header.TLabel",
                     background=COLORS["bg"],
                     foreground=COLORS["header"],
                     font=FONTS["header"])

    style.configure("GroupHeader.TLabel",
                     background=COLORS["bg"],
                     foreground=COLORS["header"],
                     font=FONTS["title"])

    style.configure("FieldLabel.TLabel",
                     background=COLORS["card_active"],
                     foreground=COLORS["label"],
                     font=FONTS["label"])

    style.configure("TButton",
                     background=COLORS["button_bg"],
                     foreground=COLORS["button_fg"],
                     font=FONTS["toolbar"])

    style.map("TButton",
              background=[("active", "#505050"), ("pressed", "#606060")])

    style.configure("TScale",
                     background=COLORS["bg"],
                     troughcolor=COLORS["slider_trough"])

    style.configure("TLabelframe",
                     background=COLORS["card_active"],
                     foreground=COLORS["header"],
                     font=FONTS["header"])

    style.configure("TLabelframe.Label",
                     background=COLORS["card_active"],
                     foreground=COLORS["header"],
                     font=FONTS["header"])

    style.configure("Inactive.TLabelframe",
                     background=COLORS["card_inactive"],
                     foreground=COLORS["label"])

    style.configure("Inactive.TLabelframe.Label",
                     background=COLORS["card_inactive"],
                     foreground=COLORS["label"])

    # Field value styles for each type
    for style_name, color in FIELD_STYLES.items():
        style.configure(f"{style_name}.TLabel",
                         background=COLORS["card_active"],
                         foreground=color,
                         font=FONTS["value"])
        style.configure(f"{style_name}.Inactive.TLabel",
                         background=COLORS["card_inactive"],
                         foreground=COLORS["label"],
                         font=FONTS["value"])
