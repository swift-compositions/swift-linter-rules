// swift-linter-tools-version: 0.1
// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// Foundation-up dogfeed continuation (Thread B). swift-linter-rules is
// the universal-rules pack — its own Bundle.universal defines the
// broadest applicable rule set for any package in the ecosystem.
// Self-lint measures against the full institute-layer enforced set,
// reached via the sibling checkout (swift-institute-linter-rules
// depends on this package by `url:`, so a `path: "."` self-pin here
// would put swift-linter-rules in the lint graph twice and close a
// cycle; the sibling path keeps a single, remote-reached copy).

import Linter
import Linter_Institute_Rules

Lint.run(dependencies: [
    .package(
        path: "../swift-institute-linter-rules",
        products: ["Linter Institute Rules"]
    ),
]) {
    Lint.Rule.Bundle.institute
}
