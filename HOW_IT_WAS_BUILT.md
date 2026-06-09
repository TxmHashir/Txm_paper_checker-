# VisionQR — How This App Was Built with AI

## Overview

VisionQR is a Flutter mobile application built with AI assistance (Claude Code). It combines a QR/barcode scanner, a QR code generator, and an AI-powered OMR (Optical Mark Recognition) system that can read handwritten student quiz answer sheets, grade them automatically, and export batch reports.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart), targeting Android & iOS |
| AI Vision | Google Gemini 2.5 Flash (`google_generative_ai` package) |
| QR Scanning | `mobile_scanner` v5 |
| QR Generation | `qr_flutter` |
| Persistence | `shared_preferences` (JSON-encoded scan history) |
| Image Handling | `image_picker`, `gal`, `share_plus` |
| Fonts | Google Fonts — Space Grotesk |
| Config | `flutter_dotenv` — API key loaded from `.env` asset |

---

## How It Was Built (Step by Step)

### Step 1 — Project Scaffold
A standard Flutter project was generated (`flutter create my_qr`). The package name is `my_qr` but the app presents itself as **VisionQR** throughout the UI.

### Step 2 — QR Scanner Screen
The scanner screen (`lib/screens/scanner_screen.dart`) was built first. It uses `MobileScannerController` with `autoStart: false` so the camera only activates when that tab is visible. An animated AR-style scanning overlay (blue laser line using `AnimationController` + `sin()`) was added to give the scanner a polished look. Flash toggle and AR toggle buttons sit in the top row.

### Step 3 — QR Generator Screen
`lib/screens/generator_screen.dart` lets a user type any text or URL and renders it as a live `QrImageView`. A "Save to Gallery" button was wired up. The generator was intentionally kept simple — no separate state management, just `setState`.

### Step 4 — Scan History with SharedPreferences
`lib/services/history_database.dart` was written to persist every scan to `SharedPreferences` as a JSON list. Each `ScannedCode` model stores the type (`url`, `wifi`, `contact`, `barcode`, `answer_key`), the raw value, a friendly title, timestamp, and optional student fields for OMR scans.

`lib/screens/history_screen.dart` loads these items and shows them in a `ListView`. Tapping an item re-opens the bottom sheet with the full details. A delete-all button wipes the log after confirmation.

### Step 5 — Answer Key QR Format Design
A plain-text QR payload format was designed so teachers can encode an entire quiz answer key in one QR code:

```
AI Quiz SP2026 Set-C | Part-I: Q1=D Q2=A Q3=B ... | Part-II: Q1=C Q2=D ... | Neg: 0.25 | Marks per: 1
```

`lib/models/answer_key.dart` parses this payload using `split('|')` and regex, extracting the quiz title, set letter, Part-I and Part-II answer maps, marks per correct answer, and optional negative marking penalty. This model is the backbone that connects scanning, grading, and batch processing.

### Step 6 — Gemini AI OMR Service
`lib/services/gemini_omr_service.dart` is where the AI integration lives. When a student's answer sheet image is passed in, it sends both the image bytes and a carefully crafted prompt to **Gemini 2.5 Flash**.

The prompt instructs Gemini to do three things in one call:
1. Read the **printed header** fields (class name, subject)
2. Transcribe the **handwritten student fields** (name, registration number)
3. Read all **16 OMR bubbles** (Part-I Q01–Q08, Part-II Q01–Q08), returning `"A"/"B"/"C"/"D"`, `null` for unattempted, or `"INVALID"` for multi-filled rows

The model is configured with `responseMimeType: 'application/json'` and `temperature: 0.0` so responses are deterministic and always valid JSON — no markdown fences to strip.

The raw JSON is parsed into a `GeminiSheetResult` object. Any stray `"null"`, `"-"`, or empty strings the model might emit are normalized to real Dart `null` so a blank row can never accidentally show as a letter.

### Step 7 — Quiz Grader
`lib/services/quiz_grader.dart` implements `grade_quiz(StudentAnswers, AnswerKey) -> GradeReport`. It iterates every question in the answer key, compares it against the student's bubble, and accumulates:

- `correct` — exact match, `+marksPerCorrect`
- `incorrect` — wrong answer or INVALID (multi-filled), `-negativePerWrong`
- `unattempted` — null bubble, no marks change

The total is clamped at `0` (a score cannot go negative). `letterGrade(percentage)` returns A/B/C/D/F using a standard 80/70/60/50 cutoff.

### Step 8 — Grade Report View Widget
`lib/widgets/grade_report_view.dart` renders the grading result inside the scanner's bottom sheet: tick (green), cross (red), or dash (grey) for each question, plus the final score, percentage, and grade chip.

### Step 9 — Full Single-Sheet Flow (Scanner + OMR + Grading)
The scanner screen ties everything together. When it detects a QR that contains `"Part-I:"` and `"Part-II:"`, it:

1. Parses the `AnswerKey` from the QR payload
2. Prompts the user to upload the student's physical answer sheet (camera or gallery)
3. Shows a loading spinner while Gemini reads the sheet
4. Receives name, reg number, and all 16 bubble answers from the single Gemini call
5. Runs `grade_quiz` locally
6. Displays the full result — student info card + answer key + grade report — in a draggable bottom sheet
7. Persists the record to scan history

### Step 10 — Batch Grading Screen
`lib/screens/batch_screen.dart` and `lib/services/batch_grading_service.dart` extend the single-sheet pipeline to whole classes. The teacher selects multiple sheet images at once. The service processes them sequentially (to avoid hitting Gemini rate limits), calling `onProgress` after each sheet so the UI shows a live counter. After processing it displays:

- A class summary card: sheets graded, failed, average marks, average %, highest, lowest
- A result tile per student with their grade badge and score
- An **Export CSV** button that builds a full spreadsheet (one row per student, 16 answer columns, score columns, plus a summary block at the bottom) and shares it via the system share sheet

### Step 11 — Dashboard Screen
`lib/screens/dashboard_screen.dart` is the home screen. It shows a gradient VisionQR banner and a 2-column grid of six cards, each navigating to one of the main features. All navigation callbacks are passed in from the parent `HomeScreen` widget so the dashboard itself stays stateless.

---

## How Each Feature Works

### Live Scanner
- Uses `MobileScannerController` to stream camera frames
- `onDetect` callback fires when a barcode is found
- Payload is passed to `_processScannedPayload` which branches on type (URL, Wi-Fi, contact, barcode, or answer-key QR)
- Flash and AR overlay can be toggled mid-scan

### Get Media (Gallery Scan)
- Calls `ImagePicker.pickImage(source: ImageSource.gallery)`
- Passes the file path to `MobileScannerController.analyzeImage` for QR/barcode decoding without the live camera
- Falls back to the same `_processScannedPayload` pipeline

### Create Code (QR Generator)
- Takes any text input and renders a `QrImageView` in real time
- `QrVersions.auto` chooses the smallest QR version that fits the data
- The "Save" button triggers a snackbar (gallery save hook is wired but the actual `gal` save call can be invoked here)

### Scan Log Hub (History)
- All scans — QR codes, URLs, answer keys — are stored locally in `SharedPreferences` as JSON
- The history screen loads them on `initState` and renders a filterable list
- Tapping any entry re-opens its detail bottom sheet; answer-key entries reconstruct the full `AnswerKey` object from the stored raw payload

### OMR Demo (Single Sheet)
- `lib/screens/bubble_sheet_demo.dart` provides a standalone screen to test the Gemini OMR pipeline on a single image without needing to scan an answer-key QR first
- Useful for verifying Gemini's bubble-reading accuracy on new sheet designs

### Batch Grading
- Teacher picks N images via `ImagePicker.pickMultiImage`
- `BatchGradingService.processAll` iterates each image:
  1. Decodes the answer-key QR embedded in the sheet image using `MobileScannerController.analyzeImage`
  2. Sends the image to Gemini for OCR + OMR
  3. Grades locally with `grade_quiz`
- Progress updates are shown live
- Results render in a scrollable list; export builds a CSV with `share_plus`

---

## AI's Role in Development

Claude Code (the AI that helped build this) was used to:

- Design the QR payload format for answer keys (pipe-delimited, human-readable, parseable)
- Write the Gemini prompt engineering — the multi-task prompt that reads header fields, handwriting, AND bubbles in one API call, with precise rules about what counts as "filled" vs "empty"
- Implement the grading logic with negative marking and INVALID handling
- Wire up the full scanner → OMR → grade → history pipeline
- Build the batch processing service and CSV export
- Design the dark UI theme (slate `#1E293B` cards, gradient blue banner, Space Grotesk font)
- Debug issues like Gemini retiring the `gemini-2.0-flash` model (migrated to `gemini-2.5-flash`)

---

## File Map

```
lib/
  models/
    answer_key.dart        — Parses QR payload into quiz title + answer maps
    grade_report.dart      — GradeReport, QuestionResult, letterGrade(), fmtNum()
    scanned_code.dart      — Model for one scan history entry
    student_answers.dart   — Thin wrapper around part1/part2 maps

  services/
    gemini_omr_service.dart  — Gemini API call: reads header + handwriting + bubbles
    omr_service.dart         — Thin facade over GeminiOmrService
    quiz_grader.dart         — grade_quiz() pure function
    batch_grading_service.dart — Batch pipeline + CSV builder
    history_database.dart    — SharedPreferences JSON persistence

  screens/
    dashboard_screen.dart    — Home 6-card grid
    scanner_screen.dart      — Live camera + gallery QR scanner + OMR flow
    generator_screen.dart    — QR code creator
    history_screen.dart      — Scan log list + detail sheets
    batch_screen.dart        — Batch grading UI
    bubble_sheet_demo.dart   — Standalone single-sheet OMR tester

  widgets/
    grade_report_view.dart   — Renders a GradeReport as tick/cross/dash table
```
