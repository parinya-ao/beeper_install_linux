# Graph Report - beeper_install_linux_clen  (2026-10-31)

## Corpus Check
- 8 files · ~4,573 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 23 file(s) not represented in the graph (top: .fish 19, (none) 3, .toml 1)

## Summary
- 117 nodes · 114 edges · 18 communities (17 shown, 1 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `df03037c`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- README.md
- Fish Shell Configuration Expert
- Fish Shell Reference
- String Builtin Complete Reference
- Advanced Function Patterns
- Writing Functions
- Advanced Prompt Techniques
- Integration with External Tools
- Performance Tips
- Complete Variable Scope Reference
- Error Handling Patterns
- Test Command Reference
- Functions vs Aliases vs Abbreviations
- Common Tasks
- Control Flow
- Completion System
- Migrating from Bash
- run.sh

## God Nodes (most connected - your core abstractions)
1. `Fish Shell Reference` - 19 edges
2. `Fish Shell Configuration Expert` - 17 edges
3. `String Builtin Complete Reference` - 9 edges
4. `Advanced Function Patterns` - 5 edges
5. `Writing Functions` - 5 edges
6. `Complete Variable Scope Reference` - 4 edges
7. `Test Command Reference` - 4 edges
8. `Error Handling Patterns` - 4 edges
9. `Performance Tips` - 4 edges
10. `Debugging Techniques` - 4 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (18 total, 1 thin omitted)

### Community 0 - "README.md"
Cohesion: 0.18
Nodes (8): Beeper Linux lifecycle design, Safety and recovery, Verification gate, Testing, Troubleshooting, Beeper user-local provisioning, Daily use, Security and recovery

### Community 1 - "Fish Shell Configuration Expert"
Cohesion: 0.09
Nodes (21): Command Substitution, Common Patterns, Configuration File Structure, Core Principles, Debugging, direnv Hook, Event Handlers, Fish Shell Configuration Expert (+13 more)

### Community 2 - "Fish Shell Reference"
Cohesion: 0.10
Nodes (19): Advanced Loops, Available Events, Command Substitution Edge Cases, Custom Bindings, Debugging Techniques, Event System, Fish Shell Reference, Function Tracing (+11 more)

### Community 3 - "String Builtin Complete Reference"
Cohesion: 0.22
Nodes (9): Escape/Unescape, Join/Split, Length, Match/Glob, Replace, String Builtin Complete Reference, Substring, Transform (+1 more)

### Community 4 - "Advanced Function Patterns"
Cohesion: 0.40
Nodes (5): Advanced Function Patterns, Default Arguments, Named Arguments, Optional Flags, Wrapper Functions

### Community 5 - "Writing Functions"
Cohesion: 0.40
Nodes (5): Advanced Example, Basic Structure, Editing Functions Interactively, Function Options, Writing Functions

### Community 6 - "Advanced Prompt Techniques"
Cohesion: 0.50
Nodes (4): Advanced Prompt Techniques, Multi-line Prompt, Right Prompt, Title (Terminal Window Title)

### Community 7 - "Integration with External Tools"
Cohesion: 0.50
Nodes (4): asdf Version Manager, direnv with Nix, fzf Integration, Integration with External Tools

### Community 8 - "Performance Tips"
Cohesion: 0.50
Nodes (4): Avoid Subshells When Possible, Cache Expensive Operations, Performance Tips, Use Builtins Over External Commands

### Community 9 - "Complete Variable Scope Reference"
Cohesion: 0.50
Nodes (4): Complete Variable Scope Reference, Scope Combinations, Variable Manipulation, Variable Queries

### Community 10 - "Error Handling Patterns"
Cohesion: 0.50
Nodes (4): Early Return Pattern, Error Handling Patterns, Error Propagation, Try-Catch Pattern

### Community 11 - "Test Command Reference"
Cohesion: 0.50
Nodes (4): File Tests, Numeric Tests, String Tests, Test Command Reference

### Community 12 - "Functions vs Aliases vs Abbreviations"
Cohesion: 0.50
Nodes (4): Abbreviations (Interactive Only), Aliases (Creates Functions), Functions (Recommended), Functions vs Aliases vs Abbreviations

### Community 13 - "Common Tasks"
Cohesion: 0.50
Nodes (4): Add to PATH, Common Tasks, Conditional Config, Create Wrapper Function

### Community 14 - "Control Flow"
Cohesion: 0.50
Nodes (4): Conditionals, Control Flow, Loops, Switch Statement

### Community 15 - "Completion System"
Cohesion: 0.67
Nodes (3): Basic Completion Definition, Completion System, Dynamic Completions

### Community 16 - "Migrating from Bash"
Cohesion: 0.67
Nodes (3): Common Bash → Fish Translations, Migrating from Bash, No Bash Features in Fish

## Knowledge Gaps
- **1 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Fish Shell Reference` connect `Fish Shell Reference` to `String Builtin Complete Reference`, `Advanced Function Patterns`, `Advanced Prompt Techniques`, `Integration with External Tools`, `Performance Tips`, `Complete Variable Scope Reference`, `Error Handling Patterns`, `Test Command Reference`, `Completion System`?**
  _High betweenness centrality (0.250) - this node is a cross-community bridge._
- **Should `Fish Shell Configuration Expert` be split into smaller, more focused modules?**
  _Cohesion score 0.09090909090909091 - nodes in this community are weakly interconnected._
- **Why does `Fish Shell Configuration Expert` connect `Fish Shell Configuration Expert` to `Writing Functions`, `Functions vs Aliases vs Abbreviations`, `Common Tasks`, `Control Flow`, `Migrating from Bash`?**
  _High betweenness centrality (0.116) - this node is a cross-community bridge._
- **Should `Fish Shell Reference` be split into smaller, more focused modules?**
  _Cohesion score 0.1 - nodes in this community are weakly interconnected._
- **Why does `String Builtin Complete Reference` connect `String Builtin Complete Reference` to `Fish Shell Reference`?**
  _High betweenness centrality (0.067) - this node is a cross-community bridge._