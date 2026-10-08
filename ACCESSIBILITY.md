# Accessibility

This project ships configuration files, a shell script and Markdown documentation. It has no graphical interface of its own.

## Commitment

Everyone who runs a Mailcow server should be able to install, operate and troubleshoot this integration,
including people who use screen readers, braille displays, screen magnifiers or only a keyboard.

## Current state

- **Documentation** is plain Markdown. Headings follow a strict order, tables have header rows, and links name their target.
- **The architecture diagram** in `README.md` is ASCII art. The bullet list below it describes the same flow in text.
- **`crowdsec.sh`** prints plain text without colour codes or animations. Output works with screen readers and in logs.
- **Commands** sit in code blocks, so they can be copied without retyping.

## Supported environments

- Any terminal that shows UTF-8 text, local or over SSH
- GitHub's web view of the Markdown files
- Screen readers on that web view, for example NVDA, JAWS, VoiceOver and Orca

## Known limitations

- The ASCII diagram reads poorly line by line in a screen reader. Use the text description below it.
- `README.md` uses emoji (✅, ⚠️) as markers. Screen readers announce them by name.
- The optional dashboard at [app.crowdsec.net](https://app.crowdsec.net) belongs to CrowdSec. This project cannot change its accessibility.
- The project has not received a formal audit, for example against WCAG 2.2.

## Report a barrier

Open an issue with the **Accessibility barrier** template. Name the file or command, your assistive technology and what blocked you.
