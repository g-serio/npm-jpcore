# OlonJS — Websites for Humans and AI Agents


<p align="center">
  <a href="https://olonjs.io">
    <img src="https://github.com/olonjs/npm-jpcore/blob/main/brand/mark/olon-mark-dark-256.png" width="120" height="120" alt="OlonJS Logo">
  </a>
</p>

<h1 align="center">OlonJS</h1>

<p align="center">
  <strong>The AI-Native Content Infrastructure.</strong><br />
  Deterministic. Sovereign. Git-Backed.
</p>

<p align="center">
  <a href="https://www.npmjs.com/package/@olonjs/core">
    <img src="https://img.shields.io/npm/v/@olonjs/core?color=blue&style=flat-square" alt="npm version">
  </a>
  <a href="https://github.com/olonjs/npm-jpcore/blob/main/LICENSE">
    <img src="https://img.shields.io/badge/license-MIT-green?style=flat-square" alt="license">
  </a>
</p>

**OlonJS** is an open-source JavaScript infrastructure designed to bridge the gap between human-centric websites and AI agents. It introduces a **deterministic machine contract** for web content: every page is natively available as a typed JSON endpoint (`/{slug}.json`), making websites reliably readable and operable by AI agents while preserving a high-end human UI.




This repository contains the OlonJS stack:

- `packages/core`: runtime engine (`@olonjs/core`)
- `packages/cli`: tenant generator (`@olonjs/cli`)
- `packages/stack`: dependency manifest (`@olonjs/stack`)
- `apps/tenant-alpha`: reference DNA template source

Use this file as entrypoint. Canonical docs are under `docs/`

## 🚀 The Vision

Websites are currently built for humans (HTML-heavy, fragmented). AI agents struggle with scraping and non-deterministic structures. **OlonJS** standardizes the web-to-agent interface through:

-   **WebMCP Readiness:** Native integration with the **Model Context Protocol**. OlonJS sites act as MCP Servers, exposing content as Resources and sections as Tools for AI-orchestrated browsers (Chrome WebMCP).
-   **Predictable Endpoints:** Canonical JSON sidecars for every route. No scraping, just pure data.
-   **Schema-Driven Contracts:** Zod-validated content structures defined by the tenant. The schema is the API.
-   **Sovereign Architecture:** A core JavaScript engine that orchestrates the runtime state and deterministic rendering of polymorphic web content.

## 📦 Monorepo Structure (Nx + Workspaces)

This repository manages the entire OlonJS ecosystem:

- **`packages/core` (@olonjs/core):** The runtime engine. Handles routing, state orchestration, and the Visual Studio (ICE).
- **`packages/cli` (@olonjs/cli):** The primary entry point for developers. Scaffolds new tenants by projecting DNA templates.
- **`packages/stack` (@olonjs/stack):** Version manifest package to keep dependency policy aligned.
- **`apps/tenant-alpha`:** Source of truth for the `alpha` DNA template.

## 🚦 Getting Started

### Scaffolding a new Tenant
The only command you need to start a new project with the OlonJS DNA:
```bash
npx @olonjs/cli new tenant my-agentic-site --template alpha
```
*Supported templates: `alpha` (default).*

### Local Monorepo Development
```bash
# Install dependencies for all packages and apps
npm install

# Run the reference alpha tenant
npm run dev

```
### Root scripts

- `npm run dev`: run `tenant-alpha` in dev mode
- `npm run build`: build `tenant-alpha`
- `npm run build:all`: run `build` for all workspaces (if script exists)
- `npm run check:templates`: validate CLI template assets (`alpha`)
- `npm run dist:dna:all`: regenerate DNA via tenant SOT (`tenant-alpha`)
- `npm run release`: legacy release flow (`scripts/release.js`)
- `npm run release:enterprise`: gated release flow (`check:templates` + `dist:dna:all` + `release`)

### DNA source of truth

DNA is generated from tenant apps, not edited manually:

- `apps/tenant-alpha` -> template `alpha`

Each source app owns its own `dist` script.
Root `dist:dna:all` delegates to those `dist` scripts.


## 📖 Documentation Index

Detailed technical documentation is available in the `docs/` directory:

### Specs 1.6
- **[OlonJS Specs_V_1_6](./specs/olonjsSpecs_V_1_6.md)**

### Core Architecture & CLI
- **[Architecture](./docs/ARCHITECTURE.md):** Monorepo layout, package responsibilities, and DNA regeneration flow.
- **[CLI Contract](./docs/CLI.md):** Command surface, template resolution, and generation pipeline.
- **[Templates Governance](./docs/TEMPLATES.md):** Rules for managing DNA source of truth and conformance checks.
- **[WebMCP (Browser API)](./docs/webmcp.md):** The Agent-Native browser API for Zero-UI mutations and programmatic exploration.

### Onboarding & Governance
- **[Client Onboarding](./docs_governance_en.md):** Guide for graphics and data development.
- **[Governance Path](./docs/docs_governance_en.md):** Full CMS integration (Studio, ICE, Form Factory, IDAC).


### Ops & Maintenance
- **[Publishing & Release](./docs/PUBLISHING.md):** Operational source of truth for NPM releases and DNA sync.
- **[Compatibility Cutoff](./docs/COMPAT_CUTOFF_EN.md):** Decommissioning plan for legacy `jsonpages` residues.

## 🛠️ Technical Stack
- **Runtime:** React 19, TypeScript, Zod.
- **Build:** Vite 6 + Tailwind CSS v4.
- **Protocol:** WebMCP (Model Context Protocol) ready via deterministic JSON endpoints.

## 🌐 JavaScript Ecosystem Integration
OlonJS is a pure JavaScript/TypeScript ecosystem project. It leverages runtime polymorphism and Zod-driven schemas to redefine how content is served and manipulated by AI. By providing a standard library for machine-readable websites, OlonJS contributes to the evolution of the JavaScript ecosystem in the age of AI.

## 📄 License
Distributed under the MIT License. See `LICENSE` for more information.

---

**Built for the Agentic Web by the OlonJS Team.**  
[olonjs.io](https://olonjs.io)

---

