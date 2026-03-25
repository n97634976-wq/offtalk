# Contributing to OffTalk

Thank you for your interest in contributing to OffTalk! This project is 100% open source
and entirely community-driven. All contributions are welcome.

## How to Contribute

1. **Fork** this repository.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/offtalk.git
   cd offtalk
   ```
3. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/my-awesome-feature
   ```
4. **Make your changes** and test them with:
   ```bash
   flutter pub get
   flutter analyze
   flutter test
   flutter build apk --release
   ```
5. **Commit** with a clear message:
   ```bash
   git add .
   git commit -m "feat: Added voice message support"
   ```
6. **Push** and open a Pull Request:
   ```bash
   git push origin feature/my-awesome-feature
   ```

## Code Style

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style).
- Run `flutter analyze` before submitting.
- Add comments explaining non-obvious logic.

## Reporting Bugs

Open a GitHub Issue with:
- Steps to reproduce
- Expected vs actual behavior
- Device model and Android version

## Feature Requests

Open an Issue with the tag `enhancement` and describe:
- What you want
- Why it's useful for offline/mesh communication
