# OpenFang Build Fix Tasks

## Current Issues

- Compilation error in openfang-kernel: use of moved value `def`
- Warning: unused mutable variable `hand_registry`

## Tasks

- [x] Analyze the error - identified 2 issues in kernel.rs
- [ ] Fix issue 1: Use `.as_ref()` for def variable (lines 5066-5068)
- [ ] Fix issue 2: Remove unnecessary `mut` from hand_registry (line 710)
- [ ] Verify compilation succeeds
