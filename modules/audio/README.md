# audio - EasyEffects speaker preset

Installs EasyEffects (Flatpak, from Flathub) and a speaker preset that was measured on the device.
For the Surface Pro 7+ that is `SurfacePro7+ v3`. For devices without a measured preset the
module installs nothing and explains how to measure one with `tools/measure-speakers.py`.

## Why

Surface speakers sound thin and, on the Surface Pro 7+, shrill. Under Windows a vendor Audio
Processing Object equalises them; Linux has no equivalent, so EasyEffects fills that gap. No
ready-made, device-specific speaker profile for the Surface Pro 7+ was found, neither in the
linux-surface project nor in the known EasyEffects preset collections.

### What the hardware offers (Surface Pro 7+)

- Codec Realtek ALC274, sink `alsa_output.pci-0000_00_1f.3.analog-stereo`, port
  `analog-output-speaker`.
- `/proc/asound/card0/codec#0` shows exactly **one** internal speaker pin (`0x90170110`, Fixed /
  Internal) feeding front-left and front-right. There is **no separate bass/woofer channel** that a
  driver quirk could unlock (unlike some Lenovo models where a missing Realtek fixup mutes the bass
  speakers). Nothing is muted; the drivers are simply tiny.
- `amixer -c0` lists only `Master`, `Headphone`, `Speaker`, `PCM` - no bass control.
  `snd_hda_intel` runs without a `model=` quirk, which is correct for this device.

Consequence: real low bass cannot be produced physically. What helps is *psychoacoustic* bass
(harmonics from which the ear reconstructs the missing fundamental) - a Bass Enhancer can do that,
an equalizer cannot.

### Measured, not guessed

Earlier presets (v1/v2) were built from guidelines and sounded "no bass, shrill highs". A
measurement explained why:

- Measured with the built-in microphone (EasyEffects quit, so the raw speakers were measured; mic
  boost lowered to avoid clipping): a large speaker resonance of +18 to +29 dB at
  **3.5-6.5 kHz**, nothing usable below ~115 Hz. v1/v2 had *boosted* exactly that region.
- A reference measurement with an external (Rode) microphone showed the real resonance at
  +12 to +15 dB, so the built-in microphone **exaggerates it by about 10 dB**.
- With v3, 3.6-6.4 kHz lies within +/-5 dB.

The raw measurement data was not kept, only the results above.

### The v3 chain

```
Filter (high-pass) -> Equalizer -> Bass Enhancer -> Stereo Tools -> Limiter
```

| Plugin | Settings |
|---|---|
| Filter | High-pass 95 Hz, RLC (BT), slope x2 |
| Equalizer (IIR, 6 bands) | input -6 dB; Lo-shelf 250 Hz +6 dB Q 0.7; Bell 160 Hz +3 dB Q 1.2; Bell 4.1 kHz -9 dB Q 1.8; Bell 5.2 kHz -10 dB Q 2.2; Bell 6.3 kHz -4 dB Q 2.5; Hi-shelf 10 kHz +4 dB Q 0.7 (taste) |
| Bass Enhancer | amount 8, harmonics 6, scope 150, floor 60 (active) |
| Stereo Tools | stereo-base 0.25 |
| Limiter | threshold -1 dB |

There is no multiband compressor in v3 (v2 had one).

## Usage

```bash
./install.sh run audio
# or directly:
modules/audio/apply.sh          # EasyEffects + the preset named by AUDIO_PRESET in devices/<device>.conf
modules/audio/apply.sh --all    # install every preset in presets/ (e.g. to use one as a template)
```

An existing preset file with the same name but different content is backed up as
`<name>.json.bak-<timestamp>` first. Presets go to
`~/.var/app/com.github.wwmm.easyeffects/data/easyeffects/output/`.

Then select the preset in EasyEffects (**Presets -> Output**) and enable "Start service at login"
in EasyEffects' preferences so it is always active.

Loading a preset from the command line (`easyeffects -l "<name>"`) while EasyEffects runs is **not
reliable**: EasyEffects keeps its state in memory and writes it on exit, so calls overtake each
other and a mixed state can result (observed: the preset was applied only partially). Use the GUI.

## Building a preset for another device

Speakers differ per model; a preset from another device corrects the wrong frequencies. The
Surface Go 2 (and any other device) has to be measured first.

1. Quit EasyEffects so the raw speakers are measured:
   ```bash
   flatpak run com.github.wwmm.easyeffects -q
   ```
2. Set the output volume you normally listen at, keep the room quiet, and run:
   ```bash
   python3 -I tools/measure-speakers.py            # options: --seconds 8 --level -12
                                                    #          --source NODE --sink NODE --out DIR
   ```
   The tool is pure Python plus PipeWire's `pw-play`/`pw-record` (no numpy). It plays pink noise,
   records it, and prints the response in 1/3-octave bands normalised to 0 dB at 500-2000 Hz,
   plus suggestions for the high-pass frequency and the resonance peaks to cut. Details:
   - It lowers "Internal Mic Boost"/"Mic Boost" to 0 and "Capture" to 40 on the ALSA card
     (`--card`, default 0) for the measurement and restores the previous values afterwards
     (`--keep-mic-gain` disables this). Built-in microphones are often at maximum boost and clip
     even on room noise.
   - It records 3 s of room noise first and marks bands with an SNR below 10 dB as unreliable; if
     the low bands are below the room noise it says the high-pass cannot be measured.
   - It skips the first 0.5 s of each recording (start-up transient) and aborts if the recording
     clipped.
   - Peak cuts are suggested at **half** the measured height, because a built-in microphone in the
     same case exaggerates resonances (about 10 dB too high at 4-6 kHz on the Surface Pro 7+). With
     a USB reference microphone (`--source`) you can cut by what is measured.
   - Results are written as `response.csv`, `speaker.wav`, `noise.wav` (to `--out`, or a temp dir).
3. Copy `presets/SurfacePro7+ v3.json`, keep the chain (Filter high-pass -> Equalizer -> Bass
   Enhancer -> Stereo Tools -> Limiter) and put in your numbers: high-pass frequency, a Bell per
   resonance peak, shelves by ear. Save it as `presets/<name>.json`, set `AUDIO_PRESET="<name>"` in
   `devices/<device>.conf`, and run `modules/audio/apply.sh`.
4. Check it: start EasyEffects, select the preset, and measure what remains:
   ```bash
   python3 -I tools/measure-speakers.py --processed
   ```

## When to re-run

Only when a preset in `presets/` changed. EasyEffects updates come through Flatpak and do not
touch the installed preset.

## Undo

Select another preset (or none) in EasyEffects, or delete the preset file from
`~/.var/app/com.github.wwmm.easyeffects/data/easyeffects/output/` (a `.bak-<timestamp>` copy is
there if one was replaced). `flatpak uninstall com.github.wwmm.easyeffects` removes EasyEffects.

## Limits

- `SurfacePro7+ v3` is valid for the Surface Pro 7+ speakers only.
- The 10 kHz high shelf (+4 dB) is a matter of taste, not a measurement result.
