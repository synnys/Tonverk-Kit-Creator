"""Tonverk Kit Forge: cross-platform random Elektron drum-kit generator."""

from __future__ import annotations

import json
import math
import os
import random
import shutil
import struct
import sys
import tempfile
import wave
import zipfile
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk

APP_NAME = "Tonverk Kit Forge"
SLOTS = ["kick", "kick2", "snare", "perc", "misc", "tom", "hihat", "cymbal"]
PITCHES = [60, 62, 64, 65, 67, 69, 71, 72]
NAMES = [
    "IRON VEIL", "NIGHT GRID", "DARK CIRCUIT", "VOID SIGNAL", "RUST ENGINE", "COLD FACTORY",
    "STATIC RITUAL", "NEON DECAY", "BLACK VOLT", "STEEL PULSE", "GHOST MACHINE", "DUST VECTOR",
    "PHASE DAMAGE", "NOIR SYSTEM", "DEAD CHANNEL", "ACID FURNACE", "CONCRETE", "ZERO HOUR",
    "CHROME ASH", "TUNNEL VISION", "DEEP PRESSURE", "MACHINE AGE", "GRIT SECTOR", "SUBLEVEL",
    "FRACTURE", "DREAD SIGNAL", "DARK MATTER", "NIGHT SHIFT", "CARBON COPY", "BROKEN PHASE",
    "CIRCUIT WRAITH", "LOW FREQUENCY", "RED SECTOR", "HEAT DEATH", "INDUSTRIAL", "DYSTOPIA",
    "ACID TOWER", "MUTED ALARM", "SHADOW WORK", "COLD METAL",
]


def config_path() -> Path:
    if sys.platform == "darwin":
        base = Path.home() / "Library" / "Application Support"
    elif os.name == "nt":
        base = Path(os.environ.get("APPDATA", Path.home() / "AppData" / "Roaming"))
    else:
        base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    return base / "Tonverk Kit Forge" / "settings.json"


def read_config() -> dict:
    try:
        return json.loads(config_path().read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}


def write_config(data: dict) -> None:
    path = config_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    except OSError:
        pass


def audio_files(folder: str) -> list[Path]:
    if not folder or not Path(folder).is_dir():
        return []
    return sorted((p for p in Path(folder).iterdir() if p.is_file() and p.suffix.lower() == ".wav"), key=lambda p: p.name.lower())


def read_wav_mono(path: Path) -> tuple[list[float], int]:
    with wave.open(str(path), "rb") as wav:
        channels, rate, width = wav.getnchannels(), wav.getframerate(), wav.getsampwidth()
        if wav.getcomptype() != "NONE" or width not in (1, 2, 3, 4):
            raise ValueError("Only uncompressed PCM WAV files (8, 16, 24 or 32 bit) are supported")
        raw = wav.readframes(wav.getnframes())
    frame_bytes = channels * width
    frames = len(raw) // frame_bytes
    mono: list[float] = []
    for frame in range(frames):
        start = frame * frame_bytes
        total = 0.0
        for channel in range(channels):
            offset = start + channel * width
            chunk = raw[offset:offset + width]
            if width == 1:
                value = (chunk[0] - 128) / 128.0
            elif width == 2:
                value = struct.unpack_from("<h", chunk)[0] / 32768.0
            elif width == 3:
                integer = chunk[0] | chunk[1] << 8 | chunk[2] << 16
                if integer & 0x800000:
                    integer -= 0x1000000
                value = integer / 8388608.0
            else:
                value = struct.unpack_from("<i", chunk)[0] / 2147483648.0
            total += value
        mono.append(total / channels)
    if not mono:
        raise ValueError("The WAV file contains no audio frames")
    return mono, rate


def convert_wav(source: Path, destination: Path) -> None:
    samples, source_rate = read_wav_mono(source)
    if source_rate <= 0:
        raise ValueError("Invalid WAV sample rate")
    if source_rate != 48_000:
        out_length = max(1, round(len(samples) * 48_000 / source_rate))
        scale = source_rate / 48_000
        resampled = []
        for i in range(out_length):
            position = i * scale
            left = min(int(position), len(samples) - 1)
            right = min(left + 1, len(samples) - 1)
            fraction = position - left
            resampled.append(samples[left] * (1 - fraction) + samples[right] * fraction)
        samples = resampled
    peak = max((abs(s) for s in samples), default=0.0)
    gain = (10 ** (-0.3 / 20)) / peak if peak else 1.0
    pcm = bytearray()
    for sample in samples:
        value = round(max(-1.0, min(1.0, sample * gain)) * 8_388_607)
        if value < 0:
            value += 1 << 24
        pcm.extend((value & 255, (value >> 8) & 255, (value >> 16) & 255))
    with wave.open(str(destination), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(3)
        wav.setframerate(48_000)
        wav.writeframes(pcm)


def toml_string(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def mapping_text(name: str, files: list[str]) -> str:
    lines = ["# ELEKTRON DRUM SET MAPPING FORMAT", "version = 0", f"name = {toml_string(name)}", ""]
    for pitch, filename in zip(PITCHES, files):
        lines.extend([
            "[[key-zones]]", f"pitch = {pitch}", f"key-center = {pitch:.1f}", "",
            "[[key-zones.velocity-layers]]", "velocity = 0.24705882", "strategy = 'Forward'", "",
            "[[key-zones.velocity-layers.sample-slots]]", f"sample = {toml_string(filename)}", "",
        ])
    return "\n".join(lines)


def safe_category(value: str) -> str:
    result = "".join(c.lower() if c.isalnum() or c in "-_" else "_" for c in value.strip())
    return result.strip("_") or "sound"


def kit_names(count: int) -> list[str]:
    names = random.sample(NAMES, len(NAMES))
    result: list[str] = []
    for index in range(count):
        base = names[index % len(names)]
        suffix_no = index // len(names) + 1
        candidate = base if suffix_no == 1 else f"{base[:13]} {suffix_no}"
        candidate = candidate[:16]
        n = 2
        while candidate.lower() in {x.lower() for x in result}:
            candidate = f"{base[:13]} {n}"[:16]
            n += 1
        result.append(candidate)
    return result


def generate_kits(slot_data: list[tuple[str, str]], count: int, output: Path, progress) -> None:
    for done, kit_name in enumerate(kit_names(count), 1):
        with tempfile.TemporaryDirectory(prefix="tonverk-kit-") as temporary:
            root = Path(temporary) / kit_name
            root.mkdir()
            output_files = []
            for number, (category, folder) in enumerate(slot_data, 1):
                choices = audio_files(folder)
                if not choices:
                    raise ValueError(f"No WAV files found for slot {number} ({category})")
                sample = random.choice(choices)
                filename = f"{number}_{safe_category(category)}_{kit_name}.wav"
                convert_wav(sample, root / filename)
                output_files.append(filename)
            (root / f"{kit_name}.eldrum").write_text(mapping_text(kit_name, output_files), encoding="utf-8")
            zip_path = output / f"{kit_name}.zip"
            with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                for file in root.iterdir():
                    archive.write(file, f"{kit_name}/{file.name}")
        progress(done)


class ForgeApp(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title(APP_NAME)
        self.geometry("900x720")
        self.minsize(760, 620)
        self.config_data = read_config()
        self.categories = self.config_data.get("categories", SLOTS.copy())
        self.folders = self.config_data.get("folders", [""] * 8)
        self.output_folder = tk.StringVar(value=self.config_data.get("output", ""))
        self.kit_count = tk.IntVar(value=int(self.config_data.get("count", 10)))
        self.category_vars: list[tk.StringVar] = []
        self.folder_labels: list[tk.StringVar] = []
        self._build()
        self.protocol("WM_DELETE_WINDOW", self._close)

    def _build(self):
        style = ttk.Style(self)
        style.configure("Title.TLabel", font=("TkDefaultFont", 21, "bold"))
        style.configure("Slot.TLabelframe.Label", font=("TkDefaultFont", 10, "bold"))
        outer = ttk.Frame(self, padding=24)
        outer.pack(fill="both", expand=True)
        ttk.Label(outer, text="TONVERK KIT FORGE", font=("TkDefaultFont", 11, "bold")).pack(anchor="w")
        ttk.Label(outer, text="Build a kit from your sample library", style="Title.TLabel").pack(anchor="w", pady=(12, 4))
        ttk.Label(outer, text="Choose a WAV folder for each slot. Your selections are remembered when you reopen the app.", wraplength=800).pack(anchor="w", pady=(0, 18))
        grid = ttk.Frame(outer)
        grid.pack(fill="both", expand=True)
        grid.columnconfigure((0, 1), weight=1)
        for i, default in enumerate(SLOTS):
            row, col = divmod(i, 2)
            box = ttk.LabelFrame(grid, text=f"  {i+1:02d}  ", style="Slot.TLabelframe", padding=12)
            box.grid(row=row, column=col, sticky="nsew", padx=(0 if col == 0 else 7, 7 if col == 0 else 0), pady=6)
            category = tk.StringVar(value=self.categories[i] if i < len(self.categories) else default)
            self.category_vars.append(category)
            ttk.Label(box, text="CATEGORY").grid(row=0, column=0, sticky="w")
            ttk.Entry(box, textvariable=category, width=18).grid(row=1, column=0, sticky="ew", pady=(3, 8))
            folder = tk.StringVar(value=self.folders[i] if i < len(self.folders) else "")
            self.folder_labels.append(folder)
            ttk.Button(box, text="Choose WAV folder…", command=lambda index=i: self._choose_slot(index)).grid(row=2, column=0, sticky="w")
            ttk.Label(box, textvariable=folder, foreground="#666", wraplength=330).grid(row=3, column=0, sticky="w", pady=(6, 0))
            box.columnconfigure(0, weight=1)
        settings = ttk.LabelFrame(outer, text="Kit output", padding=12)
        settings.pack(fill="x", pady=(15, 10))
        ttk.Label(settings, text="Number of kits").grid(row=0, column=0, sticky="w")
        ttk.Spinbox(settings, from_=1, to=500, textvariable=self.kit_count, width=7).grid(row=0, column=1, sticky="w", padx=(10, 24))
        ttk.Button(settings, text="Choose output folder…", command=self._choose_output).grid(row=0, column=2, sticky="w")
        ttk.Label(settings, textvariable=self.output_folder, foreground="#666").grid(row=1, column=0, columnspan=3, sticky="w", pady=(8, 0))
        settings.columnconfigure(3, weight=1)
        bottom = ttk.Frame(outer)
        bottom.pack(fill="x", pady=(4, 0))
        self.status = tk.StringVar(value="48 kHz · 24 bit · mono · peak normalized to −0.3 dBFS")
        ttk.Label(bottom, textvariable=self.status).pack(side="left", fill="x", expand=True)
        self.generate_button = ttk.Button(bottom, text="Generate kits", command=self._generate)
        self.generate_button.pack(side="right")

    def _choose_slot(self, index):
        folder = filedialog.askdirectory(title=f"Choose WAV folder for {self.category_vars[index].get()}", initialdir=self.folder_labels[index].get() or str(Path.home()))
        if folder:
            self.folder_labels[index].set(folder)
            self._save()

    def _choose_output(self):
        folder = filedialog.askdirectory(title="Choose output folder", initialdir=self.output_folder.get() or str(Path.home()))
        if folder:
            self.output_folder.set(folder)
            self._save()

    def _save(self):
        write_config({"categories": [v.get() for v in self.category_vars], "folders": [v.get() for v in self.folder_labels], "output": self.output_folder.get(), "count": self.kit_count.get()})

    def _generate(self):
        try:
            count = self.kit_count.get()
        except tk.TclError:
            messagebox.showerror("Invalid kit count", "Enter a whole number of kits.")
            return
        folders = [v.get() for v in self.folder_labels]
        if not self.output_folder.get() or not Path(self.output_folder.get()).is_dir():
            messagebox.showerror("Choose output folder", "Select a valid output folder first.")
            return
        if any(not folder or not audio_files(folder) for folder in folders):
            messagebox.showerror("Missing samples", "Choose a folder containing WAV files for each of the eight slots.")
            return
        if any(not v.get().strip() for v in self.category_vars):
            messagebox.showerror("Missing category", "Each slot needs a category name.")
            return
        self._save()
        self.generate_button.configure(state="disabled")
        self.status.set("Generating kits…")
        self.update_idletasks()
        try:
            data = [(self.category_vars[i].get(), folders[i]) for i in range(8)]
            generate_kits(data, count, Path(self.output_folder.get()), lambda n: self.status.set(f"Generated {n} of {count} kits…"))
            self.status.set(f"Done. Created {count} kit ZIP files.")
            messagebox.showinfo("Generation complete", f"Created {count} kit ZIP files in:\n{self.output_folder.get()}")
        except Exception as error:
            self.status.set("Generation stopped.")
            messagebox.showerror("Could not generate kits", str(error))
        finally:
            self.generate_button.configure(state="normal")

    def _close(self):
        self._save()
        self.destroy()


if __name__ == "__main__":
    ForgeApp().mainloop()
