# QuickStart - EmaxForge Test Suite

⚡ **Get testing in 5 minutes**

## 1. Enable Accessibility

```bash
# System Settings > Privacy & Security > Accessibility
# Add Terminal.app
```

## 2. Setup Tests

```bash
cd ~/clawd/EmaxForge/tests

# Apply patches
./apply-accessibility.sh

# Rebuild app
cd .. && ./build.sh
```

## 3. Run Tests

```bash
cd tests
./run-tests.sh
```

**Expected output:**
```
✅ PASS: Image list test (3s)
✅ PASS: Boot disk test (18s)

Total: 2 | Passed: 2 | Failed: 0
All tests passed! 🎉
```

## 4. Debug UI (Optional)

```bash
./quick-dump.sh
cat logs/ui-dump.txt
```

Shows all buttons, fields, and UI elements.

## Done! 🎉

**What you get:**
- Token-efficient automated testing (~500 tokens vs 5000+)
- Autonomous bug detection
- Regression prevention
- CI/CD ready

**Next steps:**
- Add more tests in `applescript/`
- Integrate with heartbeat for daily checks
- See `README.md` for full docs

---

**Problems?** Check `README.md` Troubleshooting section.
