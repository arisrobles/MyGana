# Tesseract OCR Japanese Language Data

This directory should contain the Japanese language trained data file for Tesseract OCR.

## Required File

Download the `jpn.traineddata` file from the official Tesseract repository:
https://github.com/tesseract-ocr/tessdata/raw/main/jpn.traineddata

## Instructions

1. Download the `jpn.traineddata` file from the link above
2. Place it in this directory (`assets/tessdata/jpn.traineddata`)
3. The file should be approximately 2.4 MB in size

## Alternative Download Methods

You can also download it using:

- wget: `wget https://github.com/tesseract-ocr/tessdata/raw/main/jpn.traineddata`
- curl: `curl -O https://github.com/tesseract-ocr/tessdata/raw/main/jpn.traineddata`

## Note

Without this file, Tesseract OCR will not be able to recognize Japanese characters properly.
The app will fall back to rule-based analysis if the OCR fails.
