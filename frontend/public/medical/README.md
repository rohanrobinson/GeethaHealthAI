# Bundled medical assets

This folder stores demo/reference medical images that ship with the frontend.

## Structure

- `healthcare/`: general healthcare imagery used in the app UI.
- `reports/`: sample medical report images and scans for demos.

## Rules

- Use lowercase kebab-case file names (example: `cbc-report-sample.png`).
- Only commit de-identified sample images.
- Do not store real patient data or sensitive documents here.

## Usage in frontend

Reference files by URL path from the site root:

- `/medical/healthcare/<file-name>`
- `/medical/reports/<file-name>`
