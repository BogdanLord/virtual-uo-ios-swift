# Virtual UO — iOS Native (Swift + RealityKit)

Aplicație iOS nativă pentru experiențe AR educaționale, cu plane detection, plasare model 3D și adnotări 3D ancorate.

## Tehnologii

- **Swift 5.9** + **SwiftUI** — UI declarativ modern
- **RealityKit** — motor AR Apple (ARKit + 3D rendering nativ)
- **ARKit** — plane detection, world tracking, anchoring
- **Supabase Swift** — date din baza de date
- **AVFoundation** — TTS în română

## Build

Build-ul rulează automat pe GitHub Actions la fiecare push. IPA generat e disponibil în Artifacts și poate fi instalat cu Sideloadly.

## Structură

```
VirtualUO/
├── VirtualUOApp.swift      — entry point
├── Info.plist              — permisiuni camera + AR
├── Models/                 — modele de date
├── Services/               — Supabase, download USDZ
└── Views/                  — ecrane SwiftUI + AR
```

## Modele 3D

Aplicația folosește format **USDZ** (format AR nativ Apple). Modelele sunt încărcate din Supabase Storage prin URL-ul din coloana `model_url_ios`.

Pentru conversie GLB → USDZ:
- **Reality Converter** (gratuit, Apple) — drag & drop GLB → exportă USDZ
- **usdzconvert** (command line)
