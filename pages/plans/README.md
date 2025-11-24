# Jump-to-Definition Enhancement Plans

This directory contains comprehensive test and implementation plans for enhancing jump-to-definition functionality in the Elixir LSP.

## Overview

Based on research of ElixirLS and Lexical LSP issues, we identified 7 key areas where jump-to-definition can be improved:

## Priority Tiers

### Tier 1: Quick Wins 🚀
High impact, low-to-medium complexity features that should be implemented first.

1. **[Best-Effort Arity Matching](./03-arity-fallback.md)** ⭐⭐⭐
   - **Complexity**: Low-Medium
   - **Impact**: High during refactoring
   - **Effort**: ~7-11 hours
   - Jump to closest arity when exact match fails (e.g., call `func/3` → find `func/2`)

2. **[Multi-Alias Support](./01-multi-alias-support.md)** ⭐⭐⭐
   - **Complexity**: Medium
   - **Impact**: High (common Phoenix pattern)
   - **Effort**: ~7-11 hours
   - Enable `alias Foo.{Bar, Baz}` navigation

### Tier 2: High-Value Features ⭐
Important improvements with clear user benefit.

3. **[Module References in Tuples](./02-module-in-tuples.md)** ⭐⭐
   - **Complexity**: Medium-High
   - **Impact**: High for Phoenix users
   - **Effort**: ~12-16 hours
   - Jump from `plug {MyModule, :func}` to module definition

4. **[Behaviour Callback Jumps](./05-behaviour-jumps.md)** ⭐⭐
   - **Complexity**: Medium
   - **Impact**: Medium (OTP patterns)
   - **Effort**: ~16-20 hours
   - Jump from `@behaviour GenServer` and `@impl` to callbacks

### Tier 3: Nice-to-Have Features 💡
Useful but lower priority enhancements.

5. **[Protocol Implementation Jumps](./04-protocol-jumps.md)** 💡
   - **Complexity**: Medium
   - **Impact**: Medium (protocol-heavy code)
   - **Effort**: ~12-16 hours
   - Jump from `defimpl` and `@impl` to protocol callbacks

6. **[Struct Field Definitions](./06-struct-fields.md)** 💡
   - **Complexity**: High (type tracking needed)
   - **Impact**: Low-Medium
   - **Effort**: MVP: ~12-16 hours, Full: ~40+ hours
   - Jump from `%User{name: ...}` to field definition

7. **[Stdlib Source Navigation](./07-stdlib-jump.md)** 💡
   - **Complexity**: Low-Medium
   - **Impact**: Low (learning/exploration)
   - **Effort**: ~31 hours
   - Jump to Elixir standard library source code

## Document Structure

Each plan document contains:

### Test Plan Section
- **Core Test Cases**: Basic functionality scenarios
- **Edge Cases**: Boundary conditions and error cases
- **Integration Tests**: End-to-end scenarios
- **Test Fixtures**: Required test data files
- **Expected Behaviors**: Clear success criteria

### Implementation Plan Section
- **Problem Analysis**: Root cause and current gaps
- **Solution Overview**: High-level approach
- **Implementation Steps**: Detailed, ordered steps with code locations
- **Code Changes**: Specific functions and modifications
- **Dependencies**: Implementation order and prerequisites
- **Testing Approach**: How to verify each step
- **Risks & Mitigations**: Known challenges and solutions
- **Performance Considerations**: Optimization strategies

## Current Capabilities ✅

The system already supports:
- ✅ Local function calls
- ✅ Remote module calls (aliased)
- ✅ Imported functions
- ✅ Module attributes
- ✅ Variables
- ✅ Delegated functions (`defdelegate`)
- ✅ HEEX component definitions
- ✅ Struct definitions (`%MyStruct{}`)
- ✅ Macros

## Total Estimated Effort

| Tier | Features | Total Hours |
|------|----------|-------------|
| Tier 1 | 2 features | 14-22 hours |
| Tier 2 | 2 features | 28-36 hours |
| Tier 3 | 3 features | 55-103 hours |
| **Total** | **7 features** | **97-161 hours** |

## Implementation Sequence Recommendation

1. **Phase 1** (Weeks 1-2): Arity fallback + Multi-alias
2. **Phase 2** (Weeks 3-4): Module in tuples + Behaviour jumps
3. **Phase 3** (Weeks 5-8): Protocols + Struct fields (MVP) + Stdlib

## Getting Started

To implement a feature:

1. Read the corresponding plan document
2. Review the test plan section first to understand requirements
3. Follow the implementation steps in order
4. Write tests as you go (TDD approach recommended)
5. Run existing tests to ensure no regressions

## Contributing

When adding new plans:
- Follow the existing document structure
- Include both test and implementation plans
- Provide concrete code examples
- Identify risks and edge cases
- Estimate effort in hours

## Questions or Issues?

These plans are living documents. If you find issues or have improvements:
- Update the plan document
- Document any deviations from the plan during implementation
- Add lessons learned section to completed plans
