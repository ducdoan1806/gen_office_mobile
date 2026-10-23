# Project workflow

- Develop and commit changes on `dev`; push development work to `origin/dev`.
- The current main/default branch is `codex/initial-import`. Keep it at the user-approved version.
- Do not merge, cherry-pick, or push development changes to the main/default branch unless the user explicitly approves that promotion in the conversation.
- A successful build or passing tests alone does not authorize promotion. The user decides when the development version meets their requirements.
- Device integration tests MUST use `flutter test ... --no-uninstall`. Flutter's default cleanup uninstalls the app and deletes its private data. Never uninstall or clear the user's app for testing; reinstall the normal APK with `adb install -r` after tests.
- If the main branch is renamed later, the same restriction applies to the renamed main/default branch.
