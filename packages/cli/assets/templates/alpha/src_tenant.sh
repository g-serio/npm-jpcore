#!/bin/bash
set -e

echo "Starting project reconstruction..."

mkdir -p ".cursor"
mkdir -p ".cursor/skills-cursor"
mkdir -p ".cursor/skills-cursor/create-rule"
echo "Creating .cursor/skills-cursor/create-rule/SKILL.md..."
cat << 'END_OF_FILE_CONTENT' > ".cursor/skills-cursor/create-rule/SKILL.md"
---
name: create-rule
description: >-
  Create Cursor rules for persistent AI guidance. Use when you want to create a
  rule, add coding standards, set up project conventions, configure
  file-specific patterns, create RULE.md files, or asks about .cursor/rules/ or
  AGENTS.md.
---
# Creating Cursor Rules

Create project rules in `.cursor/rules/` to provide persistent context for the AI agent.

## Gather Requirements

Before creating a rule, determine:

1. **Purpose**: What should this rule enforce or teach?
2. **Scope**: Should it always apply, or only for specific files?
3. **File patterns**: If file-specific, which glob patterns?

### Inferring from Context

If you have previous conversation context, infer rules from what was discussed. You can create multiple rules if the conversation covers distinct topics or patterns. Don't ask redundant questions if the context already provides the answers.

### Required Questions

If the user hasn't specified scope, ask:
- "Should this rule always apply, or only when working with specific files?"

If they mentioned specific files and haven't provided concrete patterns, ask:
- "Which file patterns should this rule apply to?" (e.g., `**/*.ts`, `backend/**/*.py`)

It's very important that we get clarity on the file patterns.

Use the AskQuestion tool when available to gather this efficiently.

---

## Rule File Format

Rules are `.mdc` files in `.cursor/rules/` with YAML frontmatter:

```
.cursor/rules/
  typescript-standards.mdc
  react-patterns.mdc
  api-conventions.mdc
```

### File Structure

```markdown
---
description: Brief description of what this rule does
globs: **/*.ts  # File pattern for file-specific rules
alwaysApply: false  # Set to true if rule should always apply
---

# Rule Title

Your rule content here...
```

### Frontmatter Fields

| Field | Type | Description |
|-------|------|-------------|
| `description` | string | What the rule does (shown in rule picker) |
| `globs` | string | File pattern - rule applies when matching files are open |
| `alwaysApply` | boolean | If true, applies to every session |

---

## Rule Configurations

### Always Apply

For universal standards that should apply to every conversation:

```yaml
---
description: Core coding standards for the project
alwaysApply: true
---
```

### Apply to Specific Files

For rules that apply when working with certain file types:

```yaml
---
description: TypeScript conventions for this project
globs: **/*.ts
alwaysApply: false
---
```

---

## Best Practices

### Keep Rules Concise

- **Under 50 lines**: Rules should be concise and to the point
- **One concern per rule**: Split large rules into focused pieces
- **Actionable**: Write like clear internal docs
- **Concrete examples**: Ideally provide concrete examples of how to fix issues

---

## Example Rules

### TypeScript Standards

```markdown
---
description: TypeScript coding standards
globs: **/*.ts
alwaysApply: false
---

# Error Handling

\`\`\`typescript
// ❌ BAD
try {
  await fetchData();
} catch (e) {}

// ✅ GOOD
try {
  await fetchData();
} catch (e) {
  logger.error('Failed to fetch', { error: e });
  throw new DataFetchError('Unable to retrieve data', { cause: e });
}
\`\`\`
```

### React Patterns

```markdown
---
description: React component patterns
globs: **/*.tsx
alwaysApply: false
---

# React Patterns

- Use functional components
- Extract custom hooks for reusable logic
- Colocate styles with components
```

---

## Checklist

- [ ] File is `.mdc` format in `.cursor/rules/`
- [ ] Frontmatter configured correctly
- [ ] Content under 500 lines
- [ ] Includes concrete examples

END_OF_FILE_CONTENT
mkdir -p ".cursor/skills-cursor/create-skill"
echo "Creating .cursor/skills-cursor/create-skill/SKILL.md..."
cat << 'END_OF_FILE_CONTENT' > ".cursor/skills-cursor/create-skill/SKILL.md"
---
name: create-skill
description: >-
  Guides users through creating effective Agent Skills for Cursor. Use when you
  want to create, write, or author a new skill, or asks about skill structure,
  best practices, or SKILL.md format.
---
# Creating Skills in Cursor

This skill guides you through creating effective Agent Skills for Cursor. Skills are markdown files that teach the agent how to perform specific tasks: reviewing PRs using team standards, generating commit messages in a preferred format, querying database schemas, or any specialized workflow.

## Before You Begin: Gather Requirements

Before creating a skill, gather essential information from the user about:

1. **Purpose and scope**: What specific task or workflow should this skill help with?
2. **Target location**: Should this be a personal skill (~/.cursor/skills/) or project skill (.cursor/skills/)?
3. **Trigger scenarios**: When should the agent automatically apply this skill?
4. **Key domain knowledge**: What specialized information does the agent need that it wouldn't already know?
5. **Output format preferences**: Are there specific templates, formats, or styles required?
6. **Existing patterns**: Are there existing examples or conventions to follow?

### Inferring from Context

If you have previous conversation context, infer the skill from what was discussed. You can create skills based on workflows, patterns, or domain knowledge that emerged in the conversation.

### Gathering Additional Information

If you need clarification, use the AskQuestion tool when available:

```
Example AskQuestion usage:
- "Where should this skill be stored?" with options like ["Personal (~/.cursor/skills/)", "Project (.cursor/skills/)"]
- "Should this skill include executable scripts?" with options like ["Yes", "No"]
```

If the AskQuestion tool is not available, ask these questions conversationally.

---

## Skill File Structure

### Directory Layout

Skills are stored as directories containing a `SKILL.md` file:

```
skill-name/
├── SKILL.md              # Required - main instructions
├── reference.md          # Optional - detailed documentation
├── examples.md           # Optional - usage examples
└── scripts/              # Optional - utility scripts
    ├── validate.py
    └── helper.sh
```

### Storage Locations

| Type | Path | Scope |
|------|------|-------|
| Personal | ~/.cursor/skills/skill-name/ | Available across all your projects |
| Project | .cursor/skills/skill-name/ | Shared with anyone using the repository |

**IMPORTANT**: Never create skills in `~/.cursor/skills-cursor/`. This directory is reserved for Cursor's internal built-in skills and is managed automatically by the system.

### SKILL.md Structure

Every skill requires a `SKILL.md` file with YAML frontmatter and markdown body:

```markdown
---
name: your-skill-name
description: Brief description of what this skill does and when to use it
---

# Your Skill Name

## Instructions
Clear, step-by-step guidance for the agent.

## Examples
Concrete examples of using this skill.
```

### Required Metadata Fields

| Field | Requirements | Purpose |
|-------|--------------|---------|
| `name` | Max 64 chars, lowercase letters/numbers/hyphens only | Unique identifier for the skill |
| `description` | Max 1024 chars, non-empty | Helps agent decide when to apply the skill |

---

## Writing Effective Descriptions

The description is **critical** for skill discovery. The agent uses it to decide when to apply your skill.

### Description Best Practices

1. **Write in third person** (the description is injected into the system prompt):
   - ✅ Good: "Processes Excel files and generates reports"
   - ❌ Avoid: "I can help you process Excel files"
   - ❌ Avoid: "You can use this to process Excel files"

2. **Be specific and include trigger terms**:
   - ✅ Good: "Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction."
   - ❌ Vague: "Helps with documents"

3. **Include both WHAT and WHEN**:
   - WHAT: What the skill does (specific capabilities)
   - WHEN: When the agent should use it (trigger scenarios)

### Description Examples

```yaml
# PDF Processing
description: Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDF files or when the user mentions PDFs, forms, or document extraction.

# Excel Analysis
description: Analyze Excel spreadsheets, create pivot tables, generate charts. Use when analyzing Excel files, spreadsheets, tabular data, or .xlsx files.

# Git Commit Helper
description: Generate descriptive commit messages by analyzing git diffs. Use when the user asks for help writing commit messages or reviewing staged changes.

# Code Review
description: Review code for quality, security, and best practices following team standards. Use when reviewing pull requests, code changes, or when the user asks for a code review.
```

---

## Core Authoring Principles

### 1. Concise is Key

The context window is shared with conversation history, other skills, and requests. Every token competes for space.

**Default assumption**: The agent is already very smart. Only add context it doesn't already have.

Challenge each piece of information:
- "Does the agent really need this explanation?"
- "Can I assume the agent knows this?"
- "Does this paragraph justify its token cost?"

**Good (concise)**:
```markdown
## Extract PDF text

Use pdfplumber for text extraction:

\`\`\`python
import pdfplumber

with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
\`\`\`
```

**Bad (verbose)**:
```markdown
## Extract PDF text

PDF (Portable Document Format) files are a common file format that contains
text, images, and other content. To extract text from a PDF, you'll need to
use a library. There are many libraries available for PDF processing, but we
recommend pdfplumber because it's easy to use and handles most cases well...
```

### 2. Keep SKILL.md Under 500 Lines

For optimal performance, the main SKILL.md file should be concise. Use progressive disclosure for detailed content.

### 3. Progressive Disclosure

Put essential information in SKILL.md; detailed reference material in separate files that the agent reads only when needed.

```markdown
# PDF Processing

## Quick start
[Essential instructions here]

## Additional resources
- For complete API details, see [reference.md](reference.md)
- For usage examples, see [examples.md](examples.md)
```

**Keep references one level deep** - link directly from SKILL.md to reference files. Deeply nested references may result in partial reads.

### 4. Set Appropriate Degrees of Freedom

Match specificity to the task's fragility:

| Freedom Level | When to Use | Example |
|---------------|-------------|---------|
| **High** (text instructions) | Multiple valid approaches, context-dependent | Code review guidelines |
| **Medium** (pseudocode/templates) | Preferred pattern with acceptable variation | Report generation |
| **Low** (specific scripts) | Fragile operations, consistency critical | Database migrations |

---

## Common Patterns

### Template Pattern

Provide output format templates:

```markdown
## Report structure

Use this template:

\`\`\`markdown
# [Analysis Title]

## Executive summary
[One-paragraph overview of key findings]

## Key findings
- Finding 1 with supporting data
- Finding 2 with supporting data

## Recommendations
1. Specific actionable recommendation
2. Specific actionable recommendation
\`\`\`
```

### Examples Pattern

For skills where output quality depends on seeing examples:

```markdown
## Commit message format

**Example 1:**
Input: Added user authentication with JWT tokens
Output:
\`\`\`
feat(auth): implement JWT-based authentication

Add login endpoint and token validation middleware
\`\`\`

**Example 2:**
Input: Fixed bug where dates displayed incorrectly
Output:
\`\`\`
fix(reports): correct date formatting in timezone conversion

Use UTC timestamps consistently across report generation
\`\`\`
```

### Workflow Pattern

Break complex operations into clear steps with checklists:

```markdown
## Form filling workflow

Copy this checklist and track progress:

\`\`\`
Task Progress:
- [ ] Step 1: Analyze the form
- [ ] Step 2: Create field mapping
- [ ] Step 3: Validate mapping
- [ ] Step 4: Fill the form
- [ ] Step 5: Verify output
\`\`\`

**Step 1: Analyze the form**
Run: \`python scripts/analyze_form.py input.pdf\`
...
```

### Conditional Workflow Pattern

Guide through decision points:

```markdown
## Document modification workflow

1. Determine the modification type:

   **Creating new content?** → Follow "Creation workflow" below
   **Editing existing content?** → Follow "Editing workflow" below

2. Creation workflow:
   - Use docx-js library
   - Build document from scratch
   ...
```

### Feedback Loop Pattern

For quality-critical tasks, implement validation loops:

```markdown
## Document editing process

1. Make your edits
2. **Validate immediately**: \`python scripts/validate.py output/\`
3. If validation fails:
   - Review the error message
   - Fix the issues
   - Run validation again
4. **Only proceed when validation passes**
```

---

## Utility Scripts

Pre-made scripts offer advantages over generated code:
- More reliable than generated code
- Save tokens (no code in context)
- Save time (no code generation)
- Ensure consistency across uses

```markdown
## Utility scripts

**analyze_form.py**: Extract all form fields from PDF
\`\`\`bash
python scripts/analyze_form.py input.pdf > fields.json
\`\`\`

**validate.py**: Check for errors
\`\`\`bash
python scripts/validate.py fields.json
# Returns: "OK" or lists conflicts
\`\`\`
```

Make clear whether the agent should **execute** the script (most common) or **read** it as reference.

---

## Anti-Patterns to Avoid

### 1. Windows-Style Paths
- ✅ Use: `scripts/helper.py`
- ❌ Avoid: `scripts\helper.py`

### 2. Too Many Options
```markdown
# Bad - confusing
"You can use pypdf, or pdfplumber, or PyMuPDF, or..."

# Good - provide a default with escape hatch
"Use pdfplumber for text extraction.
For scanned PDFs requiring OCR, use pdf2image with pytesseract instead."
```

### 3. Time-Sensitive Information
```markdown
# Bad - will become outdated
"If you're doing this before August 2025, use the old API."

# Good - use an "old patterns" section
## Current method
Use the v2 API endpoint.

## Old patterns (deprecated)
<details>
<summary>Legacy v1 API</summary>
...
</details>
```

### 4. Inconsistent Terminology
Choose one term and use it throughout:
- ✅ Always "API endpoint" (not mixing "URL", "route", "path")
- ✅ Always "field" (not mixing "box", "element", "control")

### 5. Vague Skill Names
- ✅ Good: `processing-pdfs`, `analyzing-spreadsheets`
- ❌ Avoid: `helper`, `utils`, `tools`

---

## Skill Creation Workflow

When helping a user create a skill, follow this process:

### Phase 1: Discovery

Gather information about:
1. The skill's purpose and primary use case
2. Storage location (personal vs project)
3. Trigger scenarios
4. Any specific requirements or constraints
5. Existing examples or patterns to follow

If you have access to the AskQuestion tool, use it for efficient structured gathering. Otherwise, ask conversationally.

### Phase 2: Design

1. Draft the skill name (lowercase, hyphens, max 64 chars)
2. Write a specific, third-person description
3. Outline the main sections needed
4. Identify if supporting files or scripts are needed

### Phase 3: Implementation

1. Create the directory structure
2. Write the SKILL.md file with frontmatter
3. Create any supporting reference files
4. Create any utility scripts if needed

### Phase 4: Verification

1. Verify the SKILL.md is under 500 lines
2. Check that the description is specific and includes trigger terms
3. Ensure consistent terminology throughout
4. Verify all file references are one level deep
5. Test that the skill can be discovered and applied

---

## Complete Example

Here's a complete example of a well-structured skill:

**Directory structure:**
```
code-review/
├── SKILL.md
├── STANDARDS.md
└── examples.md
```

**SKILL.md:**
```markdown
---
name: code-review
description: Review code for quality, security, and maintainability following team standards. Use when reviewing pull requests, examining code changes, or when the user asks for a code review.
---

# Code Review

## Quick Start

When reviewing code:

1. Check for correctness and potential bugs
2. Verify security best practices
3. Assess code readability and maintainability
4. Ensure tests are adequate

## Review Checklist

- [ ] Logic is correct and handles edge cases
- [ ] No security vulnerabilities (SQL injection, XSS, etc.)
- [ ] Code follows project style conventions
- [ ] Functions are appropriately sized and focused
- [ ] Error handling is comprehensive
- [ ] Tests cover the changes

## Providing Feedback

Format feedback as:
- 🔴 **Critical**: Must fix before merge
- 🟡 **Suggestion**: Consider improving
- 🟢 **Nice to have**: Optional enhancement

## Additional Resources

- For detailed coding standards, see [STANDARDS.md](STANDARDS.md)
- For example reviews, see [examples.md](examples.md)
```

---

## Summary Checklist

Before finalizing a skill, verify:

### Core Quality
- [ ] Description is specific and includes key terms
- [ ] Description includes both WHAT and WHEN
- [ ] Written in third person
- [ ] SKILL.md body is under 500 lines
- [ ] Consistent terminology throughout
- [ ] Examples are concrete, not abstract

### Structure
- [ ] File references are one level deep
- [ ] Progressive disclosure used appropriately
- [ ] Workflows have clear steps
- [ ] No time-sensitive information

### If Including Scripts
- [ ] Scripts solve problems rather than punt
- [ ] Required packages are documented
- [ ] Error handling is explicit and helpful
- [ ] No Windows-style paths

END_OF_FILE_CONTENT
mkdir -p ".cursor/skills-cursor/create-subagent"
echo "Creating .cursor/skills-cursor/create-subagent/SKILL.md..."
cat << 'END_OF_FILE_CONTENT' > ".cursor/skills-cursor/create-subagent/SKILL.md"
---
name: create-subagent
description: >-
  Create custom subagents for specialized AI tasks. Use when you want to create
  a new type of subagent, set up task-specific agents, configure code reviewers,
  debuggers, or domain-specific assistants with custom prompts.
disable-model-invocation: true
---
# Creating Custom Subagents

This skill guides you through creating custom subagents for Cursor. Subagents are specialized AI assistants that run in isolated contexts with custom system prompts.

## When to Use Subagents

Subagents help you:
- **Preserve context** by isolating exploration from your main conversation
- **Specialize behavior** with focused system prompts for specific domains
- **Reuse configurations** across projects with user-level subagents

### Inferring from Context

If you have previous conversation context, infer the subagent's purpose and behavior from what was discussed. Create the subagent based on specialized tasks or workflows that emerged in the conversation.

## Subagent Locations

| Location | Scope | Priority |
|----------|-------|----------|
| `.cursor/agents/` | Current project | Higher |
| `~/.cursor/agents/` | All your projects | Lower |

When multiple subagents share the same name, the higher-priority location wins.

**Project subagents** (`.cursor/agents/`): Ideal for codebase-specific agents. Check into version control to share with your team.

**User subagents** (`~/.cursor/agents/`): Personal agents available across all your projects.

## Subagent File Format

Create a `.md` file with YAML frontmatter and a markdown body (the system prompt):

```markdown
---
name: code-reviewer
description: Reviews code for quality and best practices
---

You are a code reviewer. When invoked, analyze the code and provide
specific, actionable feedback on quality, security, and best practices.
```

### Required Fields

| Field | Description |
|-------|-------------|
| `name` | Unique identifier (lowercase letters and hyphens only) |
| `description` | When to delegate to this subagent (be specific!) |

## Writing Effective Descriptions

The description is **critical** - the AI uses it to decide when to delegate.

```yaml
# ❌ Too vague
description: Helps with code

# ✅ Specific and actionable
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code.
```

Include "use proactively" to encourage automatic delegation.

## Example Subagents

### Code Reviewer

```markdown
---
name: code-reviewer
description: Expert code review specialist. Proactively reviews code for quality, security, and maintainability. Use immediately after writing or modifying code.
---

You are a senior code reviewer ensuring high standards of code quality and security.

When invoked:
1. Run git diff to see recent changes
2. Focus on modified files
3. Begin review immediately

Review checklist:
- Code is clear and readable
- Functions and variables are well-named
- No duplicated code
- Proper error handling
- No exposed secrets or API keys
- Input validation implemented
- Good test coverage
- Performance considerations addressed

Provide feedback organized by priority:
- Critical issues (must fix)
- Warnings (should fix)
- Suggestions (consider improving)

Include specific examples of how to fix issues.
```

### Debugger

```markdown
---
name: debugger
description: Debugging specialist for errors, test failures, and unexpected behavior. Use proactively when encountering any issues.
---

You are an expert debugger specializing in root cause analysis.

When invoked:
1. Capture error message and stack trace
2. Identify reproduction steps
3. Isolate the failure location
4. Implement minimal fix
5. Verify solution works

Debugging process:
- Analyze error messages and logs
- Check recent code changes
- Form and test hypotheses
- Add strategic debug logging
- Inspect variable states

For each issue, provide:
- Root cause explanation
- Evidence supporting the diagnosis
- Specific code fix
- Testing approach
- Prevention recommendations

Focus on fixing the underlying issue, not the symptoms.
```

### Data Scientist

```markdown
---
name: data-scientist
description: Data analysis expert for SQL queries, BigQuery operations, and data insights. Use proactively for data analysis tasks and queries.
---

You are a data scientist specializing in SQL and BigQuery analysis.

When invoked:
1. Understand the data analysis requirement
2. Write efficient SQL queries
3. Use BigQuery command line tools (bq) when appropriate
4. Analyze and summarize results
5. Present findings clearly

Key practices:
- Write optimized SQL queries with proper filters
- Use appropriate aggregations and joins
- Include comments explaining complex logic
- Format results for readability
- Provide data-driven recommendations

For each analysis:
- Explain the query approach
- Document any assumptions
- Highlight key findings
- Suggest next steps based on data

Always ensure queries are efficient and cost-effective.
```

## Subagent Creation Workflow

### Step 1: Decide the Scope

- **Project-level** (`.cursor/agents/`): For codebase-specific agents shared with team
- **User-level** (`~/.cursor/agents/`): For personal agents across all projects

### Step 2: Create the File

```bash
# For project-level
mkdir -p .cursor/agents
touch .cursor/agents/my-agent.md

# For user-level
mkdir -p ~/.cursor/agents
touch ~/.cursor/agents/my-agent.md
```

### Step 3: Define Configuration

Write the frontmatter with the required fields (`name` and `description`).

### Step 4: Write the System Prompt

The body becomes the system prompt. Be specific about:
- What the agent should do when invoked
- The workflow or process to follow
- Output format and structure
- Any constraints or guidelines

### Step 5: Test the Agent

Ask the AI to use your new agent:

```
Use the my-agent subagent to [task description]
```

## Best Practices

1. **Design focused subagents**: Each should excel at one specific task
2. **Write detailed descriptions**: Include trigger terms so the AI knows when to delegate
3. **Check into version control**: Share project subagents with your team
4. **Use proactive language**: Include "use proactively" in descriptions

## Troubleshooting

### Subagent Not Found
- Ensure file is in `.cursor/agents/` or `~/.cursor/agents/`
- Check file has `.md` extension
- Verify YAML frontmatter syntax is valid

END_OF_FILE_CONTENT
mkdir -p ".cursor/skills-cursor/jsonpages-tenant"
echo "Creating .cursor/skills-cursor/jsonpages-tenant/SKILL.md..."
cat << 'END_OF_FILE_CONTENT' > ".cursor/skills-cursor/jsonpages-tenant/SKILL.md"
---
name: jsonpages-tenant
description: Use when working on a JsonPages tenant, transforming the base tenant DNA into a branded tenant, adding or modifying tenant sections, maintaining schema-driven editability, or reasoning about what belongs to @jsonpages/core versus the tenant.
---

# JsonPages Tenant

Use this skill for work on the JsonPages ecosystem when the task involves:

- a tenant generated from the JsonPages CLI
- `@jsonpages/core`
- tenant sections/capsules
- `src/data/pages/**/*.json` or `src/data/config/*.json`
- schema-driven editing and inspector compatibility
- generator scripts that turn a base tenant into a branded tenant

Read code first. Treat documents as secondary unless they help interpret code that is otherwise ambiguous.

## Core Model

JsonPages has a hard split between `core` and `tenant`.

- `@jsonpages/core` owns routing, `/admin`, `/admin/preview`, preview stage, studio state, inspector/form factory, and shared engine behavior.
- The tenant owns sections, schemas, type augmentation, page/config JSON, theme/design layer, and local workflow scripts.
- The tenant does not implement the CMS. It implements the tenant protocol consumed by the engine.

In this ecosystem, code is the source of truth.

Compliance priority:

1. Data is bound correctly.
2. Schemas describe fields correctly.
3. Content is editable without breaking the inspector.
4. Tenant structure stays standardized.
5. Context-aware focus/highlight in the legacy admin is desirable but secondary.

## Canonical References

Use these local references when available:

- Base tenant DNA: `\\wsl.localhost\Ubuntu\home\dev\temp\alpha`
- Custom tenant reference: `\\wsl.localhost\Ubuntu\home\dev\temp\gptgiorgio`
- Core engine: `\\wsl.localhost\Ubuntu\home\dev\npm-jpcore\packages\core`
- Generator example: `\\wsl.localhost\Ubuntu\home\dev\temp\clonark\generate_olon.sh`

If these paths are missing, infer the same roles from the current workspace:

- base CLI-generated tenant
- branded tenant
- core package
- generator script

## Tenant Anatomy

Expect these files to move together:

- `src/components/<section>/View.tsx`
- `src/components/<section>/schema.ts`
- `src/components/<section>/types.ts`
- `src/components/<section>/index.ts`
- `src/lib/ComponentRegistry.tsx`
- `src/lib/schemas.ts`
- `src/lib/addSectionConfig.ts`
- `src/types.ts`
- `src/data/pages/**/*.json`
- `src/data/config/site.json`
- `src/data/config/theme.json`
- `src/data/config/menu.json`

Useful rule: if a section type changes, check all of the files above before concluding the task is done.

## What Good Work Looks Like

A good tenant change:

- stays inside tenant boundaries unless the issue is truly in `@jsonpages/core`
- keeps schema, defaults, registry, and type augmentation aligned
- preserves editability for strings, lists, nested objects, CTAs, and image fields
- uses `ImageSelectionSchema`-style image fields when the content is image-driven
- keeps page content JSON-first

A suspicious tenant change:

- patches the core to fix a tenant modeling problem
- adds visual complexity without data bindings
- introduces fields into JSON that are not represented in schema
- changes a section view without updating defaults or types
- optimizes legacy context awareness at the expense of simpler, reliable editability

## Workflow 1: Base Tenant -> Branded Tenant

This is the primary workflow.

Goal:

- transform a CLI-generated base tenant into a branded tenant through a single generator script

Treat the generator script as procedural source of truth for the green build workflow.

When maintaining or authoring a generator:

1. Separate non-deterministic bootstrap from deterministic sync.
2. Make explicit which files are managed output.
3. Keep the script aligned with the current tenant code, not with stale docs.
4. Preserve tenant protocol files: sections, schemas, registries, type augmentation, config JSON, assets, shims.
5. Prefer deterministic local writes after any remote/bootstrap step.

Typical structure of a good generator:

- preflight checks
- remote/bootstrap steps such as `shadcn` or external registries
- deterministic creation/sync of tenant files
- compatibility patches for known unstable upstream payloads
- final validation commands

When asked to update a branded tenant generator:

1. Diff base tenant against branded tenant.
2. Classify differences into:
   - intended branded output
   - reusable generator logic
   - accidental drift
3. Encode only the reusable intended differences into the script.
4. Keep the output reproducible from a fresh base tenant.

## Workflow 2: Add Or Change A Section

When adding a new section type:

1. Create `View.tsx`, `schema.ts`, `types.ts`, `index.ts`.
2. Register the section in `src/lib/ComponentRegistry.tsx`.
3. Register the schema in `src/lib/schemas.ts`.
4. Add defaults and label in `src/lib/addSectionConfig.ts`.
5. Extend `SectionComponentPropsMap` and module augmentation in `src/types.ts`.
6. Add or update page JSON using the new section type.

When changing an existing section:

1. Read the section schema first.
2. Read the page JSON using it.
3. Check the view for `data-jp-field` usage and binding shape.
4. Update defaults if the data shape changed.
5. Verify the inspector still has a path to edit the content.

## Workflow 3: Images, Rich Content, Nested Routes

Images:

- Prefer structured image objects compatible with tenant base schemas.
- Assume the core supports image picking and upload flows.
- The tenant is responsible for declaring image fields in schema and rendering them coherently.

Rich editorial content:

- Tiptap-style sections are tenant-level integrations.
- Treat page JSON using `type: "tiptap"` as runtime usage examples, and section code as the real source of truth.

Nested routes:

- Files under `src/data/pages/**/*.json` may represent nested slugs.
- Preserve slug/path consistency and do not replace file-based routing with manual lists.

## Decision Rules

Use `alpha` patterns when the task is about:

- tenant DNA
- capability reference
- baseline protocol shape
- proving what the base system already supports

Use `gptgiorgio` patterns when the task is about:

- stronger branded frontend customization
- richer domain-specific sections
- image-heavy schema design
- proving how far customization can go without changing the bootstrap

Do not treat `gptgiorgio` as canonical for legacy admin context awareness.

## Default Operating Procedure

When you receive a JsonPages tenant task:

1. Identify whether the problem belongs to `core`, tenant, or generator.
2. Read the smallest code surface that proves it.
3. Prefer fixing the tenant contract before touching visual polish.
4. Keep generated and deterministic workflows reproducible.
5. State assumptions when inferring intended branded output from examples.

END_OF_FILE_CONTENT
mkdir -p ".cursor/skills-cursor/migrate-to-skills"
echo "Creating .cursor/skills-cursor/migrate-to-skills/SKILL.md..."
cat << 'END_OF_FILE_CONTENT' > ".cursor/skills-cursor/migrate-to-skills/SKILL.md"
---
name: migrate-to-skills
description: >-
  Convert 'Applied intelligently' Cursor rules (.cursor/rules/*.mdc) and slash
  commands (.cursor/commands/*.md) to Agent Skills format (.cursor/skills/). Use
  when you want to migrate rules or commands to skills, convert .mdc rules to
  SKILL.md format, or consolidate commands into the skills directory.
disable-model-invocation: true
---
# Migrate Rules and Slash Commands to Skills

Convert Cursor rules ("Applied intelligently") and slash commands to Agent Skills format.

**CRITICAL: Preserve the exact body content. Do not modify, reformat, or "improve" it - copy verbatim.**

## Locations

| Level | Source | Destination |
|-------|--------|-------------|
| Project | `{workspaceFolder}/**/.cursor/rules/*.mdc`, `{workspaceFolder}/.cursor/commands/*.md` |
| User | `~/.cursor/commands/*.md` |

Notes:
- Cursor rules inside the project can live in nested directories. Be thorough in your search and use glob patterns to find them.
- Ignore anything in ~/.cursor/worktrees
- Ignore anything in ~/.cursor/skills-cursor. This is reserved for Cursor's internal built-in skills and is managed automatically by the system.

## Finding Files to Migrate

**Rules**: Migrate if rule has a `description` but NO `globs` and NO `alwaysApply: true`.

**Commands**: Migrate all - they're plain markdown without frontmatter.

## Conversion Format

### Rules: .mdc → SKILL.md

```markdown
# Before: .cursor/rules/my-rule.mdc
---
description: What this rule does
globs:
alwaysApply: false
---
# Title
Body content...
```

```markdown
# After: .cursor/skills/my-rule/SKILL.md
---
name: my-rule
description: What this rule does
---
# Title
Body content...
```

Changes: Add `name` field, remove `globs`/`alwaysApply`, keep body exactly.

### Commands: .md → SKILL.md

```markdown
# Before: .cursor/commands/commit.md
# Commit current work
Instructions here...
```

```markdown
# After: .cursor/skills/commit/SKILL.md
---
name: commit
description: Commit current work with standardized message format
disable-model-invocation: true
---
# Commit current work
Instructions here...
```

Changes: Add frontmatter with `name` (from filename), `description` (infer from content), and `disable-model-invocation: true`, keep body exactly.

**Note:** The `disable-model-invocation: true` field prevents the model from automatically invoking this skill. Slash commands are designed to be explicitly triggered by the user via the `/` menu, not automatically suggested by the model.

## Notes

- `name` must be lowercase with hyphens only
- `description` is critical for skill discovery
- Optionally delete originals after verifying migration works

### Migrate a Rule (.mdc → SKILL.md)

1. Read the rule file
2. Extract the `description` from the frontmatter
3. Extract the body content (everything after the closing `---` of the frontmatter)
4. Create the skill directory: `.cursor/skills/{skill-name}/` (skill name = filename without .mdc)
5. Write `SKILL.md` with new frontmatter (`name` and `description`) + the EXACT original body content (preserve all whitespace, formatting, code blocks verbatim)
6. Delete the original rule file

### Migrate a Command (.md → SKILL.md)

1. Read the command file
2. Extract description from the first heading (remove `#` prefix)
3. Create the skill directory: `.cursor/skills/{skill-name}/` (skill name = filename without .md)
4. Write `SKILL.md` with new frontmatter (`name`, `description`, and `disable-model-invocation: true`) + blank line + the EXACT original file content (preserve all whitespace, formatting, code blocks verbatim)
5. Delete the original command file

**CRITICAL: Copy the body content character-for-character. Do not reformat, fix typos, or "improve" anything.**

## Workflow

If you have the Task tool available:
DO NOT start to read all of the files yourself. That function should be delegated to the subagents. Your job is to dispatch the subagents for each category of files and wait for the results.

1. [ ] Create the skills directories if they don't exist (`.cursor/skills/` for project, `~/.cursor/skills/` for user)
2. Dispatch three fast general purpose subagents (NOT explore) in parallel to do the following steps for project rules (pattern: `{workspaceFolder}/**/.cursor/rules/*.mdc`), user commands (pattern: `~/.cursor/commands/*.md`), and project commands (pattern: `{workspaceFolder}/**/.cursor/commands/*.md`):
  I. [ ] Find files to migrate in the given pattern
  II. [ ] For rules, check if it's an "applied intelligently" rule (has `description`, no `globs`, no `alwaysApply: true`). Commands are always migrated. DO NOT use the terminal to read files. Use the read tool.
  III. [ ] Make a list of files to migrate. If empty, done.
  IV. [ ] For each file, read it, then write the new skill file preserving the body content EXACTLY. DO NOT use the terminal to write these files. Use the edit tool.
  V. [ ] Delete the original file. DO NOT use the terminal to delete these files. Use the delete tool.
  VI. [ ] Return a list of all the skill files that were migrated along with the original file paths.
3. [ ] Wait for all subagents to complete and summarize the results to the user. IMPORTANT: Make sure to let them know if they want to undo the migration, to ask you to.
4. [ ] If the user asks you to undo the migration, do the opposite of the above steps to restore the original files.


If you don't have the Task tool available:
1. [ ] Create the skills directories if they don't exist (`.cursor/skills/` for project, `~/.cursor/skills/` for user)
2. [ ] Find files to migrate in both project (`.cursor/`) and user (`~/.cursor/`) directories
3. [ ] For rules, check if it's an "applied intelligently" rule (has `description`, no `globs`, no `alwaysApply: true`). Commands are always migrated. DO NOT use the terminal to read files. Use the read tool.
4. [ ] Make a list of files to migrate. If empty, done.
5. [ ] For each file, read it, then write the new skill file preserving the body content EXACTLY. DO NOT use the terminal to write these files. Use the edit tool.
6. [ ] Delete the original file. DO NOT use the terminal to delete these files. Use the delete tool.
7. [ ] Summarize the results to the user. IMPORTANT: Make sure to let them know if they want to undo the migration, to ask you to.
8. [ ] If the user asks you to undo the migration, do the opposite of the above steps to restore the original files.

END_OF_FILE_CONTENT
mkdir -p ".cursor/skills-cursor/olonjs"
echo "Creating .cursor/skills-cursor/olonjs/SKILL.md..."
cat << 'END_OF_FILE_CONTENT' > ".cursor/skills-cursor/olonjs/SKILL.md"
---
name: olonjs-tenant
description: Use when working on a OlonJS tenant, transforming the base tenant DNA into a branded tenant, adding or modifying tenant sections, maintaining schema-driven editability, or reasoning about what belongs to @olonjs/core versus the tenant.
---

# OlonJS Tenant

Use this skill for work on the OlonJS ecosystem when the task involves:

- a tenant generated from the OlonJS CLI
- `@olonjs/core`
- tenant sections/capsules
- `src/data/pages/**/*.json` or `src/data/config/*.json`
- schema-driven editing and inspector compatibility
- generator scripts that turn a base tenant into a branded tenant

Read code first. Treat documents as secondary unless they help interpret code that is otherwise ambiguous.

## Architecture Specifications 

**Normative:** OlonJS Architecture Specifications **v1.5** (`olonjsSpecs_V_1_5.md`): three-layer CSS theme bridge (engine → `:root` → `@theme`), `ThemeConfig` / appendix A.2.6, path-based Studio selection (`itemPath`), local tokens (`--local-*`), IDAC, TOCC, JSP, TBP, CIP, ECIP, JEB, JAP.

Use this document as the architectural law for each tenant; compliance is judged against it:

- `\\wsl.localhost\Ubuntu\home\dev\npm-jpcore\specs\olonjsSpecs_V_1_5.md`




## Core Model

OlonJS has a hard split between `core` and `tenant`.

- `@olonjs/core` owns routing, `/admin`, `/admin/preview`, preview stage, studio state, inspector/form factory, and shared engine behavior.
- The tenant owns sections, schemas, type augmentation, page/config JSON, theme/design layer, and local workflow scripts.
- The tenant does not implement the CMS. It implements the tenant protocol consumed by the engine.

In this ecosystem, code is the source of truth.

Compliance priority:

1. Data is bound correctly.
2. Schemas describe fields correctly.
3. Content is editable without breaking the inspector.
4. Tenant structure stays standardized.
5. Context-aware focus/highlight in the legacy admin is desirable but secondary.

## Canonical References

Use these local references when available:

- Base tenant DNA: `\\wsl.localhost\Ubuntu\home\dev\temp\alpha`
- Custom tenant reference: `\\wsl.localhost\Ubuntu\home\dev\temp\gptgiorgio`
- Core engine: `\\wsl.localhost\Ubuntu\home\dev\npm-jpcore\packages\core`
- Generator example: `\\wsl.localhost\Ubuntu\home\dev\temp\clonark\generate_olon.sh`

If these paths are missing, infer the same roles from the current workspace:

- base CLI-generated tenant
- branded tenant
- core package
- generator script

## Tenant Anatomy

Expect these files to move together:

- `src/components/<section>/View.tsx`
- `src/components/<section>/schema.ts`
- `src/components/<section>/types.ts`
- `src/components/<section>/index.ts`
- `src/lib/ComponentRegistry.tsx`
- `src/lib/schemas.ts`
- `src/lib/addSectionConfig.ts`
- `src/types.ts`
- `src/data/pages/**/*.json`
- `src/data/config/site.json`
- `src/data/config/theme.json`
- `src/data/config/menu.json`

Useful rule: if a section type changes, check all of the files above before concluding the task is done.

## What Good Work Looks Like

A good tenant change:

- stays inside tenant boundaries unless the issue is truly in `@olonjs/core`
- keeps schema, defaults, registry, and type augmentation aligned
- preserves editability for strings, lists, nested objects, CTAs, and image fields
- uses `ImageSelectionSchema`-style image fields when the content is image-driven
- keeps page content JSON-first

A suspicious tenant change:

- patches the core to fix a tenant modeling problem
- adds visual complexity without data bindings
- introduces fields into JSON that are not represented in schema
- changes a section view without updating defaults or types
- optimizes legacy context awareness at the expense of simpler, reliable editability

## Workflow 1: Base Tenant -> Branded Tenant

This is the primary workflow.

Goal:

- transform a CLI-generated base tenant into a branded tenant through a single generator script

Treat the generator script as procedural source of truth for the green build workflow.

When maintaining or authoring a generator:

1. Separate non-deterministic bootstrap from deterministic sync.
2. Make explicit which files are managed output.
3. Keep the script aligned with the current tenant code, not with stale docs.
4. Preserve tenant protocol files: sections, schemas, registries, type augmentation, config JSON, assets, shims.
5. Prefer deterministic local writes after any remote/bootstrap step.

Typical structure of a good generator:

- preflight checks
- remote/bootstrap steps such as `shadcn` or external registries
- deterministic creation/sync of tenant files
- compatibility patches for known unstable upstream payloads
- final validation commands

When asked to update a branded tenant generator:

1. Diff base tenant against branded tenant.
2. Classify differences into:
   - intended branded output
   - reusable generator logic
   - accidental drift
3. Encode only the reusable intended differences into the script.
4. Keep the output reproducible from a fresh base tenant.

## Workflow 2: Add Or Change A Section

When adding a new section type:

1. Create `View.tsx`, `schema.ts`, `types.ts`, `index.ts`.
2. Register the section in `src/lib/ComponentRegistry.tsx`.
3. Register the schema in `src/lib/schemas.ts`.
4. Add defaults and label in `src/lib/addSectionConfig.ts`.
5. Extend `SectionComponentPropsMap` and module augmentation in `src/types.ts`.
6. Add or update page JSON using the new section type.

When changing an existing section:

1. Read the section schema first.
2. Read the page JSON using it.
3. Check the view for `data-jp-field` usage and binding shape.
4. Update defaults if the data shape changed.
5. Verify the inspector still has a path to edit the content.

## Workflow 3: Images, Rich Content, Nested Routes

Images:

- Prefer structured image objects compatible with tenant base schemas.
- Assume the core supports image picking and upload flows.
- The tenant is responsible for declaring image fields in schema and rendering them coherently.

Rich editorial content:

- Tiptap-style sections are tenant-level integrations.
- Treat page JSON using `type: "tiptap"` as runtime usage examples, and section code as the real source of truth.

Nested routes:

- Files under `src/data/pages/**/*.json` may represent nested slugs.
- Preserve slug/path consistency and do not replace file-based routing with manual lists.

## Decision Rules

Use `alpha` patterns when the task is about:

- tenant DNA
- capability reference
- baseline protocol shape
- proving what the base system already supports

Use `gptgiorgio` patterns when the task is about:

- stronger branded frontend customization
- richer domain-specific sections
- image-heavy schema design
- proving how far customization can go without changing the bootstrap

Do not treat `gptgiorgio` as canonical for legacy admin context awareness.

## Default Operating Procedure

When you receive a OlonJS tenant task:

1. Identify whether the problem belongs to `core`, tenant, or generator.
2. Read the smallest code surface that proves it.
3. Prefer fixing the tenant contract before touching visual polish.
4. Keep generated and deterministic workflows reproducible.
5. State assumptions when inferring intended branded output from examples.

END_OF_FILE_CONTENT
mkdir -p ".cursor/skills-cursor/shell"
echo "Creating .cursor/skills-cursor/shell/SKILL.md..."
cat << 'END_OF_FILE_CONTENT' > ".cursor/skills-cursor/shell/SKILL.md"
---
name: shell
description: >-
  Runs the rest of a /shell request as a literal shell command. Use only when
  the user explicitly invokes /shell and wants the following text executed
  directly in the terminal.
disable-model-invocation: true
---
# Run Shell Commands

Use this skill only when the user explicitly invokes `/shell`.

## Behavior

1. Treat all user text after the `/shell` invocation as the literal shell command to run.
2. Execute that command immediately with the terminal tool.
3. Do not rewrite, explain, or "improve" the command before running it.
4. Do not inspect the repository first unless the command itself requires repository context.
5. If the user invokes `/shell` without any following text, ask them which command to run.

## Response

- Run the command first.
- Then briefly report the exit status and any important stdout or stderr.

END_OF_FILE_CONTENT
mkdir -p ".cursor/skills-cursor/update-cursor-settings"
echo "Creating .cursor/skills-cursor/update-cursor-settings/SKILL.md..."
cat << 'END_OF_FILE_CONTENT' > ".cursor/skills-cursor/update-cursor-settings/SKILL.md"
---
name: update-cursor-settings
description: >-
  Modify Cursor/VSCode user settings in settings.json. Use when you want to
  change editor settings, preferences, configuration, themes, font size, tab
  size, format on save, auto save, keybindings, or any settings.json values.
---
# Updating Cursor Settings

This skill guides you through modifying Cursor/VSCode user settings. Use this when you want to change editor settings, preferences, configuration, themes, keybindings, or any `settings.json` values.

## Settings File Location

| OS | Path |
|----|------|
| macOS | ~/Library/Application Support/Cursor/User/settings.json |
| Linux | ~/.config/Cursor/User/settings.json |
| Windows | %APPDATA%\Cursor\User\settings.json |

## Before Modifying Settings

1. **Read the existing settings file** to understand current configuration
2. **Preserve existing settings** - only add/modify what the user requested
3. **Validate JSON syntax** before writing to avoid breaking the editor

## Modifying Settings

### Step 1: Read Current Settings

```typescript
// Read the settings file first
const settingsPath = "~/Library/Application Support/Cursor/User/settings.json";
// Use the Read tool to get current contents
```

### Step 2: Identify the Setting to Change

Common setting categories:
- **Editor**: `editor.fontSize`, `editor.tabSize`, `editor.wordWrap`, `editor.formatOnSave`
- **Workbench**: `workbench.colorTheme`, `workbench.iconTheme`, `workbench.sideBar.location`
- **Files**: `files.autoSave`, `files.exclude`, `files.associations`
- **Terminal**: `terminal.integrated.fontSize`, `terminal.integrated.shell.*`
- **Cursor-specific**: Settings prefixed with `cursor.` or `aipopup.`

### Step 3: Update the Setting

When modifying settings.json:
1. Parse the existing JSON (handle comments - VSCode settings support JSON with comments)
2. Add or update the requested setting
3. Preserve all other existing settings
4. Write back with proper formatting (2-space indentation)

### Example: Changing Font Size

If user says "make the font bigger":

```json
{
  "editor.fontSize": 16
}
```

### Example: Enabling Format on Save

If user says "format my code when I save":

```json
{
  "editor.formatOnSave": true
}
```

### Example: Changing Theme

If user says "use dark theme" or "change my theme":

```json
{
  "workbench.colorTheme": "Default Dark Modern"
}
```

## Important Notes

1. **JSON with Comments**: VSCode/Cursor settings.json supports comments (`//` and `/* */`). When reading, be aware comments may exist. When writing, preserve comments if possible.

2. **Restart May Be Required**: Some settings take effect immediately, others require reloading the window or restarting Cursor. Inform the user if a restart is needed.

3. **Backup**: For significant changes, consider mentioning the user can undo via Ctrl/Cmd+Z in the settings file or by reverting git changes if tracked.

4. **Workspace vs User Settings**:
   - User settings (what this skill covers): Apply globally to all projects
   - Workspace settings (`.vscode/settings.json`): Apply only to the current project

5. **Commit Attribution**: When the user asks about commit attribution, clarify whether they want to edit the **CLI agent** or the **IDE agent**. For the CLI agent, modify `~/.cursor/cli-config.json`. For the IDE agent, it is controlled from the UI at **Cursor Settings > Agent > Attribution** (not settings.json).

## Common User Requests → Settings

| User Request | Setting |
|--------------|---------|
| "bigger/smaller font" | `editor.fontSize` |
| "change tab size" | `editor.tabSize` |
| "format on save" | `editor.formatOnSave` |
| "word wrap" | `editor.wordWrap` |
| "change theme" | `workbench.colorTheme` |
| "hide minimap" | `editor.minimap.enabled` |
| "auto save" | `files.autoSave` |
| "line numbers" | `editor.lineNumbers` |
| "bracket matching" | `editor.bracketPairColorization.enabled` |
| "cursor style" | `editor.cursorStyle` |
| "smooth scrolling" | `editor.smoothScrolling` |

## Workflow

1. Read ~/Library/Application Support/Cursor/User/settings.json
2. Parse the JSON content
3. Add/modify the requested setting(s)
4. Write the updated JSON back to the file
5. Inform the user the setting has been changed and whether a reload is needed

END_OF_FILE_CONTENT
echo "Creating components.json..."
cat << 'END_OF_FILE_CONTENT' > "components.json"
{
  "$schema": "https://ui.shadcn.com/schema.json",
  "style": "radix-nova",
  "rsc": false,
  "tsx": true,
  "tailwind": {
    "config": "",
    "css": "src/index.css",
    "baseColor": "zinc",
    "cssVariables": true,
    "prefix": ""
  },
  "iconLibrary": "lucide",
  "rtl": false,
  "aliases": {
    "components": "@/components",
    "utils": "@/lib/utils",
    "ui": "@/components/ui",
    "lib": "@/lib",
    "hooks": "@/hooks"
  },
  "menuColor": "default",
  "menuAccent": "bold",
  "registries": {}
}



END_OF_FILE_CONTENT
echo "Creating index.html..."
cat << 'END_OF_FILE_CONTENT' > "index.html"
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <meta name="description" content="Olon — Agentic Content Infrastructure" />
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Geist+Mono:wght@100..900&family=Instrument+Sans:ital,wght@0,400..700;1,400..700&family=Merriweather:ital,opsz,wght@0,18..144,300..900;1,18..144,300..900&display=swap" rel="stylesheet">
    <title>Olon</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.tsx"></script>
  </body>
</html>


END_OF_FILE_CONTENT
echo "Creating package.json..."
cat << 'END_OF_FILE_CONTENT' > "package.json"
{
  "name": "tenant-alpha",
  "version": "1.0.104",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "dev:clean": "vite --force",
    "verify:webmcp": "node scripts/webmcp-feature-check.mjs",
    "prebuild": "node scripts/sync-pages-to-public.mjs && node scripts/generate-llms-txt.mjs",
    "build": "tsc && vite build",
    "dist": "bash ./src2Code.sh --template alpha src .cursor vercel.json components.json index.html tsconfig.json package.json tsconfig.node.json vite.config.ts scripts ",
    "preview": "vite preview",
    "bake:email": "tsx scripts/bake-email.tsx",
    "bakemail": "npm run bake:email --",
    "dist:dna": "npm run dist"
  },
  "dependencies": {
    "@tiptap/extension-image": "^2.11.5",
    "@tiptap/extension-link": "^2.11.5",
    "@tiptap/react": "^2.11.5",
    "@tiptap/starter-kit": "^2.11.5",
    "@olonjs/core": "^1.1.1",
    "class-variance-authority": "^0.7.1",
    "clsx": "^2.1.1",
    "lucide-react": "^0.474.0",
    "motion": "^12.23.24",
    "react": "^19.0.0",
    "react-markdown": "^9.0.1",
    "react-dom": "^19.0.0",
    "react-router-dom": "^6.30.3",
    "rehype-sanitize": "^6.0.0",
    "remark-gfm": "^4.0.1",
    "tailwind-merge": "^3.0.1",
    "tiptap-markdown": "^0.8.10",
    "zod": "^3.24.1"
  },
  "devDependencies": {
    "@tailwindcss/vite": "^4.0.0",
    "@types/react": "^19.0.8",
    "@types/react-dom": "^19.0.3",
    "@vitejs/plugin-react": "^4.3.4",
    "typescript": "^5.7.3",
    "vite": "^6.0.11",
    "@react-email/components": "^0.0.41",
    "@react-email/render": "^1.0.5",
    "tsx": "^4.20.5"
  }
}

END_OF_FILE_CONTENT
mkdir -p "scripts"
echo "Creating scripts/bake-email.tsx..."
cat << 'END_OF_FILE_CONTENT' > "scripts/bake-email.tsx"
import fs from "node:fs/promises";
import path from "node:path";
import { pathToFileURL } from "node:url";
import { render } from "@react-email/render";
import React from "react";

type Args = {
  entry?: string;
  out?: string;
  outDir?: string;
  exportName?: string;
  propsFile?: string;
  siteConfig?: string;
  themeConfig?: string;
};

type BakeTarget = {
  entryAbs: string;
  outAbs: string;
};

type SiteConfig = {
  identity?: {
    title?: string;
    logoUrl?: string;
  };
  header?: {
    data?: {
      logoImageUrl?: {
        url?: string;
        alt?: string;
      };
    };
  };
  footer?: {
    data?: {
      brandText?: string;
      brandHighlight?: string;
      tagline?: string;
      logoImageUrl?: {
        url?: string;
        alt?: string;
      };
    };
  };
};

type ThemeConfig = {
  tokens?: {
    colors?: Record<string, string>;
    typography?: {
      fontFamily?: Record<string, string>;
    };
    borderRadius?: Record<string, string>;
  };
};

const DEFAULT_EMAIL_DIR = "src/emails";
const DEFAULT_OUT_DIR = "email-templates";
const DEFAULT_SITE_CONFIG = "src/data/config/site.json";
const DEFAULT_THEME_CONFIG = "src/data/config/theme.json";

function parseArgs(argv: string[]): Args {
  const args: Args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    const next = argv[i + 1];
    if (!next) continue;
    if (key === "--entry") {
      args.entry = next;
      i += 1;
      continue;
    }
    if (key === "--out") {
      args.out = next;
      i += 1;
      continue;
    }
    if (key === "--out-dir") {
      args.outDir = next;
      i += 1;
      continue;
    }
    if (key === "--export") {
      args.exportName = next;
      i += 1;
      continue;
    }
    if (key === "--props") {
      args.propsFile = next;
      i += 1;
      continue;
    }
    if (key === "--site-config") {
      args.siteConfig = next;
      i += 1;
      continue;
    }
    if (key === "--theme-config") {
      args.themeConfig = next;
      i += 1;
    }
  }
  return args;
}

function isComponentExport(value: unknown): value is React.ComponentType<any> {
  return typeof value === "function";
}

function toKebabCase(value: string): string {
  return value
    .replace(/Email$/i, "")
    .replace(/([a-z0-9])([A-Z])/g, "$1-$2")
    .replace(/[_\s]+/g, "-")
    .toLowerCase();
}

function deriveOutAbs(entryAbs: string, outDirAbs: string): string {
  const base = path.basename(entryAbs).replace(/\.[^.]+$/, "");
  const fileName = `${toKebabCase(base)}.html`;
  return path.join(outDirAbs, fileName);
}

async function discoverEmailEntries(rootDir: string): Promise<string[]> {
  const abs = path.resolve(process.cwd(), rootDir);
  const dirEntries = await fs.readdir(abs, { withFileTypes: true }).catch(() => []);
  return dirEntries
    .filter((entry) => entry.isFile())
    .map((entry) => entry.name)
    .filter((name) => /\.(tsx|jsx)$/i.test(name))
    .map((name) => path.join(abs, name));
}

function normalizeUrl(value: string | undefined): string | undefined {
  if (!value) return undefined;
  const trimmed = value.trim();
  return trimmed || undefined;
}

async function readJsonObject<T>(filePath: string): Promise<T | null> {
  const abs = path.resolve(process.cwd(), filePath);
  const raw = await fs.readFile(abs, "utf8").catch(() => null);
  if (!raw) return null;
  const parsed = JSON.parse(raw);
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return null;
  return parsed as T;
}

function buildDefaultProps(site: SiteConfig | null, theme: ThemeConfig | null): Record<string, unknown> {
  const footerBrandText = site?.footer?.data?.brandText?.trim() ?? "";
  const footerBrandHighlight = site?.footer?.data?.brandHighlight?.trim() ?? "";
  const brandName = `${footerBrandText}${footerBrandHighlight}`.trim() || "{{tenantName}}";

  const tenantName = site?.identity?.title?.trim() || brandName;
  const logoUrl =
    normalizeUrl(site?.header?.data?.logoImageUrl?.url) ||
    normalizeUrl(site?.footer?.data?.logoImageUrl?.url) ||
    normalizeUrl(site?.identity?.logoUrl) ||
    "";
  const logoAlt =
    site?.header?.data?.logoImageUrl?.alt?.trim() ||
    site?.footer?.data?.logoImageUrl?.alt?.trim() ||
    brandName;
  const tagline = site?.footer?.data?.tagline?.trim() || "";

  return {
    tenantName,
    brandName,
    logoUrl,
    logoAlt,
    tagline,
    theme: theme?.tokens ?? {},
    correlationId: "{{correlationId}}",
    replyTo: "{{replyTo}}",
    leadData: {
      name: "{{lead.name}}",
      email: "{{lead.email}}",
      phone: "{{lead.phone}}",
      checkin: "{{lead.checkin}}",
      checkout: "{{lead.checkout}}",
      guests: "{{lead.guests}}",
      notes: "{{lead.notes}}",
    },
  };
}

async function readProps(
  propsFile: string | undefined,
  siteConfigPath: string,
  themeConfigPath: string
): Promise<Record<string, unknown>> {
  if (propsFile) {
    const raw = await fs.readFile(path.resolve(process.cwd(), propsFile), "utf8");
    const parsed = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
      throw new Error("--props must point to a JSON object file");
    }
    return parsed as Record<string, unknown>;
  }

  const site = await readJsonObject<SiteConfig>(siteConfigPath);
  const theme = await readJsonObject<ThemeConfig>(themeConfigPath);
  return buildDefaultProps(site, theme);
}

async function buildTargets(args: Args): Promise<BakeTarget[]> {
  const outDirAbs = path.resolve(process.cwd(), args.outDir ?? DEFAULT_OUT_DIR);

  if (args.entry) {
    const entryAbs = path.resolve(process.cwd(), args.entry);
    const outAbs = args.out ? path.resolve(process.cwd(), args.out) : deriveOutAbs(entryAbs, outDirAbs);
    return [{ entryAbs, outAbs }];
  }

  const discovered = await discoverEmailEntries(DEFAULT_EMAIL_DIR);
  if (discovered.length === 0) {
    throw new Error(`No templates found in ${DEFAULT_EMAIL_DIR}`);
  }

  return discovered.map((entryAbs) => ({
    entryAbs,
    outAbs: deriveOutAbs(entryAbs, outDirAbs),
  }));
}

async function bakeTemplate(target: BakeTarget, args: Args, props: Record<string, unknown>) {
  const moduleUrl = pathToFileURL(target.entryAbs).href;
  const mod = (await import(moduleUrl)) as Record<string, unknown>;
  const picked = args.exportName ? mod[args.exportName] : mod.default;

  if (!isComponentExport(picked)) {
    const available = Object.keys(mod).join(", ") || "(none)";
    throw new Error(
      `Template export not found or not a component. Requested: ${args.exportName ?? "default"}. Available exports: ${available}. Entry: ${target.entryAbs}`
    );
  }

  const element = React.createElement(picked, props);
  const html = await render(element, { pretty: true });

  await fs.mkdir(path.dirname(target.outAbs), { recursive: true });
  await fs.writeFile(target.outAbs, html, "utf8");

  console.log(`Baked email template: ${path.relative(process.cwd(), target.outAbs)}`);
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const targets = await buildTargets(args);
  const props = await readProps(
    args.propsFile,
    args.siteConfig ?? DEFAULT_SITE_CONFIG,
    args.themeConfig ?? DEFAULT_THEME_CONFIG
  );

  for (const target of targets) {
    await bakeTemplate(target, args, props);
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});

END_OF_FILE_CONTENT
echo "Creating scripts/bake.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/bake.mjs"
/**
 * olon bake - production SSG
 *
 * 1) Build client bundle (dist/)
 * 2) Build SSR entry bundle (dist-ssr/)
 * 3) Discover all page slugs from JSON files under src/data/pages
 * 4) Render each slug via SSR and write dist/<slug>/index.html
 */

import { build } from 'vite';
import path from 'path';
import { fileURLToPath, pathToFileURL } from 'url';
import fs from 'fs/promises';
import { webmcp } from '@olonjs/core';

const {
  buildPageContract,
  buildPageManifest,
  buildPageManifestHref,
  buildSiteManifest,
  buildLlmsTxt,
} = webmcp;

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, '..');
const pagesDir = path.resolve(root, 'src/data/pages');
const publicDir = path.resolve(root, 'public');
const distDir = path.resolve(root, 'dist');

async function writeTargets(relativePath, content) {
  const targets = [
    path.resolve(publicDir, relativePath),
    path.resolve(distDir, relativePath),
  ];

  for (const targetPath of targets) {
    await fs.mkdir(path.dirname(targetPath), { recursive: true });
    await fs.writeFile(targetPath, content, 'utf-8');
  }
}

async function writeJsonTargets(relativePath, value) {
  await writeTargets(relativePath, `${JSON.stringify(value, null, 2)}\n`);
}

function escapeHtmlAttribute(value) {
  return String(value).replace(/&/g, '&amp;').replace(/"/g, '&quot;');
}

function toCanonicalSlug(relativeJsonPath) {
  const normalized = relativeJsonPath.replace(/\\/g, '/');
  const slug = normalized.replace(/\.json$/i, '').replace(/^\/+|\/+$/g, '');
  if (!slug) throw new Error('[bake] Invalid page slug: empty path segment');
  return slug;
}

async function listJsonFilesRecursive(dir) {
  const items = await fs.readdir(dir, { withFileTypes: true });
  const files = [];
  for (const item of items) {
    const fullPath = path.join(dir, item.name);
    if (item.isDirectory()) {
      files.push(...(await listJsonFilesRecursive(fullPath)));
      continue;
    }
    if (item.isFile() && item.name.toLowerCase().endsWith('.json')) files.push(fullPath);
  }
  return files;
}

async function discoverTargets() {
  let files = [];
  try {
    files = await listJsonFilesRecursive(pagesDir);
  } catch {
    files = [];
  }

  const rawSlugs = files.map((fullPath) => toCanonicalSlug(path.relative(pagesDir, fullPath)));
  const slugs = Array.from(new Set(rawSlugs)).sort((a, b) => a.localeCompare(b));

  return slugs.map((slug) => {
    const depth = slug === 'home' ? 0 : slug.split('/').length;
    const out = slug === 'home' ? 'dist/index.html' : `dist/${slug}/index.html`;
    return { slug, out, depth };
  });
}

console.log('\n[bake] Building client...');
await build({ root, mode: 'production', logLevel: 'warn' });
console.log('[bake] Client build done.');

console.log('\n[bake] Building SSR bundle...');
await build({
  root,
  mode: 'production',
  logLevel: 'warn',
  build: {
    ssr: 'src/entry-ssg.tsx',
    outDir: 'dist-ssr',
    rollupOptions: {
      output: { format: 'esm' },
    },
  },
  ssr: {
    // SSG must be self-contained: the SSR artifact should not depend on
    // runtime resolution of app/framework packages at bake time.
    noExternal: true,
  },
});
console.log('[bake] SSR build done.');

const targets = await discoverTargets();
if (targets.length === 0) {
  throw new Error('[bake] No pages discovered under src/data/pages');
}
console.log(`[bake] Targets: ${targets.map((t) => t.slug).join(', ')}`);

const ssrEntryUrl = pathToFileURL(path.resolve(root, 'dist-ssr/entry-ssg.js')).href;
const { render, getCss, getRemoteStylesheets, getPageMeta, getWebMcpBuildState } = await import(ssrEntryUrl);

const template = await fs.readFile(path.resolve(root, 'dist/index.html'), 'utf-8');
const hasCommentMarker = template.includes('<!--app-html-->');
const hasRootDivMarker = template.includes('<div id="root"></div>');
if (!hasCommentMarker && !hasRootDivMarker) {
  throw new Error('[bake] Missing template marker. Expected <!--app-html--> or <div id="root"></div>.');
}

const inlinedCss = getCss();
const styleTag = `<style data-bake="inline">${inlinedCss}</style>`;
const remoteStylesheetTags = getRemoteStylesheets()
  .map((href) => `<link rel="stylesheet" href="${escapeHtmlAttribute(href)}">`)
  .join('\n  ');
const webMcpBuildState = getWebMcpBuildState();

for (const { slug } of targets) {
  const pageConfig = webMcpBuildState.pages[slug];
  if (!pageConfig) continue;
  
  // Export the raw JSON data for the agentic web (so readResource works on SSG)
  await writeJsonTargets(`pages/${slug}.json`, pageConfig);

  const contract = buildPageContract({
    slug,
    pageConfig,
    schemas: webMcpBuildState.schemas,
    siteConfig: webMcpBuildState.siteConfig,
  });
  await writeJsonTargets(`schemas/${slug}.schema.json`, contract);
  const pageManifest = buildPageManifest({
    slug,
    pageConfig,
    schemas: webMcpBuildState.schemas,
    siteConfig: webMcpBuildState.siteConfig,
  });
  await writeJsonTargets(buildPageManifestHref(slug).replace(/^\//, ''), pageManifest);
}

// Export the site config for the agentic web
await writeJsonTargets('config/site.json', webMcpBuildState.siteConfig);

const mcpManifest = buildSiteManifest({
  pages: webMcpBuildState.pages,
  schemas: webMcpBuildState.schemas,
  siteConfig: webMcpBuildState.siteConfig,
});
await writeJsonTargets('mcp-manifest.json', mcpManifest);

const llmsTxtContent = buildLlmsTxt({
  pages: webMcpBuildState.pages,
  schemas: webMcpBuildState.schemas,
  siteConfig: webMcpBuildState.siteConfig,
});
await writeTargets('llms.txt', `${llmsTxtContent}\n`);

for (const { slug, out, depth } of targets) {
  console.log(`\n[bake] Rendering /${slug === 'home' ? '' : slug}...`);

  const appHtml = render(slug);
  const { title, description } = getPageMeta(slug);
  const safeTitle = String(title).replace(/"/g, '&quot;');
  const safeDescription = String(description).replace(/"/g, '&quot;');
  const metaTags = [
    `<meta name="description" content="${safeDescription}">`,
    `<meta property="og:title" content="${safeTitle}">`,
    `<meta property="og:description" content="${safeDescription}">`,
  ].join('\n    ');
  const jsonLd = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: title,
    description,
    url: slug === 'home' ? '/' : `/${slug}`,
  });

  const prefix = depth > 0 ? '../'.repeat(depth) : './';
  const fixedTemplate = depth > 0 ? template.replace(/(['"])\.\//g, `$1${prefix}`) : template;
  const mcpManifestHref = `${prefix}${buildPageManifestHref(slug).replace(/^\//, '')}`;
  const contractHref = `${prefix}schemas/${slug}.schema.json`;
  const contractLinks = [
    `<link rel="mcp-manifest" href="${escapeHtmlAttribute(mcpManifestHref)}">`,
    `<link rel="olon-contract" href="${escapeHtmlAttribute(contractHref)}">`,
    `<script type="application/ld+json">${jsonLd}</script>`,
  ].join('\n  ');

  let bakedHtml = fixedTemplate
    .replace('</head>', `  ${remoteStylesheetTags ? `${remoteStylesheetTags}\n  ` : ''}${styleTag}\n  ${contractLinks}\n</head>`)
    .replace(/<title>.*?<\/title>/, `<title>${safeTitle}</title>\n    ${metaTags}`);

  if (hasCommentMarker) {
    bakedHtml = bakedHtml.replace('<!--app-html-->', appHtml);
  } else {
    bakedHtml = bakedHtml.replace('<div id="root"></div>', `<div id="root">${appHtml}</div>`);
  }

  const outPath = path.resolve(root, out);
  await fs.mkdir(path.dirname(outPath), { recursive: true });
  await fs.writeFile(outPath, bakedHtml, 'utf-8');
  console.log(`[bake] Written -> ${out} [title: "${safeTitle}"]`);
}

console.log('\n[bake] All pages baked. OK\n');

END_OF_FILE_CONTENT
echo "Creating scripts/generate-llms-txt.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/generate-llms-txt.mjs"
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { webmcp } from '@olonjs/core';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const { buildLlmsTxt } = webmcp;

const pagesDir = path.join(rootDir, 'src', 'data', 'pages');
const siteConfig = JSON.parse(fs.readFileSync(path.join(rootDir, 'src', 'data', 'config', 'site.json'), 'utf-8'));

function listJsonFilesRecursive(dir) {
  const items = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const item of items) {
    const fullPath = path.join(dir, item.name);
    if (item.isDirectory()) {
      files.push(...listJsonFilesRecursive(fullPath));
      continue;
    }
    if (item.isFile() && item.name.toLowerCase().endsWith('.json')) files.push(fullPath);
  }
  return files;
}

const pages = {};
for (const fullPath of listJsonFilesRecursive(pagesDir)) {
  const slug = path.relative(pagesDir, fullPath).replace(/\\/g, '/').replace(/\.json$/i, '');
  pages[slug] = JSON.parse(fs.readFileSync(fullPath, 'utf-8'));
}

const llmsTxt = buildLlmsTxt({ pages, schemas: {}, siteConfig });

const outPath = path.join(rootDir, 'public', 'llms.txt');
fs.writeFileSync(outPath, llmsTxt, 'utf-8');
console.log('[generate-llms-txt] Written -> public/llms.txt');

END_OF_FILE_CONTENT
echo "Creating scripts/sync-pages-to-public.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/sync-pages-to-public.mjs"
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.resolve(__dirname, '..');
const sourceDir = path.join(rootDir, 'src', 'data', 'pages');
const targetDir = path.join(rootDir, 'public', 'pages');
const sourceSiteConfigPath = path.join(rootDir, 'src', 'data', 'config', 'site.json');
const targetConfigDir = path.join(rootDir, 'public', 'config');
const targetSiteConfigPath = path.join(targetConfigDir, 'site.json');

if (!fs.existsSync(sourceDir)) {
  console.warn('[sync-pages-to-public] Source directory not found:', sourceDir);
  process.exit(0);
}

fs.rmSync(targetDir, { recursive: true, force: true });
fs.mkdirSync(targetDir, { recursive: true });
fs.cpSync(sourceDir, targetDir, { recursive: true });

if (fs.existsSync(sourceSiteConfigPath)) {
  fs.mkdirSync(targetConfigDir, { recursive: true });
  fs.cpSync(sourceSiteConfigPath, targetSiteConfigPath);
}

console.log('[sync-pages-to-public] Synced pages to public/pages and site config to public/config/site.json');

END_OF_FILE_CONTENT
echo "Creating scripts/webmcp-feature-check.mjs..."
cat << 'END_OF_FILE_CONTENT' > "scripts/webmcp-feature-check.mjs"
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import { createRequire } from 'module';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const baseUrl = process.env.WEBMCP_BASE_URL ?? 'http://127.0.0.1:4173';

function pageFilePathFromSlug(slug) {
  return path.resolve(rootDir, 'src', 'data', 'pages', `${slug}.json`);
}

function adminUrlFromSlug(slug) {
  return `${baseUrl}/admin${slug === 'home' ? '' : `/${slug}`}`;
}

function isStringSchema(schema) {
  if (!schema || typeof schema !== 'object') return false;
  if (schema.type === 'string') return true;
  if (Array.isArray(schema.anyOf)) {
    return schema.anyOf.some((entry) => entry && typeof entry === 'object' && entry.type === 'string');
  }
  return false;
}

function findTopLevelStringField(sectionSchema) {
  const properties = sectionSchema?.properties;
  if (!properties || typeof properties !== 'object') return null;
  const preferred = ['title', 'sectionTitle', 'label', 'headline', 'name'];
  for (const key of preferred) {
    if (isStringSchema(properties[key])) return key;
  }
  for (const [key, value] of Object.entries(properties)) {
    if (isStringSchema(value)) return key;
  }
  return null;
}

async function loadPlaywright() {
  const require = createRequire(import.meta.url);
  try {
    return require('playwright');
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    throw new Error(
      `Playwright is required for WebMCP verification. Install it before running this script. Original error: ${message}`
    );
  }
}

async function readPageJson(slug) {
  const pageFilePath = pageFilePathFromSlug(slug);
  const raw = await fs.readFile(pageFilePath, 'utf8');
  return { raw, json: JSON.parse(raw), pageFilePath };
}

async function waitFor(predicate, timeoutMs, label) {
  const startedAt = Date.now();
  for (;;) {
    const result = await predicate();
    if (result) return result;
    if (Date.now() - startedAt > timeoutMs) {
      throw new Error(`Timed out while waiting for ${label}.`);
    }
    await new Promise((resolve) => setTimeout(resolve, 150));
  }
}

async function waitForFileFieldValue(slug, sectionId, fieldKey, expectedValue) {
  await waitFor(async () => {
    const { json } = await readPageJson(slug);
    const section = Array.isArray(json.sections)
      ? json.sections.find((item) => item?.id === sectionId)
      : null;
    return section?.data?.[fieldKey] === expectedValue;
  }, 8_000, `file field "${fieldKey}" = "${expectedValue}"`);
}

async function ensureResponseOk(response, label) {
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`${label} failed with ${response.status}: ${text}`);
  }
  return response;
}

async function fetchJson(relativePath, label) {
  const response = await ensureResponseOk(await fetch(`${baseUrl}${relativePath}`), label);
  return response.json();
}

async function selectTarget() {
  const siteIndex = await fetchJson('/mcp-manifest.json', 'Manifest index request');
  const requestedSlug = typeof process.env.WEBMCP_TARGET_SLUG === 'string' && process.env.WEBMCP_TARGET_SLUG.trim()
    ? process.env.WEBMCP_TARGET_SLUG.trim()
    : null;

  const candidatePages = requestedSlug
    ? (siteIndex.pages ?? []).filter((page) => page?.slug === requestedSlug)
    : (siteIndex.pages ?? []);

  for (const pageEntry of candidatePages) {
    if (!pageEntry?.slug || !pageEntry?.manifestHref || !pageEntry?.contractHref) continue;
    const pageManifest = await fetchJson(pageEntry.manifestHref, `Page manifest request for ${pageEntry.slug}`);
    const pageContract = await fetchJson(pageEntry.contractHref, `Page contract request for ${pageEntry.slug}`);
    const localInstances = Array.isArray(pageContract.sectionInstances)
      ? pageContract.sectionInstances.filter((section) => section?.scope === 'local')
      : [];
    const tools = Array.isArray(pageManifest.tools) ? pageManifest.tools : [];

    for (const tool of tools) {
      const sectionType = tool?.sectionType;
      if (typeof tool?.name !== 'string' || typeof sectionType !== 'string') continue;
      const targetInstance = localInstances.find((section) => section?.type === sectionType);
      if (!targetInstance?.id) continue;
      const targetFieldKey = findTopLevelStringField(pageContract.sectionSchemas?.[sectionType]);
      if (!targetFieldKey) continue;
      const pageState = await readPageJson(pageEntry.slug);
      const section = Array.isArray(pageState.json.sections)
        ? pageState.json.sections.find((item) => item?.id === targetInstance.id)
        : null;
      const originalValue = section?.data?.[targetFieldKey];
      if (typeof originalValue !== 'string') continue;

      return {
        slug: pageEntry.slug,
        manifestHref: pageEntry.manifestHref,
        contractHref: pageEntry.contractHref,
        toolName: tool.name,
        sectionId: targetInstance.id,
        fieldKey: targetFieldKey,
        originalValue,
        originalState: pageState,
      };
    }
  }

  throw new Error(
    requestedSlug
      ? `No valid WebMCP verification target found for page "${requestedSlug}".`
      : 'No valid WebMCP verification target found in manifest index.'
  );
}

async function main() {
  const { chromium } = await loadPlaywright();
  const target = await selectTarget();
  const nextValue = `${target.originalValue} WebMCP ${Date.now()}`;
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage();
  const consoleEvents = [];
  let mutationApplied = false;

  page.on('console', (message) => {
    if (message.type() === 'error' || message.type() === 'warning') {
      consoleEvents.push(`[console:${message.type()}] ${message.text()}`);
    }
  });
  page.on('pageerror', (error) => {
    consoleEvents.push(`[pageerror] ${error.message}`);
  });

  const restoreOriginal = async () => {
    try {
      await page.evaluate(
        async ({ toolName, slug, sectionId, fieldKey, value }) => {
          const runtime = navigator.modelContextTesting;
          if (!runtime?.executeTool) return;
          await runtime.executeTool(
            toolName,
            JSON.stringify({
              slug,
              sectionId,
              fieldKey,
              value,
            })
          );
        },
        {
          toolName: target.toolName,
          slug: target.slug,
          sectionId: target.sectionId,
          fieldKey: target.fieldKey,
          value: target.originalValue,
        }
      );
      await waitForFileFieldValue(target.slug, target.sectionId, target.fieldKey, target.originalValue);
    } catch {
      await fs.writeFile(target.originalState.pageFilePath, target.originalState.raw, 'utf8');
    }
  };

  try {
    const pageManifest = await fetchJson(target.manifestHref, `Manifest request for ${target.slug}`);
    if (!Array.isArray(pageManifest.tools) || !pageManifest.tools.some((tool) => tool?.name === target.toolName)) {
      throw new Error(`Manifest does not expose ${target.toolName}.`);
    }

    const pageContract = await fetchJson(target.contractHref, `Contract request for ${target.slug}`);
    if (!Array.isArray(pageContract.tools) || !pageContract.tools.some((tool) => tool?.name === target.toolName)) {
      throw new Error(`Page contract does not expose ${target.toolName}.`);
    }

    await page.goto(adminUrlFromSlug(target.slug), { waitUntil: 'networkidle' });

    try {
      await page.waitForFunction(
        ({ manifestHref, contractHref }) => {
          const manifestLink = document.head.querySelector('link[rel="mcp-manifest"]');
          const contractLink = document.head.querySelector('link[rel="olon-contract"]');
          return manifestLink?.getAttribute('href') === manifestHref
            && contractLink?.getAttribute('href') === contractHref;
        },
        { manifestHref: target.manifestHref, contractHref: target.contractHref },
        { timeout: 10_000 }
      );
    } catch (error) {
      const diagnostics = await page.evaluate(() => ({
        head: document.head.innerHTML,
        bodyText: document.body.innerText,
      }));
      throw new Error(
        [
          error instanceof Error ? error.message : String(error),
          `head=${diagnostics.head}`,
          `body=${diagnostics.bodyText}`,
          ...consoleEvents,
        ].join('\n')
      );
    }

    const toolNames = await page.evaluate(() => {
      const runtime = navigator.modelContextTesting;
      return runtime?.listTools?.().map((tool) => tool.name) ?? [];
    });
    if (!toolNames.includes(target.toolName)) {
      throw new Error(`Runtime did not register ${target.toolName}. Found: ${toolNames.join(', ')}`);
    }

    const rawResult = await page.evaluate(
      async ({ toolName, slug, sectionId, fieldKey, value }) => {
        const runtime = navigator.modelContextTesting;
        if (!runtime?.executeTool) {
          throw new Error('navigator.modelContextTesting.executeTool is unavailable.');
        }
        return runtime.executeTool(
          toolName,
          JSON.stringify({
            slug,
            sectionId,
            fieldKey,
            value,
          })
        );
      },
      {
        toolName: target.toolName,
        slug: target.slug,
        sectionId: target.sectionId,
        fieldKey: target.fieldKey,
        value: nextValue,
      }
    );

    const parsedResult = JSON.parse(rawResult);
    if (parsedResult?.isError) {
      throw new Error(`WebMCP tool returned an error: ${rawResult}`);
    }

    mutationApplied = true;
    await waitForFileFieldValue(target.slug, target.sectionId, target.fieldKey, nextValue);
    await page.frameLocator('iframe').getByText(nextValue, { exact: true }).waitFor({ state: 'attached' });

    console.log(
      JSON.stringify({
        ok: true,
        slug: target.slug,
        manifestHref: target.manifestHref,
        contractHref: target.contractHref,
        toolName: target.toolName,
        sectionId: target.sectionId,
        fieldKey: target.fieldKey,
        toolNames,
      })
    );
  } finally {
    if (mutationApplied) {
      await restoreOriginal();
    }
    await browser.close();
  }
}

main().catch((error) => {
  console.error(error instanceof Error ? error.stack ?? error.message : String(error));
  process.exit(1);
});

END_OF_FILE_CONTENT
mkdir -p "src"
echo "Creating src/App.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/App.tsx"
/**
 * Thin Entry Point (Tenant).
 * Data from getHydratedData (file-backed or draft); assets from public/assets/images.
 * Supports Hybrid Persistence: Local Filesystem (Dev) or Cloud Bridge (Prod).
 */
import { useCallback, useEffect, useMemo, useRef, useState, Suspense, lazy } from 'react';
// Visitor path uses the runtime-only bundle (~28 KB gz), per ADR-0009 D7.
// The full @olonjs/core is loaded on demand only when the URL targets /admin.
import { OlonJSEngine } from '@olonjs/core/runtime';
import type { JsonPagesConfig, LibraryImageEntry, ProjectState } from '@olonjs/core/runtime';
import { normalizeBasePath, withBasePath } from '@olonjs/core/runtime';
import { ComponentRegistry } from '@/lib/ComponentRegistry';
import { SECTION_SCHEMAS, SECTION_SUBMISSION_SCHEMAS } from '@/lib/schemas';
import { addSectionConfig } from '@/lib/addSectionConfig';
import { getHydratedData } from '@/lib/draftStorage';
import type { SiteConfig, ThemeConfig, MenuConfig, PageConfig } from '@/types';
import type { DeployPhase, StepId } from '@olonjs/core/runtime';
import { DEPLOY_STEPS } from '@olonjs/core/runtime';
import { startCloudSaveStream } from '@olonjs/core/runtime';
import siteData from '@/data/config/site.json';
import themeData from '@/data/config/theme.json';
import menuData from '@/data/config/menu.json';
import { getFilePages } from '@/lib/getFilePages';
import { DopaDrawer } from '@/components/save-drawer/DopaDrawer';
import { EmptyTenantView } from '@/components/empty-tenant';
import { Skeleton } from '@/components/ui/skeleton';
import { ThemeProvider } from '@/components/ThemeProvider';
import { useOlonForms } from '@/lib/useOlonForms';
import { OlonFormsContext } from '@olonjs/core/runtime';
import { iconMap } from '@/lib/IconResolver';

/**
 * Engine selector. Visitors get OlonJSEngine (~28 KB gz); /admin paths
 * lazy-load the full JsonPagesEngine (~128 KB gz) which mounts the
 * Studio editor surface. The check runs at module load time — once per
 * page, before React mounts — so Vite statically splits the chunks.
 * See ADR-0008 + ADR-0009 + docs/plans/core-studio-split.md (Task 3.1).
 */
const isAdminPath =
  typeof window !== 'undefined' && window.location.pathname.startsWith('/admin');

const LazyJsonPagesEngine = lazy(() =>
  import('@olonjs/core').then((m) => ({ default: m.JsonPagesEngine })),
);

import tenantCss from './index.css?inline';

// Cloud Configuration (Injected by Vercel/Netlify Env Vars)
const CLOUD_API_URL =
  import.meta.env.VITE_OLONJS_CLOUD_URL ?? import.meta.env.VITE_JSONPAGES_CLOUD_URL;
const CLOUD_API_KEY =
  import.meta.env.VITE_OLONJS_API_KEY ?? import.meta.env.VITE_JSONPAGES_API_KEY;
const SAVE2REPO_ENABLED = import.meta.env.VITE_SAVE2REPO === 'true';
const APP_BASE_PATH = normalizeBasePath(import.meta.env.BASE_URL || '/');

const themeConfig = themeData as unknown as ThemeConfig;
const menuConfig = menuData as unknown as MenuConfig;
const refDocuments = {
  'menu.json': menuConfig,
  'config/menu.json': menuConfig,
  'src/data/config/menu.json': menuConfig,
} satisfies NonNullable<JsonPagesConfig['refDocuments']>;

const TENANT_ID = 'alpha';

const filePages = getFilePages();
const fileSiteConfig = siteData as unknown as SiteConfig;
const MAX_UPLOAD_SIZE_BYTES = 5 * 1024 * 1024;
const ASSET_UPLOAD_MAX_RETRIES = 2;
const ASSET_UPLOAD_TIMEOUT_MS = 20_000;
const ALLOWED_IMAGE_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/avif']);

interface CloudSaveUiState {
  isOpen: boolean;
  phase: DeployPhase;
  currentStepId: StepId | null;
  doneSteps: StepId[];
  progress: number;
  errorMessage?: string;
  deployUrl?: string;
}

type ContentMode = 'cloud' | 'error';
type ContentStatus = 'ok' | 'empty_namespace' | 'legacy_fallback';

type ContentResponse = {
  ok?: boolean;
  siteConfig?: unknown;
  pages?: unknown;
  items?: unknown;
  error?: string;
  code?: string;
  correlationId?: string;
  contentStatus?: ContentStatus;
  usedUnscopedFallback?: boolean;
  namespace?: string;
  namespaceMatchedKeys?: number;
};

type CachedCloudContent = {
  keyFingerprint: string;
  savedAt: number;
  siteConfig: unknown | null;
  pages: Record<string, unknown>;
};

const CLOUD_CACHE_KEY = 'jp_cloud_content_cache_v1';
const CLOUD_CACHE_TTL_MS = 5 * 60 * 1000;

function normalizeApiBase(raw: string): string {
  return raw.trim().replace(/\/+$/, '');
}

function buildApiCandidates(raw: string): string[] {
  const base = normalizeApiBase(raw);
  const withApi = /\/api\/v1$/i.test(base) ? base : `${base}/api/v1`;
  const candidates = [withApi, base];
  return Array.from(new Set(candidates.filter(Boolean)));
}

function getInitialData() {
  return getHydratedData(TENANT_ID, filePages, fileSiteConfig);
}

function getInitialCloudSaveUiState(): CloudSaveUiState {
  return {
    isOpen: false,
    phase: 'idle',
    currentStepId: null,
    doneSteps: [],
    progress: 0,
  };
}

function stepProgress(doneSteps: StepId[]): number {
  return Math.round((doneSteps.length / DEPLOY_STEPS.length) * 100);
}

function isObjectRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function asString(value: unknown, fallback: string): string {
  return typeof value === 'string' && value.trim() ? value : fallback;
}

function normalizeRouteSlug(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9/_-]/g, '-')
    .replace(/^\/+|\/+$/g, '') || 'home';
}

function coercePageConfig(slug: string, value: unknown): PageConfig | null {
  let input = value;
  if (typeof input === 'string') {
    try {
      input = JSON.parse(input) as unknown;
    } catch {
      return null;
    }
  }
  if (!isObjectRecord(input) || !Array.isArray(input.sections)) return null;

  const inputMeta = isObjectRecord(input.meta) ? input.meta : {};
  const normalizedSlug = asString(input.slug, slug);
  const normalizedId = asString(input.id, `${normalizedSlug}-page`);
  const title = asString(inputMeta.title, normalizedSlug);
  const description = asString(inputMeta.description, '');

  return {
    id: normalizedId,
    slug: normalizedSlug,
    meta: { title, description },
    sections: input.sections as PageConfig['sections'],
    ...(typeof input['global-header'] === 'boolean' ? { 'global-header': input['global-header'] } : {}),
  };
}

function coerceSiteConfig(value: unknown): SiteConfig | null {
  let input = value;
  if (typeof input === 'string') {
    try {
      input = JSON.parse(input) as unknown;
    } catch {
      return null;
    }
  }
  if (!isObjectRecord(input)) return null;
  if (!isObjectRecord(input.identity)) return null;

  return input as unknown as SiteConfig;
}

function toPagesRecord(value: unknown): Record<string, PageConfig> | null {
  const directPage = coercePageConfig('home', value);
  if (directPage) {
    const directSlug = normalizeRouteSlug(asString(directPage.slug, 'home'));
    return { [directSlug]: { ...directPage, slug: directSlug } };
  }

  if (!isObjectRecord(value)) return null;
  const next: Record<string, PageConfig> = {};
  for (const [rawKey, payload] of Object.entries(value)) {
    const rawKeyTrimmed = rawKey.trim();
    const slugFromNamespacedKey = rawKeyTrimmed.match(/^t_[a-z0-9-]+_page_(.+)$/i)?.[1];
    const slug = normalizeRouteSlug(slugFromNamespacedKey ?? rawKeyTrimmed);
    const page = coercePageConfig(slug, payload);
    if (!page) continue;
    next[slug] = { ...page, slug };
  }
  return next;
}

function normalizePageRegistry(value: unknown): Record<string, PageConfig> {
  if (!isObjectRecord(value)) return {};
  const normalized: Record<string, PageConfig> = {};

  for (const [registrySlug, rawPageValue] of Object.entries(value)) {
    const canonicalSlug = normalizeRouteSlug(registrySlug);
    const direct = coercePageConfig(canonicalSlug, rawPageValue);
    if (direct) {
      // Canonical key comes from registry/path, not from page JSON internal slug.
      normalized[canonicalSlug] = { ...direct, slug: canonicalSlug };
      continue;
    }

    const nested = toPagesRecord(rawPageValue);
    if (nested && Object.keys(nested).length > 0) {
      Object.assign(normalized, nested);
    }
  }

  return normalized;
}

function extractContentSources(payload: ContentResponse | Record<string, unknown>): {
  pagesSource: unknown;
  siteSource: unknown;
} {
  // Canonical contract: { pages, siteConfig }
  if (isObjectRecord(payload) && isObjectRecord(payload.pages)) {
    return { pagesSource: payload.pages, siteSource: payload.siteConfig };
  }

  // Edge public JSON contract: { digest, updatedAt, items: { ... } }
  if (isObjectRecord(payload) && isObjectRecord(payload.items)) {
    const items = payload.items;
    let siteSource: unknown = null;
    const pageEntries: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(items)) {
      if (/(_config_site|config_site|config:site)$/i.test(key)) {
        siteSource = value;
        continue;
      }
      if (/(_page_|^page_|page:)/i.test(key)) {
        pageEntries[key] = value;
      }
    }
    return { pagesSource: pageEntries, siteSource };
  }

  // Raw map fallback: treat payload object itself as page map.
  return { pagesSource: payload, siteSource: null };
}

type CloudLoadFailure = {
  reasonCode: string;
  message: string;
  correlationId?: string;
};

function isCloudLoadFailure(value: unknown): value is CloudLoadFailure {
  return (
    isObjectRecord(value) &&
    typeof value.reasonCode === 'string' &&
    typeof value.message === 'string'
  );
}

function toCloudLoadFailure(value: unknown): CloudLoadFailure {
  if (isCloudLoadFailure(value)) return value;
  if (value instanceof Error) {
    return { reasonCode: 'CLOUD_LOAD_FAILED', message: value.message };
  }
  return { reasonCode: 'CLOUD_LOAD_FAILED', message: 'Cloud content unavailable.' };
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function isRetryableStatus(status: number): boolean {
  return status === 429 || status === 500 || status === 502 || status === 503 || status === 504;
}

function backoffDelayMs(attempt: number): number {
  const base = 250 * Math.pow(2, attempt);
  const jitter = Math.floor(Math.random() * 120);
  return base + jitter;
}

function logBootstrapEvent(event: string, details: Record<string, unknown>) {
  console.info('[boot]', { event, at: new Date().toISOString(), ...details });
}

function cloudFingerprint(apiBase: string, apiKey: string): string {
  return `${normalizeApiBase(apiBase)}::${apiKey.slice(-8)}`;
}

function normalizeSlugForCache(slug: string): string {
  return (
    slug
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9/_-]/g, '-')
      .replace(/^\/+|\/+$/g, '') || 'home'
  );
}

function buildPublishedPageHref(slug: string): string {
  return withBasePath(`/pages/${normalizeSlugForCache(slug)}.json`, APP_BASE_PATH);
}

async function loadPublishedStaticContent(
  knownSlugs: string[]
): Promise<{ pages: Record<string, PageConfig>; siteConfig: SiteConfig }> {
  const siteResponse = await fetch(withBasePath('/config/site.json', APP_BASE_PATH), { cache: 'no-store' });
  if (!siteResponse.ok) {
    throw new Error(`Static site config unavailable: ${siteResponse.status}`);
  }

  const sitePayload = (await siteResponse.json().catch(() => null)) as unknown;
  const nextSite = coerceSiteConfig(sitePayload);
  if (!nextSite) {
    throw new Error('Static site config is invalid.');
  }

  const pageEntries = await Promise.all(
    knownSlugs.map(async (slug) => {
      const response = await fetch(buildPublishedPageHref(slug), { cache: 'no-store' });
      if (!response.ok) {
        throw new Error(`Static page unavailable for slug "${slug}": ${response.status}`);
      }
      return [slug, (await response.json().catch(() => null)) as unknown] as const;
    })
  );

  const nextPages = normalizePageRegistry(Object.fromEntries(pageEntries));
  if (Object.keys(nextPages).length === 0) {
    throw new Error('Static published pages are empty.');
  }

  return {
    pages: nextPages,
    siteConfig: nextSite,
  };
}

function readCachedCloudContent(fingerprint: string): CachedCloudContent | null {
  try {
    const raw = localStorage.getItem(CLOUD_CACHE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as CachedCloudContent;
    if (!parsed || parsed.keyFingerprint !== fingerprint) return null;
    if (!parsed.savedAt || Date.now() - parsed.savedAt > CLOUD_CACHE_TTL_MS) return null;
    return parsed;
  } catch {
    return null;
  }
}

function writeCachedCloudContent(entry: CachedCloudContent): void {
  try {
    localStorage.setItem(CLOUD_CACHE_KEY, JSON.stringify(entry));
  } catch {
    // non-blocking cache path
  }
}

function buildThemeFontVarsCss(input: unknown): string {
  if (!isObjectRecord(input)) return '';
  const tokens = isObjectRecord(input.tokens) ? input.tokens : null;
  const typography = tokens && isObjectRecord(tokens.typography) ? tokens.typography : null;
  const fontFamily = typography && isObjectRecord(typography.fontFamily) ? typography.fontFamily : null;
  const primary = typeof fontFamily?.primary === 'string' ? fontFamily.primary : "'Instrument Sans', system-ui, sans-serif";
  const serif = typeof fontFamily?.serif === 'string' ? fontFamily.serif : "'Instrument Serif', Georgia, serif";
  const mono = typeof fontFamily?.mono === 'string' ? fontFamily.mono : "'JetBrains Mono', monospace";
  return `:root{--theme-font-primary:${primary};--theme-font-serif:${serif};--theme-font-mono:${mono};}`;
}

const REMOTE_CSS_LINK_ATTR = 'data-jp-tenant-remote-css';

function isRemoteStylesheetHref(value: string): boolean {
  return /^https?:\/\//i.test(value.trim());
}

function extractLeadingRemoteCssImports(cssText: string): { hrefs: string[]; rest: string } {
  const hrefs = new Set<string>();
  const leadingTriviaPattern = /^(?:\s+|\/\*[\s\S]*?\*\/)*/;
  const importPattern =
    /^@import\s+url\(\s*(?:'([^']+)'|"([^"]+)"|([^'")\s][^)]*))\s*\)\s*([^;]*);/i;
  let rest = cssText;

  for (;;) {
    const trivia = rest.match(leadingTriviaPattern);
    if (trivia && trivia[0]) {
      rest = rest.slice(trivia[0].length);
    }

    const match = rest.match(importPattern);
    if (!match) break;

    const href = (match[1] ?? match[2] ?? match[3] ?? '').trim();
    const trailingDirectives = (match[4] ?? '').trim();

    if (!isRemoteStylesheetHref(href) || trailingDirectives.length > 0) {
      break;
    }

    hrefs.add(href);
    rest = rest.slice(match[0].length);
  }

  return { hrefs: Array.from(hrefs), rest };
}

function setTenantPreviewReady(ready: boolean): void {
  if (typeof window !== 'undefined') {
    (window as Window & { __TENANT_PREVIEW_READY__?: boolean }).__TENANT_PREVIEW_READY__ = ready;
  }
  if (typeof document !== 'undefined' && document.body) {
    document.body.dataset.previewReady = ready ? '1' : '0';
  }
}

function App() {
  const { states: formStates } = useOlonForms();
  const isCloudMode = Boolean(CLOUD_API_URL && CLOUD_API_KEY);
  const isSave2RepoMode = isCloudMode && SAVE2REPO_ENABLED;
  const isHotSaveMode = isCloudMode && !isSave2RepoMode;
  const localInitialData = useMemo(() => (isCloudMode ? null : getInitialData()), [isCloudMode]);
  const localInitialPages = useMemo(() => {
    if (!localInitialData) return {};
    const normalized = normalizePageRegistry(localInitialData.pages as unknown);
    return Object.keys(normalized).length > 0 ? normalized : localInitialData.pages;
  }, [localInitialData]);
  const [pages, setPages] = useState<Record<string, PageConfig>>(localInitialPages);
  const [siteConfig, setSiteConfig] = useState<SiteConfig>(
    localInitialData?.siteConfig ?? fileSiteConfig
  );
  const [assetsManifest, setAssetsManifest] = useState<LibraryImageEntry[]>([]);
  const [cloudSaveUi, setCloudSaveUi] = useState<CloudSaveUiState>(getInitialCloudSaveUiState);
  const [contentMode, setContentMode] = useState<ContentMode>('cloud');
  const [contentFallback, setContentFallback] = useState<CloudLoadFailure | null>(null);
  const [showTopProgress, setShowTopProgress] = useState(false);
  const [hasInitialCloudResolved, setHasInitialCloudResolved] = useState(!isCloudMode);
  const [bootstrapRunId, setBootstrapRunId] = useState(0);
  const activeCloudSaveController = useRef<AbortController | null>(null);
  const contentLoadInFlight = useRef<Promise<void> | null>(null);
  const pendingCloudSave = useRef<{ state: ProjectState; slug: string } | null>(null);
  const cloudApiCandidates = useMemo(
    () => (isCloudMode && CLOUD_API_URL ? buildApiCandidates(CLOUD_API_URL) : []),
    [isCloudMode, CLOUD_API_URL]
  );

  const loadAssetsManifest = useCallback(async (): Promise<void> => {
    if (isCloudMode && CLOUD_API_URL && CLOUD_API_KEY) {
      const apiBases = cloudApiCandidates.length > 0 ? cloudApiCandidates : [normalizeApiBase(CLOUD_API_URL)];
      for (const apiBase of apiBases) {
        try {
          const res = await fetch(`${apiBase}/assets/list?limit=200`, {
            method: 'GET',
            headers: {
              Authorization: `Bearer ${CLOUD_API_KEY}`,
            },
          });
          const body = (await res.json().catch(() => ({}))) as { items?: LibraryImageEntry[] };
          if (!res.ok) continue;
          const items = Array.isArray(body.items) ? body.items : [];
          setAssetsManifest(items);
          return;
        } catch {
          // try next candidate
        }
      }
      setAssetsManifest([]);
      return;
    }

    fetch('/api/list-assets')
      .then((r) => (r.ok ? r.json() : []))
      .then((list: LibraryImageEntry[]) => setAssetsManifest(Array.isArray(list) ? list : []))
      .catch(() => setAssetsManifest([]));
  }, [isCloudMode, CLOUD_API_URL, CLOUD_API_KEY, cloudApiCandidates]);

  useEffect(() => {
    void loadAssetsManifest();
  }, [loadAssetsManifest]);

  useEffect(() => {
    return () => {
      activeCloudSaveController.current?.abort();
    };
  }, []);

  useEffect(() => {
    setTenantPreviewReady(false);
    return () => {
      setTenantPreviewReady(false);
    };
  }, []);

  useEffect(() => {
    if (!isCloudMode || !CLOUD_API_URL || !CLOUD_API_KEY) {
      setContentMode('cloud');
      setContentFallback(null);
      setShowTopProgress(false);
      setHasInitialCloudResolved(true);
      logBootstrapEvent('boot.local.ready', { mode: 'local' });
      return;
    }

    if (isSave2RepoMode) {
      if (contentLoadInFlight.current) {
        return;
      }

      setContentMode('cloud');
      setContentFallback(null);
      setShowTopProgress(true);
      setHasInitialCloudResolved(false);
      logBootstrapEvent('boot.start', { mode: 'save2repo-static', pageCount: Object.keys(filePages).length });

      let inFlight: Promise<void> | null = null;
      inFlight = loadPublishedStaticContent(Object.keys(filePages))
        .then(({ pages: nextPages, siteConfig: nextSite }) => {
          setPages(nextPages);
          setSiteConfig(nextSite);
          setContentMode('cloud');
          setContentFallback(null);
          setHasInitialCloudResolved(true);
          logBootstrapEvent('boot.save2repo.success', {
            mode: 'save2repo-static',
            pageCount: Object.keys(nextPages).length,
          });
        })
        .catch((error: unknown) => {
          const failure = toCloudLoadFailure(error);
          setContentMode('error');
          setContentFallback(failure);
          setHasInitialCloudResolved(true);
          logBootstrapEvent('boot.save2repo.error', {
            mode: 'save2repo-static',
            reasonCode: failure.reasonCode,
            correlationId: failure.correlationId ?? null,
          });
        })
        .finally(() => {
          setShowTopProgress(false);
          if (contentLoadInFlight.current === inFlight) {
            contentLoadInFlight.current = null;
          }
        });
      contentLoadInFlight.current = inFlight;
      return () => {
        contentLoadInFlight.current = null;
      };
    }

    if (contentLoadInFlight.current) {
      return;
    }

    const controller = new AbortController();
    const maxRetryAttempts = 2;
    const startedAt = Date.now();
    const primaryApiBase = cloudApiCandidates[0] ?? normalizeApiBase(CLOUD_API_URL);
    const fingerprint = cloudFingerprint(primaryApiBase, CLOUD_API_KEY);
    const cached = readCachedCloudContent(fingerprint);
    const cachedPages = cached ? toPagesRecord(cached.pages) : null;
    const cachedSite = cached ? coerceSiteConfig(cached.siteConfig) : null;
    const hasCachedFallback = Boolean((cachedPages && Object.keys(cachedPages).length > 0) || cachedSite);
    if (cached) {
      logBootstrapEvent('boot.cloud.cache_hit', { ageMs: Date.now() - cached.savedAt });
    }
    setContentMode('cloud');
    setContentFallback(null);
    setShowTopProgress(true);
    setHasInitialCloudResolved(false);
    logBootstrapEvent('boot.start', { mode: 'cloud', apiCandidates: cloudApiCandidates.length });

    const loadCloudContent = async () => {
      try {
        let payload: ContentResponse | null = null;
        let lastFailure: CloudLoadFailure | null = null;

        for (const apiBase of cloudApiCandidates) {
          for (let attempt = 0; attempt <= maxRetryAttempts; attempt += 1) {
            try {
              const res = await fetch(`${apiBase}/content`, {
                method: 'GET',
                cache: 'no-store',
                headers: {
                  Authorization: `Bearer ${CLOUD_API_KEY}`,
                },
                signal: controller.signal,
              });

              const contentType = (res.headers.get('content-type') || '').toLowerCase();
              if (!contentType.includes('application/json')) {
                lastFailure = {
                  reasonCode: 'NON_JSON_RESPONSE',
                  message: `Non-JSON response from ${apiBase}/content`,
                };
                break;
              }

              const parsed = (await res.json().catch(() => ({}))) as ContentResponse;
              if (!res.ok) {
                lastFailure = {
                  reasonCode: parsed.code || `HTTP_${res.status}`,
                  message: parsed.error || `Cloud content read failed: ${res.status} (${apiBase}/content)`,
                  correlationId: parsed.correlationId,
                };
                if (isRetryableStatus(res.status) && attempt < maxRetryAttempts) {
                  await sleep(backoffDelayMs(attempt));
                  continue;
                }
                break;
              }

              payload = parsed;
              break;
            } catch (error: unknown) {
              if (controller.signal.aborted) throw error;
              const message = error instanceof Error ? error.message : 'Network error';
              lastFailure = {
                reasonCode: 'NETWORK_TRANSIENT',
                message: `${message} (${apiBase}/content)`,
              };
              if (attempt < maxRetryAttempts) {
                await sleep(backoffDelayMs(attempt));
                continue;
              }
            }
          }
          if (payload) {
            break;
          }
        }

        if (!payload) {
          throw (
            lastFailure || {
              reasonCode: 'CLOUD_ENDPOINT_UNREACHABLE',
              message: 'Cloud content endpoint not reachable as JSON.',
            }
          );
        }

        const { pagesSource, siteSource } = extractContentSources(payload);
        const remotePages = toPagesRecord(pagesSource);
        const remoteSite = coerceSiteConfig(siteSource);
        const remotePageCount = remotePages ? Object.keys(remotePages).length : 0;
        if (remotePageCount === 0 && !remoteSite) {
          throw {
            reasonCode: payload.contentStatus === 'empty_namespace' ? 'EMPTY_NAMESPACE' : 'EMPTY_PAYLOAD',
            message: 'Cloud payload is empty for this tenant namespace.',
            correlationId: payload.correlationId,
          } satisfies CloudLoadFailure;
        }
        if (import.meta.env.DEV) {
          console.info('[content] cloud diagnostics', {
            contentStatus: payload.contentStatus ?? 'ok',
            namespace: payload.namespace,
            namespaceMatchedKeys: payload.namespaceMatchedKeys,
            usedUnscopedFallback: payload.usedUnscopedFallback,
            correlationId: payload.correlationId,
          });
        }
        if (remotePages && remotePageCount > 0) {
          setPages(remotePages);
        }
        if (remoteSite) {
          setSiteConfig(remoteSite);
        }
        writeCachedCloudContent({
          keyFingerprint: fingerprint,
          savedAt: Date.now(),
          siteConfig: remoteSite ?? null,
          pages: (remotePages ?? {}) as Record<string, unknown>,
        });
        setContentMode('cloud');
        setContentFallback(null);
        setHasInitialCloudResolved(true);
        logBootstrapEvent('boot.cloud.success', {
          mode: 'cloud',
          elapsedMs: Date.now() - startedAt,
          contentStatus: payload.contentStatus ?? 'ok',
          correlationId: payload.correlationId ?? null,
        });
      } catch (error: unknown) {
        if (controller.signal.aborted) return;
        const failure = toCloudLoadFailure(error);
        if (hasCachedFallback) {
          if (cachedPages && Object.keys(cachedPages).length > 0) {
            setPages(cachedPages);
          }
          if (cachedSite) {
            setSiteConfig(cachedSite);
          }
          setContentMode('cloud');
          setContentFallback({
            reasonCode: 'CLOUD_REFRESH_FAILED',
            message: failure.message,
            correlationId: failure.correlationId,
          });
          setHasInitialCloudResolved(true);
        } else {
          setContentMode('error');
          setContentFallback(failure);
          setHasInitialCloudResolved(true);
        }
        logBootstrapEvent('boot.cloud.error', {
          mode: 'cloud',
          elapsedMs: Date.now() - startedAt,
          reasonCode: failure.reasonCode,
          correlationId: failure.correlationId ?? null,
        });
      }
    };

    let inFlight: Promise<void> | null = null;
    inFlight = loadCloudContent().finally(() => {
      setShowTopProgress(false);
      if (contentLoadInFlight.current === inFlight) {
        contentLoadInFlight.current = null;
      }
    });
    contentLoadInFlight.current = inFlight;
    return () => controller.abort();
  }, [isCloudMode, isSave2RepoMode, CLOUD_API_KEY, CLOUD_API_URL, cloudApiCandidates, bootstrapRunId]);

  const runCloudSave = useCallback(
    async (
      payload: { state: ProjectState; slug: string },
      rejectOnError: boolean
    ): Promise<void> => {
      if (!CLOUD_API_URL || !CLOUD_API_KEY) {
        const noCloudError = new Error('Cloud mode is not configured.');
        if (rejectOnError) throw noCloudError;
        return;
      }

      pendingCloudSave.current = payload;
      activeCloudSaveController.current?.abort();
      const controller = new AbortController();
      activeCloudSaveController.current = controller;

      setCloudSaveUi({
        isOpen: true,
        phase: 'running',
        currentStepId: null,
        doneSteps: [],
        progress: 0,
      });

      try {
        await startCloudSaveStream({
          apiBaseUrl: CLOUD_API_URL,
          apiKey: CLOUD_API_KEY,
          path: `src/data/pages/${payload.slug}.json`,
          content: payload.state.page,
          message: `Content update for ${payload.slug} via Visual Editor`,
          signal: controller.signal,
          onStep: (event) => {
            setCloudSaveUi((prev) => {
              if (event.status === 'running') {
                return {
                  ...prev,
                  isOpen: true,
                  phase: 'running',
                  currentStepId: event.id,
                  errorMessage: undefined,
                };
              }

              if (prev.doneSteps.includes(event.id)) {
                return prev;
              }

              const nextDone = [...prev.doneSteps, event.id];
              return {
                ...prev,
                isOpen: true,
                phase: 'running',
                currentStepId: event.id,
                doneSteps: nextDone,
                progress: stepProgress(nextDone),
              };
            });
          },
          onDone: (event) => {
            const completed = DEPLOY_STEPS.map((step) => step.id);
            setCloudSaveUi({
              isOpen: true,
              phase: 'done',
              currentStepId: 'live',
              doneSteps: completed,
              progress: 100,
              deployUrl: event.deployUrl,
            });
          },
        });
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : 'Cloud save failed.';
        setCloudSaveUi((prev) => ({
          ...prev,
          isOpen: true,
          phase: 'error',
          errorMessage: message,
        }));
        if (rejectOnError) throw new Error(message);
      } finally {
        if (activeCloudSaveController.current === controller) {
          activeCloudSaveController.current = null;
        }
      }
    },
    []
  );

  const closeCloudDrawer = useCallback(() => {
    setCloudSaveUi(getInitialCloudSaveUiState());
  }, []);

  const retryCloudSave = useCallback(() => {
    if (!pendingCloudSave.current) return;
    void runCloudSave(pendingCloudSave.current, false);
  }, [runCloudSave]);

  const tenantCssParts = useMemo(() => extractLeadingRemoteCssImports(tenantCss), [tenantCss]);
  const resolvedTenantCss = useMemo(
    () => [buildThemeFontVarsCss(themeConfig), tenantCssParts.rest].filter(Boolean).join('\n'),
    [tenantCssParts],
  );

  useEffect(() => {
    if (typeof document === 'undefined') return undefined;

    const createdLinks: HTMLLinkElement[] = [];

    tenantCssParts.hrefs.forEach((href) => {
      const existing = Array.from(document.querySelectorAll('link[rel="stylesheet"]')).find(
        (link) => (link as HTMLLinkElement).href === href,
      ) as HTMLLinkElement | undefined;
      if (existing) return;

      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = href;
      link.setAttribute(REMOTE_CSS_LINK_ATTR, href);
      document.head.appendChild(link);
      createdLinks.push(link);
    });

    return () => {
      createdLinks.forEach((link) => {
        if (link.getAttribute(REMOTE_CSS_LINK_ATTR) !== link.href) return;
        if (link.parentNode) link.parentNode.removeChild(link);
      });
    };
  }, [tenantCssParts]);

  const config: JsonPagesConfig = {
    tenantId: TENANT_ID,
    basePath: APP_BASE_PATH,
    registry: ComponentRegistry as JsonPagesConfig['registry'],
    schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
    submissionSchemas: SECTION_SUBMISSION_SCHEMAS as unknown as JsonPagesConfig['submissionSchemas'],
    pages,
    siteConfig,
    themeConfig,
    menuConfig,
    refDocuments,
    iconRegistry: iconMap,
    themeCss: { tenant: resolvedTenantCss },
    addSection: addSectionConfig,
    webmcp: {
      enabled: true,
      namespace: typeof window !== 'undefined' ? window.location.href : '',
    },
    persistence: {
      async saveToFile(state: ProjectState, slug: string): Promise<void> {
        // 💻 LOCAL FILESYSTEM (development path)
        console.log(`💻 Saving ${slug} to Local Filesystem...`);
        const res = await fetch('/api/save-to-file', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ projectState: state, slug }),
        });
        
        const body = (await res.json().catch(() => ({}))) as { error?: string };
        if (!res.ok) throw new Error(body.error ?? `Save to file failed: ${res.status}`);
      },
      async hotSave(state: ProjectState, slug: string): Promise<void> {
        if (!isCloudMode || !CLOUD_API_URL || !CLOUD_API_KEY) {
          throw new Error('Cloud mode is not configured for hot save.');
        }
        const apiBase = CLOUD_API_URL.replace(/\/$/, '');
        const res = await fetch(`${apiBase}/hotSave`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            Authorization: `Bearer ${CLOUD_API_KEY}`,
          },
          body: JSON.stringify({
            slug,
            page: state.page,
            siteConfig: state.site,
          }),
        });
        const body = (await res.json().catch(() => ({}))) as { error?: string; code?: string };
        if (!res.ok) {
          throw new Error(body.error || body.code || `Hot save failed: ${res.status}`);
        }
        const keyFingerprint = cloudFingerprint(apiBase, CLOUD_API_KEY);
        const normalizedSlug = normalizeSlugForCache(slug);
        const existing = readCachedCloudContent(keyFingerprint);
        writeCachedCloudContent({
          keyFingerprint,
          savedAt: Date.now(),
          siteConfig: state.site ?? null,
          pages: {
            ...(existing?.pages ?? {}),
            [normalizedSlug]: state.page,
          },
        });
      },
      async coldSave(state: ProjectState, slug: string): Promise<void> {
        await runCloudSave({ state, slug }, true);
      },
      showLocalSave: !isCloudMode,
      showHotSave: isHotSaveMode,
      showColdSave: isSave2RepoMode,
    },
    assets: {
      assetsBaseUrl: withBasePath('/assets', APP_BASE_PATH),
      assetsManifest,
      async onAssetUpload(file: File): Promise<string> {
        if (!file.type.startsWith('image/')) throw new Error('Invalid file type.');
        if (!ALLOWED_IMAGE_MIME_TYPES.has(file.type)) {
          throw new Error('Unsupported image format. Allowed: jpeg, png, webp, gif, avif.');
        }
        if (file.size > MAX_UPLOAD_SIZE_BYTES) throw new Error(`File too large. Max ${MAX_UPLOAD_SIZE_BYTES / 1024 / 1024}MB.`);

        if (isCloudMode && CLOUD_API_URL && CLOUD_API_KEY) {
          const apiBases = cloudApiCandidates.length > 0 ? cloudApiCandidates : [normalizeApiBase(CLOUD_API_URL)];
          let lastError: Error | null = null;
          for (const apiBase of apiBases) {
            for (let attempt = 0; attempt <= ASSET_UPLOAD_MAX_RETRIES; attempt += 1) {
              try {
                const formData = new FormData();
                formData.append('file', file);
                formData.append('filename', file.name);
                const controller = new AbortController();
                const timeout = window.setTimeout(() => controller.abort(), ASSET_UPLOAD_TIMEOUT_MS);
                const res = await fetch(`${apiBase}/assets/upload`, {
                  method: 'POST',
                  headers: {
                    Authorization: `Bearer ${CLOUD_API_KEY}`,
                    'X-Correlation-Id': crypto.randomUUID(),
                  },
                  body: formData,
                  signal: controller.signal,
                }).finally(() => window.clearTimeout(timeout));
                const body = (await res.json().catch(() => ({}))) as { url?: string; error?: string; code?: string };
                if (res.ok && typeof body.url === 'string') {
                  await loadAssetsManifest().catch(() => undefined);
                  return body.url;
                }
                lastError = new Error(body.error || body.code || `Cloud upload failed: ${res.status}`);
                if (isRetryableStatus(res.status) && attempt < ASSET_UPLOAD_MAX_RETRIES) {
                  await sleep(backoffDelayMs(attempt));
                  continue;
                }
                break;
              } catch (error: unknown) {
                const message = error instanceof Error ? error.message : 'Cloud upload failed.';
                lastError = new Error(message);
                if (attempt < ASSET_UPLOAD_MAX_RETRIES) {
                  await sleep(backoffDelayMs(attempt));
                  continue;
                }
                break;
              }
            }
          }
          throw lastError ?? new Error('Cloud upload failed.');
        }

        const base64 = await new Promise<string>((resolve, reject) => {
          const reader = new FileReader();
          reader.onload = () => resolve((reader.result as string).split(',')[1] ?? '');
          reader.onerror = () => reject(reader.error);
          reader.readAsDataURL(file);
        });

        const res = await fetch('/api/upload-asset', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ filename: file.name, mimeType: file.type || undefined, data: base64 }),
        });
        const body = (await res.json().catch(() => ({}))) as { url?: string; error?: string };
        if (!res.ok) throw new Error(body.error || `Upload failed: ${res.status}`);
        if (typeof body.url !== 'string') throw new Error('Invalid server response: missing url');
        await loadAssetsManifest().catch(() => undefined);
        return body.url;
      },
    },
  };

  const shouldRenderEngine = !isCloudMode || hasInitialCloudResolved;
  const isTenantEmpty = Object.keys(pages).length === 0;

  useEffect(() => {
    if (!shouldRenderEngine) {
      setTenantPreviewReady(false);
      return;
    }
    let cancelled = false;
    let raf1 = 0;
    let raf2 = 0;
    raf1 = window.requestAnimationFrame(() => {
      raf2 = window.requestAnimationFrame(() => {
        if (!cancelled) setTenantPreviewReady(true);
      });
    });
    return () => {
      cancelled = true;
      window.cancelAnimationFrame(raf1);
      window.cancelAnimationFrame(raf2);
      setTenantPreviewReady(false);
    };
  }, [shouldRenderEngine, pages, siteConfig]);

  return (
    <ThemeProvider>
      <OlonFormsContext.Provider value={formStates}>
      <>
      {isCloudMode && showTopProgress ? (
        <>
          <style>
            {`@keyframes jp-top-progress-slide { 0% { transform: translateX(-120%); } 100% { transform: translateX(320%); } }`}
          </style>
          <div
            role="status"
            aria-live="polite"
            aria-label="Cloud loading progress"
            style={{
              position: 'fixed',
              top: 0,
              left: 0,
              right: 0,
              height: 2,
              zIndex: 1300,
              background: 'rgba(255,255,255,0.08)',
              overflow: 'hidden',
            }}
          >
            <div
              style={{
                width: '32%',
                height: '100%',
                background: 'linear-gradient(90deg, rgba(88,166,255,0.15) 0%, rgba(88,166,255,0.85) 50%, rgba(88,166,255,0.15) 100%)',
                animation: 'jp-top-progress-slide 1.15s ease-in-out infinite',
                willChange: 'transform',
              }}
            />
          </div>
        </>
      ) : null}
      {isCloudMode && !hasInitialCloudResolved ? (
        <div className="fixed inset-0 z-[1290] bg-background/80 backdrop-blur-sm">
          <div className="mx-auto w-full max-w-[1600px] p-6">
            <div className="grid gap-4 lg:grid-cols-[1fr_420px]">
              <div className="space-y-4">
                <Skeleton className="h-10 w-64" />
                <Skeleton className="h-[220px] w-full rounded-xl" />
                <Skeleton className="h-[220px] w-full rounded-xl" />
              </div>
              <div className="space-y-3 rounded-xl border border-border/50 bg-card/60 p-4">
                <Skeleton className="h-8 w-32" />
                <Skeleton className="h-5 w-full" />
                <Skeleton className="h-5 w-5/6" />
                <Skeleton className="h-5 w-4/6" />
                <Skeleton className="h-24 w-full rounded-lg" />
              </div>
            </div>
          </div>
        </div>
      ) : null}
     {shouldRenderEngine ? (
        isTenantEmpty ? (
          <EmptyTenantView />
        ) : isAdminPath ? (
          <Suspense fallback={null}>
            <LazyJsonPagesEngine config={config} />
          </Suspense>
        ) : (
          <OlonJSEngine config={config} />
        )
      ) : null}
      {isCloudMode && (contentMode === 'error' || contentFallback?.reasonCode === 'CLOUD_REFRESH_FAILED') ? (
        <div
          role="status"
          aria-live="polite"
          style={{
            position: 'fixed',
            top: 12,
            right: 12,
            zIndex: 1200,
            background: 'rgba(179, 65, 24, 0.92)',
            border: '1px solid rgba(255,255,255,0.18)',
            color: '#fff',
            padding: '8px 12px',
            borderRadius: 10,
            fontSize: 12,
            maxWidth: 360,
            boxShadow: '0 8px 24px rgba(0,0,0,0.25)',
          }}
        >
          {contentMode === 'error' ? 'Cloud content unavailable.' : 'Cloud refresh failed, showing cached content.'}
          {contentFallback ? (
            <div style={{ opacity: 0.85, marginTop: 4 }}>
              <div>{contentFallback.message}</div>
              <div style={{ marginTop: 2 }}>
                Reason: {contentFallback.reasonCode}
                {contentFallback.correlationId ? ` | Correlation: ${contentFallback.correlationId}` : ''}
              </div>
              <div style={{ marginTop: 8 }}>
                <button
                  type="button"
                  onClick={() => {
                    contentLoadInFlight.current = null;
                    setContentMode('cloud');
                    setContentFallback(null);
                    setHasInitialCloudResolved(false);
                    setShowTopProgress(true);
                    setBootstrapRunId((prev) => prev + 1);
                  }}
                  style={{
                    border: '1px solid rgba(255,255,255,0.3)',
                    borderRadius: 8,
                    padding: '4px 10px',
                    background: 'transparent',
                    color: '#fff',
                    cursor: 'pointer',
                    fontSize: 12,
                  }}
                >
                  Retry
                </button>
              </div>
            </div>
          ) : null}
        </div>
      ) : null}
      <DopaDrawer
        isOpen={cloudSaveUi.isOpen}
        phase={cloudSaveUi.phase}
        currentStepId={cloudSaveUi.currentStepId}
        doneSteps={cloudSaveUi.doneSteps}
        progress={cloudSaveUi.progress}
        errorMessage={cloudSaveUi.errorMessage}
        deployUrl={cloudSaveUi.deployUrl}
        onClose={closeCloudDrawer}
        onRetry={retryCloudSave}
      />
      </>
      </OlonFormsContext.Provider>
    </ThemeProvider>
  );
}

export default App;

END_OF_FILE_CONTENT
mkdir -p "src/components"
echo "Creating src/components/ThemeProvider.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ThemeProvider.tsx"
import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from 'react'

type Theme = 'dark' | 'light'

interface ThemeContextValue {
  theme: Theme
  toggleTheme: () => void
  setTheme: (t: Theme) => void
}

const ThemeContext = createContext<ThemeContextValue>({
  theme: 'dark',
  toggleTheme: () => {},
  setTheme: () => {},
})

const STORAGE_KEY = 'olon:theme'

function isTheme(value: unknown): value is Theme {
  return value === 'dark' || value === 'light'
}

function resolveInitialTheme(): Theme {
  if (typeof window === 'undefined') return 'dark'

  const fromDom = document.documentElement.getAttribute('data-theme')
  if (isTheme(fromDom)) return fromDom

  const fromStorage = window.localStorage.getItem(STORAGE_KEY)
  if (isTheme(fromStorage)) return fromStorage

  const prefersLight = window.matchMedia?.('(prefers-color-scheme: light)').matches
  return prefersLight ? 'light' : 'dark'
}

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<Theme>(resolveInitialTheme)

  useEffect(() => {
    document.documentElement.setAttribute('data-theme', theme)
    window.localStorage.setItem(STORAGE_KEY, theme)
  }, [theme])

  function setTheme(t: Theme) {
    setThemeState(t)
  }

  function toggleTheme() {
    setThemeState((prev) => (prev === 'dark' ? 'light' : 'dark'))
  }

  const value = useMemo(() => ({ theme, toggleTheme, setTheme }), [theme])

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>
}

export function useTheme() {
  return useContext(ThemeContext)
}

END_OF_FILE_CONTENT
mkdir -p "src/components/empty-tenant"
echo "Creating src/components/empty-tenant/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/View.tsx"
import type { EmptyTenantData } from './types';

type EmptyTenantViewProps = {
  data?: EmptyTenantData;
};

export function EmptyTenantView({ data }: EmptyTenantViewProps) {
  const title = data?.title?.trim() || 'Your tenant is empty.';
  const description = data?.description?.trim() || 'Create your first page to start building your site.';

  return (
    <main className="min-h-screen flex items-center justify-center bg-background text-foreground px-6">
      <section className="w-full max-w-xl rounded-xl border border-border bg-card p-8 shadow-sm">
        <h1 className="text-2xl font-semibold tracking-tight">{title}</h1>
        <p className="mt-3 text-sm text-muted-foreground">{description}</p>
      </section>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/empty-tenant/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/index.ts"
export * from './View';
export * from './schema';
export * from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/empty-tenant/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core/runtime';

export const EmptyTenantSchema = BaseSectionData.extend({
  title: z.string().optional().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
});

export const EmptyTenantSettingsSchema = z.object({});

END_OF_FILE_CONTENT
echo "Creating src/components/empty-tenant/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/empty-tenant/types.ts"
import { z } from 'zod';
import { EmptyTenantSchema, EmptyTenantSettingsSchema } from './schema';

export type EmptyTenantData = z.infer<typeof EmptyTenantSchema>;
export type EmptyTenantSettings = z.infer<typeof EmptyTenantSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/form-demo"
echo "Creating src/components/form-demo/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/View.tsx"
import { Icon } from '@/lib/IconResolver';
import { useFormState } from '@olonjs/core/runtime';
import type { FormDemoData } from './types';

type FormDemoViewProps = {
  data: FormDemoData;
};

const missingEnv =
  !import.meta.env.VITE_JSONPAGES_CLOUD_URL &&
  !import.meta.env.VITE_OLONJS_CLOUD_URL;

function SetupGuide({ recipientEmail }: { recipientEmail?: string }) {
  const steps = [
    {
      done: !!recipientEmail,
      label: 'recipientEmail nel JSON della sezione',
      code: '"recipientEmail": "tu@esempio.it"',
    },
    {
      done: !missingEnv,
      label: 'VITE_JSONPAGES_CLOUD_URL nel file .env',
      code: 'VITE_JSONPAGES_CLOUD_URL=https://cloud.olonjs.io',
    },
    {
      done: !!import.meta.env.VITE_JSONPAGES_API_KEY || !!import.meta.env.VITE_OLONJS_API_KEY,
      label: 'VITE_JSONPAGES_API_KEY nel file .env',
      code: 'VITE_JSONPAGES_API_KEY=sk-...',
    },
  ];

  const allDone = steps.every((s) => s.done);
  if (allDone) return null;

  return (
    <div className="rounded-lg border border-border bg-muted/40 p-4 space-y-3 text-sm">
      <p className="font-medium text-foreground">Quasi pronto — completa questi passaggi</p>
      <ol className="space-y-2">
        {steps.map((step, i) => (
          <li key={i} className="flex items-start gap-2">
            <span className={step.done ? 'text-green-500' : 'text-muted-foreground'}>
              {step.done ? '✓' : `${i + 1}.`}
            </span>
            <span className={step.done ? 'text-muted-foreground line-through' : 'text-foreground'}>
              {step.label}
              {!step.done && (
                <code className="block mt-0.5 text-xs bg-background rounded px-1.5 py-0.5 font-mono text-muted-foreground border border-border">
                  {step.code}
                </code>
              )}
            </span>
          </li>
        ))}
      </ol>
    </div>
  );
}

export function FormDemoView({ data }: FormDemoViewProps) {
  const formId = data.anchorId?.trim() || 'form-demo';
  const { status, message } = useFormState(formId);

  return (
    <main className="min-h-screen flex items-center justify-center bg-background text-foreground px-6">
      <section className="w-full max-w-xl rounded-xl border border-border bg-card p-8 shadow-sm space-y-6">
        {data.icon && (
          <div data-jp-field="icon" className="mb-2">
            <Icon name={data.icon} size={24} />
          </div>
        )}
        {data.title && (
          <div>
            <h1
              data-jp-field="title"
              className="text-2xl font-semibold tracking-tight"
            >
              {data.title}
            </h1>
            {data.description && (
              <p
                data-jp-field="description"
                className="mt-3 text-sm text-muted-foreground"
              >
                {data.description}
              </p>
            )}
          </div>
        )}

        <SetupGuide recipientEmail={data.recipientEmail} />

        <form
          id={formId}
          data-olon-recipient={data.recipientEmail ?? ''}
          className="space-y-4"
        >
          <div>
            <label className="block text-xs font-medium text-muted-foreground mb-1">
              Nome
            </label>
            <input
              name="name"
              type="text"
              required
              className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-muted-foreground mb-1">
              Email
            </label>
            <input
              name="email"
              type="email"
              required
              className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm focus:outline-none focus:ring-1 focus:ring-primary"
            />
          </div>

          <div>
            <label className="block text-xs font-medium text-muted-foreground mb-1">
              Messaggio
            </label>
            <textarea
              name="message"
              required
              rows={4}
              className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm resize-none focus:outline-none focus:ring-1 focus:ring-primary"
            />
          </div>

          {status === 'error' && (
            <p className="text-xs text-destructive">{message}</p>
          )}
          {status === 'success' && (
            <p className="text-xs text-green-600">
              {data.successMessage || message}
            </p>
          )}

          <button
            type="submit"
            disabled={status === 'submitting'}
            className="w-full rounded-md bg-primary text-primary-foreground px-4 py-2 text-sm font-medium hover:opacity-90 disabled:opacity-60 disabled:cursor-not-allowed transition-opacity"
          >
            {status === 'submitting' ? 'Invio...' : (data.submitLabel || 'Invia')}
          </button>
        </form>
      </section>
    </main>
  );
}

END_OF_FILE_CONTENT
echo "Creating src/components/form-demo/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/index.ts"
export * from './View';
export * from './schema';
export * from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/form-demo/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/schema.ts"
import { z } from 'zod';
import { BaseSectionData, WithFormRecipient } from '@olonjs/core/runtime';

export const FormDemoSchema = BaseSectionData.merge(WithFormRecipient).extend({
  icon: z.string().optional().describe('ui:icon-picker'),
  title: z.string().optional().describe('ui:text'),
  description: z.string().optional().describe('ui:textarea'),
  submitLabel: z.string().default('Invia').describe('ui:text'),
  successMessage: z.string().default('Richiesta inviata con successo.').describe('ui:text'),
});

export const FormDemoSettingsSchema = z.object({});

/**
 * Submission payload schema for the `form-demo` section.
 *
 * Describes the fields actually submitted by the rendered `<form>` in View.tsx
 * (name, email, message). Exposed via `JsonPagesConfig.submissionSchemas` so that
 * MCP agents can discover the submission contract for this section type without
 * scraping the DOM. See ADR-0002 (docs/decisions/ADR-0002-form-submission-schemas.md).
 */
export const FormDemoSubmissionSchema = z.object({
  name: z.string().min(1).describe('Full name of the person submitting the form'),
  email: z.string().email().describe('Contact email address where we will reply'),
  message: z.string().min(1).describe('Free-form message body'),
});

END_OF_FILE_CONTENT
echo "Creating src/components/form-demo/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/form-demo/types.ts"
import { z } from 'zod';
import { FormDemoSchema, FormDemoSettingsSchema } from './schema';

export type FormDemoData = z.infer<typeof FormDemoSchema>;
export type FormDemoSettings = z.infer<typeof FormDemoSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/save-drawer"
echo "Creating src/components/save-drawer/DeployConnector.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/save-drawer/DeployConnector.tsx"
import type { StepState } from '@olonjs/core/runtime';

interface DeployConnectorProps {
  fromState: StepState;
  toState: StepState;
  color: string;
}

export function DeployConnector({ fromState, toState, color }: DeployConnectorProps) {
  const filled = fromState === 'done' && toState === 'done';
  const filling = fromState === 'done' && toState === 'active';
  const lit = filled || filling;

  return (
    <div className="jp-drawer-connector">
      <div className="jp-drawer-connector-base" />

      <div
        className="jp-drawer-connector-fill"
        style={{
          background: `linear-gradient(90deg, ${color}cc, ${color}66)`,
          width: filled ? '100%' : filling ? '100%' : '0%',
          transition: filling ? 'width 2s cubic-bezier(0.4,0,0.2,1)' : 'none',
          boxShadow: lit ? `0 0 8px ${color}77` : 'none',
        }}
      />

      {filling && (
        <div
          className="jp-drawer-connector-orb"
          style={{
            background: color,
            boxShadow: `0 0 14px ${color}, 0 0 28px ${color}88`,
            animation: 'orb-travel 2s cubic-bezier(0.4,0,0.6,1) forwards',
          }}
        />
      )}
    </div>
  );
}


END_OF_FILE_CONTENT
echo "Creating src/components/save-drawer/DeployNode.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/save-drawer/DeployNode.tsx"
import type { CSSProperties } from 'react';
import type { DeployStep, StepState } from '@olonjs/core/runtime';

interface DeployNodeProps {
  step: DeployStep;
  state: StepState;
}

export function DeployNode({ step, state }: DeployNodeProps) {
  const isActive = state === 'active';
  const isDone = state === 'done';
  const isPending = state === 'pending';

  return (
    <div className="jp-drawer-node-wrap">
      <div
        className={`jp-drawer-node ${isPending ? 'jp-drawer-node-pending' : ''}`}
        style={
          {
            background: isDone ? step.color : isActive ? 'rgba(0,0,0,0.5)' : undefined,
            borderWidth: isDone ? 0 : 1,
            borderColor: isActive ? `${step.color}80` : undefined,
            boxShadow: isDone
              ? `0 0 20px ${step.color}55, 0 0 40px ${step.color}22`
              : isActive
                ? `0 0 14px ${step.color}33`
                : undefined,
            animation: isActive ? 'node-glow 2s ease infinite' : undefined,
            ['--glow-color' as string]: step.color,
          } as CSSProperties
        }
      >
        {isDone && (
          <svg className="h-5 w-5" viewBox="0 0 24 24" fill="none" aria-label="Done">
            <path
              className="stroke-dash-30 animate-check-draw"
              d="M5 13l4 4L19 7"
              stroke="#0a0f1a"
              strokeWidth="2.5"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        )}

        {isActive && (
          <span
            className="jp-drawer-node-glyph jp-drawer-node-glyph-active"
            style={{ color: step.color, animation: 'glyph-rotate 9s linear infinite' }}
            aria-hidden
          >
            {step.glyph}
          </span>
        )}

        {isPending && (
          <span className="jp-drawer-node-glyph jp-drawer-node-glyph-pending" aria-hidden>
            {step.glyph}
          </span>
        )}

        {isActive && (
          <span
            className="jp-drawer-node-ring"
            style={{
              inset: -7,
              borderColor: `${step.color}50`,
              animation: 'ring-expand 2s ease-out infinite',
            }}
          />
        )}
      </div>

      <span
        className="jp-drawer-node-label"
        style={{ color: isDone ? step.color : isActive ? 'rgba(255,255,255,0.85)' : 'rgba(255,255,255,0.18)' }}
      >
        {step.label}
      </span>
    </div>
  );
}


END_OF_FILE_CONTENT
echo "Creating src/components/save-drawer/DopaDrawer.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/save-drawer/DopaDrawer.tsx"
import { useEffect, useMemo, useState } from 'react';
import { createPortal } from 'react-dom';
import type { StepId, StepState } from '@olonjs/core/runtime';
import { DEPLOY_STEPS } from '@olonjs/core/runtime';
import fontsCss from '@/fonts.css?inline';
import saverStyleCss from './saverStyle.css?inline';
import { DeployNode } from './DeployNode';
import { DeployConnector } from './DeployConnector';
import { BuildBars, ElapsedTimer, Particles, SuccessBurst } from './Visuals';

interface DopaDrawerProps {
  isOpen: boolean;
  phase: 'idle' | 'running' | 'done' | 'error';
  currentStepId: StepId | null;
  doneSteps: StepId[];
  progress: number;
  errorMessage?: string;
  deployUrl?: string;
  onClose: () => void;
  onRetry: () => void;
}

export function DopaDrawer({
  isOpen,
  phase,
  currentStepId,
  doneSteps,
  progress,
  errorMessage,
  deployUrl,
  onClose,
  onRetry,
}: DopaDrawerProps) {
  const [shadowMount, setShadowMount] = useState<HTMLElement | null>(null);
  const [burst, setBurst] = useState(false);
  const [countdown, setCountdown] = useState(3);

  const isRunning = phase === 'running';
  const isDone = phase === 'done';
  const isError = phase === 'error';

  useEffect(() => {
    const host = document.createElement('div');
    host.setAttribute('data-jp-drawer-shadow-host', '');

    const shadowRoot = host.attachShadow({ mode: 'open' });
    const style = document.createElement('style');
    style.textContent = `${fontsCss}\n${saverStyleCss}`;

    const mount = document.createElement('div');
    shadowRoot.append(style, mount);

    document.body.appendChild(host);
    setShadowMount(mount);

    return () => {
      setShadowMount(null);
      host.remove();
    };
  }, []);

  useEffect(() => {
    if (!isOpen) {
      setBurst(false);
      setCountdown(3);
      return;
    }
    if (isDone) setBurst(true);
  }, [isDone, isOpen]);

  useEffect(() => {
    if (!isOpen || !isDone) return;
    setCountdown(3);
    const interval = window.setInterval(() => {
      setCountdown((prev) => {
        if (prev <= 1) {
          window.clearInterval(interval);
          onClose();
          return 0;
        }
        return prev - 1;
      });
    }, 1000);
    return () => window.clearInterval(interval);
  }, [isDone, isOpen, onClose]);

  const currentStep = useMemo(
    () => DEPLOY_STEPS.find((step) => step.id === currentStepId) ?? null,
    [currentStepId]
  );

  const activeColor = isDone ? '#34d399' : isError ? '#f87171' : (currentStep?.color ?? '#60a5fa');
  const particleCount = isDone ? 40 : doneSteps.length === 3 ? 28 : doneSteps.length === 2 ? 16 : doneSteps.length === 1 ? 8 : 4;

  const stepState = (index: number): StepState => {
    const step = DEPLOY_STEPS[index];
    if (doneSteps.includes(step.id)) return 'done';
    if (phase === 'running' && currentStepId === step.id) return 'active';
    return 'pending';
  };

  if (!shadowMount || !isOpen || phase === 'idle') return null;

  return createPortal(
    <div className="jp-drawer-root">
      <div
        className="jp-drawer-overlay animate-fade-in"
        onClick={isDone || isError ? onClose : undefined}
        aria-hidden
      />

      <div
        role="status"
        aria-live="polite"
        aria-label={isDone ? 'Deploy completed' : isError ? 'Deploy failed' : 'Deploying'}
        className="jp-drawer-shell animate-drawer-up"
        style={{ bottom: 'max(2.25rem, env(safe-area-inset-bottom))' }}
      >
        <div
          className="jp-drawer-card"
          style={{
            backgroundColor: 'hsl(222 18% 7%)',
            boxShadow: `0 0 0 1px rgba(255,255,255,0.04), 0 -20px 60px rgba(0,0,0,0.6), 0 0 80px ${activeColor}0d`,
            transition: 'box-shadow 1.2s ease',
          }}
        >
          <div
            className="jp-drawer-ambient"
            style={{
              background: `radial-gradient(ellipse 70% 60% at 50% 110%, ${activeColor}12 0%, transparent 65%)`,
              transition: 'background 1.5s ease',
              animation: 'ambient-pulse 3.5s ease infinite',
            }}
            aria-hidden
          />

          {isDone && (
            <div className="jp-drawer-shimmer" aria-hidden>
              <div
                className="jp-drawer-shimmer-bar"
                style={{
                  background: 'linear-gradient(90deg, transparent, rgba(255,255,255,0.04), transparent)',
                  animation: 'shimmer-sweep 1.4s 0.1s ease forwards',
                }}
              />
            </div>
          )}

          <Particles count={particleCount} color={activeColor} />
          {burst && <SuccessBurst />}

          <div className="jp-drawer-content">
            <div className="jp-drawer-header">
              <div className="jp-drawer-header-left">
                <div className="jp-drawer-status" style={{ color: activeColor }}>
                  <span
                    className="jp-drawer-status-dot"
                    style={{
                      background: activeColor,
                      boxShadow: `0 0 6px ${activeColor}`,
                      animation: isRunning ? 'ambient-pulse 1.5s ease infinite' : 'none',
                    }}
                    aria-hidden
                  />
                  {isDone ? 'Live' : isError ? 'Build failed' : currentStep?.verb ?? 'Saving'}
                </div>

                <div key={currentStep?.id ?? phase} className="jp-drawer-copy animate-text-in">
                  {isDone ? (
                    <div className="animate-success-pop">
                      <p className="jp-drawer-copy-title jp-drawer-copy-title-lg">Your content is live.</p>
                      <p className="jp-drawer-copy-sub">Deployed to production successfully</p>
                    </div>
                  ) : isError ? (
                    <>
                      <p className="jp-drawer-copy-title jp-drawer-copy-title-md">Deploy failed at build.</p>
                      <p className="jp-drawer-copy-sub jp-drawer-copy-sub-error">{errorMessage ?? 'Check your Vercel logs or retry below'}</p>
                    </>
                  ) : currentStep ? (
                    <>
                      <p className="jp-drawer-poem-line jp-drawer-poem-line-1">{currentStep.poem[0]}</p>
                      <p className="jp-drawer-poem-line jp-drawer-poem-line-2">{currentStep.poem[1]}</p>
                    </>
                  ) : null}
                </div>
              </div>

              <div className="jp-drawer-right">
                {isDone ? (
                  <div className="jp-drawer-countdown-wrap animate-fade-up">
                    <span className="jp-drawer-countdown-text" aria-live="polite">
                      Chiusura in {countdown}s
                    </span>
                    <div className="jp-drawer-countdown-track">
                      <div className="jp-drawer-countdown-bar countdown-bar" style={{ boxShadow: '0 0 6px #34d39988' }} />
                    </div>
                  </div>
                ) : (
                  <ElapsedTimer running={isRunning} />
                )}
              </div>
            </div>

            <div className="jp-drawer-track-row">
              {DEPLOY_STEPS.map((step, i) => (
                <div key={step.id} style={{ display: 'flex', alignItems: 'center', flex: i < DEPLOY_STEPS.length - 1 ? 1 : 'none' }}>
                  <DeployNode step={step} state={stepState(i)} />
                  {i < DEPLOY_STEPS.length - 1 && (
                    <DeployConnector fromState={stepState(i)} toState={stepState(i + 1)} color={DEPLOY_STEPS[i + 1].color} />
                  )}
                </div>
              ))}
            </div>

            <div className="jp-drawer-bars-wrap">
              <BuildBars active={stepState(2) === 'active'} />
            </div>

            <div className="jp-drawer-separator" />

            <div className="jp-drawer-footer">
              <div className="jp-drawer-progress">
                <div
                  className="jp-drawer-progress-indicator"
                  style={{
                    width: `${Math.max(0, Math.min(100, progress))}%`,
                    background: `linear-gradient(90deg, ${DEPLOY_STEPS[0].color}, ${activeColor})`,
                  }}
                />
              </div>

              <div className="jp-drawer-cta">
                {isDone && (
                  <div className="jp-drawer-btn-row animate-fade-up">
                    <button type="button" className="jp-drawer-btn jp-drawer-btn-secondary" onClick={onClose}>
                      Chiudi
                    </button>
                    <button
                      type="button"
                      className="jp-drawer-btn jp-drawer-btn-emerald"
                      onClick={() => {
                        if (deployUrl) window.open(deployUrl, '_blank', 'noopener,noreferrer');
                      }}
                      disabled={!deployUrl}
                    >
                      <span aria-hidden>↗</span> Open site
                    </button>
                  </div>
                )}

                {isError && (
                  <div className="jp-drawer-btn-row animate-fade-up">
                    <button type="button" className="jp-drawer-btn jp-drawer-btn-ghost" onClick={onClose}>
                      Annulla
                    </button>
                    <button type="button" className="jp-drawer-btn jp-drawer-btn-destructive" onClick={onRetry}>
                      Retry
                    </button>
                  </div>
                )}

                {isRunning && (
                  <span className="jp-drawer-running-step" aria-hidden>
                    {doneSteps.length + 1} / {DEPLOY_STEPS.length}
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>,
    shadowMount
  );
}


END_OF_FILE_CONTENT
echo "Creating src/components/save-drawer/Visuals.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/save-drawer/Visuals.tsx"
import { useEffect, useRef, useState } from 'react';
import type { CSSProperties } from 'react';

interface Particle {
  id: number;
  x: number;
  y: number;
  size: number;
  dur: number;
  delay: number;
}

const PARTICLE_POOL: Particle[] = Array.from({ length: 44 }, (_, i) => ({
  id: i,
  x: 5 + Math.random() * 90,
  y: 15 + Math.random() * 70,
  size: 1.5 + Math.random() * 2.5,
  dur: 2.8 + Math.random() * 3.5,
  delay: Math.random() * 4,
}));

interface ParticlesProps {
  count: number;
  color: string;
}

export function Particles({ count, color }: ParticlesProps) {
  return (
    <div className="jp-drawer-particles" aria-hidden>
      {PARTICLE_POOL.slice(0, count).map((particle) => (
        <div
          key={particle.id}
          className="jp-drawer-particle"
          style={{
            left: `${particle.x}%`,
            bottom: `${particle.y}%`,
            width: particle.size,
            height: particle.size,
            background: color,
            boxShadow: `0 0 ${particle.size * 3}px ${color}`,
            opacity: 0,
            animation: `particle-float ${particle.dur}s ${particle.delay}s ease-out infinite`,
          }}
        />
      ))}
    </div>
  );
}

const BAR_H = [0.45, 0.75, 0.55, 0.9, 0.65, 0.8, 0.5, 0.72, 0.6, 0.85, 0.42, 0.7];

interface BuildBarsProps {
  active: boolean;
}

export function BuildBars({ active }: BuildBarsProps) {
  if (!active) return <div className="jp-drawer-bars-placeholder" />;

  return (
    <div className="jp-drawer-bars" aria-hidden>
      {BAR_H.map((height, i) => (
        <div
          key={i}
          className="jp-drawer-bar"
          style={{
            height: `${height * 100}%`,
            animation: `bar-eq ${0.42 + i * 0.06}s ${i * 0.04}s ease-in-out infinite alternate`,
          }}
        />
      ))}
    </div>
  );
}

const BURST_COLORS = ['#34d399', '#60a5fa', '#a78bfa', '#f59e0b', '#f472b6'];

export function SuccessBurst() {
  return (
    <div className="jp-drawer-burst" aria-hidden>
      {Array.from({ length: 16 }).map((_, i) => (
        <div
          key={i}
          className="jp-drawer-burst-dot"
          style={
            {
              background: BURST_COLORS[i % BURST_COLORS.length],
              ['--r' as string]: `${i * 22.5}deg`,
              animation: `burst-ray 0.85s ${i * 0.03}s cubic-bezier(0,0.6,0.5,1) forwards`,
              transform: `rotate(${i * 22.5}deg)`,
              transformOrigin: '50% 50%',
              opacity: 0,
            } as CSSProperties
          }
        />
      ))}
    </div>
  );
}

interface ElapsedTimerProps {
  running: boolean;
}

export function ElapsedTimer({ running }: ElapsedTimerProps) {
  const [elapsed, setElapsed] = useState(0);
  const startRef = useRef<number | null>(null);
  const rafRef = useRef<number | null>(null);

  useEffect(() => {
    if (!running) return;
    if (!startRef.current) startRef.current = performance.now();

    const tick = () => {
      if (!startRef.current) return;
      setElapsed(Math.floor((performance.now() - startRef.current) / 1000));
      rafRef.current = requestAnimationFrame(tick);
    };

    rafRef.current = requestAnimationFrame(tick);
    return () => {
      if (rafRef.current) cancelAnimationFrame(rafRef.current);
    };
  }, [running]);

  const sec = String(elapsed % 60).padStart(2, '0');
  const min = String(Math.floor(elapsed / 60)).padStart(2, '0');
  return <span className="jp-drawer-elapsed" aria-live="off">{min}:{sec}</span>;
}


END_OF_FILE_CONTENT
echo "Creating src/components/save-drawer/saverStyle.css..."
cat << 'END_OF_FILE_CONTENT' > "src/components/save-drawer/saverStyle.css"
/* Save Drawer strict_full isolated stylesheet */

.jp-drawer-root {
  --background: 222 18% 6%;
  --foreground: 210 20% 96%;
  --card: 222 16% 8%;
  --card-foreground: 210 20% 96%;
  --primary: 0 0% 95%;
  --primary-foreground: 222 18% 6%;
  --secondary: 220 14% 13%;
  --secondary-foreground: 210 20% 96%;
  --destructive: 0 72% 51%;
  --destructive-foreground: 0 0% 98%;
  --border: 220 14% 13%;
  --radius: 0.6rem;
  font-family: 'Geist', system-ui, sans-serif;
}

.jp-drawer-overlay {
  position: fixed;
  inset: 0;
  z-index: 2147483600;
  background: rgb(0 0 0 / 0.4);
  backdrop-filter: blur(2px);
}

.jp-drawer-shell {
  position: fixed;
  left: 0;
  right: 0;
  z-index: 2147483601;
  display: flex;
  justify-content: center;
  padding: 0 1rem;
}

.jp-drawer-card {
  position: relative;
  width: 100%;
  max-width: 31rem;
  overflow: hidden;
  border-radius: 1rem;
  border: 1px solid rgb(255 255 255 / 0.07);
}

.jp-drawer-ambient {
  position: absolute;
  inset: 0;
  pointer-events: none;
}

.jp-drawer-shimmer {
  position: absolute;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
}

.jp-drawer-shimmer-bar {
  position: absolute;
  inset-block: 0;
  width: 35%;
}

.jp-drawer-content {
  position: relative;
  z-index: 10;
  padding: 2rem 2rem 1.75rem;
}

.jp-drawer-header {
  margin-bottom: 1.5rem;
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
}

.jp-drawer-header-left {
  display: flex;
  flex-direction: column;
  gap: 0.625rem;
}

.jp-drawer-status {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.75rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  transition: color 0.5s;
}

.jp-drawer-status-dot {
  width: 0.375rem;
  height: 0.375rem;
  border-radius: 9999px;
  display: inline-block;
}

.jp-drawer-copy {
  min-height: 52px;
}

.jp-drawer-copy-title {
  margin: 0;
  color: white;
  line-height: 1.25;
  font-weight: 600;
}

.jp-drawer-copy-title-lg {
  font-size: 1.125rem;
}

.jp-drawer-copy-title-md {
  font-size: 1rem;
}

.jp-drawer-copy-sub {
  margin: 0.125rem 0 0;
  color: rgb(255 255 255 / 0.4);
  font-size: 0.875rem;
}

.jp-drawer-copy-sub-error {
  color: rgb(255 255 255 / 0.35);
}

.jp-drawer-poem-line {
  margin: 0;
  font-size: 0.875rem;
  font-weight: 300;
  line-height: 1.5;
}

.jp-drawer-poem-line-1 {
  color: rgb(255 255 255 / 0.55);
}

.jp-drawer-poem-line-2 {
  color: rgb(255 255 255 / 0.3);
}

.jp-drawer-right {
  margin-left: 1.5rem;
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.5rem;
  flex-shrink: 0;
}

.jp-drawer-countdown-wrap {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.5rem;
}

.jp-drawer-countdown-text {
  font-family: 'Geist Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.75rem;
  font-weight: 600;
  color: #34d399;
}

.jp-drawer-countdown-track {
  width: 6rem;
  height: 0.125rem;
  border-radius: 9999px;
  overflow: hidden;
  background: rgb(255 255 255 / 0.1);
}

.jp-drawer-countdown-bar {
  width: 100%;
  height: 100%;
  border-radius: 9999px;
  background: #34d399;
}

.jp-drawer-track-row {
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
}

.jp-drawer-bars-wrap {
  margin-bottom: 1rem;
  display: flex;
  justify-content: center;
}

.jp-drawer-separator {
  margin-bottom: 1rem;
  height: 1px;
  width: 100%;
  border: 0;
  background: rgb(255 255 255 / 0.06);
}

.jp-drawer-footer {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.jp-drawer-progress {
  flex: 1;
  height: 2px;
  border-radius: 9999px;
  overflow: hidden;
  background: rgb(255 255 255 / 0.06);
}

.jp-drawer-progress-indicator {
  height: 100%;
}

.jp-drawer-cta {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-shrink: 0;
}

.jp-drawer-running-step {
  font-family: 'Geist Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.75rem;
  color: rgb(255 255 255 / 0.2);
}

.jp-drawer-btn-row {
  display: flex;
  gap: 0.5rem;
}

.jp-drawer-btn {
  border: 1px solid transparent;
  border-radius: 0.375rem;
  font-size: 0.8125rem;
  font-weight: 500;
  line-height: 1;
  height: 2.25rem;
  padding: 0 0.75rem;
  cursor: pointer;
  transition: all 0.2s ease;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.375rem;
}

.jp-drawer-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.jp-drawer-btn-secondary {
  background: hsl(var(--secondary));
  color: hsl(var(--secondary-foreground));
}

.jp-drawer-btn-secondary:hover {
  filter: brightness(1.08);
}

.jp-drawer-btn-emerald {
  background: #34d399;
  color: #18181b;
  font-weight: 600;
}

.jp-drawer-btn-emerald:hover {
  background: #6ee7b7;
}

.jp-drawer-btn-ghost {
  background: transparent;
  color: rgb(255 255 255 / 0.9);
}

.jp-drawer-btn-ghost:hover {
  background: rgb(255 255 255 / 0.08);
}

.jp-drawer-btn-destructive {
  background: hsl(var(--destructive));
  color: hsl(var(--destructive-foreground));
}

.jp-drawer-btn-destructive:hover {
  filter: brightness(1.06);
}

.jp-drawer-node-wrap {
  position: relative;
  z-index: 10;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.625rem;
}

.jp-drawer-node {
  position: relative;
  width: 3rem;
  height: 3rem;
  border-radius: 9999px;
  border: 1px solid transparent;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.5s;
}

.jp-drawer-node-pending {
  border-color: rgb(255 255 255 / 0.08);
  background: rgb(255 255 255 / 0.02);
}

.jp-drawer-node-glyph {
  font-size: 1.125rem;
  line-height: 1;
}

.jp-drawer-node-glyph-active {
  display: inline-block;
}

.jp-drawer-node-glyph-pending {
  color: rgb(255 255 255 / 0.15);
}

.jp-drawer-node-ring {
  position: absolute;
  border-radius: 9999px;
  border: 1px solid transparent;
}

.jp-drawer-node-label {
  font-size: 10px;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.1em;
  transition: color 0.5s;
}

.jp-drawer-connector {
  position: relative;
  z-index: 0;
  flex: 1;
  height: 2px;
  margin-top: -24px;
}

.jp-drawer-connector-base {
  position: absolute;
  inset: 0;
  border-radius: 9999px;
  background: rgb(255 255 255 / 0.08);
}

.jp-drawer-connector-fill {
  position: absolute;
  left: 0;
  right: auto;
  top: 0;
  bottom: 0;
  border-radius: 9999px;
}

.jp-drawer-connector-orb {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  width: 10px;
  height: 10px;
  border-radius: 9999px;
}

.jp-drawer-particles {
  position: absolute;
  inset: 0;
  overflow: hidden;
  pointer-events: none;
}

.jp-drawer-particle {
  position: absolute;
  border-radius: 9999px;
}

.jp-drawer-bars {
  height: 1.75rem;
  display: flex;
  align-items: flex-end;
  gap: 3px;
}

.jp-drawer-bars-placeholder {
  height: 1.75rem;
}

.jp-drawer-bar {
  width: 3px;
  border-radius: 2px;
  background: #f59e0b;
  transform-origin: bottom;
}

.jp-drawer-burst {
  position: absolute;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.jp-drawer-burst-dot {
  position: absolute;
  width: 5px;
  height: 5px;
  border-radius: 9999px;
}

.jp-drawer-elapsed {
  font-family: 'Geist Mono', ui-monospace, SFMono-Regular, Menlo, monospace;
  font-size: 0.75rem;
  letter-spacing: 0.1em;
  color: rgb(255 255 255 / 0.25);
}

/* Animation helper classes */
.animate-drawer-up { animation: drawer-up 0.45s cubic-bezier(0.22, 1, 0.36, 1) forwards; }
.animate-fade-in { animation: fade-in 0.25s ease forwards; }
.animate-fade-up { animation: fade-up 0.35s ease forwards; }
.animate-text-in { animation: text-in 0.3s ease forwards; }
.animate-success-pop { animation: success-pop 0.5s cubic-bezier(0.34, 1.56, 0.64, 1) forwards; }
.countdown-bar { animation: countdown-drain 3s linear forwards; }

.stroke-dash-30 {
  stroke-dasharray: 30;
  stroke-dashoffset: 30;
}

.animate-check-draw {
  animation: check-draw 0.4s 0.05s ease forwards;
}

@keyframes check-draw {
  to { stroke-dashoffset: 0; }
}

@keyframes drawer-up {
  from { transform: translateY(100%); opacity: 0; }
  to { transform: translateY(0); opacity: 1; }
}

@keyframes fade-in {
  from { opacity: 0; }
  to { opacity: 1; }
}

@keyframes fade-up {
  from { opacity: 0; transform: translateY(8px); }
  to { transform: translateY(0); opacity: 1; }
}

@keyframes text-in {
  from { opacity: 0; transform: translateX(-6px); }
  to { opacity: 1; transform: translateX(0); }
}

@keyframes success-pop {
  0% { transform: scale(0.88); opacity: 0; }
  60% { transform: scale(1.04); }
  100% { transform: scale(1); opacity: 1; }
}

@keyframes ambient-pulse {
  0%, 100% { opacity: 0.3; }
  50% { opacity: 0.65; }
}

@keyframes shimmer-sweep {
  from { transform: translateX(-100%); }
  to { transform: translateX(250%); }
}

@keyframes node-glow {
  0%, 100% { box-shadow: 0 0 12px var(--glow-color,#60a5fa55); }
  50% { box-shadow: 0 0 28px var(--glow-color,#60a5fa88), 0 0 48px var(--glow-color,#60a5fa22); }
}

@keyframes glyph-rotate {
  from { transform: rotate(0deg); }
  to { transform: rotate(360deg); }
}

@keyframes ring-expand {
  from { transform: scale(1); opacity: 0.7; }
  to { transform: scale(2.1); opacity: 0; }
}

@keyframes orb-travel {
  from { left: 0%; }
  to { left: calc(100% - 10px); }
}

@keyframes particle-float {
  0% { transform: translateY(0) scale(1); opacity: 0; }
  15% { opacity: 1; }
  100% { transform: translateY(-90px) scale(0.3); opacity: 0; }
}

@keyframes bar-eq {
  from { transform: scaleY(0.4); }
  to { transform: scaleY(1); }
}

@keyframes burst-ray {
  0% { transform: rotate(var(--r, 0deg)) translateX(0); opacity: 1; }
  100% { transform: rotate(var(--r, 0deg)) translateX(56px); opacity: 0; }
}

@keyframes countdown-drain {
  from { width: 100%; }
  to { width: 0%; }
}


END_OF_FILE_CONTENT
mkdir -p "src/components/tiptap"
echo "Creating src/components/tiptap/INTEGRATION.md..."
cat << 'END_OF_FILE_CONTENT' > "src/components/tiptap/INTEGRATION.md"
# Tiptap Editorial — Integration Guide

How to add the `tiptap` section to a new tenant.

---

## 1. Copy the component

Copy the entire folder into the new tenant:

```
src/components/tiptap/
  index.ts
  types.ts
  View.tsx
```

---

## 2. Install npm dependencies

Add to the tenant's `package.json` and run `npm install`:

```json
"@tiptap/extension-image": "^2.11.5",
"@tiptap/extension-link": "^2.11.5",
"@tiptap/react": "^2.11.5",
"@tiptap/starter-kit": "^2.11.5",
"react-markdown": "^9.0.1",
"rehype-sanitize": "^6.0.0",
"remark-gfm": "^4.0.1",
"tiptap-markdown": "^0.8.10"
```

---

## 3. Add CSS to `src/index.css`

Two blocks are required — one for the public (visitor) view, one for the editor (studio) view.

```css
/* ==========================================================================
   TIPTAP — Public content typography (visitor view)
   ========================================================================== */
.jp-tiptap-content > * + * { margin-top: 0.75em; }

.jp-tiptap-content h1 { font-size: 2em;    font-weight: 700; line-height: 1.2; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-tiptap-content h2 { font-size: 1.5em;  font-weight: 700; line-height: 1.3; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-tiptap-content h3 { font-size: 1.25em; font-weight: 600; line-height: 1.4; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-tiptap-content h4 { font-size: 1em;    font-weight: 600; line-height: 1.5; margin-top: 1em;    margin-bottom: 0.25em; }

.jp-tiptap-content p  { line-height: 1.7; }
.jp-tiptap-content strong { font-weight: 700; }
.jp-tiptap-content em     { font-style: italic; }
.jp-tiptap-content s      { text-decoration: line-through; }

.jp-tiptap-content a { color: var(--primary); text-decoration: underline; text-underline-offset: 2px; }
.jp-tiptap-content a:hover { opacity: 0.8; }

.jp-tiptap-content code {
  font-family: var(--font-mono, ui-monospace, monospace);
  font-size: 0.875em;
  background: color-mix(in oklch, var(--foreground) 8%, transparent);
  border-radius: 0.25em;
  padding: 0.1em 0.35em;
}
.jp-tiptap-content pre {
  background: color-mix(in oklch, var(--background) 60%, black);
  border-radius: 0.5em;
  padding: 1em 1.25em;
  overflow-x: auto;
}
.jp-tiptap-content pre code { background: none; padding: 0; }

.jp-tiptap-content ul { list-style-type: disc;    padding-left: 1.625em; }
.jp-tiptap-content ol { list-style-type: decimal; padding-left: 1.625em; }
.jp-tiptap-content li { line-height: 1.7; margin-top: 0.25em; }
.jp-tiptap-content li + li { margin-top: 0.25em; }

.jp-tiptap-content blockquote {
  border-left: 3px solid var(--border);
  padding-left: 1em;
  color: var(--muted-foreground);
  font-style: italic;
}
.jp-tiptap-content hr { border: none; border-top: 1px solid var(--border); margin: 1.5em 0; }
.jp-tiptap-content img { max-width: 100%; height: auto; border-radius: 0.5rem; }

/* ==========================================================================
   TIPTAP / PROSEMIRROR — Editor typography (studio view)
   ========================================================================== */
.jp-simple-editor .ProseMirror { outline: none; word-break: break-word; }
.jp-simple-editor .ProseMirror > * + * { margin-top: 0.75em; }

.jp-simple-editor .ProseMirror h1 { font-size: 2em;    font-weight: 700; line-height: 1.2; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-simple-editor .ProseMirror h2 { font-size: 1.5em;  font-weight: 700; line-height: 1.3; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-simple-editor .ProseMirror h3 { font-size: 1.25em; font-weight: 600; line-height: 1.4; margin-top: 1.25em; margin-bottom: 0.25em; }
.jp-simple-editor .ProseMirror h4 { font-size: 1em;    font-weight: 600; line-height: 1.5; margin-top: 1em;    margin-bottom: 0.25em; }

.jp-simple-editor .ProseMirror p  { line-height: 1.7; }
.jp-simple-editor .ProseMirror strong { font-weight: 700; }
.jp-simple-editor .ProseMirror em     { font-style: italic; }
.jp-simple-editor .ProseMirror s      { text-decoration: line-through; }

.jp-simple-editor .ProseMirror a { color: var(--primary); text-decoration: underline; text-underline-offset: 2px; }
.jp-simple-editor .ProseMirror a:hover { opacity: 0.8; }

.jp-simple-editor .ProseMirror code {
  font-family: var(--font-mono, ui-monospace, monospace);
  font-size: 0.875em;
  background: color-mix(in oklch, var(--foreground) 8%, transparent);
  border-radius: 0.25em;
  padding: 0.1em 0.35em;
}
.jp-simple-editor .ProseMirror pre {
  background: color-mix(in oklch, var(--background) 60%, black);
  border-radius: 0.5em;
  padding: 1em 1.25em;
  overflow-x: auto;
}
.jp-simple-editor .ProseMirror pre code { background: none; padding: 0; }

.jp-simple-editor .ProseMirror ul { list-style-type: disc;    padding-left: 1.625em; }
.jp-simple-editor .ProseMirror ol { list-style-type: decimal; padding-left: 1.625em; }
.jp-simple-editor .ProseMirror li { line-height: 1.7; margin-top: 0.25em; }
.jp-simple-editor .ProseMirror li + li { margin-top: 0.25em; }

.jp-simple-editor .ProseMirror blockquote {
  border-left: 3px solid var(--border);
  padding-left: 1em;
  color: var(--muted-foreground);
  font-style: italic;
}
.jp-simple-editor .ProseMirror hr { border: none; border-top: 1px solid var(--border); margin: 1.5em 0; }

.jp-simple-editor .ProseMirror img { max-width: 100%; height: auto; border-radius: 0.5rem; }
.jp-simple-editor .ProseMirror img[data-uploading="true"] {
  opacity: 0.6;
  filter: grayscale(0.25);
  outline: 2px dashed rgb(59 130 246 / 0.7);
  outline-offset: 2px;
}
.jp-simple-editor .ProseMirror img[data-upload-error="true"] {
  outline: 2px solid rgb(239 68 68 / 0.8);
  outline-offset: 2px;
}
.jp-simple-editor .ProseMirror p.is-editor-empty:first-child::before {
  content: attr(data-placeholder);
  color: var(--muted-foreground);
  opacity: 0.5;
  pointer-events: none;
  float: left;
  height: 0;
}
```

---

## 4. Register in `src/lib/schemas.ts`

```ts
import { TiptapSchema } from '@/components/tiptap';

export const SECTION_SCHEMAS = {
  // ... existing schemas
  'tiptap': TiptapSchema,
} as const;
```

---

## 5. Register in `src/lib/addSectionConfig.ts`

```ts
const addableSectionTypes = [
  // ... existing types
  'tiptap',
] as const;

const sectionTypeLabels = {
  // ... existing labels
  'tiptap': 'Tiptap Editorial',
};

function getDefaultSectionData(type: string) {
  switch (type) {
    // ... existing cases
    case 'tiptap': return { content: '# Post title\n\nStart writing in Markdown...' };
  }
}
```

---

## 6. Register in `src/lib/ComponentRegistry.tsx`

```tsx
import { Tiptap } from '@/components/tiptap';

export const ComponentRegistry = {
  // ... existing components
  'tiptap': Tiptap,
};
```

---

## 7. Register in `src/types.ts`

```ts
import type { TiptapData, TiptapSettings } from '@/components/tiptap';

export type SectionComponentPropsMap = {
  // ... existing entries
  'tiptap': { data: TiptapData; settings?: TiptapSettings };
};

declare module '@jsonpages/core' {
  export interface SectionDataRegistry {
    // ... existing entries
    'tiptap': TiptapData;
  }
  export interface SectionSettingsRegistry {
    // ... existing entries
    'tiptap': TiptapSettings;
  }
}
```

---

## Notes

- Typography uses tenant CSS variables (`--primary`, `--border`, `--muted-foreground`, `--font-mono`) — no hardcoded colors.
- `@tailwindcss/typography` is **not** required; the CSS blocks above replace it.
- The toolbar is admin-only (studio mode). In visitor mode, content is rendered via `ReactMarkdown`.
- Underline is intentionally excluded: `tiptap-markdown` with `html: false` cannot round-trip `<u>` tags.

END_OF_FILE_CONTENT
echo "Creating src/components/tiptap/View.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/tiptap/View.tsx"
import React from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import rehypeSanitize from 'rehype-sanitize';
import { useEditor, EditorContent } from '@tiptap/react';
import type { Editor } from '@tiptap/react';
import StarterKit from '@tiptap/starter-kit';
import Link from '@tiptap/extension-link';
import Image from '@tiptap/extension-image';
import { Markdown } from 'tiptap-markdown';
import {
  Undo2, Redo2,
  List, ListOrdered,
  Bold, Italic, Strikethrough,
  Code2, Quote, SquareCode,
  Link2, Unlink2, ImagePlus, Eraser,
} from 'lucide-react';
import { STUDIO_EVENTS, useConfig, useStudio } from '@olonjs/core/runtime';
import type { TiptapData, TiptapSettings } from './types';

// ── UI primitives ─────────────────────────────────────────────────
const Btn: React.FC<{
  active?: boolean; title: string; onClick: () => void; children: React.ReactNode;
}> = ({ active = false, title, onClick, children }) => (
  <button
    type="button" title={title}
    onMouseDown={(e) => e.preventDefault()} onClick={onClick}
    className={[
      'inline-flex h-7 min-w-7 items-center justify-center rounded-md px-2 text-xs transition-colors',
      active ? 'bg-zinc-700/70 text-zinc-100' : 'text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200',
    ].join(' ')}
  >{children}</button>
);

const Sep: React.FC = () => (
  <span className="mx-0.5 h-5 w-px shrink-0 bg-zinc-800" aria-hidden />
);

// ── Image extension with upload metadata ──────────────────────────
const UploadableImage = Image.extend({
  addAttributes() {
    const bool = (attr: string) => ({
      default: false,
      parseHTML: (el: HTMLElement) => el.getAttribute(attr) === 'true',
      renderHTML: (attrs: Record<string, unknown>) =>
        attrs[attr.replace('data-', '').replace(/-([a-z])/g, (_: string, c: string) => c.toUpperCase())]
          ? { [attr]: 'true' } : {},
    });
    return {
      ...this.parent?.(),
      uploadId: {
        default: null,
        parseHTML: (el: HTMLElement) => el.getAttribute('data-upload-id'),
        renderHTML: (attrs: Record<string, unknown>) =>
          attrs.uploadId ? { 'data-upload-id': String(attrs.uploadId) } : {},
      },
      uploading: bool('data-uploading'),
      uploadError: bool('data-upload-error'),
      awaitingUpload: bool('data-awaiting-upload'),
    };
  },
});

// ── Helpers ───────────────────────────────────────────────────────
const getMarkdown = (ed: Editor | null | undefined): string =>
  (ed?.storage as { markdown?: { getMarkdown?: () => string } } | undefined)
    ?.markdown?.getMarkdown?.() ?? '';

const svg = (body: string) =>
  'data:image/svg+xml;utf8,' +
  encodeURIComponent(
    '<svg xmlns=\'http://www.w3.org/2000/svg\' width=\'1200\' height=\'420\' viewBox=\'0 0 1200 420\'>' + body + '</svg>'
  );

const RECT = '<rect width=\'1200\' height=\'420\' fill=\'#090B14\' stroke=\'#3F3F46\' stroke-width=\'3\' stroke-dasharray=\'10 10\' rx=\'12\'/>';

const UPLOADING_SRC = svg(
  RECT + '<text x=\'600\' y=\'215\' font-family=\'Inter,Arial,sans-serif\' font-size=\'28\' font-weight=\'700\' fill=\'#A1A1AA\' text-anchor=\'middle\'>Uploading image\u2026</text>'
);

const PICKER_SRC = svg(
  RECT +
  '<text x=\'600\' y=\'200\' font-family=\'Inter,Arial,sans-serif\' font-size=\'32\' font-weight=\'700\' fill=\'#E4E4E7\' text-anchor=\'middle\'>Click to upload or drag &amp; drop</text>' +
  '<text x=\'600\' y=\'248\' font-family=\'Inter,Arial,sans-serif\' font-size=\'22\' fill=\'#A1A1AA\' text-anchor=\'middle\'>Max 5 MB per file</text>'
);

const patchImage = (ed: Editor, uploadId: string, patch: Record<string, unknown>): boolean => {
  let pos: number | null = null;
  ed.state.doc.descendants(
    (node: { type: { name: string }; attrs?: Record<string, unknown> }, p: number) => {
      if (node.type.name === 'image' && node.attrs?.uploadId === uploadId) { pos = p; return false; }
      return true;
    }
  );
  if (pos == null) return false;
  const cur = ed.state.doc.nodeAt(pos);
  if (!cur) return false;
  ed.view.dispatch(ed.state.tr.setNodeMarkup(pos, undefined, { ...cur.attrs, ...patch }));
  return true;
};

const EXTENSIONS = [
  StarterKit,
  Link.configure({ openOnClick: false, autolink: true }),
  UploadableImage,
  Markdown.configure({ html: false }),
];

// ── Studio editor ─────────────────────────────────────────────────
const StudioTiptapEditor: React.FC<{ data: TiptapData }> = ({ data }) => {
  const { assets } = useConfig();
  const hostRef = React.useRef<HTMLDivElement | null>(null);
  const sectionRef = React.useRef<HTMLElement | null>(null);
  const fileInputRef = React.useRef<HTMLInputElement | null>(null);
  const editorRef = React.useRef<Editor | null>(null);
  const pendingUploads = React.useRef<Map<string, Promise<void>>>(new Map());
  const pendingPickerId = React.useRef<string | null>(null);
  const latestMd = React.useRef<string>(data.content ?? '');
  const emittedMd = React.useRef<string>(data.content ?? '');
  const [linkOpen, setLinkOpen] = React.useState(false);
  const [linkUrl, setLinkUrl] = React.useState('');
  const linkInputRef = React.useRef<HTMLInputElement | null>(null);

  const getSectionId = React.useCallback((): string | null => {
    const el = sectionRef.current ?? (hostRef.current?.closest('[data-section-id]') as HTMLElement | null);
    sectionRef.current = el;
    return el?.getAttribute('data-section-id') ?? null;
  }, []);

  const emit = React.useCallback((markdown: string) => {
    latestMd.current = markdown;
    const sectionId = getSectionId();
    if (!sectionId) return;
    window.parent.postMessage({ type: STUDIO_EVENTS.INLINE_FIELD_UPDATE, sectionId, fieldKey: 'content', value: markdown }, window.location.origin);
    emittedMd.current = markdown;
  }, [getSectionId]);

  const setFocusLock = React.useCallback((on: boolean) => {
    sectionRef.current?.classList.toggle('jp-editorial-focus', on);
  }, []);

  const insertPlaceholder = React.useCallback((uploadId: string, src: string, awaitingUpload: boolean) => {
    const ed = editorRef.current;
    if (!ed) return;
    ed.chain().focus().setImage({ src, alt: 'upload-placeholder', title: awaitingUpload ? 'Click to upload' : 'Uploading\u2026', uploadId, uploading: !awaitingUpload, awaitingUpload, uploadError: false } as any).run();
    emit(getMarkdown(ed));
  }, [emit]);

  const doUpload = React.useCallback(async (uploadId: string, file: File) => {
    const uploadFn = assets?.onAssetUpload;
    if (!uploadFn) return;
    const ed = editorRef.current;
    if (!ed) return;
    patchImage(ed, uploadId, { src: UPLOADING_SRC, alt: file.name, title: file.name, uploading: true, awaitingUpload: false, uploadError: false });
    const task = (async () => {
      try {
        const url = await uploadFn(file);
        const cur = editorRef.current;
        if (cur) { patchImage(cur, uploadId, { src: url, alt: file.name, title: file.name, uploadId: null, uploading: false, awaitingUpload: false, uploadError: false }); emit(getMarkdown(cur)); }
      } catch {
        const cur = editorRef.current;
        if (cur) { patchImage(cur, uploadId, { uploading: false, awaitingUpload: false, uploadError: true }); emit(getMarkdown(cur)); }
      } finally { pendingUploads.current.delete(uploadId); }
    })();
    pendingUploads.current.set(uploadId, task);
  }, [assets, emit]);

  const uploadFile = React.useCallback(async (file: File) => {
    const id = crypto.randomUUID();
    insertPlaceholder(id, UPLOADING_SRC, false);
    await doUpload(id, file);
  }, [insertPlaceholder, doUpload]);

  const editor = useEditor({
    extensions: EXTENSIONS,
    content: data.content ?? '',
    editorProps: { attributes: { class: 'min-h-[220px] p-4 outline-none' } },
    onUpdate({ editor: ed }) { emit(getMarkdown(ed)); },
    onFocus() { setFocusLock(true); },
    onBlur() {
      setTimeout(() => {
        if (!hostRef.current?.contains(document.activeElement)) setFocusLock(false);
      }, 100);
    },
    onCreate({ editor: ed }) {
      editorRef.current = ed;
      if (data.content) ed.commands.setContent(data.content);
    },
    onDestroy() { editorRef.current = null; },
  });

  React.useEffect(() => {
    if (!editor || !data.content || data.content === latestMd.current) return;
    latestMd.current = data.content;
    emittedMd.current = data.content;
    editor.commands.setContent(data.content);
  }, [editor, data.content]);

  React.useEffect(() => {
    const host = hostRef.current;
    if (!host) return;
    const onDrop = (e: DragEvent) => {
      e.preventDefault();
      const files = Array.from(e.dataTransfer?.files ?? []).filter(f => f.type.startsWith('image/'));
      files.forEach(f => void uploadFile(f));
    };
    const onPaste = (e: ClipboardEvent) => {
      const files = Array.from(e.clipboardData?.files ?? []).filter(f => f.type.startsWith('image/'));
      if (!files.length) return;
      e.preventDefault();
      files.forEach(f => void uploadFile(f));
    };
    host.addEventListener('drop', onDrop);
    host.addEventListener('paste', onPaste);
    return () => { host.removeEventListener('drop', onDrop); host.removeEventListener('paste', onPaste); };
  }, [uploadFile]);

  const openLink = () => {
    const existing = editor?.getAttributes('link').href ?? '';
    setLinkUrl(existing);
    setLinkOpen(true);
    setTimeout(() => linkInputRef.current?.focus(), 50);
  };

  const applyLink = () => {
    if (!editor) return;
    const url = linkUrl.trim();
    if (url) editor.chain().focus().setLink({ href: url }).run();
    else editor.chain().focus().unsetLink().run();
    setLinkOpen(false);
  };

  const onFileSelected = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    const pickId = pendingPickerId.current;
    void (async () => {
      try {
        if (pickId) { await doUpload(pickId, file); pendingPickerId.current = null; }
        else { await uploadFile(file); }
      } catch { pendingPickerId.current = null; }
    })();
  };

  const onPickImage = () => {
    if (pendingPickerId.current) return;
    const id = crypto.randomUUID();
    pendingPickerId.current = id;
    insertPlaceholder(id, PICKER_SRC, true);
  };

  const isActive = (name: string, attrs?: Record<string, unknown>) => editor?.isActive(name, attrs) ?? false;

  return (
    <div ref={hostRef} data-jp-field="content" className="space-y-2">
      {editor && (
        <div data-jp-ignore-select="true" className="sticky top-0 z-[65] border-b border-zinc-800 bg-zinc-950">
          <div className="flex flex-wrap items-center justify-center gap-1 p-2">
            <Btn title="Undo" onClick={() => editor.chain().focus().undo().run()}><Undo2 size={13} /></Btn>
            <Btn title="Redo" onClick={() => editor.chain().focus().redo().run()}><Redo2 size={13} /></Btn>
            <Sep />
            <Btn active={isActive('paragraph')} title="Paragraph" onClick={() => editor.chain().focus().setParagraph().run()}>P</Btn>
            <Btn active={isActive('heading', { level: 1 })} title="Heading 1" onClick={() => editor.chain().focus().toggleHeading({ level: 1 }).run()}>H1</Btn>
            <Btn active={isActive('heading', { level: 2 })} title="Heading 2" onClick={() => editor.chain().focus().toggleHeading({ level: 2 }).run()}>H2</Btn>
            <Btn active={isActive('heading', { level: 3 })} title="Heading 3" onClick={() => editor.chain().focus().toggleHeading({ level: 3 }).run()}>H3</Btn>
            <Sep />
            <Btn active={isActive('bold')} title="Bold (Ctrl+B)" onClick={() => editor.chain().focus().toggleBold().run()}><Bold size={13} /></Btn>
            <Btn active={isActive('italic')} title="Italic (Ctrl+I)" onClick={() => editor.chain().focus().toggleItalic().run()}><Italic size={13} /></Btn>
            <Btn active={isActive('strike')} title="Strikethrough" onClick={() => editor.chain().focus().toggleStrike().run()}><Strikethrough size={13} /></Btn>
            <Btn active={isActive('code')} title="Inline code" onClick={() => editor.chain().focus().toggleCode().run()}><Code2 size={13} /></Btn>
            <Sep />
            <Btn active={isActive('bulletList')} title="Bullet list" onClick={() => editor.chain().focus().toggleBulletList().run()}><List size={13} /></Btn>
            <Btn active={isActive('orderedList')} title="Ordered list" onClick={() => editor.chain().focus().toggleOrderedList().run()}><ListOrdered size={13} /></Btn>
            <Btn active={isActive('blockquote')} title="Blockquote" onClick={() => editor.chain().focus().toggleBlockquote().run()}><Quote size={13} /></Btn>
            <Btn active={isActive('codeBlock')} title="Code block" onClick={() => editor.chain().focus().toggleCodeBlock().run()}><SquareCode size={13} /></Btn>
            <Sep />
            <Btn active={isActive('link') || linkOpen} title="Set link" onClick={openLink}><Link2 size={13} /></Btn>
            <Btn title="Remove link" onClick={() => editor.chain().focus().unsetLink().run()}><Unlink2 size={13} /></Btn>
            <Btn title="Insert image" onClick={onPickImage}><ImagePlus size={13} /></Btn>
            <Btn title="Clear formatting" onClick={() => editor.chain().focus().unsetAllMarks().clearNodes().run()}><Eraser size={13} /></Btn>
          </div>
          {linkOpen && (
            <div className="flex items-center gap-2 border-t border-zinc-700 px-2 py-1.5">
              <Link2 size={12} className="shrink-0 text-zinc-500" />
              <input ref={linkInputRef} type="url" value={linkUrl} onChange={(e) => setLinkUrl(e.target.value)}
                onKeyDown={(e) => { if (e.key === 'Enter') { e.preventDefault(); applyLink(); } if (e.key === 'Escape') setLinkOpen(false); }}
                placeholder="https://example.com"
                className="min-w-0 flex-1 bg-transparent text-xs text-zinc-100 placeholder:text-zinc-500 outline-none" />
              <button type="button" onMouseDown={(e) => e.preventDefault()} onClick={applyLink} className="shrink-0 rounded px-2 py-0.5 text-xs bg-blue-600 hover:bg-blue-500 text-white transition-colors">Set</button>
              <button type="button" onMouseDown={(e) => e.preventDefault()} onClick={() => setLinkOpen(false)} className="shrink-0 rounded px-2 py-0.5 text-xs bg-zinc-700 hover:bg-zinc-600 text-zinc-200 transition-colors">Cancel</button>
            </div>
          )}
        </div>
      )}
      <EditorContent editor={editor} className="jp-simple-editor" />
      <input ref={fileInputRef} type="file" accept="image/*" className="hidden" onChange={onFileSelected} />
    </div>
  );
};

// ── Public view ───────────────────────────────────────────────────
const PublicTiptapContent: React.FC<{ content: string }> = ({ content }) => (
  <article className="jp-tiptap-content" data-jp-field="content">
    <ReactMarkdown remarkPlugins={[remarkGfm]} rehypePlugins={[rehypeSanitize]}>
      {content}
    </ReactMarkdown>
  </article>
);

// ── Export ────────────────────────────────────────────────────────
export const Tiptap: React.FC<{ data: TiptapData; settings?: TiptapSettings }> = ({ data }) => {
  const { mode } = useStudio();
  return (
    <section
      style={{ '--local-bg': 'var(--background)', '--local-text': 'var(--foreground)' } as React.CSSProperties}
      className="relative z-0 w-full py-12 bg-[var(--local-bg)]"
    >
      <div className="max-w-3xl mx-auto px-6">
        {mode === 'studio' ? (
          <StudioTiptapEditor data={data} />
        ) : (
          <PublicTiptapContent content={data.content ?? ''} />
        )}
      </div>
    </section>
  );
};

END_OF_FILE_CONTENT
echo "Creating src/components/tiptap/index.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/tiptap/index.ts"
export * from './View';
export * from './schema';
export * from './types';

END_OF_FILE_CONTENT
echo "Creating src/components/tiptap/schema.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/tiptap/schema.ts"
import { z } from 'zod';
import { BaseSectionData } from '@olonjs/core/runtime';

export const TiptapSchema = BaseSectionData.extend({
  content: z.string().default('').describe('ui:editorial-markdown'),
});

export const TiptapSettingsSchema = z.object({});

END_OF_FILE_CONTENT
echo "Creating src/components/tiptap/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/components/tiptap/types.ts"
import { z } from 'zod';
import { TiptapSchema, TiptapSettingsSchema } from './schema';

export type TiptapData     = z.infer<typeof TiptapSchema>;
export type TiptapSettings = z.infer<typeof TiptapSettingsSchema>;

END_OF_FILE_CONTENT
mkdir -p "src/components/ui"
echo "Creating src/components/ui/OlonMark.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/OlonMark.tsx"
import { cn } from '@olonjs/core/runtime'

interface OlonMarkProps {
  size?: number
  /** mono: uses currentColor — for single-colour print/emboss contexts */
  variant?: 'default' | 'mono'
  className?: string
}

export function OlonMark({ size = 32, variant = 'default', className }: OlonMarkProps) {
  const gid = `olon-ring-${size}`

  if (variant === 'mono') {
    return (
      <svg
        viewBox="0 0 100 100"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        width={size}
        height={size}
        aria-label="Olon mark"
        className={cn('flex-shrink-0', className)}
      >
        <circle cx="50" cy="50" r="38" stroke="currentColor" strokeWidth="20"/>
        <circle cx="50" cy="50" r="15" fill="currentColor"/>
      </svg>
    )
  }

  return (
    <svg
      viewBox="0 0 100 100"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      width={size}
      height={size}
      aria-label="Olon mark"
      className={cn('flex-shrink-0', className)}
    >
      <defs>
        <linearGradient id={gid} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%"   stopColor="var(--olon-ring-top)"/>
          <stop offset="100%" stopColor="var(--olon-ring-bottom)"/>
        </linearGradient>
      </defs>
      <circle cx="50" cy="50" r="38" stroke={`url(#${gid})`} strokeWidth="20"/>
      <circle cx="50" cy="50" r="15" fill="var(--olon-nucleus)"/>
    </svg>
  )
}

interface OlonLogoProps {
  markSize?: number
  fontSize?: number
  variant?: 'default' | 'mono'
  className?: string
}

export function OlonLogo({
  markSize = 32,
  fontSize = 24,
  variant = 'default',
  className,
}: OlonLogoProps) {
  return (
    <div className={cn('flex items-center gap-3', className)}>
      <OlonMark size={markSize} variant={variant}/>
      <span
        style={{
          fontFamily: "'Instrument Sans', Helvetica, Arial, sans-serif",
          fontWeight: 700,
          fontSize,
          letterSpacing: '-0.02em',
          color: 'hsl(var(--foreground))',
          lineHeight: 1,
        }}
      >
        Olon
      </span>
    </div>
  )
}

END_OF_FILE_CONTENT
# SKIP: src/components/ui/OlonMark.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/accordion.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/accordion.tsx"
import * as React from "react"
import { Accordion as AccordionPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"
import { ChevronDownIcon, ChevronUpIcon } from "lucide-react"

function Accordion({
  className,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Root>) {
  return (
    <AccordionPrimitive.Root
      data-slot="accordion"
      className={cn("flex w-full flex-col", className)}
      {...props}
    />
  )
}

function AccordionItem({
  className,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Item>) {
  return (
    <AccordionPrimitive.Item
      data-slot="accordion-item"
      className={cn("not-last:border-b", className)}
      {...props}
    />
  )
}

function AccordionTrigger({
  className,
  children,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Trigger>) {
  return (
    <AccordionPrimitive.Header className="flex">
      <AccordionPrimitive.Trigger
        data-slot="accordion-trigger"
        className={cn(
          "group/accordion-trigger relative flex flex-1 items-start justify-between rounded-lg border border-transparent py-2.5 text-left text-sm font-medium transition-all outline-none hover:underline focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:after:border-ring disabled:pointer-events-none disabled:opacity-50 **:data-[slot=accordion-trigger-icon]:ml-auto **:data-[slot=accordion-trigger-icon]:size-4 **:data-[slot=accordion-trigger-icon]:text-muted-foreground",
          className
        )}
        {...props}
      >
        {children}
        <ChevronDownIcon data-slot="accordion-trigger-icon" className="pointer-events-none shrink-0 group-aria-expanded/accordion-trigger:hidden" />
        <ChevronUpIcon data-slot="accordion-trigger-icon" className="pointer-events-none hidden shrink-0 group-aria-expanded/accordion-trigger:inline" />
      </AccordionPrimitive.Trigger>
    </AccordionPrimitive.Header>
  )
}

function AccordionContent({
  className,
  children,
  ...props
}: React.ComponentProps<typeof AccordionPrimitive.Content>) {
  return (
    <AccordionPrimitive.Content
      data-slot="accordion-content"
      className="overflow-hidden text-sm data-open:animate-accordion-down data-closed:animate-accordion-up"
      {...props}
    >
      <div
        className={cn(
          "h-(--radix-accordion-content-height) pt-0 pb-2.5 [&_a]:underline [&_a]:underline-offset-3 [&_a]:hover:text-foreground [&_p:not(:last-child)]:mb-4",
          className
        )}
      >
        {children}
      </div>
    </AccordionPrimitive.Content>
  )
}

export { Accordion, AccordionItem, AccordionTrigger, AccordionContent }


END_OF_FILE_CONTENT
# SKIP: src/components/ui/accordion.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/aspect-ratio.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/aspect-ratio.tsx"
"use client"

import { AspectRatio as AspectRatioPrimitive } from "radix-ui"

function AspectRatio({
  ...props
}: React.ComponentProps<typeof AspectRatioPrimitive.Root>) {
  return <AspectRatioPrimitive.Root data-slot="aspect-ratio" {...props} />
}

export { AspectRatio }


END_OF_FILE_CONTENT
# SKIP: src/components/ui/aspect-ratio.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/avatar.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/avatar.tsx"
"use client"

import * as React from "react"
import { Avatar as AvatarPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"

function Avatar({
  className,
  size = "default",
  ...props
}: React.ComponentProps<typeof AvatarPrimitive.Root> & {
  size?: "default" | "sm" | "lg"
}) {
  return (
    <AvatarPrimitive.Root
      data-slot="avatar"
      data-size={size}
      className={cn(
        "group/avatar relative flex size-8 shrink-0 rounded-full select-none after:absolute after:inset-0 after:rounded-full after:border after:border-border after:mix-blend-darken data-[size=lg]:size-10 data-[size=sm]:size-6 dark:after:mix-blend-lighten",
        className
      )}
      {...props}
    />
  )
}

function AvatarImage({
  className,
  ...props
}: React.ComponentProps<typeof AvatarPrimitive.Image>) {
  return (
    <AvatarPrimitive.Image
      data-slot="avatar-image"
      className={cn(
        "aspect-square size-full rounded-full object-cover",
        className
      )}
      {...props}
    />
  )
}

function AvatarFallback({
  className,
  ...props
}: React.ComponentProps<typeof AvatarPrimitive.Fallback>) {
  return (
    <AvatarPrimitive.Fallback
      data-slot="avatar-fallback"
      className={cn(
        "flex size-full items-center justify-center rounded-full bg-muted text-sm text-muted-foreground group-data-[size=sm]/avatar:text-xs",
        className
      )}
      {...props}
    />
  )
}

function AvatarBadge({ className, ...props }: React.ComponentProps<"span">) {
  return (
    <span
      data-slot="avatar-badge"
      className={cn(
        "absolute right-0 bottom-0 z-10 inline-flex items-center justify-center rounded-full bg-primary text-primary-foreground bg-blend-color ring-2 ring-background select-none",
        "group-data-[size=sm]/avatar:size-2 group-data-[size=sm]/avatar:[&>svg]:hidden",
        "group-data-[size=default]/avatar:size-2.5 group-data-[size=default]/avatar:[&>svg]:size-2",
        "group-data-[size=lg]/avatar:size-3 group-data-[size=lg]/avatar:[&>svg]:size-2",
        className
      )}
      {...props}
    />
  )
}

function AvatarGroup({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="avatar-group"
      className={cn(
        "group/avatar-group flex -space-x-2 *:data-[slot=avatar]:ring-2 *:data-[slot=avatar]:ring-background",
        className
      )}
      {...props}
    />
  )
}

function AvatarGroupCount({
  className,
  ...props
}: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="avatar-group-count"
      className={cn(
        "relative flex size-8 shrink-0 items-center justify-center rounded-full bg-muted text-sm text-muted-foreground ring-2 ring-background group-has-data-[size=lg]/avatar-group:size-10 group-has-data-[size=sm]/avatar-group:size-6 [&>svg]:size-4 group-has-data-[size=lg]/avatar-group:[&>svg]:size-5 group-has-data-[size=sm]/avatar-group:[&>svg]:size-3",
        className
      )}
      {...props}
    />
  )
}

export {
  Avatar,
  AvatarImage,
  AvatarFallback,
  AvatarGroup,
  AvatarGroupCount,
  AvatarBadge,
}


END_OF_FILE_CONTENT
# SKIP: src/components/ui/avatar.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/badge.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/badge.tsx"
import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@olonjs/core/runtime'

const badgeVariants = cva(
  'inline-flex items-center px-2.5 py-0.5 text-xs font-medium transition-colors',
  {
    variants: {
      variant: {
        default:  'bg-primary-900 text-primary-light border border-primary rounded-sm',
        outline:  'bg-elevated text-muted-foreground border border-border rounded-sm',
        accent:   'text-accent border border-border-strong rounded-sm',
        solid:    'bg-primary text-primary-foreground rounded-sm',
        pill:     'bg-elevated text-muted-foreground border border-border rounded-full gap-1.5',
      },
    },
    defaultVariants: { variant: 'default' },
  }
)

export interface BadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />
}

export { Badge, badgeVariants }

END_OF_FILE_CONTENT
# SKIP: src/components/ui/badge.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/breadcrumb.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/breadcrumb.tsx"
import * as React from "react"
import { Slot } from "radix-ui"

import { cn } from "@olonjs/core/runtime"
import { ChevronRightIcon, MoreHorizontalIcon } from "lucide-react"

function Breadcrumb({ className, ...props }: React.ComponentProps<"nav">) {
  return (
    <nav
      aria-label="breadcrumb"
      data-slot="breadcrumb"
      className={cn(className)}
      {...props}
    />
  )
}

function BreadcrumbList({ className, ...props }: React.ComponentProps<"ol">) {
  return (
    <ol
      data-slot="breadcrumb-list"
      className={cn(
        "flex flex-wrap items-center gap-1.5 text-sm wrap-break-word text-muted-foreground",
        className
      )}
      {...props}
    />
  )
}

function BreadcrumbItem({ className, ...props }: React.ComponentProps<"li">) {
  return (
    <li
      data-slot="breadcrumb-item"
      className={cn("inline-flex items-center gap-1", className)}
      {...props}
    />
  )
}

function BreadcrumbLink({
  asChild,
  className,
  ...props
}: React.ComponentProps<"a"> & {
  asChild?: boolean
}) {
  const Comp = asChild ? Slot.Root : "a"

  return (
    <Comp
      data-slot="breadcrumb-link"
      className={cn("transition-colors hover:text-foreground", className)}
      {...props}
    />
  )
}

function BreadcrumbPage({ className, ...props }: React.ComponentProps<"span">) {
  return (
    <span
      data-slot="breadcrumb-page"
      role="link"
      aria-disabled="true"
      aria-current="page"
      className={cn("font-normal text-foreground", className)}
      {...props}
    />
  )
}

function BreadcrumbSeparator({
  children,
  className,
  ...props
}: React.ComponentProps<"li">) {
  return (
    <li
      data-slot="breadcrumb-separator"
      role="presentation"
      aria-hidden="true"
      className={cn("[&>svg]:size-3.5", className)}
      {...props}
    >
      {children ?? (
        <ChevronRightIcon />
      )}
    </li>
  )
}

function BreadcrumbEllipsis({
  className,
  ...props
}: React.ComponentProps<"span">) {
  return (
    <span
      data-slot="breadcrumb-ellipsis"
      role="presentation"
      aria-hidden="true"
      className={cn(
        "flex size-5 items-center justify-center [&>svg]:size-4",
        className
      )}
      {...props}
    >
      <MoreHorizontalIcon
      />
      <span className="sr-only">More</span>
    </span>
  )
}

export {
  Breadcrumb,
  BreadcrumbList,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbPage,
  BreadcrumbSeparator,
  BreadcrumbEllipsis,
}


END_OF_FILE_CONTENT
# SKIP: src/components/ui/breadcrumb.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/button.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/button.tsx"
import * as React from 'react'
import { cva, type VariantProps } from 'class-variance-authority'
import { cn } from '@olonjs/core/runtime'

const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 whitespace-nowrap font-medium transition-all duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring disabled:pointer-events-none disabled:opacity-40 shrink-0',
  {
    variants: {
      variant: {
        default:     'bg-primary text-primary-foreground hover:opacity-90 active:scale-[0.98]',
        secondary:   'bg-transparent text-primary-light border border-primary hover:bg-primary-900 active:scale-[0.98]',
        outline:     'bg-transparent text-foreground border border-border hover:bg-elevated active:scale-[0.98]',
        ghost:       'bg-transparent text-muted-foreground hover:text-foreground hover:bg-elevated active:scale-[0.98]',
        accent:      'bg-accent text-accent-foreground hover:opacity-90 active:scale-[0.98]',
        destructive: 'bg-destructive text-destructive-foreground border border-destructive-border hover:opacity-90 active:scale-[0.98]',
      },
      size: {
        default: 'h-9 px-4 text-sm rounded-md',
        sm:      'h-8 px-3.5 text-sm rounded-md',
        lg:      'h-10 px-5 text-base rounded-md',
        icon:    'h-9 w-9 rounded-md',
      },
    },
    defaultVariants: {
      variant: 'default',
      size: 'default',
    },
  }
)

export interface ButtonProps
  extends React.ButtonHTMLAttributes<HTMLButtonElement>,
    VariantProps<typeof buttonVariants> {
  asChild?: boolean
}

const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild = false, children, ...props }, ref) => {
    const classes = cn(buttonVariants({ variant, size, className }))

    // asChild: clone the single child element, merging our classes onto it
    if (asChild && React.isValidElement(children)) {
      return React.cloneElement(children as React.ReactElement<{ className?: string }>, {
        className: cn(classes, (children as React.ReactElement<{ className?: string }>).props.className),
      })
    }

    return (
      <button className={classes} ref={ref} {...props}>
        {children}
      </button>
    )
  }
)
Button.displayName = 'Button'

export { Button, buttonVariants }

END_OF_FILE_CONTENT
# SKIP: src/components/ui/button.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/card.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/card.tsx"
import * as React from 'react'
import { cn } from '@olonjs/core/runtime'

const Card = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div
      ref={ref}
      className={cn('rounded-lg border border-border bg-card text-card-foreground', className)}
      {...props}
    />
  )
)
Card.displayName = 'Card'

const CardHeader = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('flex flex-col gap-1.5 p-5', className)} {...props} />
  )
)
CardHeader.displayName = 'CardHeader'

const CardTitle = React.forwardRef<HTMLParagraphElement, React.HTMLAttributes<HTMLHeadingElement>>(
  ({ className, ...props }, ref) => (
    <h3 ref={ref} className={cn('text-sm font-medium text-foreground leading-tight', className)} {...props} />
  )
)
CardTitle.displayName = 'CardTitle'

const CardDescription = React.forwardRef<HTMLParagraphElement, React.HTMLAttributes<HTMLParagraphElement>>(
  ({ className, ...props }, ref) => (
    <p ref={ref} className={cn('text-xs text-muted-foreground leading-relaxed', className)} {...props} />
  )
)
CardDescription.displayName = 'CardDescription'

const CardContent = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('px-5 pb-5', className)} {...props} />
  )
)
CardContent.displayName = 'CardContent'

const CardFooter = React.forwardRef<HTMLDivElement, React.HTMLAttributes<HTMLDivElement>>(
  ({ className, ...props }, ref) => (
    <div ref={ref} className={cn('flex items-center px-5 pb-5', className)} {...props} />
  )
)
CardFooter.displayName = 'CardFooter'

export { Card, CardHeader, CardTitle, CardDescription, CardContent, CardFooter }

END_OF_FILE_CONTENT
# SKIP: src/components/ui/card.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/checkbox.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/checkbox.tsx"
"use client"

import * as React from "react"
import { Checkbox as CheckboxPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"
import { CheckIcon } from "lucide-react"

function Checkbox({
  className,
  ...props
}: React.ComponentProps<typeof CheckboxPrimitive.Root>) {
  return (
    <CheckboxPrimitive.Root
      data-slot="checkbox"
      className={cn(
        "border-input dark:bg-input/30 data-checked:bg-primary data-checked:text-primary-foreground dark:data-checked:bg-primary data-checked:border-primary aria-invalid:aria-checked:border-primary aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 flex size-4 items-center justify-center rounded-[4px] border transition-colors group-has-disabled/field:opacity-50 focus-visible:ring-3 aria-invalid:ring-3 peer relative shrink-0 outline-none after:absolute after:-inset-x-3 after:-inset-y-2 disabled:cursor-not-allowed disabled:opacity-50",
        className
      )}
      {...props}
    >
      <CheckboxPrimitive.Indicator
        data-slot="checkbox-indicator"
        className="[&>svg]:size-3.5 grid place-content-center text-current transition-none"
      >
        <CheckIcon
        />
      </CheckboxPrimitive.Indicator>
    </CheckboxPrimitive.Root>
  )
}

export { Checkbox }





END_OF_FILE_CONTENT
# SKIP: src/components/ui/checkbox.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/dialog.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/dialog.tsx"
import * as React from "react"
import { Dialog as DialogPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"
import { Button } from "@/components/ui/button"
import { XIcon } from "lucide-react"

function Dialog({
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Root>) {
  return <DialogPrimitive.Root data-slot="dialog" {...props} />
}

function DialogTrigger({
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Trigger>) {
  return <DialogPrimitive.Trigger data-slot="dialog-trigger" {...props} />
}

function DialogPortal({
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Portal>) {
  return <DialogPrimitive.Portal data-slot="dialog-portal" {...props} />
}

function DialogClose({
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Close>) {
  return <DialogPrimitive.Close data-slot="dialog-close" {...props} />
}

function DialogOverlay({
  className,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Overlay>) {
  return (
    <DialogPrimitive.Overlay
      data-slot="dialog-overlay"
      className={cn(
        "fixed inset-0 isolate z-50 bg-black/10 duration-100 supports-backdrop-filter:backdrop-blur-xs data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0",
        className
      )}
      {...props}
    />
  )
}

function DialogContent({
  className,
  children,
  showCloseButton = true,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Content> & {
  showCloseButton?: boolean
}) {
  return (
    <DialogPortal>
      <DialogOverlay />
      <DialogPrimitive.Content
        data-slot="dialog-content"
        className={cn(
          "fixed top-1/2 left-1/2 z-50 grid w-full max-w-[calc(100%-2rem)] -translate-x-1/2 -translate-y-1/2 gap-4 rounded-xl bg-popover p-4 text-sm text-popover-foreground ring-1 ring-foreground/10 duration-100 outline-none sm:max-w-sm data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95",
          className
        )}
        {...props}
      >
        {children}
        {showCloseButton && (
          <DialogPrimitive.Close data-slot="dialog-close" asChild>
            <Button
              variant="ghost"
              className="absolute top-2 right-2"
              size="sm"
            >
              <XIcon
              />
              <span className="sr-only">Close</span>
            </Button>
          </DialogPrimitive.Close>
        )}
      </DialogPrimitive.Content>
    </DialogPortal>
  )
}

function DialogHeader({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="dialog-header"
      className={cn("flex flex-col gap-2", className)}
      {...props}
    />
  )
}

function DialogFooter({
  className,
  showCloseButton = false,
  children,
  ...props
}: React.ComponentProps<"div"> & {
  showCloseButton?: boolean
}) {
  return (
    <div
      data-slot="dialog-footer"
      className={cn(
        "-mx-4 -mb-4 flex flex-col-reverse gap-2 rounded-b-xl border-t bg-muted/50 p-4 sm:flex-row sm:justify-end",
        className
      )}
      {...props}
    >
      {children}
      {showCloseButton && (
        <DialogPrimitive.Close asChild>
          <Button variant="outline">Close</Button>
        </DialogPrimitive.Close>
      )}
    </div>
  )
}

function DialogTitle({
  className,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Title>) {
  return (
    <DialogPrimitive.Title
      data-slot="dialog-title"
      className={cn(
        "text-base leading-none font-medium",
        className
      )}
      {...props}
    />
  )
}

function DialogDescription({
  className,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Description>) {
  return (
    <DialogPrimitive.Description
      data-slot="dialog-description"
      className={cn(
        "text-sm text-muted-foreground *:[a]:underline *:[a]:underline-offset-3 *:[a]:hover:text-foreground",
        className
      )}
      {...props}
    />
  )
}

export {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogOverlay,
  DialogPortal,
  DialogTitle,
  DialogTrigger,
}


END_OF_FILE_CONTENT
# SKIP: src/components/ui/dialog.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/dropdown-menu.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/dropdown-menu.tsx"
import * as React from "react"
import { DropdownMenu as DropdownMenuPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"
import { CheckIcon, ChevronRightIcon } from "lucide-react"

function DropdownMenu({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Root>) {
  return <DropdownMenuPrimitive.Root data-slot="dropdown-menu" {...props} />
}

function DropdownMenuPortal({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Portal>) {
  return (
    <DropdownMenuPrimitive.Portal data-slot="dropdown-menu-portal" {...props} />
  )
}

function DropdownMenuTrigger({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Trigger>) {
  return (
    <DropdownMenuPrimitive.Trigger
      data-slot="dropdown-menu-trigger"
      {...props}
    />
  )
}

function DropdownMenuContent({
  className,
  align = "start",
  sideOffset = 4,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Content>) {
  return (
    <DropdownMenuPrimitive.Portal>
      <DropdownMenuPrimitive.Content
        data-slot="dropdown-menu-content"
        sideOffset={sideOffset}
        align={align}
        className={cn("z-50 max-h-(--radix-dropdown-menu-content-available-height) w-(--radix-dropdown-menu-trigger-width) min-w-32 origin-(--radix-dropdown-menu-content-transform-origin) overflow-x-hidden overflow-y-auto rounded-lg bg-popover p-1 text-popover-foreground shadow-md ring-1 ring-foreground/10 duration-100 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-[state=closed]:overflow-hidden data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95", className )}
        {...props}
      />
    </DropdownMenuPrimitive.Portal>
  )
}

function DropdownMenuGroup({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Group>) {
  return (
    <DropdownMenuPrimitive.Group data-slot="dropdown-menu-group" {...props} />
  )
}

function DropdownMenuItem({
  className,
  inset,
  variant = "default",
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Item> & {
  inset?: boolean
  variant?: "default" | "destructive"
}) {
  return (
    <DropdownMenuPrimitive.Item
      data-slot="dropdown-menu-item"
      data-inset={inset}
      data-variant={variant}
      className={cn(
        "group/dropdown-menu-item relative flex cursor-default items-center gap-1.5 rounded-md px-1.5 py-1 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground data-inset:pl-7 data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 data-[variant=destructive]:focus:text-destructive dark:data-[variant=destructive]:focus:bg-destructive/20 data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4 data-[variant=destructive]:*:[svg]:text-destructive",
        className
      )}
      {...props}
    />
  )
}

function DropdownMenuCheckboxItem({
  className,
  children,
  checked,
  inset,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.CheckboxItem> & {
  inset?: boolean
}) {
  return (
    <DropdownMenuPrimitive.CheckboxItem
      data-slot="dropdown-menu-checkbox-item"
      data-inset={inset}
      className={cn(
        "relative flex cursor-default items-center gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground data-inset:pl-7 data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      checked={checked}
      {...props}
    >
      <span
        className="pointer-events-none absolute right-2 flex items-center justify-center"
        data-slot="dropdown-menu-checkbox-item-indicator"
      >
        <DropdownMenuPrimitive.ItemIndicator>
          <CheckIcon
          />
        </DropdownMenuPrimitive.ItemIndicator>
      </span>
      {children}
    </DropdownMenuPrimitive.CheckboxItem>
  )
}

function DropdownMenuRadioGroup({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.RadioGroup>) {
  return (
    <DropdownMenuPrimitive.RadioGroup
      data-slot="dropdown-menu-radio-group"
      {...props}
    />
  )
}

function DropdownMenuRadioItem({
  className,
  children,
  inset,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.RadioItem> & {
  inset?: boolean
}) {
  return (
    <DropdownMenuPrimitive.RadioItem
      data-slot="dropdown-menu-radio-item"
      data-inset={inset}
      className={cn(
        "relative flex cursor-default items-center gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground data-inset:pl-7 data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    >
      <span
        className="pointer-events-none absolute right-2 flex items-center justify-center"
        data-slot="dropdown-menu-radio-item-indicator"
      >
        <DropdownMenuPrimitive.ItemIndicator>
          <CheckIcon
          />
        </DropdownMenuPrimitive.ItemIndicator>
      </span>
      {children}
    </DropdownMenuPrimitive.RadioItem>
  )
}

function DropdownMenuLabel({
  className,
  inset,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Label> & {
  inset?: boolean
}) {
  return (
    <DropdownMenuPrimitive.Label
      data-slot="dropdown-menu-label"
      data-inset={inset}
      className={cn(
        "px-1.5 py-1 text-xs font-medium text-muted-foreground data-inset:pl-7",
        className
      )}
      {...props}
    />
  )
}

function DropdownMenuSeparator({
  className,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Separator>) {
  return (
    <DropdownMenuPrimitive.Separator
      data-slot="dropdown-menu-separator"
      className={cn("-mx-1 my-1 h-px bg-border", className)}
      {...props}
    />
  )
}

function DropdownMenuShortcut({
  className,
  ...props
}: React.ComponentProps<"span">) {
  return (
    <span
      data-slot="dropdown-menu-shortcut"
      className={cn(
        "ml-auto text-xs tracking-widest text-muted-foreground group-focus/dropdown-menu-item:text-accent-foreground",
        className
      )}
      {...props}
    />
  )
}

function DropdownMenuSub({
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.Sub>) {
  return <DropdownMenuPrimitive.Sub data-slot="dropdown-menu-sub" {...props} />
}

function DropdownMenuSubTrigger({
  className,
  inset,
  children,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.SubTrigger> & {
  inset?: boolean
}) {
  return (
    <DropdownMenuPrimitive.SubTrigger
      data-slot="dropdown-menu-sub-trigger"
      data-inset={inset}
      className={cn(
        "flex cursor-default items-center gap-1.5 rounded-md px-1.5 py-1 text-sm outline-hidden select-none focus:bg-accent focus:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground data-inset:pl-7 data-open:bg-accent data-open:text-accent-foreground [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    >
      {children}
      <ChevronRightIcon className="ml-auto" />
    </DropdownMenuPrimitive.SubTrigger>
  )
}

function DropdownMenuSubContent({
  className,
  ...props
}: React.ComponentProps<typeof DropdownMenuPrimitive.SubContent>) {
  return (
    <DropdownMenuPrimitive.SubContent
      data-slot="dropdown-menu-sub-content"
      className={cn("z-50 min-w-[96px] origin-(--radix-dropdown-menu-content-transform-origin) overflow-hidden rounded-lg bg-popover p-1 text-popover-foreground shadow-lg ring-1 ring-foreground/10 duration-100 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95", className )}
      {...props}
    />
  )
}

export {
  DropdownMenu,
  DropdownMenuPortal,
  DropdownMenuTrigger,
  DropdownMenuContent,
  DropdownMenuGroup,
  DropdownMenuLabel,
  DropdownMenuItem,
  DropdownMenuCheckboxItem,
  DropdownMenuRadioGroup,
  DropdownMenuRadioItem,
  DropdownMenuSeparator,
  DropdownMenuShortcut,
  DropdownMenuSub,
  DropdownMenuSubTrigger,
  DropdownMenuSubContent,
}


END_OF_FILE_CONTENT
# SKIP: src/components/ui/dropdown-menu.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/hover-card.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/hover-card.tsx"
"use client"

import * as React from "react"
import { HoverCard as HoverCardPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"

function HoverCard({
  ...props
}: React.ComponentProps<typeof HoverCardPrimitive.Root>) {
  return <HoverCardPrimitive.Root data-slot="hover-card" {...props} />
}

function HoverCardTrigger({
  ...props
}: React.ComponentProps<typeof HoverCardPrimitive.Trigger>) {
  return (
    <HoverCardPrimitive.Trigger data-slot="hover-card-trigger" {...props} />
  )
}

function HoverCardContent({
  className,
  align = "center",
  sideOffset = 4,
  ...props
}: React.ComponentProps<typeof HoverCardPrimitive.Content>) {
  return (
    <HoverCardPrimitive.Portal data-slot="hover-card-portal">
      <HoverCardPrimitive.Content
        data-slot="hover-card-content"
        align={align}
        sideOffset={sideOffset}
        className={cn(
          "z-50 w-64 origin-(--radix-hover-card-content-transform-origin) rounded-lg bg-popover p-2.5 text-sm text-popover-foreground shadow-md ring-1 ring-foreground/10 outline-hidden duration-100 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95",
          className
        )}
        {...props}
      />
    </HoverCardPrimitive.Portal>
  )
}

export { HoverCard, HoverCardTrigger, HoverCardContent }


END_OF_FILE_CONTENT
# SKIP: src/components/ui/hover-card.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/input.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/input.tsx"
import * as React from 'react'
import { cn } from '@olonjs/core/runtime'

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {}

const Input = React.forwardRef<HTMLInputElement, InputProps>(
  ({ className, type, ...props }, ref) => {
    return (
      <input
        type={type}
        className={cn(
          'flex h-9 w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground',
          'focus:outline-none focus:border-primary focus:ring-1 focus:ring-primary',
          'disabled:cursor-not-allowed disabled:opacity-50',
          'transition-colors duration-150',
          className
        )}
        ref={ref}
        {...props}
      />
    )
  }
)
Input.displayName = 'Input'

export { Input }

END_OF_FILE_CONTENT
# SKIP: src/components/ui/input.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/label.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/label.tsx"
import * as React from 'react'
import { cn } from '@olonjs/core/runtime'

const Label = React.forwardRef<
  HTMLLabelElement,
  React.LabelHTMLAttributes<HTMLLabelElement>
>(({ className, ...props }, ref) => (
  <label
    ref={ref}
    className={cn('block text-xs font-medium text-foreground mb-1.5 cursor-default', className)}
    {...props}
  />
))
Label.displayName = 'Label'

export { Label }

END_OF_FILE_CONTENT
# SKIP: src/components/ui/label.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/navigation-menu.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/navigation-menu.tsx"
import * as React from "react"
import { cva } from "class-variance-authority"
import { NavigationMenu as NavigationMenuPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"
import { ChevronDownIcon } from "lucide-react"

function NavigationMenu({
  className,
  children,
  viewport = true,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Root> & {
  viewport?: boolean
}) {
  return (
    <NavigationMenuPrimitive.Root
      data-slot="navigation-menu"
      data-viewport={viewport}
      className={cn(
        "group/navigation-menu relative flex max-w-max flex-1 items-center justify-center",
        className
      )}
      {...props}
    >
      {children}
      {viewport && <NavigationMenuViewport />}
    </NavigationMenuPrimitive.Root>
  )
}

function NavigationMenuList({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.List>) {
  return (
    <NavigationMenuPrimitive.List
      data-slot="navigation-menu-list"
      className={cn(
        "group flex flex-1 list-none items-center justify-center gap-0",
        className
      )}
      {...props}
    />
  )
}

function NavigationMenuItem({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Item>) {
  return (
    <NavigationMenuPrimitive.Item
      data-slot="navigation-menu-item"
      className={cn("relative", className)}
      {...props}
    />
  )
}

const navigationMenuTriggerStyle = cva(
  "group/navigation-menu-trigger inline-flex h-9 w-max items-center justify-center rounded-lg px-2.5 py-1.5 text-sm font-medium transition-all outline-none hover:bg-muted focus:bg-muted focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-1 disabled:pointer-events-none disabled:opacity-50 data-popup-open:bg-muted/50 data-popup-open:hover:bg-muted data-open:bg-muted/50 data-open:hover:bg-muted data-open:focus:bg-muted"
)

function NavigationMenuTrigger({
  className,
  children,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Trigger>) {
  return (
    <NavigationMenuPrimitive.Trigger
      data-slot="navigation-menu-trigger"
      className={cn(navigationMenuTriggerStyle(), "group", className)}
      {...props}
    >
      {children}{" "}
      <ChevronDownIcon className="relative top-px ml-1 size-3 transition duration-300 group-data-popup-open/navigation-menu-trigger:rotate-180 group-data-open/navigation-menu-trigger:rotate-180" aria-hidden="true" />
    </NavigationMenuPrimitive.Trigger>
  )
}

function NavigationMenuContent({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Content>) {
  return (
    <NavigationMenuPrimitive.Content
      data-slot="navigation-menu-content"
      className={cn(
        "top-0 left-0 w-full p-1 ease-[cubic-bezier(0.22,1,0.36,1)] group-data-[viewport=false]/navigation-menu:top-full group-data-[viewport=false]/navigation-menu:mt-1.5 group-data-[viewport=false]/navigation-menu:overflow-hidden group-data-[viewport=false]/navigation-menu:rounded-lg group-data-[viewport=false]/navigation-menu:bg-popover group-data-[viewport=false]/navigation-menu:text-popover-foreground group-data-[viewport=false]/navigation-menu:shadow group-data-[viewport=false]/navigation-menu:ring-1 group-data-[viewport=false]/navigation-menu:ring-foreground/10 group-data-[viewport=false]/navigation-menu:duration-300 data-[motion=from-end]:slide-in-from-right-52 data-[motion=from-start]:slide-in-from-left-52 data-[motion=to-end]:slide-out-to-right-52 data-[motion=to-start]:slide-out-to-left-52 data-[motion^=from-]:animate-in data-[motion^=from-]:fade-in data-[motion^=to-]:animate-out data-[motion^=to-]:fade-out **:data-[slot=navigation-menu-link]:focus:ring-0 **:data-[slot=navigation-menu-link]:focus:outline-none md:absolute md:w-auto group-data-[viewport=false]/navigation-menu:data-open:animate-in group-data-[viewport=false]/navigation-menu:data-open:fade-in-0 group-data-[viewport=false]/navigation-menu:data-open:zoom-in-95 group-data-[viewport=false]/navigation-menu:data-closed:animate-out group-data-[viewport=false]/navigation-menu:data-closed:fade-out-0 group-data-[viewport=false]/navigation-menu:data-closed:zoom-out-95",
        className
      )}
      {...props}
    />
  )
}

function NavigationMenuViewport({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Viewport>) {
  return (
    <div
      className={cn(
        "absolute top-full left-0 isolate z-50 flex justify-center"
      )}
    >
      <NavigationMenuPrimitive.Viewport
        data-slot="navigation-menu-viewport"
        className={cn(
          "origin-top-center relative mt-1.5 h-(--radix-navigation-menu-viewport-height) w-full overflow-hidden rounded-lg bg-popover text-popover-foreground shadow ring-1 ring-foreground/10 duration-100 md:w-(--radix-navigation-menu-viewport-width) data-open:animate-in data-open:zoom-in-90 data-closed:animate-out data-closed:zoom-out-90",
          className
        )}
        {...props}
      />
    </div>
  )
}

function NavigationMenuLink({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Link>) {
  return (
    <NavigationMenuPrimitive.Link
      data-slot="navigation-menu-link"
      className={cn(
        "flex items-center gap-2 rounded-lg p-2 text-sm transition-all outline-none hover:bg-muted focus:bg-muted focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-1 in-data-[slot=navigation-menu-content]:rounded-md data-active:bg-muted/50 data-active:hover:bg-muted data-active:focus:bg-muted [&_svg:not([class*='size-'])]:size-4",
        className
      )}
      {...props}
    />
  )
}

function NavigationMenuIndicator({
  className,
  ...props
}: React.ComponentProps<typeof NavigationMenuPrimitive.Indicator>) {
  return (
    <NavigationMenuPrimitive.Indicator
      data-slot="navigation-menu-indicator"
      className={cn(
        "top-full z-1 flex h-1.5 items-end justify-center overflow-hidden data-[state=hidden]:animate-out data-[state=hidden]:fade-out data-[state=visible]:animate-in data-[state=visible]:fade-in",
        className
      )}
      {...props}
    >
      <div className="relative top-[60%] h-2 w-2 rotate-45 rounded-tl-sm bg-border shadow-md" />
    </NavigationMenuPrimitive.Indicator>
  )
}

export {
  NavigationMenu,
  NavigationMenuList,
  NavigationMenuItem,
  NavigationMenuContent,
  NavigationMenuTrigger,
  NavigationMenuLink,
  NavigationMenuIndicator,
  NavigationMenuViewport,
  navigationMenuTriggerStyle,
}


END_OF_FILE_CONTENT
# SKIP: src/components/ui/navigation-menu.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/progress.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/progress.tsx"
import * as React from "react"
import { Progress as ProgressPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"

function Progress({
  className,
  value,
  ...props
}: React.ComponentProps<typeof ProgressPrimitive.Root>) {
  return (
    <ProgressPrimitive.Root
      data-slot="progress"
      className={cn(
        "relative flex h-1 w-full items-center overflow-x-hidden rounded-full bg-muted",
        className
      )}
      {...props}
    >
      <ProgressPrimitive.Indicator
        data-slot="progress-indicator"
        className="size-full flex-1 bg-primary transition-all"
        style={{ transform: `translateX(-${100 - (value || 0)}%)` }}
      />
    </ProgressPrimitive.Root>
  )
}

export { Progress }


END_OF_FILE_CONTENT
# SKIP: src/components/ui/progress.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/scroll-area.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/scroll-area.tsx"
import * as React from "react"
import { ScrollArea as ScrollAreaPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"

function ScrollArea({
  className,
  children,
  ...props
}: React.ComponentProps<typeof ScrollAreaPrimitive.Root>) {
  return (
    <ScrollAreaPrimitive.Root
      data-slot="scroll-area"
      className={cn("relative", className)}
      {...props}
    >
      <ScrollAreaPrimitive.Viewport
        data-slot="scroll-area-viewport"
        className="size-full rounded-[inherit] transition-[color,box-shadow] outline-none focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1"
      >
        {children}
      </ScrollAreaPrimitive.Viewport>
      <ScrollBar />
      <ScrollAreaPrimitive.Corner />
    </ScrollAreaPrimitive.Root>
  )
}

function ScrollBar({
  className,
  orientation = "vertical",
  ...props
}: React.ComponentProps<typeof ScrollAreaPrimitive.ScrollAreaScrollbar>) {
  return (
    <ScrollAreaPrimitive.ScrollAreaScrollbar
      data-slot="scroll-area-scrollbar"
      data-orientation={orientation}
      orientation={orientation}
      className={cn(
        "flex touch-none p-px transition-colors select-none data-horizontal:h-2.5 data-horizontal:flex-col data-horizontal:border-t data-horizontal:border-t-transparent data-vertical:h-full data-vertical:w-2.5 data-vertical:border-l data-vertical:border-l-transparent",
        className
      )}
      {...props}
    >
      <ScrollAreaPrimitive.ScrollAreaThumb
        data-slot="scroll-area-thumb"
        className="relative flex-1 rounded-full bg-border"
      />
    </ScrollAreaPrimitive.ScrollAreaScrollbar>
  )
}

export { ScrollArea, ScrollBar }


END_OF_FILE_CONTENT
# SKIP: src/components/ui/scroll-area.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/select.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/select.tsx"
import * as React from "react"
import { Select as SelectPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"
import { ChevronDownIcon, CheckIcon, ChevronUpIcon } from "lucide-react"

function Select({
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Root>) {
  return <SelectPrimitive.Root data-slot="select" {...props} />
}

function SelectGroup({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Group>) {
  return (
    <SelectPrimitive.Group
      data-slot="select-group"
      className={cn("scroll-my-1 p-1", className)}
      {...props}
    />
  )
}

function SelectValue({
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Value>) {
  return <SelectPrimitive.Value data-slot="select-value" {...props} />
}

function SelectTrigger({
  className,
  size = "default",
  children,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Trigger> & {
  size?: "sm" | "default"
}) {
  return (
    <SelectPrimitive.Trigger
      data-slot="select-trigger"
      data-size={size}
      className={cn(
        "border-input data-placeholder:text-muted-foreground dark:bg-input/30 dark:hover:bg-input/50 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 gap-1.5 rounded-lg border bg-transparent py-2 pr-2 pl-2.5 text-sm transition-colors select-none focus-visible:ring-3 aria-invalid:ring-3 data-[size=default]:h-8 data-[size=sm]:h-7 data-[size=sm]:rounded-[min(var(--radius-md),10px)] *:data-[slot=select-value]:gap-1.5 [&_svg:not([class*='size-'])]:size-4 flex w-full items-center justify-between whitespace-nowrap outline-none disabled:cursor-not-allowed disabled:opacity-50 *:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex *:data-[slot=select-value]:items-center [&_svg]:pointer-events-none [&_svg]:shrink-0",
        className
      )}
      {...props}
    >
      {children}
      <SelectPrimitive.Icon asChild>
        <ChevronDownIcon className="text-muted-foreground size-4 pointer-events-none" />
      </SelectPrimitive.Icon>
    </SelectPrimitive.Trigger>
  )
}

function SelectContent({
  className,
  children,
  position = "popper",
  align = "center",
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Content>) {
  return (
    <SelectPrimitive.Portal>
      <SelectPrimitive.Content
        data-slot="select-content"
        data-align-trigger={position === "item-aligned"}
        className={cn(
          "bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 min-w-36 rounded-lg shadow-md ring-1 duration-100 relative z-[110] max-h-(--radix-select-content-available-height) origin-(--radix-select-content-transform-origin) overflow-x-hidden overflow-y-auto data-[align-trigger=true]:animate-none", 
          position === "popper" && "data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1", 
          className 
        )}
        position={position}
        align={align}
        {...props}
      >
        <SelectScrollUpButton />
        <SelectPrimitive.Viewport
          data-position={position}
          className={cn(
            "p-1",
            position === "popper" && "h-(--radix-select-trigger-height) w-full min-w-(--radix-select-trigger-width)"
          )}
        >
          {children}
        </SelectPrimitive.Viewport>
        <SelectScrollDownButton />
      </SelectPrimitive.Content>
    </SelectPrimitive.Portal>
  )
}

function SelectLabel({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Label>) {
  return (
    <SelectPrimitive.Label
      data-slot="select-label"
      className={cn("text-muted-foreground px-1.5 py-1 text-xs", className)}
      {...props}
    />
  )
}

function SelectItem({
  className,
  children,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Item>) {
  return (
    <SelectPrimitive.Item
      data-slot="select-item"
      className={cn(
        "focus:bg-accent focus:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm [&_svg:not([class*='size-'])]:size-4 *:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2 relative flex w-full cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0",
        className
      )}
      {...props}
    >
      <span className="pointer-events-none absolute right-2 flex size-4 items-center justify-center">
        <SelectPrimitive.ItemIndicator>
          <CheckIcon className="pointer-events-none" />
        </SelectPrimitive.ItemIndicator>
      </span>
      <SelectPrimitive.ItemText>{children}</SelectPrimitive.ItemText>
    </SelectPrimitive.Item>
  )
}

function SelectSeparator({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Separator>) {
  return (
    <SelectPrimitive.Separator
      data-slot="select-separator"
      className={cn("bg-border -mx-1 my-1 h-px pointer-events-none", className)}
      {...props}
    />
  )
}

function SelectScrollUpButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollUpButton>) {
  return (
    <SelectPrimitive.ScrollUpButton
      data-slot="select-scroll-up-button"
      className={cn("bg-popover z-10 flex cursor-default items-center justify-center py-1 [&_svg:not([class*='size-'])]:size-4", className)}
      {...props}
    >
      <ChevronUpIcon />
    </SelectPrimitive.ScrollUpButton>
  )
}

function SelectScrollDownButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollDownButton>) {
  return (
    <SelectPrimitive.ScrollDownButton
      data-slot="select-scroll-down-button"
      className={cn("bg-popover z-10 flex cursor-default items-center justify-center py-1 [&_svg:not([class*='size-'])]:size-4", className)}
      {...props}
    >
      <ChevronDownIcon />
    </SelectPrimitive.ScrollDownButton>
  )
}

export {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectScrollDownButton,
  SelectScrollUpButton,
  SelectSeparator,
  SelectTrigger,
  SelectValue,
}




END_OF_FILE_CONTENT
# SKIP: src/components/ui/select.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/select.txt..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/select.txt"
import * as React from "react"
import { Select as SelectPrimitive } from "radix-ui"

import { cn } from "@/lib/utils"
import { ChevronDownIcon, CheckIcon, ChevronUpIcon } from "lucide-react"

function Select({
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Root>) {
  return <SelectPrimitive.Root data-slot="select" {...props} />
}

function SelectGroup({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Group>) {
  return (
    <SelectPrimitive.Group
      data-slot="select-group"
      className={cn("scroll-my-1 p-1", className)}
      {...props}
    />
  )
}

function SelectValue({
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Value>) {
  return <SelectPrimitive.Value data-slot="select-value" {...props} />
}

function SelectTrigger({
  className,
  size = "default",
  children,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Trigger> & {
  size?: "sm" | "default"
}) {
  return (
    <SelectPrimitive.Trigger
      data-slot="select-trigger"
      data-size={size}
      className={cn(
        "border-input data-placeholder:text-muted-foreground dark:bg-input/30 dark:hover:bg-input/50 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 gap-1.5 rounded-lg border bg-transparent py-2 pr-2 pl-2.5 text-sm transition-colors select-none focus-visible:ring-3 aria-invalid:ring-3 data-[size=default]:h-8 data-[size=sm]:h-7 data-[size=sm]:rounded-[min(var(--radius-md),10px)] *:data-[slot=select-value]:gap-1.5 [&_svg:not([class*='size-'])]:size-4 flex w-full items-center justify-between whitespace-nowrap outline-none disabled:cursor-not-allowed disabled:opacity-50 *:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex *:data-[slot=select-value]:items-center [&_svg]:pointer-events-none [&_svg]:shrink-0",
        className
      )}
      {...props}
    >
      {children}
      <SelectPrimitive.Icon asChild>
        <ChevronDownIcon className="text-muted-foreground size-4 pointer-events-none" />
      </SelectPrimitive.Icon>
    </SelectPrimitive.Trigger>
  )
}

function SelectContent({
  className,
  children,
  position = "popper",
  align = "center",
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Content>) {
  return (
    <SelectPrimitive.Portal>
      <SelectPrimitive.Content
        data-slot="select-content"
        data-align-trigger={position === "item-aligned"}
        className={cn(
          "bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 min-w-36 rounded-lg shadow-md ring-1 duration-100 relative z-[110] max-h-(--radix-select-content-available-height) origin-(--radix-select-content-transform-origin) overflow-x-hidden overflow-y-auto data-[align-trigger=true]:animate-none", 
          position === "popper" && "data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1", 
          className 
        )}
        position={position}
        align={align}
        {...props}
      >
        <SelectScrollUpButton />
        <SelectPrimitive.Viewport
          data-position={position}
          className={cn(
            "p-1",
            position === "popper" && "h-(--radix-select-trigger-height) w-full min-w-(--radix-select-trigger-width)"
          )}
        >
          {children}
        </SelectPrimitive.Viewport>
        <SelectScrollDownButton />
      </SelectPrimitive.Content>
    </SelectPrimitive.Portal>
  )
}

function SelectLabel({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Label>) {
  return (
    <SelectPrimitive.Label
      data-slot="select-label"
      className={cn("text-muted-foreground px-1.5 py-1 text-xs", className)}
      {...props}
    />
  )
}

function SelectItem({
  className,
  children,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Item>) {
  return (
    <SelectPrimitive.Item
      data-slot="select-item"
      className={cn(
        "focus:bg-accent focus:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm [&_svg:not([class*='size-'])]:size-4 *:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2 relative flex w-full cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0",
        className
      )}
      {...props}
    >
      <span className="pointer-events-none absolute right-2 flex size-4 items-center justify-center">
        <SelectPrimitive.ItemIndicator>
          <CheckIcon className="pointer-events-none" />
        </SelectPrimitive.ItemIndicator>
      </span>
      <SelectPrimitive.ItemText>{children}</SelectPrimitive.ItemText>
    </SelectPrimitive.Item>
  )
}

function SelectSeparator({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.Separator>) {
  return (
    <SelectPrimitive.Separator
      data-slot="select-separator"
      className={cn("bg-border -mx-1 my-1 h-px pointer-events-none", className)}
      {...props}
    />
  )
}

function SelectScrollUpButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollUpButton>) {
  return (
    <SelectPrimitive.ScrollUpButton
      data-slot="select-scroll-up-button"
      className={cn("bg-popover z-10 flex cursor-default items-center justify-center py-1 [&_svg:not([class*='size-'])]:size-4", className)}
      {...props}
    >
      <ChevronUpIcon />
    </SelectPrimitive.ScrollUpButton>
  )
}

function SelectScrollDownButton({
  className,
  ...props
}: React.ComponentProps<typeof SelectPrimitive.ScrollDownButton>) {
  return (
    <SelectPrimitive.ScrollDownButton
      data-slot="select-scroll-down-button"
      className={cn("bg-popover z-10 flex cursor-default items-center justify-center py-1 [&_svg:not([class*='size-'])]:size-4", className)}
      {...props}
    >
      <ChevronDownIcon />
    </SelectPrimitive.ScrollDownButton>
  )
}

export {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectScrollDownButton,
  SelectScrollUpButton,
  SelectSeparator,
  SelectTrigger,
  SelectValue,
}




END_OF_FILE_CONTENT
# SKIP: src/components/ui/select.txt:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/separator.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/separator.tsx"
import * as React from 'react'
import { cn } from '@olonjs/core/runtime'

const Separator = React.forwardRef<
  HTMLDivElement,
  React.HTMLAttributes<HTMLDivElement> & { orientation?: 'horizontal' | 'vertical' }
>(({ className, orientation = 'horizontal', ...props }, ref) => (
  <div
    ref={ref}
    className={cn(
      'shrink-0 bg-border',
      orientation === 'horizontal' ? 'h-[0.5px] w-full' : 'h-full w-[0.5px]',
      className
    )}
    {...props}
  />
))
Separator.displayName = 'Separator'

export { Separator }

END_OF_FILE_CONTENT
# SKIP: src/components/ui/separator.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/sheet.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/sheet.tsx"
"use client"

import * as React from "react"
import { Dialog as SheetPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"
import { Button } from "@/components/ui/button"
import { XIcon } from "lucide-react"

function Sheet({ ...props }: React.ComponentProps<typeof SheetPrimitive.Root>) {
  return <SheetPrimitive.Root data-slot="sheet" {...props} />
}

function SheetTrigger({
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Trigger>) {
  return <SheetPrimitive.Trigger data-slot="sheet-trigger" {...props} />
}

function SheetClose({
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Close>) {
  return <SheetPrimitive.Close data-slot="sheet-close" {...props} />
}

function SheetPortal({
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Portal>) {
  return <SheetPrimitive.Portal data-slot="sheet-portal" {...props} />
}

function SheetOverlay({
  className,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Overlay>) {
  return (
    <SheetPrimitive.Overlay
      data-slot="sheet-overlay"
      className={cn(
        "fixed inset-0 z-50 bg-black/10 duration-100 supports-backdrop-filter:backdrop-blur-xs data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0",
        className
      )}
      {...props}
    />
  )
}

function SheetContent({
  className,
  children,
  side = "right",
  showCloseButton = true,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Content> & {
  side?: "top" | "right" | "bottom" | "left"
  showCloseButton?: boolean
}) {
  return (
    <SheetPortal>
      <SheetOverlay />
      <SheetPrimitive.Content
        data-slot="sheet-content"
        data-side={side}
        className={cn(
          "fixed z-50 flex flex-col gap-4 bg-popover bg-clip-padding text-sm text-popover-foreground shadow-lg transition duration-200 ease-in-out data-[side=bottom]:inset-x-0 data-[side=bottom]:bottom-0 data-[side=bottom]:h-auto data-[side=bottom]:border-t data-[side=left]:inset-y-0 data-[side=left]:left-0 data-[side=left]:h-full data-[side=left]:w-3/4 data-[side=left]:border-r data-[side=right]:inset-y-0 data-[side=right]:right-0 data-[side=right]:h-full data-[side=right]:w-3/4 data-[side=right]:border-l data-[side=top]:inset-x-0 data-[side=top]:top-0 data-[side=top]:h-auto data-[side=top]:border-b data-[side=left]:sm:max-w-sm data-[side=right]:sm:max-w-sm data-open:animate-in data-open:fade-in-0 data-[side=bottom]:data-open:slide-in-from-bottom-10 data-[side=left]:data-open:slide-in-from-left-10 data-[side=right]:data-open:slide-in-from-right-10 data-[side=top]:data-open:slide-in-from-top-10 data-closed:animate-out data-closed:fade-out-0 data-[side=bottom]:data-closed:slide-out-to-bottom-10 data-[side=left]:data-closed:slide-out-to-left-10 data-[side=right]:data-closed:slide-out-to-right-10 data-[side=top]:data-closed:slide-out-to-top-10",
          className
        )}
        {...props}
      >
        {children}
        {showCloseButton && (
          <SheetPrimitive.Close data-slot="sheet-close" asChild>
            <Button
              variant="ghost"
              className="absolute top-3 right-3"
              size="sm"
            >
              <XIcon
              />
              <span className="sr-only">Close</span>
            </Button>
          </SheetPrimitive.Close>
        )}
      </SheetPrimitive.Content>
    </SheetPortal>
  )
}

function SheetHeader({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="sheet-header"
      className={cn("flex flex-col gap-0.5 p-4", className)}
      {...props}
    />
  )
}

function SheetFooter({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="sheet-footer"
      className={cn("mt-auto flex flex-col gap-2 p-4", className)}
      {...props}
    />
  )
}

function SheetTitle({
  className,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Title>) {
  return (
    <SheetPrimitive.Title
      data-slot="sheet-title"
      className={cn(
        "text-base font-medium text-foreground",
        className
      )}
      {...props}
    />
  )
}

function SheetDescription({
  className,
  ...props
}: React.ComponentProps<typeof SheetPrimitive.Description>) {
  return (
    <SheetPrimitive.Description
      data-slot="sheet-description"
      className={cn("text-sm text-muted-foreground", className)}
      {...props}
    />
  )
}

export {
  Sheet,
  SheetTrigger,
  SheetClose,
  SheetContent,
  SheetHeader,
  SheetFooter,
  SheetTitle,
  SheetDescription,
}


END_OF_FILE_CONTENT
# SKIP: src/components/ui/sheet.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/skeleton.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/skeleton.tsx"
import { cn } from '@olonjs/core/runtime';
import type { HTMLAttributes } from 'react';

function Skeleton({
  className,
  ...props
}: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn('animate-pulse rounded-md bg-muted', className)}
      {...props}
    />
  );
}

export { Skeleton };

END_OF_FILE_CONTENT
# SKIP: src/components/ui/skeleton.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/switch.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/switch.tsx"
import * as React from "react"
import { Switch as SwitchPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"

function Switch({
  className,
  size = "default",
  ...props
}: React.ComponentProps<typeof SwitchPrimitive.Root> & {
  size?: "sm" | "default"
}) {
  return (
    <SwitchPrimitive.Root
      data-slot="switch"
      data-size={size}
      className={cn(
        "peer group/switch relative inline-flex shrink-0 items-center rounded-full border border-transparent transition-all outline-none after:absolute after:-inset-x-3 after:-inset-y-2 focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 aria-invalid:border-destructive aria-invalid:ring-3 aria-invalid:ring-destructive/20 data-[size=default]:h-[18.4px] data-[size=default]:w-[32px] data-[size=sm]:h-[14px] data-[size=sm]:w-[24px] dark:aria-invalid:border-destructive/50 dark:aria-invalid:ring-destructive/40 data-checked:bg-primary data-unchecked:bg-input dark:data-unchecked:bg-input/80 data-disabled:cursor-not-allowed data-disabled:opacity-50",
        className
      )}
      {...props}
    >
      <SwitchPrimitive.Thumb
        data-slot="switch-thumb"
        className="pointer-events-none block rounded-full bg-background ring-0 transition-transform group-data-[size=default]/switch:size-4 group-data-[size=sm]/switch:size-3 group-data-[size=default]/switch:data-checked:translate-x-[calc(100%-2px)] group-data-[size=sm]/switch:data-checked:translate-x-[calc(100%-2px)] dark:data-checked:bg-primary-foreground group-data-[size=default]/switch:data-unchecked:translate-x-0 group-data-[size=sm]/switch:data-unchecked:translate-x-0 dark:data-unchecked:bg-foreground"
      />
    </SwitchPrimitive.Root>
  )
}

export { Switch }


END_OF_FILE_CONTENT
# SKIP: src/components/ui/switch.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/table.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/table.tsx"
import * as React from "react"

import { cn } from "@olonjs/core/runtime"

function Table({ className, ...props }: React.ComponentProps<"table">) {
  return (
    <div
      data-slot="table-container"
      className="relative w-full overflow-x-auto"
    >
      <table
        data-slot="table"
        className={cn("w-full caption-bottom text-sm", className)}
        {...props}
      />
    </div>
  )
}

function TableHeader({ className, ...props }: React.ComponentProps<"thead">) {
  return (
    <thead
      data-slot="table-header"
      className={cn("[&_tr]:border-b", className)}
      {...props}
    />
  )
}

function TableBody({ className, ...props }: React.ComponentProps<"tbody">) {
  return (
    <tbody
      data-slot="table-body"
      className={cn("[&_tr:last-child]:border-0", className)}
      {...props}
    />
  )
}

function TableFooter({ className, ...props }: React.ComponentProps<"tfoot">) {
  return (
    <tfoot
      data-slot="table-footer"
      className={cn(
        "border-t bg-muted/50 font-medium [&>tr]:last:border-b-0",
        className
      )}
      {...props}
    />
  )
}

function TableRow({ className, ...props }: React.ComponentProps<"tr">) {
  return (
    <tr
      data-slot="table-row"
      className={cn(
        "border-b transition-colors hover:bg-muted/50 has-aria-expanded:bg-muted/50 data-[state=selected]:bg-muted",
        className
      )}
      {...props}
    />
  )
}

function TableHead({ className, ...props }: React.ComponentProps<"th">) {
  return (
    <th
      data-slot="table-head"
      className={cn(
        "h-10 px-2 text-left align-middle font-medium whitespace-nowrap text-foreground [&:has([role=checkbox])]:pr-0",
        className
      )}
      {...props}
    />
  )
}

function TableCell({ className, ...props }: React.ComponentProps<"td">) {
  return (
    <td
      data-slot="table-cell"
      className={cn(
        "p-2 align-middle whitespace-nowrap [&:has([role=checkbox])]:pr-0",
        className
      )}
      {...props}
    />
  )
}

function TableCaption({
  className,
  ...props
}: React.ComponentProps<"caption">) {
  return (
    <caption
      data-slot="table-caption"
      className={cn("mt-4 text-sm text-muted-foreground", className)}
      {...props}
    />
  )
}

export {
  Table,
  TableHeader,
  TableBody,
  TableFooter,
  TableHead,
  TableRow,
  TableCell,
  TableCaption,
}


END_OF_FILE_CONTENT
# SKIP: src/components/ui/table.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/tabs.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/tabs.tsx"
"use client"

import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { Tabs as TabsPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"

function Tabs({
  className,
  orientation = "horizontal",
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Root>) {
  return (
    <TabsPrimitive.Root
      data-slot="tabs"
      data-orientation={orientation}
      className={cn(
        "group/tabs flex gap-2 data-horizontal:flex-col",
        className
      )}
      {...props}
    />
  )
}

const tabsListVariants = cva(
  "group/tabs-list inline-flex w-fit items-center justify-center rounded-lg p-[3px] text-muted-foreground group-data-horizontal/tabs:h-8 group-data-vertical/tabs:h-fit group-data-vertical/tabs:flex-col data-[variant=line]:rounded-none",
  {
    variants: {
      variant: {
        default: "bg-muted",
        line: "gap-1 bg-transparent",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
)

function TabsList({
  className,
  variant = "default",
  ...props
}: React.ComponentProps<typeof TabsPrimitive.List> &
  VariantProps<typeof tabsListVariants>) {
  return (
    <TabsPrimitive.List
      data-slot="tabs-list"
      data-variant={variant}
      className={cn(tabsListVariants({ variant }), className)}
      {...props}
    />
  )
}

function TabsTrigger({
  className,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Trigger>) {
  return (
    <TabsPrimitive.Trigger
      data-slot="tabs-trigger"
      className={cn(
        "relative inline-flex h-[calc(100%-1px)] flex-1 items-center justify-center gap-1.5 rounded-md border border-transparent px-1.5 py-0.5 text-sm font-medium whitespace-nowrap text-foreground/60 transition-all group-data-vertical/tabs:w-full group-data-vertical/tabs:justify-start hover:text-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 focus-visible:outline-1 focus-visible:outline-ring disabled:pointer-events-none disabled:opacity-50 has-data-[icon=inline-end]:pr-1 has-data-[icon=inline-start]:pl-1 dark:text-muted-foreground dark:hover:text-foreground group-data-[variant=default]/tabs-list:data-active:shadow-sm group-data-[variant=line]/tabs-list:data-active:shadow-none [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
        "group-data-[variant=line]/tabs-list:bg-transparent group-data-[variant=line]/tabs-list:data-active:bg-transparent dark:group-data-[variant=line]/tabs-list:data-active:border-transparent dark:group-data-[variant=line]/tabs-list:data-active:bg-transparent",
        "data-active:bg-background data-active:text-foreground dark:data-active:border-input dark:data-active:bg-input/30 dark:data-active:text-foreground",
        "after:absolute after:bg-foreground after:opacity-0 after:transition-opacity group-data-horizontal/tabs:after:inset-x-0 group-data-horizontal/tabs:after:bottom-[-5px] group-data-horizontal/tabs:after:h-0.5 group-data-vertical/tabs:after:inset-y-0 group-data-vertical/tabs:after:-right-1 group-data-vertical/tabs:after:w-0.5 group-data-[variant=line]/tabs-list:data-active:after:opacity-100",
        className
      )}
      {...props}
    />
  )
}

function TabsContent({
  className,
  ...props
}: React.ComponentProps<typeof TabsPrimitive.Content>) {
  return (
    <TabsPrimitive.Content
      data-slot="tabs-content"
      className={cn("flex-1 text-sm outline-none", className)}
      {...props}
    />
  )
}

export { Tabs, TabsList, TabsTrigger, TabsContent, tabsListVariants }


END_OF_FILE_CONTENT
# SKIP: src/components/ui/tabs.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/textarea.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/textarea.tsx"
import * as React from "react"

import { cn } from "@olonjs/core/runtime"

function Textarea({ className, ...props }: React.ComponentProps<"textarea">) {
  return (
    <textarea
      data-slot="textarea"
      className={cn(
        "border-input dark:bg-input/30 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 disabled:bg-input/50 dark:disabled:bg-input/80 rounded-lg border bg-transparent px-2.5 py-2 text-base transition-colors focus-visible:ring-3 aria-invalid:ring-3 md:text-sm placeholder:text-muted-foreground flex field-sizing-content min-h-16 w-full outline-none disabled:cursor-not-allowed disabled:opacity-50",
        className
      )}
      {...props}
    />
  )
}

export { Textarea }





END_OF_FILE_CONTENT
# SKIP: src/components/ui/textarea.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/toggle-group.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/toggle-group.tsx"
import * as React from "react"
import { type VariantProps } from "class-variance-authority"
import { ToggleGroup as ToggleGroupPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"
import { toggleVariants } from "@/components/ui/toggle"

const ToggleGroupContext = React.createContext<
  VariantProps<typeof toggleVariants> & {
    spacing?: number
    orientation?: "horizontal" | "vertical"
  }
>({
  size: "default",
  variant: "default",
  spacing: 0,
  orientation: "horizontal",
})

function ToggleGroup({
  className,
  variant,
  size,
  spacing = 0,
  orientation = "horizontal",
  children,
  ...props
}: React.ComponentProps<typeof ToggleGroupPrimitive.Root> &
  VariantProps<typeof toggleVariants> & {
    spacing?: number
    orientation?: "horizontal" | "vertical"
  }) {
  return (
    <ToggleGroupPrimitive.Root
      data-slot="toggle-group"
      data-variant={variant}
      data-size={size}
      data-spacing={spacing}
      data-orientation={orientation}
      style={{ "--gap": spacing } as React.CSSProperties}
      className={cn(
        "group/toggle-group flex w-fit flex-row items-center gap-[--spacing(var(--gap))] rounded-lg data-[size=sm]:rounded-[min(var(--radius-md),10px)] data-vertical:flex-col data-vertical:items-stretch",
        className
      )}
      {...props}
    >
      <ToggleGroupContext.Provider
        value={{ variant, size, spacing, orientation }}
      >
        {children}
      </ToggleGroupContext.Provider>
    </ToggleGroupPrimitive.Root>
  )
}

function ToggleGroupItem({
  className,
  children,
  variant = "default",
  size = "default",
  ...props
}: React.ComponentProps<typeof ToggleGroupPrimitive.Item> &
  VariantProps<typeof toggleVariants>) {
  const context = React.useContext(ToggleGroupContext)

  return (
    <ToggleGroupPrimitive.Item
      data-slot="toggle-group-item"
      data-variant={context.variant || variant}
      data-size={context.size || size}
      data-spacing={context.spacing}
      className={cn(
        "shrink-0 group-data-[spacing=0]/toggle-group:rounded-none group-data-[spacing=0]/toggle-group:px-2 focus:z-10 focus-visible:z-10 group-data-[spacing=0]/toggle-group:has-data-[icon=inline-end]:pr-1.5 group-data-[spacing=0]/toggle-group:has-data-[icon=inline-start]:pl-1.5 group-data-horizontal/toggle-group:data-[spacing=0]:first:rounded-l-lg group-data-vertical/toggle-group:data-[spacing=0]:first:rounded-t-lg group-data-horizontal/toggle-group:data-[spacing=0]:last:rounded-r-lg group-data-vertical/toggle-group:data-[spacing=0]:last:rounded-b-lg group-data-horizontal/toggle-group:data-[spacing=0]:data-[variant=outline]:border-l-0 group-data-vertical/toggle-group:data-[spacing=0]:data-[variant=outline]:border-t-0 group-data-horizontal/toggle-group:data-[spacing=0]:data-[variant=outline]:first:border-l group-data-vertical/toggle-group:data-[spacing=0]:data-[variant=outline]:first:border-t",
        toggleVariants({
          variant: context.variant || variant,
          size: context.size || size,
        }),
        className
      )}
      {...props}
    >
      {children}
    </ToggleGroupPrimitive.Item>
  )
}

export { ToggleGroup, ToggleGroupItem }


END_OF_FILE_CONTENT
# SKIP: src/components/ui/toggle-group.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/toggle.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/toggle.tsx"
"use client"

import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"
import { Toggle as TogglePrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"

const toggleVariants = cva(
  "group/toggle inline-flex items-center justify-center gap-1 rounded-lg text-sm font-medium whitespace-nowrap transition-all outline-none hover:bg-muted hover:text-foreground focus-visible:border-ring focus-visible:ring-[3px] focus-visible:ring-ring/50 disabled:pointer-events-none disabled:opacity-50 aria-invalid:border-destructive aria-invalid:ring-destructive/20 aria-pressed:bg-muted data-[state=on]:bg-muted dark:aria-invalid:ring-destructive/40 [&_svg]:pointer-events-none [&_svg]:shrink-0 [&_svg:not([class*='size-'])]:size-4",
  {
    variants: {
      variant: {
        default: "bg-transparent",
        outline: "border border-input bg-transparent hover:bg-muted",
      },
      size: {
        default:
          "h-8 min-w-8 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
        sm: "h-7 min-w-7 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem] has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3.5",
        lg: "h-9 min-w-9 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
)

function Toggle({
  className,
  variant = "default",
  size = "default",
  ...props
}: React.ComponentProps<typeof TogglePrimitive.Root> &
  VariantProps<typeof toggleVariants>) {
  return (
    <TogglePrimitive.Root
      data-slot="toggle"
      className={cn(toggleVariants({ variant, size, className }))}
      {...props}
    />
  )
}

export { Toggle, toggleVariants }


END_OF_FILE_CONTENT
# SKIP: src/components/ui/toggle.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/components/ui/tooltip.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/components/ui/tooltip.tsx"
"use client"

import * as React from "react"
import { Tooltip as TooltipPrimitive } from "radix-ui"

import { cn } from "@olonjs/core/runtime"

function TooltipProvider({
  delayDuration = 0,
  ...props
}: React.ComponentProps<typeof TooltipPrimitive.Provider>) {
  return (
    <TooltipPrimitive.Provider
      data-slot="tooltip-provider"
      delayDuration={delayDuration}
      {...props}
    />
  )
}

function Tooltip({
  ...props
}: React.ComponentProps<typeof TooltipPrimitive.Root>) {
  return <TooltipPrimitive.Root data-slot="tooltip" {...props} />
}

function TooltipTrigger({
  ...props
}: React.ComponentProps<typeof TooltipPrimitive.Trigger>) {
  return <TooltipPrimitive.Trigger data-slot="tooltip-trigger" {...props} />
}

function TooltipContent({
  className,
  sideOffset = 0,
  children,
  ...props
}: React.ComponentProps<typeof TooltipPrimitive.Content>) {
  return (
    <TooltipPrimitive.Portal>
      <TooltipPrimitive.Content
        data-slot="tooltip-content"
        sideOffset={sideOffset}
        className={cn(
          "z-50 inline-flex w-fit max-w-xs origin-(--radix-tooltip-content-transform-origin) items-center gap-1.5 rounded-md bg-foreground px-3 py-1.5 text-xs text-background has-data-[slot=kbd]:pr-1.5 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 **:data-[slot=kbd]:relative **:data-[slot=kbd]:isolate **:data-[slot=kbd]:z-50 **:data-[slot=kbd]:rounded-sm data-[state=delayed-open]:animate-in data-[state=delayed-open]:fade-in-0 data-[state=delayed-open]:zoom-in-95 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-closed:animate-out data-closed:fade-out-0 data-closed:zoom-out-95",
          className
        )}
        {...props}
      >
        {children}
        <TooltipPrimitive.Arrow className="z-50 size-2.5 translate-y-[calc(-50%_-_2px)] rotate-45 rounded-[2px] bg-foreground fill-foreground" />
      </TooltipPrimitive.Content>
    </TooltipPrimitive.Portal>
  )
}

export { Tooltip, TooltipContent, TooltipProvider, TooltipTrigger }


END_OF_FILE_CONTENT
# SKIP: src/components/ui/tooltip.tsx:Zone.Identifier is binary and cannot be embedded as text.
mkdir -p "src/data"
mkdir -p "src/data/config"
echo "Creating src/data/config/menu.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/config/menu.json"
{
  "main": [
    {
      "label": "Why",
      "href": "#Why"
    },
    {
      "label": "Architecture",
      "href": "#Architecture"
    },
    {
      "label": "Example",
      "href": "#Example"
    },
    {
      "label": "Get started",
      "href": "#Getstarted"
    },
    {
      "label": "GitHub",
      "href": "https://github.com/olonjs/core"
    }
  ]
}
END_OF_FILE_CONTENT
echo "Creating src/data/config/menu_example_for_schema.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/config/menu_example_for_schema.json"
{
  "main": [
    { 
      "label": "Why",
      "href": "/why",
      "children": [
        {
          "label": "Overview",
          "href": "/platform/overview"
        },
        {
          "label": "Architecture",
          "href": "/platform/architecture"
        },
        {
          "label": "Security",
          "href": "/platform/security"
        },
        {
          "label": "Integrations",
          "href": "/platform/integrations"
        },
        {
          "label": "Roadmap",
          "href": "/platform/roadmap"
        }
      ]
    },
    {
      "label": "Solutions",
      "href": "/solutions"
    },
    {
      "label": "Pricing",
      "href": "/pricing"
    },
    {
      "label": "Resources",
      "href": "/resources"
    }
  ]
}
END_OF_FILE_CONTENT
echo "Creating src/data/config/site.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/config/site.json"
{
  "identity": {
    "title": "OlonJS",
    "logoUrl": "/brand/mark/olon-mark-dark.svg"
  },
  
  "header": {
    "id": "global-header",
    "type": "header",
    "data": {
      "logoText": "Olon",
      "badge": "JS",
      "links": [
        {
          "label": "Why",
          "href": "#Why"
        },
        {
          "label": "Architecture",
          "href": "#Architecture"
        },
        {
          "label": "Example",
          "href": "#Example"
        },
        {
          "label": "Get started",
          "href": "#Getstarted"
        },
        {
          "label": "GitHub",
          "href": "https://github.com/olonjs/core"
        }
      ],
      "ctaLabel": "",
      "ctaHref": "",
      "signinHref": ""
    }
  },
  "footer": {
    "id": "global-footer",
    "type": "footer",
    "data": {
      "brandText": "OlonJS",
      "copyright": "© 2026 OlonJS · v1.5 · Guido Serio",
      "links": [
        {
          "label": "GitHub",
          "href": "https://github.com/olonjs/core"
        }
      ],
      "designSystemHref": ""
    },
    "settings": {
      "showLogo": true
    }
  }
}
END_OF_FILE_CONTENT
echo "Creating src/data/config/theme.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/config/theme.json"
{
  "name": "Olon",
  "tokens": {
    "colors": {
      "background": "hsl(215 28% 7%)",
      "card": "hsl(218 44% 9%)",
      "elevated": "#141B24",
      "overlay": "#1C2433",
      "popover": "hsl(218 44% 9%)",
      "popover-foreground": "hsl(214 33% 84%)",
      "foreground": "hsl(214 33% 84%)",
      "card-foreground": "hsl(214 33% 84%)",
      "muted-foreground": "hsl(215 23% 57%)",
      "placeholder": "#4A5C78",
      "primary": "hsl(222 100% 54%)",
      "primary-foreground": "hsl(0 0% 100%)",
      "primary-light": "#84ABFF",
      "primary-dark": "#0F52E0",
      "primary-50": "#EEF3FF",
      "primary-100": "#D6E4FF",
      "primary-200": "#ADC8FF",
      "primary-300": "#84ABFF",
      "primary-400": "#5B8EFF",
      "primary-500": "#1763FF",
      "primary-600": "#0F52E0",
      "primary-700": "#0940B8",
      "primary-800": "#063090",
      "primary-900": "#031E68",
      "accent": "hsl(216 28% 15%)",
      "accent-foreground": "hsl(214 33% 84%)",
      "secondary": "hsl(217 30% 11%)",
      "secondary-foreground": "hsl(214 33% 84%)",
      "muted": "hsl(217 30% 11%)",
      "border": "hsl(216 27% 21%)",
      "border-strong": "#2F3D55",
      "input": "hsl(216 27% 21%)",
      "ring": "hsl(222 100% 54%)",
      "destructive": "hsl(0 40% 46%)",
      "destructive-foreground": "hsl(210 58% 93%)",
      "destructive-border": "#7F2626",
      "destructive-ring": "#E06060",
      "success": "hsl(152 83% 26%)",
      "success-foreground": "hsl(210 58% 93%)",
      "success-border": "#1DB87A",
      "success-indicator": "#1DB87A",
      "warning": "hsl(46 100% 21%)",
      "warning-foreground": "hsl(210 58% 93%)",
      "warning-border": "#C49A00",
      "info": "hsl(214 100% 40%)",
      "info-foreground": "hsl(210 58% 93%)",
      "info-border": "#4D9FE0"
    },
    "modes": {
      "light": {
        "colors": {
          "background": "hsl(0 0% 96%)",
          "card": "hsl(0 0% 100%)",
          "elevated": "#F4F3EF",
          "overlay": "#E5E3DC",
          "popover": "hsl(0 0% 100%)",
          "popover-foreground": "hsl(0 0% 3%)",
          "foreground": "hsl(0 0% 3%)",
          "card-foreground": "hsl(0 0% 3%)",
          "muted-foreground": "hsl(0 0% 42%)",
          "placeholder": "#B4B2AD",
          "primary": "hsl(222 100% 54%)",
          "primary-foreground": "hsl(0 0% 100%)",
          "primary-light": "#5B8EFF",
          "primary-dark": "#0F52E0",
          "primary-50": "#EEF3FF",
          "primary-100": "#D6E4FF",
          "primary-200": "#ADC8FF",
          "primary-300": "#84ABFF",
          "primary-400": "#5B8EFF",
          "primary-500": "#1763FF",
          "primary-600": "#0F52E0",
          "primary-700": "#0940B8",
          "primary-800": "#063090",
          "primary-900": "#031E68",
          "accent": "hsl(222 100% 92%)",
          "accent-foreground": "hsl(222 100% 54%)",
          "secondary": "hsl(0 0% 92%)",
          "secondary-foreground": "hsl(0 0% 3%)",
          "muted": "hsl(0 0% 92%)",
          "border": "hsl(0 0% 84%)",
          "border-strong": "#B4B2AD",
          "input": "hsl(0 0% 84%)",
          "ring": "hsl(222 100% 54%)",
          "destructive": "hsl(0 72% 51%)",
          "destructive-foreground": "hsl(0 0% 100%)",
          "destructive-border": "#FECACA",
          "destructive-ring": "#EF4444",
          "success": "hsl(160 84% 39%)",
          "success-foreground": "hsl(0 0% 100%)",
          "success-border": "#D4F0E2",
          "success-indicator": "#0A7C4E",
          "warning": "hsl(38 92% 50%)",
          "warning-foreground": "hsl(0 0% 3%)",
          "warning-border": "#F5EAD4",
          "info": "hsl(222 100% 54%)",
          "info-foreground": "hsl(0 0% 100%)",
          "info-border": "#D4E5F5"
        }
      }
    },
    "typography": {
      "fontFamily": {
        "primary": "\"Instrument Sans\", Helvetica, Arial, sans-serif",
        "mono": "\"JetBrains Mono\", \"Fira Code\", monospace",
        "display": "\"Instrument Sans\", Helvetica, Arial, sans-serif"
      },
      "wordmark": {
        "fontFamily": "\"Instrument Sans\", Helvetica, Arial, sans-serif",
        "weight": "700",
        "tracking": "-0.05em"
      },
      "scale": {
        "xs": "0.75rem",
        "sm": "0.875rem",
        "base": "1rem",
        "lg": "1.125rem",
        "xl": "1.25rem",
        "2xl": "1.5rem",
        "3xl": "1.875rem",
        "4xl": "2.25rem",
        "5xl": "3rem",
        "6xl": "3rem",
        "7xl": "4.5rem"
      },
      "tracking": {
        "tight": "-0.04em",
        "normal": "0em",
        "wide": "0.04em",
        "widest": "0.14em"
      },
      "leading": {
        "tight": "1.2",
        "normal": "1.5",
        "relaxed": "1.7"
      }
    },
    "borderRadius": {
      "xl": "1rem",
      "lg": "0.75rem",
      "md": "0.5rem",
      "sm": "0.25rem",
      "full": "9999px"
    },
    "spacing": {
      "container-max": "72rem",
      "section-y": "4rem",
      "header-h": "4rem"
    },
    "zIndex": {
      "base": "0",
      "elevated": "10",
      "dropdown": "20",
      "sticky": "40",
      "overlay": "50",
      "modal": "60",
      "toast": "100"
    }
  }
}
END_OF_FILE_CONTENT
mkdir -p "src/data/pages"
echo "Creating src/data/pages/home.json..."
cat << 'END_OF_FILE_CONTENT' > "src/data/pages/home.json"
{
  "id": "home-page",
  "slug": "home",
  "meta": {
    "title": "Home",
    "description": "OlonJS tenant alpha — form smoke test"
  },
  "sections": [
    {
      "id": "form-demo-1",
      "type": "form-demo",
      "data": {
        "anchorId": "form-demo",
        "title": "Contattaci",
        "description": "Compila il modulo e ti risponderemo al più presto.",
        "recipientEmail": "test@olonjs.io",
        "submitLabel": "Invia",
        "successMessage": "Richiesta inviata con successo.",
        "icon": "mail"
      }
    }
  ],
  "global-header": false
}
END_OF_FILE_CONTENT
mkdir -p "src/emails"
echo "Creating src/emails/LeadNotificationEmail.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/emails/LeadNotificationEmail.tsx"
import React from "react";
import {
  Body,
  Button,
  Container,
  Head,
  Heading,
  Hr,
  Html,
  Img,
  Preview,
  Section,
  Text,
} from "@react-email/components";

type LeadData = Record<string, unknown>;

type EmailTheme = {
  colors?: {
    primary?: string;
    secondary?: string;
    accent?: string;
    background?: string;
    surface?: string;
    surfaceAlt?: string;
    text?: string;
    textMuted?: string;
    border?: string;
  };
  typography?: {
    fontFamily?: {
      primary?: string;
      display?: string;
      mono?: string;
    };
  };
  borderRadius?: {
    sm?: string;
    md?: string;
    lg?: string;
    xl?: string;
  };
};

export type LeadNotificationEmailProps = {
  tenantName: string;
  correlationId: string;
  replyTo?: string | null;
  leadData: LeadData;
  brandName?: string;
  logoUrl?: string;
  logoAlt?: string;
  tagline?: string;
  theme?: EmailTheme;
};

function safeString(value: unknown): string {
  if (value == null) return "-";
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed || "-";
  }
  return JSON.stringify(value);
}

function flattenLeadData(data: LeadData) {
  return Object.entries(data)
    .filter(([key]) => !key.startsWith("_"))
    .slice(0, 20)
    .map(([key, value]) => ({ label: key, value: safeString(value) }));
}

export function LeadNotificationEmail({
  tenantName,
  correlationId,
  replyTo,
  leadData,
  brandName,
  logoUrl,
  logoAlt,
  tagline,
  theme,
}: LeadNotificationEmailProps) {
  const fields = flattenLeadData(leadData);
  const brandLabel = brandName || tenantName;

  const colors = {
    primary: theme?.colors?.primary || "#2D5016",
    background: theme?.colors?.background || "#FAFAF5",
    surface: theme?.colors?.surface || "#FFFFFF",
    text: theme?.colors?.text || "#1C1C14",
    textMuted: theme?.colors?.textMuted || "#5A5A4A",
    border: theme?.colors?.border || "#D8D5C5",
  };

  const fonts = {
    primary: theme?.typography?.fontFamily?.primary || "Inter, Arial, sans-serif",
    display: theme?.typography?.fontFamily?.display || "Georgia, serif",
  };

  const radius = {
    md: theme?.borderRadius?.md || "10px",
    lg: theme?.borderRadius?.lg || "16px",
  };

  return (
    <Html>
      <Head />
      <Preview>Nuovo lead ricevuto da {brandLabel}</Preview>
      <Body style={{ backgroundColor: colors.background, color: colors.text, fontFamily: fonts.primary, padding: "24px" }}>
        <Container style={{ backgroundColor: colors.surface, border: `1px solid ${colors.border}`, borderRadius: radius.lg, padding: "24px" }}>
          <Section>
            {logoUrl ? <Img src={logoUrl} alt={logoAlt || brandLabel} height="44" style={{ marginBottom: "8px" }} /> : null}
            <Text style={{ color: colors.text, fontSize: "18px", fontWeight: 700, margin: "0 0 6px 0" }}>{brandLabel}</Text>
            <Text style={{ color: colors.textMuted, marginTop: "0", marginBottom: "0" }}>{tagline || "Notifica automatica lead"}</Text>
          </Section>

          <Hr style={{ borderColor: colors.border, margin: "20px 0" }} />

          <Heading as="h2" style={{ color: colors.text, margin: "0 0 12px 0", fontSize: "22px", fontFamily: fonts.display }}>
            Nuovo lead da {tenantName}
          </Heading>
          <Text style={{ color: colors.textMuted, marginTop: "0", marginBottom: "16px" }}>Correlation ID: {correlationId}</Text>

          <Section style={{ border: `1px solid ${colors.border}`, borderRadius: radius.md, padding: "12px" }}>
            {fields.length === 0 ? (
              <Text style={{ color: colors.textMuted, margin: 0 }}>Nessun campo lead disponibile.</Text>
            ) : (
              fields.map((field) => (
                <Text key={field.label} style={{ margin: "0 0 8px 0", color: colors.text, fontSize: "14px", wordBreak: "break-word" }}>
                  <strong>{field.label}:</strong> {field.value}
                </Text>
              ))
            )}
          </Section>

          <Section style={{ marginTop: "18px" }}>
            <Button
              href={replyTo ? `mailto:${replyTo}` : "mailto:"}
              style={{
                backgroundColor: colors.primary,
                color: "#ffffff",
                borderRadius: radius.md,
                textDecoration: "none",
                padding: "12px 18px",
                fontWeight: 600,
              }}
            >
              Rispondi ora
            </Button>
          </Section>
        </Container>
      </Body>
    </Html>
  );
}

export default LeadNotificationEmail;

END_OF_FILE_CONTENT
echo "Creating src/emails/LeadSenderConfirmationEmail.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/emails/LeadSenderConfirmationEmail.tsx"
import React from "react";
import {
  Body,
  Container,
  Head,
  Heading,
  Hr,
  Html,
  Img,
  Preview,
  Section,
  Text,
} from "@react-email/components";

type LeadData = Record<string, unknown>;

type EmailTheme = {
  colors?: {
    primary?: string;
    secondary?: string;
    accent?: string;
    background?: string;
    surface?: string;
    surfaceAlt?: string;
    text?: string;
    textMuted?: string;
    border?: string;
  };
  typography?: {
    fontFamily?: {
      primary?: string;
      display?: string;
      mono?: string;
    };
  };
  borderRadius?: {
    sm?: string;
    md?: string;
    lg?: string;
    xl?: string;
  };
};

export type LeadSenderConfirmationEmailProps = {
  tenantName: string;
  correlationId: string;
  leadData: LeadData;
  brandName?: string;
  logoUrl?: string;
  logoAlt?: string;
  tagline?: string;
  theme?: EmailTheme;
};

function safeString(value: unknown): string {
  if (value == null) return "-";
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed || "-";
  }
  return JSON.stringify(value);
}

function flattenLeadData(data: LeadData) {
  const skipKeys = new Set(["recipientEmail", "tenant", "source", "submittedAt", "email_confirm"]);
  return Object.entries(data)
    .filter(([key]) => !key.startsWith("_") && !skipKeys.has(key))
    .slice(0, 12)
    .map(([key, value]) => ({ label: key, value: safeString(value) }));
}

export function LeadSenderConfirmationEmail({
  tenantName,
  correlationId,
  leadData,
  brandName,
  logoUrl,
  logoAlt,
  tagline,
  theme,
}: LeadSenderConfirmationEmailProps) {
  const fields = flattenLeadData(leadData);
  const brandLabel = brandName || tenantName;

  const colors = {
    primary: theme?.colors?.primary || "#2D5016",
    background: theme?.colors?.background || "#FAFAF5",
    surface: theme?.colors?.surface || "#FFFFFF",
    text: theme?.colors?.text || "#1C1C14",
    textMuted: theme?.colors?.textMuted || "#5A5A4A",
    border: theme?.colors?.border || "#D8D5C5",
  };

  const fonts = {
    primary: theme?.typography?.fontFamily?.primary || "Inter, Arial, sans-serif",
    display: theme?.typography?.fontFamily?.display || "Georgia, serif",
  };

  const radius = {
    md: theme?.borderRadius?.md || "10px",
    lg: theme?.borderRadius?.lg || "16px",
  };

  return (
    <Html>
      <Head />
      <Preview>Conferma invio richiesta - {brandLabel}</Preview>
      <Body style={{ backgroundColor: colors.background, color: colors.background, fontFamily: fonts.primary, padding: "24px" }}>
        <Container style={{ backgroundColor: colors.primary, color: colors.background, border: `1px solid ${colors.border}`, borderRadius: radius.lg, padding: "24px" }}>
          <Section>
            {logoUrl ? <Img src={logoUrl} alt={logoAlt || brandLabel} height="44" style={{ marginBottom: "8px" }} /> : null}
            <Text style={{ color: colors.background, fontSize: "18px", fontWeight: 700, margin: "0 0 6px 0" }}>{brandLabel}</Text>
            <Text style={{ color: colors.background, marginTop: "0", marginBottom: "0" }}>{tagline || "Conferma automatica di ricezione"}</Text>
          </Section>

          <Hr style={{ borderColor: colors.border, margin: "20px 0" }} />

          <Heading as="h2" style={{ color: colors.background, margin: "0 0 12px 0", fontSize: "22px", fontFamily: fonts.display }}>
            Richiesta ricevuta
          </Heading>
          <Text style={{ color: colors.background, marginTop: "0", marginBottom: "16px" }}>
            Grazie, abbiamo ricevuto la tua richiesta per {tenantName}. Ti risponderemo il prima possibile.
          </Text>

          <Section style={{ border: `1px solid ${colors.border}`, borderRadius: radius.md, padding: "12px" }}>
            <Text style={{ margin: "0 0 8px 0", color: colors.background, fontWeight: 600 }}>Riepilogo inviato</Text>
            {fields.length === 0 ? (
              <Text style={{ color: colors.background, margin: 0 }}>Nessun dettaglio disponibile.</Text>
            ) : (
              fields.map((field) => (
                <Text key={field.label} style={{ margin: "0 0 8px 0", color: colors.background, fontSize: "14px", wordBreak: "break-word" }}>
                  <strong>{field.label}:</strong> {field.value}
                </Text>
              ))
            )}
          </Section>

          <Hr style={{ borderColor: colors.border, margin: "20px 0 12px 0" }} />
          <Text style={{ color: colors.background, fontSize: "12px", margin: 0 }}>Riferimento richiesta: {correlationId}</Text>
        </Container>
      </Body>
    </Html>
  );
}

export default LeadSenderConfirmationEmail;

END_OF_FILE_CONTENT
echo "Creating src/entry-ssg.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/entry-ssg.tsx"
import { renderToString } from 'react-dom/server';
import { StaticRouter } from 'react-router-dom/server';
import { ConfigProvider, PageRenderer, StudioProvider, resolveRuntimeConfig } from '@olonjs/core/runtime';
import type { JsonPagesConfig, PageConfig, SiteConfig, ThemeConfig } from '@/types';
import { ThemeProvider } from '@/components/ThemeProvider';
import { ComponentRegistry } from '@/lib/ComponentRegistry';
import { SECTION_SCHEMAS } from '@/lib/schemas';
import { menuConfig, pages, refDocuments, siteConfig, themeConfig } from '@/runtime';
import tenantCss from '@/index.css?inline';

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function normalizeSlug(input: string): string {
  return input.trim().toLowerCase().replace(/\\/g, '/').replace(/^\/+|\/+$/g, '');
}

function getSortedSlugs(): string[] {
  return Object.keys(pages).sort((a, b) => a.localeCompare(b));
}

function resolvePage(slug: string): { slug: string; page: PageConfig } {
  const normalized = normalizeSlug(slug);
  if (normalized && pages[normalized]) {
    return { slug: normalized, page: pages[normalized] };
  }

  const slugs = getSortedSlugs();
  if (slugs.length === 0) {
    throw new Error('[SSG_CONFIG_ERROR] No pages found under src/data/pages');
  }

  const home = slugs.find((item) => item === 'home');
  const fallbackSlug = home ?? slugs[0];
  return { slug: fallbackSlug, page: pages[fallbackSlug] };
}

function flattenThemeTokens(
  input: unknown,
  pathSegments: string[] = [],
  out: Array<{ name: string; value: string }> = []
): Array<{ name: string; value: string }> {
  if (typeof input === 'string') {
    const cleaned = input.trim();
    if (cleaned.length > 0 && pathSegments.length > 0) {
      out.push({ name: `--theme-${pathSegments.join('-')}`, value: cleaned });
    }
    return out;
  }

  if (!isRecord(input)) return out;

  const entries = Object.entries(input).sort(([a], [b]) => a.localeCompare(b));
  for (const [key, value] of entries) {
    flattenThemeTokens(value, [...pathSegments, key], out);
  }
  return out;
}

function buildThemeCssFromSot(theme: ThemeConfig): string {
  const root: Record<string, unknown> = isRecord(theme) ? theme : {};
  const tokens = root['tokens'];
  const flattened = flattenThemeTokens(tokens);
  if (flattened.length === 0) return '';
  const serialized = flattened.map((item) => `${item.name}:${item.value}`).join(';');
  return `:root{${serialized}}`;
}

function isRemoteStylesheetHref(value: string): boolean {
  return /^https?:\/\//i.test(value.trim());
}

function extractLeadingRemoteCssImports(cssText: string): { hrefs: string[]; rest: string } {
  const hrefs = new Set<string>();
  const leadingTriviaPattern = /^(?:\s+|\/\*[\s\S]*?\*\/)*/;
  const importPattern =
    /^@import(?:\s+url\(\s*(?:'([^']+)'|"([^"]+)"|([^'")\s][^)]*))\s*\)|\s*(['"])([^'"]+)\4)\s*([^;]*);/i;
  let rest = cssText;

  for (;;) {
    const trivia = rest.match(leadingTriviaPattern);
    if (trivia && trivia[0]) {
      rest = rest.slice(trivia[0].length);
    }

    const match = rest.match(importPattern);
    if (!match) break;

    const href = (match[1] ?? match[2] ?? match[3] ?? match[5] ?? '').trim();
    const trailingDirectives = (match[6] ?? '').trim();
    if (!isRemoteStylesheetHref(href) || trailingDirectives.length > 0) {
      break;
    }

    hrefs.add(href);
    rest = rest.slice(match[0].length);
  }

  return { hrefs: Array.from(hrefs), rest };
}

function resolveTenantId(): string {
  const site: Record<string, unknown> = isRecord(siteConfig) ? siteConfig : {};
  const identityRaw = site['identity'];
  const identity: Record<string, unknown> = isRecord(identityRaw) ? identityRaw : {};
  const titleRaw = typeof identity.title === 'string' ? identity.title : '';
  const title = titleRaw.trim();
  if (title.length > 0) {
    const normalized = title.toLowerCase().replace(/[^a-z0-9-]+/g, '-').replace(/^-+|-+$/g, '');
    if (normalized.length > 0) return normalized;
  }

  const slugs = getSortedSlugs();
  if (slugs.length === 0) {
    throw new Error('[SSG_CONFIG_ERROR] Cannot resolve tenantId without site.identity.title or pages');
  }
  return slugs[0].replace(/\//g, '-');
}

export function render(slug: string): string {
  const resolved = resolvePage(slug);
  const location = resolved.slug === 'home' ? '/' : `/${resolved.slug}`;
  const resolvedRuntime = resolveRuntimeConfig({
    pages,
    siteConfig,
    themeConfig,
    menuConfig,
    refDocuments,
  });
  const resolvedPage = resolvedRuntime.pages[resolved.slug] ?? resolved.page;

  return renderToString(
    <StaticRouter location={location}>
      <ConfigProvider
        config={{
          registry: ComponentRegistry as JsonPagesConfig['registry'],
          schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
          tenantId: resolveTenantId(),
        }}
      >
        <StudioProvider mode="visitor">
          <ThemeProvider>
            <PageRenderer
              pageConfig={resolvedPage}
              siteConfig={resolvedRuntime.siteConfig}
              menuConfig={resolvedRuntime.menuConfig}
            />
          </ThemeProvider>
        </StudioProvider>
      </ConfigProvider>
    </StaticRouter>
  );
}

export function getCss(): string {
  const themeCss = buildThemeCssFromSot(themeConfig);
  const { rest } = extractLeadingRemoteCssImports(tenantCss);
  if (!themeCss) return rest;
  return `${themeCss}\n${rest}`;
}

export function getRemoteStylesheets(): string[] {
  return extractLeadingRemoteCssImports(tenantCss).hrefs;
}

export function getPageMeta(slug: string): { title: string; description: string } {
  const resolved = resolvePage(slug);
  const rawMeta = isRecord((resolved.page as unknown as { meta?: unknown }).meta)
    ? ((resolved.page as unknown as { meta?: Record<string, unknown> }).meta as Record<string, unknown>)
    : {};

  const title = typeof rawMeta.title === 'string' ? rawMeta.title : resolved.slug;
  const description = typeof rawMeta.description === 'string' ? rawMeta.description : '';
  return { title, description };
}

export function getWebMcpBuildState(): {
  pages: Record<string, PageConfig>;
  schemas: JsonPagesConfig['schemas'];
  siteConfig: SiteConfig;
} {
  return {
    pages,
    schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
    siteConfig,
  };
}

END_OF_FILE_CONTENT
# SKIP: src/entry-ssg.tsx:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/fonts.css..."
cat << 'END_OF_FILE_CONTENT' > "src/fonts.css"
@import url('https://fonts.googleapis.com/css2?family=Instrument+Sans:ital,wght@0,400;0,500;0,600;0,700;1,400&family=JetBrains+Mono:wght@400;500&display=swap');

END_OF_FILE_CONTENT
mkdir -p "src/hooks"
echo "Creating src/hooks/useDocumentMeta.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/hooks/useDocumentMeta.ts"
import { useEffect } from 'react';
import type { PageMeta } from '@/types';

export const useDocumentMeta = (meta: PageMeta): void => {
  useEffect(() => {
    // Set document title
    document.title = meta.title;

    // Set or update meta description
    let metaDescription = document.querySelector('meta[name="description"]');
    if (!metaDescription) {
      metaDescription = document.createElement('meta');
      metaDescription.setAttribute('name', 'description');
      document.head.appendChild(metaDescription);
    }
    metaDescription.setAttribute('content', meta.description);
  }, [meta.title, meta.description]);
};





END_OF_FILE_CONTENT
echo "Creating src/index.css..."
cat << 'END_OF_FILE_CONTENT' > "src/index.css"
@import "tailwindcss";

/* ═══════════════════════════════════════════════════════════════
   OLON DESIGN SYSTEM — index.css
   v1.4 · Holon · Labradorite

   Architecture:
   1. :root      — bridge: reads vars injected by @olonjs/core from theme.json
                   SOT lives in src/data/config/theme.json
   2. @theme      — Tailwind v4 bridge: --color-{slug}: var(--{slug})
   3. @layer base — global resets + base element styles
   4. @layer utilities — custom utility classes
═══════════════════════════════════════════════════════════════ */


/* ─────────────────────────────────────────────────────────────
   1. TOKEN BRIDGE
   Reads CSS vars injected by @olonjs/core engine from theme.json.
   engine injects: --theme-colors-{name}, --theme-typography-*,
                   --theme-border-radius-*, --theme-spacing-*
   Aliases: --theme-font-*, --theme-radius-*, --theme-primary etc.
───────────────────────────────────────────────────────────── */
:root {

  /* ── Backgrounds ─────────────────────────────────────────── */
  --background:           var(--theme-colors-background);
  --card:                 var(--theme-colors-card);
  --elevated:             var(--theme-colors-elevated);
  --overlay:              var(--theme-colors-overlay);
  --popover:              var(--theme-colors-popover);
  --popover-foreground:   var(--theme-colors-popover-foreground);

  /* ── Foregrounds ─────────────────────────────────────────── */
  --foreground:           var(--theme-colors-foreground);
  --card-foreground:      var(--theme-colors-card-foreground);
  --muted-foreground:     var(--theme-colors-muted-foreground);
  --placeholder:          var(--theme-colors-placeholder);

  /* ── Brand — Labradorite ramp ────────────────────────────── */
  --primary:              var(--theme-colors-primary);
  --primary-foreground:   var(--theme-colors-primary-foreground);
  --primary-light:        var(--theme-colors-primary-light);
  --primary-dark:         var(--theme-colors-primary-dark);
  --primary-50:           var(--theme-colors-primary-50);
  --primary-100:          var(--theme-colors-primary-100);
  --primary-200:          var(--theme-colors-primary-200);
  --primary-300:          var(--theme-colors-primary-300);
  --primary-400:          var(--theme-colors-primary-400);
  --primary-500:          var(--theme-colors-primary-500);
  --primary-600:          var(--theme-colors-primary-600);
  --primary-700:          var(--theme-colors-primary-700);
  --primary-800:          var(--theme-colors-primary-800);
  --primary-900:          var(--theme-colors-primary-900);

  /* ── Accent ──────────────────────────────────────────────── */
  --accent:               var(--theme-colors-accent);
  --accent-foreground:    var(--theme-colors-accent-foreground);

  /* ── Secondary ───────────────────────────────────────────── */
  --secondary:            var(--theme-colors-secondary);
  --secondary-foreground: var(--theme-colors-secondary-foreground);

  /* ── Muted ───────────────────────────────────────────────── */
  --muted:                var(--theme-colors-muted);

  /* ── Border ──────────────────────────────────────────────── */
  --border:               var(--theme-colors-border);
  --border-strong:        var(--theme-colors-border-strong);

  /* ── Form ────────────────────────────────────────────────── */
  --input:                var(--theme-colors-input);
  --ring:                 var(--theme-colors-ring);

  /* ── Feedback — Destructive ──────────────────────────────── */
  --destructive:              var(--theme-colors-destructive);
  --destructive-foreground:   var(--theme-colors-destructive-foreground);
  --destructive-border:       var(--theme-colors-destructive-border);
  --destructive-ring:         var(--theme-colors-destructive-ring);

  /* ── Feedback — Success ──────────────────────────────────── */
  --success:              var(--theme-colors-success);
  --success-foreground:   var(--theme-colors-success-foreground);
  --success-border:       var(--theme-colors-success-border);
  --success-indicator:    var(--theme-colors-success-indicator);

  /* ── Feedback — Warning ──────────────────────────────────── */
  --warning:              var(--theme-colors-warning);
  --warning-foreground:   var(--theme-colors-warning-foreground);
  --warning-border:       var(--theme-colors-warning-border);

  /* ── Feedback — Info ─────────────────────────────────────── */
  --info:                 var(--theme-colors-info);
  --info-foreground:      var(--theme-colors-info-foreground);
  --info-border:          var(--theme-colors-info-border);

  /* ── Radius (xl/full not aliased by engine, bridge here) ─── */
  --theme-radius-xl:      var(--theme-border-radius-xl);
  --theme-radius-full:    var(--theme-border-radius-full);

  /* ── Typography — scale ──────────────────────────────────── */
  --theme-text-xs:        var(--theme-typography-scale-xs);
  --theme-text-sm:        var(--theme-typography-scale-sm);
  --theme-text-base:      var(--theme-typography-scale-base);
  --theme-text-md:        var(--theme-typography-scale-md);
  --theme-text-lg:        var(--theme-typography-scale-lg);
  --theme-text-xl:        var(--theme-typography-scale-xl);
  --theme-text-2xl:       var(--theme-typography-scale-2xl);
  --theme-text-3xl:       var(--theme-typography-scale-3xl);
  --theme-text-4xl:       var(--theme-typography-scale-4xl);
  --theme-text-5xl:       var(--theme-typography-scale-5xl);
  --theme-text-6xl:       var(--theme-typography-scale-6xl);
  --theme-text-7xl:       var(--theme-typography-scale-7xl);

  /* ── Typography — tracking ───────────────────────────────── */
  --theme-tracking-tight:   var(--theme-typography-tracking-tight);
  --theme-tracking-display: var(--theme-typography-tracking-display);
  --theme-tracking-normal:  var(--theme-typography-tracking-normal);
  --theme-tracking-wide:    var(--theme-typography-tracking-wide);
  --theme-tracking-label:   var(--theme-typography-tracking-label);

  /* ── Typography — wordmark ───────────────────────────────── */
  --wordmark-font:     var(--theme-typography-wordmark-font-family);
  --wordmark-tracking: var(--theme-typography-wordmark-tracking);
  --wordmark-weight:   var(--theme-typography-wordmark-weight);
  --wordmark-width:    var(--theme-typography-wordmark-width);

  /* ── Typography — leading ────────────────────────────────── */
  --theme-leading-none:    var(--theme-typography-leading-none);
  --theme-leading-tight:   var(--theme-typography-leading-tight);
  --theme-leading-snug:    var(--theme-typography-leading-snug);
  --theme-leading-normal:  var(--theme-typography-leading-normal);
  --theme-leading-relaxed: var(--theme-typography-leading-relaxed);

  /* ── Spacing ─────────────────────────────────────────────── */
  --theme-container-max:  var(--theme-spacing-container-max);
  --theme-section-y:      var(--theme-spacing-section-y);
  --theme-header-h:       var(--theme-spacing-header-h);
  --theme-sidebar-w:      var(--theme-spacing-sidebar-w);

  /* ── Z-index ─────────────────────────────────────────────── */
  --z-base:     var(--theme-z-index-base);
  --z-elevated: var(--theme-z-index-elevated);
  --z-dropdown: var(--theme-z-index-dropdown);
  --z-sticky:   var(--theme-z-index-sticky);
  --z-overlay:  var(--theme-z-index-overlay);
  --z-modal:    var(--theme-z-index-modal);
  --z-toast:    var(--theme-z-index-toast);
}


/* ─────────────────────────────────────────────────────────────
   2. @theme — Tailwind v4 TOKEN BRIDGE
   Pattern: --color-{slug}: var(--{slug})
   Every token exposed here becomes a Tailwind utility class.
───────────────────────────────────────────────────────────── */
@theme {

  /* Colors — Backgrounds */
  --color-background:              var(--background);
  --color-card:                    var(--card);
  --color-elevated:                var(--elevated);
  --color-overlay:                 var(--overlay);
  --color-popover:                 var(--popover);
  --color-popover-foreground:      var(--popover-foreground);

  /* Colors — Foregrounds */
  --color-foreground:              var(--foreground);
  --color-card-foreground:         var(--card-foreground);
  --color-muted-foreground:        var(--muted-foreground);
  --color-placeholder:             var(--placeholder);

  /* Colors — Brand ramp */
  --color-primary:                 var(--primary);
  --color-primary-foreground:      var(--primary-foreground);
  --color-primary-light:           var(--primary-light);
  --color-primary-dark:            var(--primary-dark);
  --color-primary-50:              var(--primary-50);
  --color-primary-100:             var(--primary-100);
  --color-primary-200:             var(--primary-200);
  --color-primary-300:             var(--primary-300);
  --color-primary-400:             var(--primary-400);
  --color-primary-500:             var(--primary-500);
  --color-primary-600:             var(--primary-600);
  --color-primary-700:             var(--primary-700);
  --color-primary-800:             var(--primary-800);
  --color-primary-900:             var(--primary-900);

  /* Colors — Accent */
  --color-accent:                  var(--accent);
  --color-accent-foreground:       var(--accent-foreground);

  /* Colors — Secondary */
  --color-secondary:               var(--secondary);
  --color-secondary-foreground:    var(--secondary-foreground);

  /* Colors — Muted */
  --color-muted:                   var(--muted);

  /* Colors — Border */
  --color-border:                  var(--border);
  --color-border-strong:           var(--border-strong);

  /* Colors — Form */
  --color-input:                   var(--input);
  --color-ring:                    var(--ring);

  /* Colors — Feedback */
  --color-destructive:             var(--destructive);
  --color-destructive-foreground:  var(--destructive-foreground);
  --color-destructive-border:      var(--destructive-border);
  --color-destructive-ring:        var(--destructive-ring);
  --color-success:                 var(--success);
  --color-success-foreground:      var(--success-foreground);
  --color-success-border:          var(--success-border);
  --color-success-indicator:       var(--success-indicator);
  --color-warning:                 var(--warning);
  --color-warning-foreground:      var(--warning-foreground);
  --color-warning-border:          var(--warning-border);
  --color-info:                    var(--info);
  --color-info-foreground:         var(--info-foreground);
  --color-info-border:             var(--info-border);

  /* Radius */
  --radius-xl:                     var(--theme-radius-xl);
  --radius-lg:                     var(--theme-radius-lg);
  --radius-md:                     var(--theme-radius-md);
  --radius-sm:                     var(--theme-radius-sm);
  --radius-full:                   var(--theme-radius-full);

  /* Fonts */
  --font-primary:                  var(--theme-font-primary);
  --font-mono:                     var(--theme-font-mono);
  --font-display:                  var(--theme-font-display);

  /* Text scale */
  --text-xs:                       var(--theme-text-xs);
  --text-sm:                       var(--theme-text-sm);
  --text-base:                     var(--theme-text-base);
  --text-md:                       var(--theme-text-md);
  --text-lg:                       var(--theme-text-lg);
  --text-xl:                       var(--theme-text-xl);
  --text-2xl:                      var(--theme-text-2xl);
  --text-3xl:                      var(--theme-text-3xl);
  --text-4xl:                      var(--theme-text-4xl);
  --text-5xl:                      var(--theme-text-5xl);
  --text-6xl:                      var(--theme-text-6xl);
  --text-7xl:                      var(--theme-text-7xl);

  /* Line heights */
  --leading-none:                  var(--theme-leading-none);
  --leading-tight:                 var(--theme-leading-tight);
  --leading-snug:                  var(--theme-leading-snug);
  --leading-normal:                var(--theme-leading-normal);
  --leading-relaxed:               var(--theme-leading-relaxed);

  /* Tracking */
  --tracking-tight:                var(--theme-tracking-tight);
  --tracking-display:              var(--theme-tracking-display);
  --tracking-normal:               var(--theme-tracking-normal);
  --tracking-wide:                 var(--theme-tracking-wide);
  --tracking-label:                var(--theme-tracking-label);
}


/* ─────────────────────────────────────────────────────────────
   3. BASE LAYER
───────────────────────────────────────────────────────────── */
@layer base {
  *, *::before, *::after {
    box-sizing: border-box;
  }

  html {
    scroll-behavior: smooth;
    text-size-adjust: 100%;
  }

  body {
    background-color: var(--background);
    color: var(--foreground);
    font-family: var(--theme-font-primary);
    font-size: var(--theme-text-base);
    line-height: var(--theme-leading-normal);
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }

  h1, h2, h3, h4, h5, h6 {
    font-family: var(--theme-font-primary);
    font-weight: 500;
    line-height: var(--theme-leading-tight);
    color: var(--foreground);
  }

  h1 {
    font-size: var(--theme-text-5xl);
  }
  h2 {
    font-size: var(--theme-text-4xl);
  }
  h3 {
    font-size: var(--theme-text-3xl);
  }
  h4 {
    font-size: var(--theme-text-2xl);
  }
  h5 {
    font-size: var(--theme-text-xl);
  }
  h6 {
    font-size: var(--theme-text-lg);
  }

  @media (min-width: 768px) {
    h1 { font-size: var(--theme-text-6xl); }
    h2 { font-size: var(--theme-text-5xl); }
    h3 { font-size: var(--theme-text-4xl); }
    h4 { font-size: var(--theme-text-3xl); }
    h5 { font-size: var(--theme-text-2xl); }
    h6 { font-size: var(--theme-text-xl);  }
  }

  @media (min-width: 1024px) {
    h1 { font-size: var(--theme-text-7xl); }
    h2 { font-size: var(--theme-text-6xl); }
    h3 { font-size: var(--theme-text-5xl); }
    h4 { font-size: var(--theme-text-4xl); }
    h5 { font-size: var(--theme-text-3xl); }
    h6 { font-size: var(--theme-text-2xl); }
  }

  p {
    line-height: var(--theme-leading-normal);
  }

  code, pre, kbd, samp {
    font-family: var(--theme-font-mono);
  }

  a {
    color: inherit;
    text-decoration: none;
  }

  button {
    cursor: pointer;
  }

  input, textarea, select {
    font-family: var(--theme-font-primary);
    font-size: var(--theme-text-sm);
  }

  ::selection {
    background-color: var(--primary);
    color: var(--primary-foreground);
  }

  /* Scrollbar */
  ::-webkit-scrollbar           { width: 4px; height: 4px; }
  ::-webkit-scrollbar-track     { background: var(--background); }
  ::-webkit-scrollbar-thumb     { background: var(--border); border-radius: 2px; }
  ::-webkit-scrollbar-thumb:hover { background: var(--border-strong); }
}


/* ─────────────────────────────────────────────────────────────
   4. UTILITIES LAYER
───────────────────────────────────────────────────────────── */
@layer utilities {

  /* ── Typography helpers ─────────────────────────────────── */
  .font-display   { font-family: var(--theme-font-display); }
  .font-mono-olon { font-family: var(--theme-font-mono); }

  .tracking-label { letter-spacing: var(--theme-tracking-label); }
  .tracking-display { letter-spacing: var(--theme-tracking-display); }

  /* ── Layout ─────────────────────────────────────────────── */
  .container-olon {
    width: 100%;
    max-width: var(--theme-container-max);
    margin-left: auto;
    margin-right: auto;
    padding-left: 1.5rem;
    padding-right: 1.5rem;
  }

  .section-anchor {
    scroll-margin-top: calc(var(--theme-header-h) + 24px);
  }

  /* TOCC — required overlay visuals for Studio stage */
  [data-section-id] {
    position: relative;
  }

  [data-jp-section-overlay] {
    position: absolute;
    inset: 0;
    pointer-events: none;
    border: 1px dashed transparent;
    background: transparent;
    z-index: 9999;
    transition: border-color 0.15s ease, background-color 0.15s ease;
  }

  [data-section-id]:hover [data-jp-section-overlay] {
    border-color: color-mix(in srgb, var(--primary-light) 75%, transparent);
    background-color: color-mix(in srgb, var(--primary-900) 12%, transparent);
  }

  [data-section-id][data-jp-selected] [data-jp-section-overlay] {
    border-color: var(--primary-light);
    background-color: color-mix(in srgb, var(--primary-900) 20%, transparent);
  }

  [data-jp-section-overlay] > div {
    position: absolute;
    top: 8px;
    left: 8px;
    font-family: var(--theme-font-mono);
    font-size: var(--theme-text-xs);
    letter-spacing: var(--theme-tracking-label);
    text-transform: uppercase;
    color: var(--primary-light);
    background: color-mix(in srgb, var(--background) 82%, transparent);
    border: 1px solid color-mix(in srgb, var(--primary-light) 50%, transparent);
    border-radius: var(--theme-radius-sm);
    padding: 2px 8px;
    opacity: 0;
    transform: translateY(-2px);
    transition: opacity 0.15s ease, transform 0.15s ease;
  }

  [data-section-id]:hover [data-jp-section-overlay] > div,
  [data-section-id][data-jp-selected] [data-jp-section-overlay] > div {
    opacity: 1;
    transform: translateY(0);
  }

  /* ── DS-specific ────────────────────────────────────────── */
  .ds-divider {
    border: none;
    border-top: 0.5px solid var(--border);
    margin: 0;
  }

  .token-label {
    font-family: var(--theme-font-mono);
    font-size: var(--theme-text-xs);
    color: var(--muted-foreground);
  }

  /* ── DS Sidebar nav link ────────────────────────────────── */
  .nav-link {
    display: block;
    font-size: var(--theme-text-sm);
    color: var(--muted-foreground);
    padding: 5px 12px;
    border-radius: var(--theme-radius-sm);
    transition: color 0.15s, background-color 0.15s;
    cursor: pointer;
    text-decoration: none;
  }
  .nav-link:hover {
    color: var(--foreground);
    background-color: var(--elevated);
  }
  .nav-link.active {
    color: var(--primary-light);
    background-color: var(--elevated);
  }

  /* ── Focus ring ─────────────────────────────────────────── */
  .focus-ring {
    outline: none;
    box-shadow: 0 0 0 2px var(--ring);
  }

  /* ── Inline code ────────────────────────────────────────── */
  .code-inline {
    font-family: var(--theme-font-mono);
    font-size: 0.85em;
    background-color: var(--primary-900);
    color: var(--primary-light);
    padding: 1px 6px;
    border-radius: var(--theme-radius-sm);
  }

  /* ── Surface elevations ─────────────────────────────────── */
  .surface-base     { background-color: var(--background); }
  .surface-card     { background-color: var(--card); }
  .surface-elevated { background-color: var(--elevated); }
  .surface-overlay  { background-color: var(--overlay); }

  /* ── Feedback surfaces ──────────────────────────────────── */
  .surface-destructive {
    background-color: var(--destructive);
    color: var(--destructive-foreground);
    border-color: var(--destructive-border);
  }
  .surface-success {
    background-color: var(--success);
    color: var(--success-foreground);
    border-color: var(--success-border);
  }
  .surface-warning {
    background-color: var(--warning);
    color: var(--warning-foreground);
    border-color: var(--warning-border);
  }
  .surface-info {
    background-color: var(--info);
    color: var(--info-foreground);
    border-color: var(--info-border);
  }

  /* ── Syntax highlight roles (code blocks) ───────────────── */
  .syntax-keyword   { color: var(--primary-400); }
  .syntax-string    { color: var(--primary-200); }
  .syntax-property  { color: var(--accent); }
  .syntax-variable  { color: var(--primary-light); }
  .syntax-comment   { color: var(--muted-foreground); }
  .syntax-value     { color: var(--primary-light); }

  /* Hero image blend overlay */
  .hero-media-overlay {
    background:
      linear-gradient(
        to right,
        color-mix(in srgb, var(--background) 100%, transparent) 0%,
        color-mix(in srgb, var(--background) 82%, transparent) 16%,
        color-mix(in srgb, var(--background) 56%, transparent) 34%,
        color-mix(in srgb, var(--background) 22%, transparent) 54%,
        color-mix(in srgb, var(--background) 6%, transparent) 74%,
        color-mix(in srgb, var(--background) 0%, transparent) 100%
      ),
      linear-gradient(
        to top,
        color-mix(in srgb, var(--background) 24%, transparent) 0%,
        color-mix(in srgb, var(--background) 8%, transparent) 28%,
        color-mix(in srgb, var(--background) 0%, transparent) 56%
      );
  }

  .hero-media-portrait {
    aspect-ratio: 3 / 4;
    min-height: 26rem;
  }

  @media (min-width: 768px) {
    .hero-media-portrait {
      min-height: 34rem;
    }
  }
}


/* ─────────────────────────────────────────────────────────────
   4b. TIPTAP — visitor markdown (.jp-tiptap-content) + Studio ProseMirror
   Typography, color, radius: :root bridge only (theme.json → engine).
───────────────────────────────────────────────────────────── */

.jp-simple-editor .ProseMirror {
  outline: none;
  word-break: break-word;
}

.jp-tiptap-content,
.jp-simple-editor .ProseMirror {
  color: var(--foreground);
  font-family: var(--theme-font-primary);
  font-size: var(--theme-text-md);
  line-height: var(--theme-leading-relaxed);
}

.jp-tiptap-content > * + *,
.jp-simple-editor .ProseMirror > * + * {
  margin-top: 0.75em;
}

.jp-tiptap-content h1,
.jp-simple-editor .ProseMirror h1 {
  font-family: var(--theme-font-display, var(--theme-font-primary));
  font-size: var(--theme-text-4xl);
  font-weight: 700;
  line-height: var(--theme-leading-tight);
  letter-spacing: var(--theme-tracking-display);
  color: var(--foreground);
  margin-top: 1.25em;
  margin-bottom: 0.25em;
}

@media (min-width: 768px) {
  .jp-tiptap-content h1,
  .jp-simple-editor .ProseMirror h1 {
    font-size: var(--theme-text-5xl);
  }
}

.jp-tiptap-content h2,
.jp-simple-editor .ProseMirror h2 {
  font-family: var(--theme-font-display, var(--theme-font-primary));
  font-size: var(--theme-text-3xl);
  font-weight: 700;
  line-height: var(--theme-leading-tight);
  letter-spacing: var(--theme-tracking-tight);
  color: var(--foreground);
  margin-top: 1.25em;
  margin-bottom: 0.25em;
}

.jp-tiptap-content h3,
.jp-simple-editor .ProseMirror h3 {
  font-size: var(--theme-text-2xl);
  font-weight: 600;
  line-height: var(--theme-leading-snug);
  color: var(--foreground);
  margin-top: 1.25em;
  margin-bottom: 0.25em;
}

.jp-tiptap-content h4,
.jp-simple-editor .ProseMirror h4 {
  font-size: var(--theme-text-xl);
  font-weight: 600;
  line-height: var(--theme-leading-snug);
  color: var(--foreground);
  margin-top: 1em;
  margin-bottom: 0.25em;
}

.jp-tiptap-content h5,
.jp-simple-editor .ProseMirror h5 {
  font-size: var(--theme-text-lg);
  font-weight: 600;
  line-height: var(--theme-leading-snug);
  color: var(--foreground);
  margin-top: 1em;
  margin-bottom: 0.25em;
}

.jp-tiptap-content h6,
.jp-simple-editor .ProseMirror h6 {
  font-size: var(--theme-text-md);
  font-weight: 600;
  line-height: var(--theme-leading-normal);
  letter-spacing: var(--theme-tracking-wide);
  color: var(--muted-foreground);
  margin-top: 1em;
  margin-bottom: 0.25em;
}

.jp-tiptap-content p,
.jp-simple-editor .ProseMirror p {
  line-height: var(--theme-leading-relaxed);
}

.jp-tiptap-content strong,
.jp-simple-editor .ProseMirror strong {
  font-weight: 700;
}

.jp-tiptap-content em,
.jp-simple-editor .ProseMirror em {
  font-style: italic;
}

.jp-tiptap-content s,
.jp-simple-editor .ProseMirror s {
  text-decoration: line-through;
}

.jp-tiptap-content a,
.jp-simple-editor .ProseMirror a {
  color: var(--primary);
  text-decoration: underline;
  text-underline-offset: 2px;
}

.jp-tiptap-content a:hover,
.jp-simple-editor .ProseMirror a:hover {
  opacity: 0.88;
}

.jp-tiptap-content code,
.jp-simple-editor .ProseMirror code {
  font-family: var(--theme-font-mono);
  font-size: var(--theme-text-sm);
  background: color-mix(in srgb, var(--foreground) 10%, transparent);
  border-radius: var(--theme-radius-sm);
  padding: 0.1em 0.35em;
}

.jp-tiptap-content pre,
.jp-simple-editor .ProseMirror pre {
  background: var(--elevated);
  border: 1px solid var(--border);
  border-radius: var(--theme-radius-md);
  padding: 1em 1.25em;
  overflow-x: auto;
  font-size: var(--theme-text-sm);
  line-height: var(--theme-leading-relaxed);
}

.jp-tiptap-content pre code,
.jp-simple-editor .ProseMirror pre code {
  background: none;
  padding: 0;
  font-size: inherit;
}

.jp-tiptap-content ul,
.jp-simple-editor .ProseMirror ul {
  list-style-type: disc;
  padding-left: 1.625em;
}

.jp-tiptap-content ol,
.jp-simple-editor .ProseMirror ol {
  list-style-type: decimal;
  padding-left: 1.625em;
}

.jp-tiptap-content li,
.jp-simple-editor .ProseMirror li {
  line-height: var(--theme-leading-relaxed);
  margin-top: 0.25em;
}

.jp-tiptap-content li + li,
.jp-simple-editor .ProseMirror li + li {
  margin-top: 0.25em;
}

.jp-tiptap-content blockquote,
.jp-simple-editor .ProseMirror blockquote {
  border-left: 3px solid var(--border);
  padding-left: 1em;
  color: var(--muted-foreground);
  font-style: italic;
}

.jp-tiptap-content hr,
.jp-simple-editor .ProseMirror hr {
  border: none;
  border-top: 1px solid var(--border);
  margin: 1.5em 0;
}

.jp-tiptap-content img,
.jp-simple-editor .ProseMirror img {
  max-width: 100%;
  height: auto;
  border-radius: var(--theme-radius-md);
}

.jp-simple-editor .ProseMirror img[data-uploading="true"] {
  opacity: 0.6;
  filter: grayscale(0.25);
  outline: 2px dashed color-mix(in srgb, var(--primary) 70%, transparent);
  outline-offset: 2px;
}

.jp-simple-editor .ProseMirror img[data-upload-error="true"] {
  outline: 2px solid color-mix(in srgb, var(--destructive) 85%, transparent);
  outline-offset: 2px;
}

.jp-simple-editor .ProseMirror p.is-editor-empty:first-child::before {
  content: attr(data-placeholder);
  color: var(--muted-foreground);
  opacity: 0.5;
  pointer-events: none;
  float: left;
  height: 0;
}

/* Tiptap docs — scrollable TOC rail */
.jp-docs-toc-scroll {
  scrollbar-width: thin;
  scrollbar-color: var(--border) transparent;
}

.jp-docs-toc-scroll::-webkit-scrollbar {
  width: 6px;
}

.jp-docs-toc-scroll::-webkit-scrollbar-thumb {
  background: var(--border);
  border-radius: var(--theme-radius-sm);
}

.jp-docs-toc-scroll::-webkit-scrollbar-thumb:hover {
  background: var(--border-strong);
}


/* ─────────────────────────────────────────────────────────────
   5. CLOUD-AI-NATIVE-GRID — ported from platform-frontend
   Classes used by cloud-ai-native-grid component.
───────────────────────────────────────────────────────────── */
.animate-fadeInUp {
  animation: fadeInUp 0.6s ease forwards;
}

.card-hover:hover {
  transform: translateY(-2px);
}

.jp-feature-card {
  border-radius: 1rem;
  border-width: 1px;
  border-style: solid;
  transition: all 0.2s;
  background-color: var(--card);
  border-color: var(--border);
}

@keyframes fadeInUp {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}


/* ─────────────────────────────────────────────────────────────
   6. LIGHT MODE
   Applied when <html data-theme="light">.
   Overrides the bridge vars directly.
   SOT future: move to theme.json when engine supports modes.
───────────────────────────────────────────────────────────── */
[data-theme="light"] {

  /* Backgrounds — warm whites */
  --background:                 var(--theme-modes-light-colors-background);
  --card:                       var(--theme-modes-light-colors-card);
  --elevated:                   var(--theme-modes-light-colors-elevated);
  --overlay:                    var(--theme-modes-light-colors-overlay);
  --popover:                    var(--theme-modes-light-colors-popover);
  --popover-foreground:         var(--theme-modes-light-colors-popover-foreground);

  /* Foregrounds */
  --foreground:                 var(--theme-modes-light-colors-foreground);
  --card-foreground:            var(--theme-modes-light-colors-card-foreground);
  --muted-foreground:           var(--theme-modes-light-colors-muted-foreground);
  --placeholder:                var(--theme-modes-light-colors-placeholder);

  /* Brand — Labradorite (same hues, adjusted for light bg) */
  --primary:                    var(--theme-modes-light-colors-primary);
  --primary-foreground:         var(--theme-modes-light-colors-primary-foreground);
  --primary-light:              var(--theme-modes-light-colors-primary-light);
  --primary-dark:               var(--theme-modes-light-colors-primary-dark);
  --primary-50:                 var(--theme-modes-light-colors-primary-50);
  --primary-100:                var(--theme-modes-light-colors-primary-100);
  --primary-200:                var(--theme-modes-light-colors-primary-200);
  --primary-300:                var(--theme-modes-light-colors-primary-300);
  --primary-400:                var(--theme-modes-light-colors-primary-400);
  --primary-500:                var(--theme-modes-light-colors-primary-500);
  --primary-600:                var(--theme-modes-light-colors-primary-600);
  --primary-700:                var(--theme-modes-light-colors-primary-700);
  --primary-800:                var(--theme-modes-light-colors-primary-800);
  --primary-900:                var(--theme-modes-light-colors-primary-900);

  /* Accent — Parchment darker for light bg contrast */
  --accent:                     var(--theme-modes-light-colors-accent);
  --accent-foreground:          var(--theme-modes-light-colors-accent-foreground);

  /* Secondary */
  --secondary:                  var(--theme-modes-light-colors-secondary);
  --secondary-foreground:       var(--theme-modes-light-colors-secondary-foreground);

  /* Muted */
  --muted:                      var(--theme-modes-light-colors-muted);

  /* Border */
  --border:                     var(--theme-modes-light-colors-border);
  --border-strong:              var(--theme-modes-light-colors-border-strong);

  /* Form */
  --input:                      var(--theme-modes-light-colors-input);
  --ring:                       var(--theme-modes-light-colors-ring);

  /* Feedback */
  --destructive:                var(--theme-modes-light-colors-destructive);
  --destructive-foreground:     var(--theme-modes-light-colors-destructive-foreground);
  --destructive-border:         var(--theme-modes-light-colors-destructive-border);
  --destructive-ring:           var(--theme-modes-light-colors-destructive-ring);
  --success:                    var(--theme-modes-light-colors-success);
  --success-foreground:         var(--theme-modes-light-colors-success-foreground);
  --success-border:             var(--theme-modes-light-colors-success-border);
  --success-indicator:          var(--theme-modes-light-colors-success-indicator);
  --warning:                    var(--theme-modes-light-colors-warning);
  --warning-foreground:         var(--theme-modes-light-colors-warning-foreground);
  --warning-border:             var(--theme-modes-light-colors-warning-border);
  --info:                       var(--theme-modes-light-colors-info);
  --info-foreground:            var(--theme-modes-light-colors-info-foreground);
  --info-border:                var(--theme-modes-light-colors-info-border);
}

END_OF_FILE_CONTENT
mkdir -p "src/lib"
echo "Creating src/lib/ComponentRegistry.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/ComponentRegistry.tsx"
import type { SectionType } from '@/types';
import type { SectionComponentPropsMap } from '@/types';
import { EmptyTenantView } from '@/components/empty-tenant';
import { FormDemoView } from '@/components/form-demo';

export const ComponentRegistry: {
  [K in SectionType]: React.FC<SectionComponentPropsMap[K]>;
} = {
  'empty-tenant': EmptyTenantView as React.FC<SectionComponentPropsMap['empty-tenant']>,
  'form-demo': FormDemoView as React.FC<SectionComponentPropsMap['form-demo']>,
};

END_OF_FILE_CONTENT
echo "Creating src/lib/IconResolver.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/IconResolver.tsx"
import React from 'react';
import {
  Layers,
  Github,
  ArrowRight,
  Box,
  Terminal,
  ChevronRight,
  Menu,
  X,
  Sparkles,
  Zap,
  Mail,
  type LucideIcon
} from 'lucide-react';

export const iconMap = {
  'layers': Layers,
  'github': Github,
  'arrow-right': ArrowRight,
  'box': Box,
  'terminal': Terminal,
  'chevron-right': ChevronRight,
  'menu': Menu,
  'x': X,
  'sparkles': Sparkles,
  'zap': Zap,
  'mail': Mail,
} as const satisfies Record<string, LucideIcon>;

export type IconName = keyof typeof iconMap;

export function isIconName(s: string): s is IconName {
  return s in iconMap;
}

interface IconProps {
  name: string;
  size?: number;
  className?: string;
}

export const Icon: React.FC<IconProps> = ({ name, size = 20, className }) => {
  const IconComponent = isIconName(name) ? iconMap[name] : undefined;

  if (!IconComponent) {
    if (import.meta.env.DEV) {
      console.warn(`[IconResolver] Unknown icon: "${name}". Add it to iconMap.`);
    }
    return null;
  }

  return <IconComponent size={size} className={className} />;
};



END_OF_FILE_CONTENT
echo "Creating src/lib/addSectionConfig.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/addSectionConfig.ts"
import type { AddSectionConfig } from '@olonjs/core/runtime';

const addableSectionTypes = ['empty-tenant', 'form-demo'] as const;

const sectionTypeLabels: Record<string, string> = {
  'empty-tenant': 'Empty Tenant',
  'form-demo': 'Form Demo',
};

function getDefaultSectionData(type: string): Record<string, unknown> {
  switch (type) {
    case 'empty-tenant':
      return {
        title: 'Your tenant is empty.',
        description: 'Create your first page to start building your site.',
      };
    case 'form-demo':
      return {
        title: 'Contattaci',
        description: 'Compila il modulo e ti risponderemo al più presto.',
        recipientEmail: '',
        submitLabel: 'Invia',
        successMessage: 'Richiesta inviata con successo.',
      };
    default:
      return {};
  }
}

export const addSectionConfig: AddSectionConfig = {
  addableSectionTypes: [...addableSectionTypes],
  sectionTypeLabels,
  getDefaultSectionData,
};

END_OF_FILE_CONTENT
echo "Creating src/lib/draftStorage.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/draftStorage.ts"
/**
 * Tenant initial data — file-backed only (no localStorage).
 */

import type { PageConfig, SiteConfig } from '@/types';

export interface HydratedData {
  pages: Record<string, PageConfig>;
  siteConfig: SiteConfig;
}

/**
 * Return pages and siteConfig from file-backed data only.
 */
export function getHydratedData(
  _tenantId: string,
  filePages: Record<string, PageConfig>,
  fileSiteConfig: SiteConfig
): HydratedData {
  return {
    pages: { ...filePages },
    siteConfig: fileSiteConfig,
  };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/getFilePages.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/getFilePages.ts"
/**
 * Page registry loaded from nested JSON files under src/data/pages.
 * Add a JSON file in that directory tree to register a page; no manual list in App.tsx.
 */
import type { PageConfig } from '@/types';

function slugFromPath(filePath: string): string {
  const normalizedPath = filePath.replace(/\\/g, '/');
  const match = normalizedPath.match(/\/data\/pages\/(.+)\.json$/i);
  const rawSlug = match?.[1] ?? normalizedPath.split('/').pop()?.replace(/\.json$/i, '') ?? '';
  const canonical = rawSlug
    .split('/')
    .map((segment) => segment.trim())
    .filter(Boolean)
    .join('/');
  return canonical || 'home';
}

export function getFilePages(): Record<string, PageConfig> {
  const glob = import.meta.glob<{ default: unknown }>('@/data/pages/**/*.json', { eager: true });
  const bySlug = new Map<string, PageConfig>();
  const entries = Object.entries(glob).sort(([a], [b]) => a.localeCompare(b));
  for (const [path, mod] of entries) {
    const slug = slugFromPath(path);
    const raw = mod?.default;
    if (raw == null || typeof raw !== 'object') {
      console.warn(`[tenant-alpha:getFilePages] Ignoring invalid page module at "${path}".`);
      continue;
    }
    if (bySlug.has(slug)) {
      console.warn(`[tenant-alpha:getFilePages] Duplicate slug "${slug}" at "${path}". Keeping latest match.`);
    }
    bySlug.set(slug, raw as PageConfig);
  }
  const slugs = Array.from(bySlug.keys()).sort((a, b) =>
    a === 'home' ? -1 : b === 'home' ? 1 : a.localeCompare(b)
  );
  const record: Record<string, PageConfig> = {};
  for (const slug of slugs) {
    const config = bySlug.get(slug);
    if (config) record[slug] = config;
  }
  return record;
}

END_OF_FILE_CONTENT
echo "Creating src/lib/schemas.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/schemas.ts"
import { EmptyTenantSchema } from '@/components/empty-tenant';
import { FormDemoSchema, FormDemoSubmissionSchema } from '@/components/form-demo';

export const SECTION_SCHEMAS = {
  'empty-tenant': EmptyTenantSchema,
  'form-demo': FormDemoSchema,
} as const;

/**
 * Registry of per-section-type submission schemas. Keys MUST match a key of
 * SECTION_SCHEMAS. A section type appearing here is declaring itself as
 * MCP-submittable: the Zod schema describes the payload accepted by the form.
 *
 * See ADR-0002 (docs/decisions/ADR-0002-form-submission-schemas.md).
 */
export const SECTION_SUBMISSION_SCHEMAS = {
  'form-demo': FormDemoSubmissionSchema,
} as const;

export type SectionType = keyof typeof SECTION_SCHEMAS;

export {
  BaseSectionData,
  BaseArrayItem,
  BaseSectionSettingsSchema,
  CtaSchema,
  ImageSelectionSchema,
} from '@olonjs/core/runtime';

END_OF_FILE_CONTENT
echo "Creating src/lib/useFormSubmit.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/useFormSubmit.ts"
import { useState, useCallback } from 'react';

export type SubmitStatus = 'idle' | 'submitting' | 'success' | 'error';

interface UseFormSubmitOptions {
  source: string;
  tenantId: string;
}

export function useFormSubmit({ source, tenantId }: UseFormSubmitOptions) {
  const [status, setStatus] = useState<SubmitStatus>('idle');
  const [message, setMessage] = useState<string>('');

  const submit = useCallback(async (
    formData: FormData, 
    recipientEmail: string, 
    pageSlug: string, 
    sectionId: string
  ) => {
    const cloudApiUrl = import.meta.env.VITE_JSONPAGES_CLOUD_URL as string | undefined;
    const cloudApiKey = import.meta.env.VITE_JSONPAGES_API_KEY as string | undefined;

    if (!cloudApiUrl || !cloudApiKey) {
      setStatus('error');
      setMessage('Configurazione API non disponibile. Riprova tra poco.');
      return false;
    }

    // Trasformiamo FormData in un oggetto piatto per il payload JSON
    const data: Record<string, any> = {};
    formData.forEach((value, key) => {
      data[key] = String(value).trim();
    });

    const payload = {
      ...data,
      recipientEmail,
      page: pageSlug,
      section: sectionId,
      tenant: tenantId,
      source: source,
      submittedAt: new Date().toISOString(),
    };

    // Idempotency Key per evitare doppi invii accidentali
    const idempotencyKey = `form-${sectionId}-${Date.now()}`;

    setStatus('submitting');
    setMessage('Invio in corso...');

    try {
      const apiBase = cloudApiUrl.replace(/\/$/, '');
      const response = await fetch(`${apiBase}/forms/submit`, {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${cloudApiKey}`,
          'Content-Type': 'application/json',
          'Idempotency-Key': idempotencyKey,
        },
        body: JSON.stringify(payload),
      });

      const body = (await response.json().catch(() => ({}))) as { error?: string; code?: string };

      if (!response.ok) {
        throw new Error(body.error || body.code || `Submit failed (${response.status})`);
      }

      setStatus('success');
      setMessage('Richiesta inviata con successo. Ti risponderemo al più presto.');
      return true;
    } catch (error: unknown) {
      const errorMsg = error instanceof Error ? error.message : 'Invio non riuscito. Riprova tra poco.';
      setStatus('error');
      setMessage(errorMsg);
      return false;
    }
  }, [source, tenantId]);

  const reset = useCallback(() => {
    setStatus('idle');
    setMessage('');
  }, []);

  return { submit, status, message, reset };
}
END_OF_FILE_CONTENT
echo "Creating src/lib/useOlonForms.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/useOlonForms.ts"
import { useCallback, useEffect, useState } from 'react';
import type { FormState } from '@olonjs/core/runtime';

const API_BASE =
  (import.meta.env.VITE_OLONJS_CLOUD_URL as string | undefined) ??
  (import.meta.env.VITE_JSONPAGES_CLOUD_URL as string | undefined);

const API_KEY =
  (import.meta.env.VITE_OLONJS_API_KEY as string | undefined) ??
  (import.meta.env.VITE_JSONPAGES_API_KEY as string | undefined);

interface UseOlonFormsOptions {
  /** Override the submit endpoint. Defaults to VITE_OLONJS_CLOUD_URL/forms/submit */
  endpoint?: string;
}

/**
 * Mount once in App.tsx. Scans the DOM for all <form data-olon-recipient="...">
 * elements and attaches submit handlers. Returns per-form states to be provided
 * via OlonFormsContext.Provider.
 *
 * Views consume state via useFormState(formId) — no direct coupling to this hook.
 */
export function useOlonForms(options?: UseOlonFormsOptions): { states: Record<string, FormState> } {
  const [states, setStates] = useState<Record<string, FormState>>({});

  const setFormState = useCallback((formId: string, state: FormState) => {
    setStates((prev) => ({ ...prev, [formId]: state }));
  }, []);

  useEffect(() => {
    const resolvedBase = options?.endpoint
      ? options.endpoint.replace(/\/$/, '')
      : API_BASE
        ? API_BASE.replace(/\/$/, '')
        : null;

    if (!resolvedBase || !API_KEY) {
      console.warn('[useOlonForms] Missing API endpoint or key — forms will not submit.');
      return;
    }

    const endpoint = resolvedBase.endsWith('/forms/submit')
      ? resolvedBase
      : `${resolvedBase}/forms/submit`;

    const forms = Array.from(
      document.querySelectorAll<HTMLFormElement>('form[data-olon-recipient]')
    );

    const controllers: AbortController[] = [];

    async function handleSubmit(form: HTMLFormElement, event: SubmitEvent) {
      event.preventDefault();

      const formId = form.id || form.dataset.olonRecipient || 'olon-form';
      const recipientEmail = form.dataset.olonRecipient ?? '';

      setFormState(formId, { status: 'submitting', message: 'Invio in corso...' });

      const raw: Record<string, string> = {};
      new FormData(form).forEach((value, key) => {
        raw[key] = String(value).trim();
      });

      const payload = {
        ...raw,
        recipientEmail,
        page: window.location.pathname,
        source: 'olon-form',
        submittedAt: new Date().toISOString(),
      };

      const controller = new AbortController();
      controllers.push(controller);

      try {
        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${API_KEY}`,
            'Content-Type': 'application/json',
            'Idempotency-Key': `form-${formId}-${Date.now()}`,
          },
          body: JSON.stringify(payload),
          signal: controller.signal,
        });

        const body = (await response.json().catch(() => ({}))) as {
          error?: string;
          code?: string;
        };

        if (!response.ok) {
          throw new Error(body.error ?? body.code ?? `Submit failed (${response.status})`);
        }

        setFormState(formId, {
          status: 'success',
          message: 'Richiesta inviata con successo.',
        });
        form.reset();
      } catch (error: unknown) {
        if (error instanceof Error && error.name === 'AbortError') return;
        const message =
          error instanceof Error ? error.message : 'Invio non riuscito. Riprova.';
        setFormState(formId, { status: 'error', message });
      }
    }

    type Listener = { form: HTMLFormElement; handler: (e: Event) => void };
    const listeners: Listener[] = [];

    forms.forEach((form) => {
      const handler = (e: Event) => void handleSubmit(form, e as SubmitEvent);
      form.addEventListener('submit', handler);
      listeners.push({ form, handler });
    });

    return () => {
      controllers.forEach((c) => c.abort());
      listeners.forEach(({ form, handler }) => form.removeEventListener('submit', handler));
    };
  }, [options?.endpoint, setFormState]);

  return { states };
}

END_OF_FILE_CONTENT
echo "Creating src/lib/utils.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/lib/utils.ts"
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

END_OF_FILE_CONTENT
# SKIP: src/lib/utils.ts:Zone.Identifier is binary and cannot be embedded as text.
echo "Creating src/main.tsx..."
cat << 'END_OF_FILE_CONTENT' > "src/main.tsx"
import '@/types'; // TBP: load type augmentation from capsule-driven types
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
// ... resto del file

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);




END_OF_FILE_CONTENT
echo "Creating src/runtime.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/runtime.ts"
import type { JsonPagesConfig, MenuConfig, PageConfig, SiteConfig, ThemeConfig } from '@/types';
import { SECTION_SCHEMAS, SECTION_SUBMISSION_SCHEMAS } from '@/lib/schemas';
import { getFilePages } from '@/lib/getFilePages';
import siteData from '@/data/config/site.json';
import menuData from '@/data/config/menu.json';
import themeData from '@/data/config/theme.json';

export const siteConfig = siteData as unknown as SiteConfig;
export const themeConfig = themeData as unknown as ThemeConfig;
export const menuConfig = menuData as unknown as MenuConfig;
export const pages = getFilePages();
export const refDocuments = {
  'menu.json': menuConfig,
  'config/menu.json': menuConfig,
  'src/data/config/menu.json': menuConfig,
} satisfies NonNullable<JsonPagesConfig['refDocuments']>;

export function getWebMcpBuildState(): {
  pages: Record<string, PageConfig>;
  schemas: JsonPagesConfig['schemas'];
  submissionSchemas: JsonPagesConfig['submissionSchemas'];
  siteConfig: SiteConfig;
} {
  return {
    pages,
    schemas: SECTION_SCHEMAS as unknown as JsonPagesConfig['schemas'],
    submissionSchemas: SECTION_SUBMISSION_SCHEMAS as unknown as JsonPagesConfig['submissionSchemas'],
    siteConfig,
  };
}

END_OF_FILE_CONTENT
echo "Creating src/types.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/types.ts"
import type { EmptyTenantData, EmptyTenantSettings } from '@/components/empty-tenant';
import type { FormDemoData, FormDemoSettings } from '@/components/form-demo';

export type SectionComponentPropsMap = {
  'empty-tenant': { data: EmptyTenantData; settings?: EmptyTenantSettings };
  'form-demo': { data: FormDemoData; settings?: FormDemoSettings };
};

// MTRP module augmentation. TypeScript treats `@olonjs/core` and
// `@olonjs/core/runtime` as separate module identifiers (different
// import specifiers). After ADR-0009 the tenant imports JsonPagesConfig
// from `/runtime` for the visitor path, so the section registries must
// be augmented for *both* identifiers, otherwise PageConfig.sections
// resolves to a generic FallbackSection on the runtime side.
declare module '@olonjs/core' {
  export interface SectionDataRegistry {
    'empty-tenant': EmptyTenantData;
    'form-demo': FormDemoData;
  }
  export interface SectionSettingsRegistry {
    'empty-tenant': EmptyTenantSettings;
    'form-demo': FormDemoSettings;
  }
}

declare module '@olonjs/core/runtime' {
  export interface SectionDataRegistry {
    'empty-tenant': EmptyTenantData;
    'form-demo': FormDemoData;
  }
  export interface SectionSettingsRegistry {
    'empty-tenant': EmptyTenantSettings;
    'form-demo': FormDemoSettings;
  }
}

// ADR-0009 D7: tenant types re-export from the runtime subpath, NOT the
// full @olonjs/core. This is a value re-export — even though every
// consumer in this codebase only does `import type`, Vite's static
// graph treats `export *` as a runtime dependency edge. Pointing it at
// '@olonjs/core' would pull the full Studio bundle (AdminSidebar,
// FormFactory, StudioStage, admin-skin) into the visitor main chunk.
// Pointing it at '@olonjs/core/runtime' anchors the graph to the
// runtime-only bundle (~28 KB gz) so the visitor entry stays clean.
export * from '@olonjs/core/runtime';

END_OF_FILE_CONTENT
echo "Creating src/vite-env.d.ts..."
cat << 'END_OF_FILE_CONTENT' > "src/vite-env.d.ts"
/// <reference types="vite/client" />

declare module '*?inline' {
  const content: string;
  export default content;
}



END_OF_FILE_CONTENT
echo "Creating tsconfig.json..."
cat << 'END_OF_FILE_CONTENT' > "tsconfig.json"
{
  "compilerOptions": {
    "target": "ES2022",
    "useDefineForClassFields": true,
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "esModuleInterop": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"],
  "exclude": ["src/emails"],
  "references": [{ "path": "./tsconfig.node.json" }]
}

END_OF_FILE_CONTENT
echo "Creating tsconfig.node.json..."
cat << 'END_OF_FILE_CONTENT' > "tsconfig.node.json"
{
  "compilerOptions": {
    "composite": true,
    "skipLibCheck": true,
    "module": "ESNext",
    "moduleResolution": "bundler",
    "allowSyntheticDefaultImports": true,
    "strict": true
  },
  "include": ["vite.config.ts"]
}




END_OF_FILE_CONTENT
echo "Creating vercel.json..."
cat << 'END_OF_FILE_CONTENT' > "vercel.json"
{
    "rewrites":  [
                     {
                         "source":  "/:pagePath*.json",
                         "destination":  "/pages/:pagePath*.json"
                     },
                     {
                         "source":  "/(.*)",
                         "destination":  "/index.html"
                     }
                 ],
    "headers":  [
                    {
                        "source":  "/assets/(.*)",
                        "headers":  [
                                        {
                                            "key":  "Cache-Control",
                                            "value":  "public, max-age=31536000, immutable"
                                        }
                                    ]
                    }
                ]
}

END_OF_FILE_CONTENT
echo "Creating vite.config.ts..."
cat << 'END_OF_FILE_CONTENT' > "vite.config.ts"
/**
 * Generated by @jsonpages/cli. Dev server API: /api/save-to-file, /api/upload-asset, /api/list-assets.
 */
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const ASSETS_IMAGES_DIR = path.resolve(__dirname, 'public', 'assets', 'images');
const DATA_CONFIG_DIR = path.resolve(__dirname, 'src', 'data', 'config');
const DATA_PAGES_DIR = path.resolve(__dirname, 'src', 'data', 'pages');
const IMAGE_EXT = new Set(['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg', '.avif']);
const IMAGE_MIMES = new Set([
  'image/jpeg', 'image/png', 'image/webp', 'image/gif', 'image/svg+xml', 'image/avif',
]);
const MAX_FILE_SIZE_BYTES = 5 * 1024 * 1024; // 5MB

function safeFilename(original, mimeType) {
  const base = (original.replace(/\.[^.]+$/, '').replace(/[^a-zA-Z0-9-_]/g, '_').slice(0, 128)) || 'image';
  const ext = original.includes('.') ? path.extname(original).toLowerCase() : (mimeType?.startsWith('image/') ? `.${(mimeType.split('/')[1] || 'png').replace('jpeg', 'jpg')}` : '.png');
  return `${Date.now()}-${base}${IMAGE_EXT.has(ext) ? ext : '.png'}`;
}

function listImagesInDir(dir, urlPrefix) {
  const list = [];
  if (!fs.existsSync(dir)) return list;
  for (const name of fs.readdirSync(dir)) {
    if (IMAGE_EXT.has(path.extname(name).toLowerCase())) list.push({ id: name, url: `${urlPrefix}/${name}`, alt: name, tags: [] });
  }
  return list;
}

function sendJson(res, status, body) {
  res.writeHead(status, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify(body));
}

function sendJsonFile(res, filePath) {
  try {
    const content = fs.readFileSync(filePath, 'utf8');
    res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' });
    res.end(content);
  } catch (e) {
    sendJson(res, 500, { error: e?.message || 'Read failed' });
  }
}

function isTenantPageJsonRequest(req, pathname) {
  if (req.method !== 'GET' || !pathname.endsWith('.json')) return false;
  const viteOrStaticPrefixes = ['/api/', '/assets/', '/src/', '/node_modules/', '/public/', '/@'];
  return !viteOrStaticPrefixes.some((prefix) => pathname.startsWith(prefix));
}

function normalizeManifestSlug(raw) {
  return decodeURIComponent(raw || '')
    .replace(/^\/+|\/+$/g, '')
    .replace(/\\/g, '/')
    .replace(/(\.schema)?\.json$/i, '');
}

async function loadWebMcpBuilders() {
  const moduleUrl = import.meta.resolve('@olonjs/core');
  return import(moduleUrl);
}
export default defineConfig({
  plugins: [
    react(),
    tailwindcss(),
    {
      name: 'upload-asset-api',
      configureServer(server) {
        server.middlewares.use((req, res, next) => {
          const pathname = (req.url || '').split('?')[0];
          const isPageJsonRequest = isTenantPageJsonRequest(req, pathname);

          const handleManifestRequest = async () => {
            const core = await loadWebMcpBuilders();
            const { buildPageContract, buildPageManifest, buildSiteManifest, buildLlmsTxt } = core.webmcp;
            const runtime = await server.ssrLoadModule('/src/runtime.ts');
            const buildState = runtime.getWebMcpBuildState();

            if (req.method === 'GET' && pathname === '/llms.txt') {
              res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
              res.end(buildLlmsTxt({
                pages: buildState.pages,
                schemas: buildState.schemas,
                siteConfig: buildState.siteConfig,
              }));
              return true;
            }

            if (req.method === 'GET' && pathname === '/mcp-manifest.json') {
              sendJson(res, 200, buildSiteManifest({
                pages: buildState.pages,
                schemas: buildState.schemas,
                submissionSchemas: buildState.submissionSchemas,
                siteConfig: buildState.siteConfig,
              }));
              return true;
            }

            const pageManifestMatch = pathname.match(/^\/mcp-manifests\/(.+)\.json$/i);
            if (pageManifestMatch && req.method === 'GET') {
              const slug = normalizeManifestSlug(pageManifestMatch[1]);
              const pageConfig = buildState.pages[slug];
              if (!pageConfig) {
                sendJson(res, 404, { error: 'Page manifest not found' });
                return true;
              }

              sendJson(res, 200, buildPageManifest({
                slug,
                pageConfig,
                schemas: buildState.schemas,
                submissionSchemas: buildState.submissionSchemas,
                siteConfig: buildState.siteConfig,
              }));
              return true;
            }

            const schemaMatch = pathname.match(/^\/schemas\/(.+)\.schema\.json$/i);
            if (schemaMatch && req.method === 'GET') {
              const slug = normalizeManifestSlug(schemaMatch[1]);
              const pageConfig = buildState.pages[slug];
              if (!pageConfig) {
                sendJson(res, 404, { error: 'Schema contract not found' });
                return true;
              }

              sendJson(res, 200, buildPageContract({
                slug,
                pageConfig,
                schemas: buildState.schemas,
                submissionSchemas: buildState.submissionSchemas,
                siteConfig: buildState.siteConfig,
              }));
              return true;
            }
            return false;
          };

          if (
            req.method === 'GET' &&
            (
              pathname === '/mcp-manifest.json'
              || pathname === '/llms.txt'
              || /^\/mcp-manifests\/.+\.json$/i.test(pathname)
              || /^\/schemas\/.+\.schema\.json$/i.test(pathname)
            )
          ) {
            void handleManifestRequest()
              .then((handled) => {
                if (!handled) {
                  // Se handleManifestRequest fallisce a trovare qualcosa ma l'URL era giusto, 
                  // forziamo un 404 JSON per evitare che Vite serva l'index.html
                  sendJson(res, 404, { error: 'Manifest or schema not found' });
                }
              })
              .catch((error) => {
                sendJson(res, 500, { error: error?.message || 'Manifest generation failed' });
              });
            return;
          }

          if (isPageJsonRequest) {
            const normalizedPath = decodeURIComponent(pathname).replace(/\\/g, '/');
            // Rimuoviamo la root folder opzionale "/pages/" introdotta per matchare la prod e il file extension
            const slug = normalizedPath
              .replace(/^\/+/, '')
              .replace(/^pages\//i, '')
              .replace(/\.json$/i, '')
              .replace(/^\/+|\/+$/g, '');
            const candidate = path.resolve(DATA_PAGES_DIR, `${slug}.json`);
            const isInsidePagesDir = candidate.startsWith(`${DATA_PAGES_DIR}${path.sep}`) || candidate === DATA_PAGES_DIR;
            if (!slug || !isInsidePagesDir || !fs.existsSync(candidate) || !fs.statSync(candidate).isFile()) {
              sendJson(res, 404, { error: 'Page JSON not found' });
              return;
            }
            sendJsonFile(res, candidate);
            return;
          }
          if (req.method === 'GET' && req.url === '/api/list-assets') {
            try { sendJson(res, 200, listImagesInDir(ASSETS_IMAGES_DIR, '/assets/images')); } catch (e) { sendJson(res, 500, { error: e?.message || 'List failed' }); }
            return;
          }
          if (req.method === 'POST' && pathname === '/api/save-to-file') {
            const chunks = [];
            req.on('data', (chunk) => chunks.push(chunk));
            req.on('end', () => {
              try {
                const raw = Buffer.concat(chunks).toString('utf8');
                if (!raw.trim()) { sendJson(res, 400, { error: 'Empty body' }); return; }
                const body = JSON.parse(raw);
                const { projectState, slug } = body;
                if (!projectState || typeof slug !== 'string') { sendJson(res, 400, { error: 'Missing projectState or slug' }); return; }
                if (!fs.existsSync(DATA_CONFIG_DIR)) fs.mkdirSync(DATA_CONFIG_DIR, { recursive: true });
                if (!fs.existsSync(DATA_PAGES_DIR)) fs.mkdirSync(DATA_PAGES_DIR, { recursive: true });
                if (projectState.site != null) fs.writeFileSync(path.join(DATA_CONFIG_DIR, 'site.json'), JSON.stringify(projectState.site, null, 2), 'utf8');
                if (projectState.menu != null) fs.writeFileSync(path.join(DATA_CONFIG_DIR, 'menu.json'), JSON.stringify(projectState.menu, null, 2), 'utf8');
                if (projectState.theme != null) fs.writeFileSync(path.join(DATA_CONFIG_DIR, 'theme.json'), JSON.stringify(projectState.theme, null, 2), 'utf8');
                if (projectState.page != null) {
                  const safeSlug = (slug.replace(/[^a-zA-Z0-9-_]/g, '_') || 'page');
                  fs.writeFileSync(path.join(DATA_PAGES_DIR, `${safeSlug}.json`), JSON.stringify(projectState.page, null, 2), 'utf8');
                }
                sendJson(res, 200, { ok: true });
              } catch (e) { sendJson(res, 500, { error: e?.message || 'Save to file failed' }); }
            });
            req.on('error', () => sendJson(res, 500, { error: 'Request error' }));
            return;
          }
          if (req.method !== 'POST' || req.url !== '/api/upload-asset') return next();
          const chunks = [];
          req.on('data', (chunk) => chunks.push(chunk));
          req.on('end', () => {
            try {
              const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
              const { filename, mimeType, data } = body;
              if (!filename || typeof data !== 'string') { sendJson(res, 400, { error: 'Missing filename or data' }); return; }
              const buf = Buffer.from(data, 'base64');
              if (buf.length > MAX_FILE_SIZE_BYTES) { sendJson(res, 413, { error: 'File too large. Max 5MB.' }); return; }
              if (mimeType && !IMAGE_MIMES.has(mimeType)) { sendJson(res, 400, { error: 'Invalid file type' }); return; }
              const name = safeFilename(filename, mimeType);
              if (!fs.existsSync(ASSETS_IMAGES_DIR)) fs.mkdirSync(ASSETS_IMAGES_DIR, { recursive: true });
              fs.writeFileSync(path.join(ASSETS_IMAGES_DIR, name), buf);
              sendJson(res, 200, { url: `/assets/images/${name}` });
            } catch (e) { sendJson(res, 500, { error: e?.message || 'Upload failed' }); }
          });
          req.on('error', () => sendJson(res, 500, { error: 'Request error' }));
        });
      },
    },
  ],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
      'next/link': path.resolve(__dirname, './src/shims/next-link.tsx'),
    },
  },
  server: {
    fs: {
      allow: [
        path.resolve(__dirname, '..', '..'),
      ],
    },
    watch: {
      usePolling: true,
      interval: 300,
    },
  },
});


END_OF_FILE_CONTENT
