---
name: personale-design
description: Use this skill to generate well-branded interfaces and assets for Personale — a local-first open-source macOS productivity tracker (self-hostable Rize alternative). Contains essential design guidelines, color system, typography tokens, UI components, and a full interactive app prototype for mocking and prototyping.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.

If creating visual artifacts (slides, mocks, throwaway prototypes, etc), copy assets out and create static HTML files for the user to view. Use the token CSS files and component bundle to ensure visual fidelity.

Key facts to internalize before designing:
- Dark-only: #101014 background, #17171C cards, #7B56D2 primary purple, #00CCB8 cyan accent
- Font: SF Pro / Inter; all numbers use monospaced tabular-nums
- Cards: 8px radius, 1px border at rgba(43,43,49,0.5), no shadow
- Section titles: ALL CAPS, 10px, semibold, letter-spacing 0.8px, --color-muted-foreground
- Category colors are fixed (Code=#7C5CFC, Browsing=#F5A623, Communication=#D64D8A, Design=#00CCBF, Writing=#35A882, Media=#9B85F5, Other=#3D4451)
- Three products: macOS Swift app, Java Spring Boot server, Chrome extension
- No emoji, no gradients, no shadows, no imagery

If the user invokes this skill without any other guidance, ask them what they want to build or design, ask some questions about which screen/flow/component they need, and act as an expert product designer who outputs HTML artifacts for prototypes or production code depending on the need.
