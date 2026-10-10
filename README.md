# KrishiMitra: AI crop health assistant for farmers

KrishiMitra helps farmers who do not know crop diseases. The farmer picks a
crop, takes a photo of one leaf, and the app says what the problem may be,
how bad it is, and what to do next, in simple English or Hindi.

## What makes it different

- **Two-AI check.** An offline TensorFlow Lite model runs on the phone. A cloud
  vision model (Google Gemini) looks at the same photo. The app shows whether
  the two AIs agree, and says "Not sure" instead of guessing.
- **Severity meter.** It estimates how much of the leaf is damaged (Trace, Mild,
  Moderate, Severe) and paints the damaged areas red on the photo. It runs on
  the phone with no internet.
- **Recovery tracker.** Saved reports show whether the damage is shrinking after
  treatment.
- **Works offline.** With no internet the app still gives a verdict and advice
  in English and Hindi.
- **All crops.** Offline AI for tomato, potato and bell pepper. Rice, wheat,
  maize, cotton, sugarcane and chickpea use a knowledge base plus the cloud AI.
- Shows the Kisan Call Centre toll-free number: 1800-180-1551.

## How it works

1. Pick the crop, add a leaf photo, and pick the symptom you see.
2. The offline model classifies the leaf. The severity meter measures damage.
3. The cloud AI names the condition and gives three simple steps.
4. If the cloud AI is not available, the app uses built-in offline guidance.

## Tech stack

Flutter (Dart), TensorFlow Lite (MobileNetV2) via tflite_flutter, Google Gemini
API, the image package for photo processing, shared_preferences for saved reports.

## Run it

1. Install Flutter and the Android SDK.
2. Get a free Gemini key at https://aistudio.google.com.
3. Copy lib/secrets.example.dart to lib/secrets.dart and paste your key in it.
4. Run: flutter pub get, then flutter run (or flutter build apk --release).

On Windows, the script SETUP.ps1 can do the setup and build for you.

## Limits (please read)

- Results are preliminary and must be confirmed by an agriculture officer.
- The offline model was trained on clean leaf photos and can be less accurate on
  field photos.
- The severity meter is a colour-based estimate. It works best with one leaf on
  a plain background.
- The cloud AI needs internet and a Gemini key.
- The app gives no pesticide names or doses.