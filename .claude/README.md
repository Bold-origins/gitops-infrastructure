# Claude Optimization Directory

This directory contains metadata and resources specifically optimized for Claude AI to better understand and work with this repository.

## Directory Structure

- `metadata/` - Normalized information about the codebase
  - `components/` - Component metadata and relationships
  - `dependencies/` - Dependency graphs
  - `classifications/` - File classification metadata
  - `errors/` - Error patterns database
  - `memory_anchors.md` - Memory anchors for key parts of the codebase
  - `codebase_model.md` - Model-friendly documentation of the codebase

- `code_index/` - Pre-analyzed semantic relationships
  - `call_graphs/` - Function calling relationships
  - `types/` - Type definitions and relationships
  - `interfaces/` - Interface implementations
  - `intents/` - Code section intent classifications
  - `codebase_structure.md` - Overview of codebase structure with memory anchors

- `debug_history/` - Debugging sessions with error-solution pairs
  - `sessions/` - Individual debugging sessions
  - `components/` - Component-specific debug history
  - `patterns/` - Common error patterns and solutions
  - `common_errors.md` - Common errors and their solutions

- `patterns/` - Canonical implementation patterns
  - `interfaces/` - Interface implementation patterns
  - `error_handling/` - Error handling patterns
  - `composition/` - Component composition patterns
  - `testing/` - Testing patterns
  - `new_component.md` - Pattern for creating new components
  - `gitops_error_patterns.md` - Error handling patterns for GitOps

- `cheatsheets/` - Quick-reference guides for components
  - `commands.md` - Common commands for the repository
  - `workflows.md` - Common workflows

- `qa/` - Previous solved problems database
  - `components/` - Component-specific Q&A
  - `errors/` - Error-type specific Q&A
  - `workflows/` - Workflow-related Q&A
  - `flux_qa.md` - Q&A about Flux GitOps

- `delta/` - Semantic change logs between versions
  - `api_changes/` - API-specific changes
  - `behavior_changes/` - Behavior changes
  - `reasoning/` - Documentation of reasoning behind changes
  - `recent_changes.md` - Summary of recent changes

## Purpose

This structure helps Claude:
1. Quickly understand the codebase architecture through structured metadata
2. Reference common patterns and solutions in a standardized format
3. Maintain context across sessions with memory anchors
4. Track changes and their implications through delta summaries
5. Provide consistent reasoning and solutions by leveraging pre-analyzed relationships
6. Efficiently troubleshoot issues using the debug history and error patterns
7. Implement solutions following established patterns
8. Understand the intent behind different components

## Usage

When working with Claude on this repository, refer to files in this directory to provide context about:
- Component relationships and dependencies
- Common patterns and workflows
- Error handling strategies
- Code organization and structure
- Recent changes and their implications

The CLAUDE.md file in the repository root provides a high-level overview and commonly used commands.