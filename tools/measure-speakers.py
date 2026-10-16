#!/usr/bin/env python3
"""Measure the frequency response of the built-in speakers with a microphone.

Plays pink noise through the default output, records it with the default (or given)
input, and prints the response in 1/3-octave bands, normalised to 0 dB at 500-2000 Hz.
From that it suggests a high-pass frequency and the resonance peaks to cut - the method
used to build the Surface Pro 7+ preset (modules/audio). Pure Python + PipeWire tools
(pw-play, pw-record), no numpy needed.

Before measuring the RAW speakers, quit EasyEffects, otherwise you measure its output:
    flatpak run com.github.wwmm.easyeffects -q      (or: easyeffects -q)
Use --processed to measure WITH EasyEffects on purpose (to check a finished preset).

Caveats, learned on the Surface Pro 7+:
  * a built-in microphone sits in the same case and exaggerates resonances (there about
    10 dB too high around 4-6 kHz compared to a reference microphone). Cut peaks by about
    half of what is shown, or measure with a USB reference mic (--source).
  * built-in microphones are often set to maximum boost and clip even on room noise. The
    script lowers "Internal Mic Boost" to 0 and "Capture" to 40 on the ALSA card for the
    measurement and restores the previous values afterwards (--keep-mic-gain disables this).
  * set the output volume you normally listen at, keep the room quiet.

Usage: python3 -I measure-speakers.py [--seconds 8] [--level -12] [--source NODE]
                                      [--sink NODE] [--out DIR] [--processed]
"""
import argparse, cmath, csv, math, os, random, statistics, struct, subprocess, sys, tempfile, time, wave

RATE = 48000
NFFT = 8192
BANDS = [63, 80, 100, 125, 160, 200, 250, 315, 400, 500, 630, 800, 1000, 1250, 1600,
         2000, 2500, 3150, 4000, 5000, 6300, 8000, 10000, 12500, 16000]


def pink_noise(n, level_db):
    """Paul Kellet's refined pink-noise filter on white noise."""
    rnd = random.Random(1)
    b0 = b1 = b2 = b3 = b4 = b5 = b6 = 0.0
    out = []
    for _ in range(n):
        w = rnd.uniform(-1, 1)
        b0 = 0.99886 * b0 + w * 0.0555179; b1 = 0.99332 * b1 + w * 0.0750759
        b2 = 0.96900 * b2 + w * 0.1538520; b3 = 0.86650 * b3 + w * 0.3104856
        b4 = 0.55000 * b4 + w * 0.5329522; b5 = -0.7616 * b5 - w * 0.0168980
        out.append(b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362)
        b6 = w * 0.115926
    rms = math.sqrt(sum(x * x for x in out) / n)
    gain = 10 ** (level_db / 20) / rms
    fade = int(0.2 * RATE)
    for i in range(fade):
        out[i] *= i / fade
        out[-1 - i] *= i / fade
    return [max(-1.0, min(1.0, x * gain)) for x in out]


def write_wav(path, samples):
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in samples))


def read_wav(path):
    with wave.open(path, "rb") as w:
        ch, width, n = w.getnchannels(), w.getsampwidth(), w.getnframes()
        raw = w.readframes(n)
    if width != 2:
        sys.exit(f"unexpected sample width {width} in {path}")
    vals = struct.unpack("<%dh" % (len(raw) // 2), raw)
    return [v / 32768 for v in vals[::ch]]   # first channel


def fft(x):
    n = len(x)
    a = [complex(v) for v in x]
    j = 0
    for i in range(1, n):
        bit = n >> 1
        while j & bit:
            j ^= bit; bit >>= 1
        j |= bit
        if i < j:
            a[i], a[j] = a[j], a[i]
    size = 2
    while size <= n:
        w = cmath.exp(-2j * math.pi / size)
        half = size // 2
        tw = [w ** k for k in range(half)]
        for start in range(0, n, size):
            for k in range(half):
                u = a[start + k]; v = a[start + k + half] * tw[k]
                a[start + k] = u + v; a[start + k + half] = u - v
        size <<= 1
    return a


def psd(x, max_frames=60):
    """Welch power spectrum (Hann window, 50 % overlap), bins 0..NFFT/2."""
    win = [0.5 - 0.5 * math.cos(2 * math.pi * i / (NFFT - 1)) for i in range(NFFT)]
    starts = list(range(0, len(x) - NFFT, NFFT // 2))
    if len(starts) > max_frames:
        step = len(starts) / max_frames
        starts = [starts[int(i * step)] for i in range(max_frames)]
    acc = [0.0] * (NFFT // 2 + 1)
    for s in starts:
        spec = fft([x[s + i] * win[i] for i in range(NFFT)])
        for k in range(NFFT // 2 + 1):
            acc[k] += abs(spec[k]) ** 2
    return [v / max(1, len(starts)) for v in acc]


def band_power(p, fc):
    lo, hi = fc / 2 ** (1 / 6), fc * 2 ** (1 / 6)
    k0, k1 = max(1, int(lo * NFFT / RATE)), min(len(p) - 1, int(math.ceil(hi * NFFT / RATE)))
    vals = p[k0:k1 + 1]
    return sum(vals) / len(vals) if vals else 0.0


GAIN_CONTROLS = [("Internal Mic Boost Volume", "0"), ("Mic Boost Volume", "0"), ("Capture Volume", "40")]


def amixer(card, *args):
    return subprocess.run(["amixer", "-c", str(card), *args], capture_output=True, text=True)


def lower_mic_gain(card):
    """Lower mic boost/capture for the measurement; returns what to restore."""
    restore = []
    for name, value in GAIN_CONTROLS:
        cur = amixer(card, "cget", f"name={name}")
        if cur.returncode != 0:
            continue
        vals = [l.split("=", 1)[1] for l in cur.stdout.splitlines() if l.strip().startswith(": values=")]
        if not vals:
            continue
        restore.append((name, vals[0]))
        amixer(card, "cset", f"name={name}", value)
        print(f"   {name}: {vals[0]} -> {value} (restored afterwards)")
    return restore


def restore_mic_gain(card, restore):
    for name, vals in restore:
        amixer(card, "cset", f"name={name}", vals)


def easyeffects_running():
    return subprocess.run(["pgrep", "-f", "easyeffects"], capture_output=True).returncode == 0


def record(path, seconds, source):
    cmd = ["pw-record", "--rate", str(RATE), "--channels", "1", "--format", "s16"]
    if source:
        cmd += ["--target", source]
    proc = subprocess.Popen(cmd + [path])
    return proc, seconds


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--seconds", type=float, default=8)
    ap.add_argument("--level", type=float, default=-12, help="pink noise RMS in dBFS")
    ap.add_argument("--source", help="PipeWire input node (default: system default)")
    ap.add_argument("--sink", help="PipeWire output node (default: system default)")
    ap.add_argument("--out", default=None, help="directory for wav/csv results")
    ap.add_argument("--processed", action="store_true", help="measure with EasyEffects running")
    ap.add_argument("--card", default="0", help="ALSA card of the microphone (for the gain change)")
    ap.add_argument("--keep-mic-gain", action="store_true", help="do not touch the microphone gain")
    a = ap.parse_args()

    if easyeffects_running() and not a.processed:
        sys.exit("EasyEffects is running - quit it for a raw measurement "
                 "(flatpak run com.github.wwmm.easyeffects -q) or pass --processed.")
    out = a.out or tempfile.mkdtemp(prefix="speaker-measure-")
    os.makedirs(out, exist_ok=True)
    ref = pink_noise(int(a.seconds * RATE), a.level)
    write_wav(f"{out}/pink.wav", ref)

    restore = [] if a.keep_mic_gain else lower_mic_gain(a.card)
    try:
        if restore:
            print("   waiting 4 s for the microphone input to settle after the gain change ...")
            time.sleep(4)
        print(f"1/2 recording {3} s of room noise - keep quiet ...")
        p, _ = record(f"{out}/noise.wav", 3, a.source); time.sleep(3.3); p.terminate(); p.wait()
        print(f"2/2 playing {a.seconds:.0f} s of pink noise and recording it ...")
        p, _ = record(f"{out}/speaker.wav", a.seconds + 1, a.source)
        time.sleep(0.5)
        play = ["pw-play"] + (["--target", a.sink] if a.sink else []) + [f"{out}/pink.wav"]
        subprocess.run(play, check=True)
        time.sleep(0.4); p.terminate(); p.wait()
    finally:
        restore_mic_gain(a.card, restore)

    skip = RATE // 2   # the first 0.5 s of a recording contains the start-up transient
    rec, noise = read_wav(f"{out}/speaker.wav")[skip:], read_wav(f"{out}/noise.wav")[skip:]
    peak = max(abs(v) for v in rec)
    if peak > 0.99:
        sys.exit(f"recording clipped (peak {peak:.3f}) - lower the microphone gain and retry")
    print(f"   recording peak {20 * math.log10(peak):.1f} dBFS, analysing (pure Python, ~20 s) ...")

    p_ref, p_rec, p_noise = psd(ref), psd(rec), psd(noise)
    rows = []
    for fc in BANDS:
        r, s, n = band_power(p_ref, fc), band_power(p_rec, fc), band_power(p_noise, fc)
        resp = 10 * math.log10(s / r) if r > 0 and s > 0 else float("nan")
        snr = 10 * math.log10(s / n) if n > 0 and s > 0 else float("nan")
        rows.append([fc, resp, snr])
    ref_level = statistics.median(r[1] for r in rows if 500 <= r[0] <= 2000)
    for r in rows:
        r[1] -= ref_level

    with open(f"{out}/response.csv", "w", newline="") as f:
        csv.writer(f).writerows([["band_hz", "response_db", "snr_db"]] + [[r[0], f"{r[1]:.1f}", f"{r[2]:.1f}"] for r in rows])

    print(f"\n{'band':>7}  {'resp':>6}  {'SNR':>5}")
    for fc, resp, snr in rows:
        bar = ("+" * int(max(0, resp) / 2)) if resp > 0 else ("-" * int(min(20, -resp) / 2))
        flag = " (low SNR, unreliable)" if snr < 10 else (" <- peak" if resp > 6 else "")
        print(f"{fc:>6} Hz {resp:>+6.1f} {snr:>5.1f}  {bar}{flag}")

    reliable = [r for r in rows if r[2] >= 10]
    hp = next((fc for fc, resp, _ in reliable if resp > -12), None)
    peaks, cur = [], []
    for fc, resp, _ in reliable:
        if resp > 6:
            cur.append((fc, resp))
        elif cur:
            peaks.append(cur); cur = []
    if cur:
        peaks.append(cur)
    print("\nSuggestions (starting point, verify by ear and with --processed):")
    low_unreliable = rows[0][2] < 10
    if hp and not low_unreliable:
        print(f"  high-pass  ~{int(hp * 0.8)} Hz (first band louder than -12 dB is {hp} Hz)")
    else:
        print("  high-pass  not measurable here: the low bands are below the room noise (SNR < 10 dB).")
        print("             Raise the volume / quiet the room, or keep the template's high-pass and decide by ear.")
    if a.processed:
        print("  (measured WITH EasyEffects: the numbers are what remains after the current preset)")
    for grp in peaks:
        top = max(grp, key=lambda g: g[1])
        width_oct = max(1, len(grp)) / 3
        q = round(1 / (2 ** (width_oct / 2) - 2 ** (-width_oct / 2)), 1)
        print(f"  cut peak   {grp[0][0]}-{grp[-1][0]} Hz: Bell {top[0]} Hz, about {-top[1] / 2:.0f} dB "
              f"(half of +{top[1]:.0f} dB, built-in mics exaggerate), Q ~{q}")
    print(f"\nFiles: {out}/response.csv, speaker.wav, noise.wav")


if __name__ == "__main__":
    main()
