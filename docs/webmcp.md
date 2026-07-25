# WebMCP: The Agent-Native Browser API

OlonJS implements **WebMCP** (Web Model Context Protocol) natively within its Engine. This transforms any OlonJS website into an API directly accessible from the browser's context, allowing AI Agents (and automated E2E scripts) to interact with the site semantically, bypassing traditional, fragile DOM scraping.

## The Paradigm: Core as an MCP Server

Instead of running a separate backend Node.js server, OlonJS exposes the **React Engine itself** as an MCP server directly within the browser tab.

1.  **Discovery (The Manifesto):** When an Agent visits the site, the Engine exposes a manifesto of capabilities via `document.modelContextProtocol`.
2.  **Semantic Bridge:** The Agent doesn't "click buttons" (`.btn-primary`). It calls explicitly typed functions (Tools) using JSON.
3.  **Governance & Security:** The Engine validates all Agent inputs against the tenant's Zod schemas *before* altering the React state or saving to disk.

---

## Accessing WebMCP

Tool registration uses the WebMCP Imperative API on **`document.modelContext`** (spec). `navigator.modelContext` is removed — do not use it.

```typescript
const modelContext = document.modelContext;
const mcp = document.modelContextProtocol;
```

---

## 1. Discovery: Listing Tools

You can query the Engine to see which tools are currently available. 

OlonJS uses an **Enterprise Grade** architecture: instead of exposing dozens of redundant tools for each section type, it exposes a single, universal `update-section` tool.

**Console Example:**
```javascript
const tools = document.modelContextProtocol.listTools();
console.log(tools);
// Output:
// [{
//   name: "update-section",
//   description: "Update any section in OlonJS Studio...",
//   inputSchema: { ... }
// }]
```

---

## 2. Reading Resources (Data Fetching)

Agents can read the exact data state of any page without parsing HTML. OlonJS pages are exposed as `olon://` URIs.

Currently, the Engine supports reading page data. The Agent can discover available resources using the `listResources` method (if implemented) or directly fetch known paths.

**Console Example:**
```javascript
// Fetch the structured JSON data for the current 'home' page
const pageDataString = await document.modelContextProtocol.readResource('olon://pages/home');
const pageData = JSON.parse(pageDataString);

console.log("Page data:", pageData);
console.log("Sections count:", pageData.sections.length);

// Example: Finding a specific section ID by its type
const heroSection = pageData.sections.find(s => s.type === 'olon-hero');
console.log("Found Hero ID:", heroSection?.id);
```

---

## 3. Executing Tools (Zero-UI Mutations)

The core capability of WebMCP is allowing Agents to perform actions. Currently, OlonJS exposes the universal `update-section` tool.

### `update-section`

This tool allows an Agent to modify any section on the page. The Engine will automatically look up the correct Zod schema based on the `sectionType` provided, validate the payload, and update the UI instantly.

**Arguments:**
*   `sectionId` (string, required): The unique ID of the section to update.
*   `sectionType` (string, required): The type of the section (e.g., `"olon-hero"`, `"olon-why"`). Used by the Engine to pick the correct validation schema.
*   `scope` (string, optional): `"local"` (default) or `"global"`.
*   `data` (object): The full replacement payload for the section.

**Console Example: Updating a Hero Section**
```javascript
// 1. First, read the page to find the sectionId you want to edit
const pageStr = await document.modelContextProtocol.readResource('olon://pages/home');
const page = JSON.parse(pageStr);

// Let's assume we found a hero section with ID "hero-1" and type "olon-hero"
const targetSectionId = "hero-1"; 

// 2. Call the update-section tool
const responseStr = await document.modelContextProtocol.executeTool(
  'update-section', 
  JSON.stringify({
    sectionId: targetSectionId,
    sectionType: 'olon-hero',
    scope: 'local',
    data: {
      eyebrow: "AI GENERATED",
      headline: "Welcome to the Agentic Web",
      subline: "This section was updated directly via the browser console using WebMCP.",
      cta: {
        primary: { label: "Learn More", href: "/docs" },
        secondary: { label: "GitHub", href: "https://github.com" },
        ghost: { label: "Contact", href: "/contact" }
      }
    }
  })
);

console.log(JSON.parse(responseStr));
// Output: { content: [{ type: "text", text: "{\"ok\":true,...}" }], isError: false }
```

## Future Extensibility: The E-Commerce Flow

This exact architecture scales seamlessly to complex interactions like an e-commerce checkout. 

In the future, the Engine will expose tools like `search_products` and `execute_purchase`. The Agent will negotiate the purchase entirely via JSON payloads, and the OlonJS Engine will orchestrate the transaction, only rendering a final, secure payment overlay for human confirmation (Governance).
