# Patchwork — Project Documentation

GitHub is the source of truth for this project documentation. Notion indexes this file in the Priyansh App Factory Command Center.

## 00. Executive Summary
Patchwork is a native iOS puzzle/app candidate about assembling smaller pieces into a satisfying whole. It is for mobile puzzle players who enjoy calm visual interactions and completion feedback. The end product should include a clear board mechanic, tutorial, starter levels, progress, and a polished local-first puzzle experience.

## 01. Product
MVP scope: core board/canvas, piece placement, completion detection, tutorial, starter levels or repeatable board mode, and local progress. Acceptance criteria: tutorial teaches the mechanic in under two minutes and early puzzles are solvable.

## 02. Design
Tactile, calm, handcrafted visuals with clear piece states and satisfying placement. Screens: home, puzzle board, piece tray, completion screen, level map, settings.

## 03. Frontend Technical
SwiftUI app with optional SpriteKit/custom canvas if drag mechanics need it. PuzzleSession tracks board state, pieces, placements, moves, completion, undo/reset, and progress.

## 04. Backend Technical
No backend for v1. Future services may include daily puzzles, remote level packs, cloud save, or community puzzles.

## 05. Business
Business model: premium unlock, level packs, themes, and possibly daily puzzle subscription later. Keep v1 local to reduce cost.

## 06. Marketing
Positioning: piece by piece, make the whole picture click. Channels: solve clips, puzzle communities, App Store feature pitch.

## 07. User Acquisition
Beta with puzzle players and cozy-game testers. Metrics: tutorial completion, level completion, D1/D7 retention, pack interest.

## 08. Execution
Plan: audit repo, freeze mechanic, define level schema, build board engine, create starter levels, QA/TestFlight.

## 09. QA
Test all starter levels, invalid placements, completion detection, undo/reset, progress persistence, device sizes, and accessibility.

## 10. Legal / Compliance
No account or backend for v1. Disclose data handling if analytics, purchases, or cloud features are added.

## 11. Operations
Release process: internal level QA, puzzle beta, TestFlight, App Store submission. Post-launch: daily puzzle, themes, level packs.
