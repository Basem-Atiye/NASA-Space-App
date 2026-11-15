# Open Bounds — Junior Astronaut Mission Trainer

Walk Commander Nova across the Moon’s south pole, solve real engineering problems with real NASA numbers, and bring your crew home safely.

**Demo video:** [https://youtu.be/Ywzh4uJW13U](https://youtu.be/Ywzh4uJW13U?si=5e3egp4Fhohj9X4a)

Built for the **NASA Space Apps Challenge 2026** — *Build a Junior Astronaut Mission Trainer* (Beirut team).

---

## Play it

| | Link |
|---|---|
| **Play in the browser** | [https://basem-atiye.github.io/NASA-Space-App/](https://basem-atiye.github.io/NASA-Space-App/) |
| **Download Android APK** | [Space Bounds v2.0.0 (arm64)](https://github.com/Basem-Atiye/NASA-Space-App/releases/tag/v2.0.0) |

On a phone: open the release page → download **SpaceBounds-arm64-v2.0.0.apk** → allow install from that source → open the file.

---

## How to play

1. **Start** — Tap **Start** on the welcome screen (or **Play** on the home card) to begin a mission.
2. **Pick a difficulty (rank)** — Choose how hard the reading, maths, and timers feel:
   - **Cadet (6–10)** — every line read aloud, pictures, Pip helps, no timers
   - **Explorer (11–14)** — real numbers, gentle timers, hints cost a star
   - **Engineer (15–18)** — NASA rates and formulas, tight timers, mistakes carry forward  
   Teachers can lock a rank for a whole class.
3. **What you are trying to do** — Walk Nova on the lunar surface, talk to Mission Control, fix systems (power, air, leaks, dust…), and finish each level with good decisions. Stars and skills track how well you did. In **Base Commander**, keep oxygen, water, food, and power alive day by day until the mission ends.

---

## Screenshots

<p align="center">
  <img src="docs/screenshots/01-welcome.jpg" alt="Welcome — Mission Trainer" width="220" />
  &nbsp;
  <img src="docs/screenshots/02-rank.jpg" alt="Choose your rank" width="220" />
</p>
<p align="center">
  <img src="docs/screenshots/03-home.jpg" alt="Home — Open Bounds / Artemis Base Camp" width="220" />
  &nbsp;
  <img src="docs/screenshots/04-mission.jpg" alt="In mission — Power Budget brief" width="220" />
</p>

---

## Run from source

You need [Flutter](https://flutter.dev) **3.27.4+** (stable).

```bash
git clone https://github.com/Basem-Atiye/NASA-Space-App.git
cd NASA-Space-App
flutter pub get
flutter run
```

Useful variants:

```bash
flutter run -d chrome                          # browser
flutter run --release                          # phone / emulator
cp env/dev.example.json env/dev.json           # optional cloud keys (public only)
flutter run --dart-define-from-file=env/dev.json
```

Tests: `flutter test`

---

## Tools used

- **Flutter / Dart** — game client (Android, iOS, Web)
- **Figma** — Mission Trainer UI design
- **Supabase** — auth, Postgres, Realtime (classes, co-op, sync)
- **GitHub Actions + GitHub Pages** — web deploy
- **Audioplayers / flutter_tts / sensors_plus** — sound, read-aloud, tilt & motion
- **Cursor** - To make coding and planning (coding architecture) faster

---

## NASA sources

Science numbers and scenarios draw on public NASA and mission data, including:

1. DONKI – Space Weather Database (NASA)
https://ccmc.gsfc.nasa.gov/tools/DONKI/


2. NASA Open Science Data Repository (OSDR)
https://osdr.nasa.gov/bio/repo/
Provides spaceflight research about astronaut health. Relevant to the crew-health and survival systems.

3. RadLab – Radiation Dosimetry Database (NASA)
https://visualization.osdr.nasa.gov/radlab/gui/overview/


4. Canadian Space Agency – Food Production on the Moon
https://www.asc-csa.gc.ca/eng/youth-educators/toolkits/food-production/


5. Canadian Space Agency – STEM Resources
https://www.asc-csa.gc.ca/eng/youth-educators/resources-stem-and-youth-organizations.asp

---

## Team

Beirut — NASA Space Apps Challenge 2026

- **Basem Atiye**
- **Ahmad El Haj**
- **Amal Nakuzi**
- **Maria Abo Shakra**
- **Reem Agha**
- **Marwa Al Hamedi**

---

## License notes

Fonts under the SIL Open Font License (`assets/fonts/`). Sounds made for this project.
