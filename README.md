# Hermes + 9Router — Skill & Kit

Paket lengkap buat bikin **Hermes Agent** (bot Telegram) dengan **9Router** sebagai router modelnya, persis seperti stack yang dipakai di produksi.

## Isi

- `hermes_9router_install/SKILL.md` — skill/playbook instalasi: urutan kerja, wiring Telegram, gateway, tunnel, dan semua gotcha yang sudah terbukti di lapangan.
- `hermuse-kit/` — kit Hermuse: installer (`scripts/install.sh`), skrip start/restart 9Router & gateway, watchdog, doctor, dan tunnel Cloudflare Pages + D1 buat dashboard.

## Cara pakai

Kasih repo ini ke agen AI kamu (Muse/Hermes/dll), suruh baca `hermuse-kit/AGENTS.md` dan `hermes_9router_install/SKILL.md`, lalu ikuti urutannya: 9Router dulu, Hermes kedua, Telegram ketiga, gateway keempat, tunnel terakhir.

## Keamanan

Repo ini TIDAK berisi kredensial apa pun. Semua nilai rahasia (token bot Telegram, API key, password dashboard, key tunnel) dibuat saat instalasi dan disimpan lokal di mesin masing-masing (chmod 600), tidak pernah ikut ter-commit.
