p = r"C:\Users\Admin\Desktop\APss\cyber\threatguard\test\widget_test.dart"
with open(p, "rb") as f:
    raw = f.read()

old = (
    b"    expect(find.text('Your messages stay on your device'), findsOneWidget);\r\n"
    b"\r\n"
    b"    // Detection sensitivity lives on the Shield tab, where the thresholds it\r\n"
    b"    // changes are displayed beside it. Settings must link there rather than\r\n"
    b"    // carry a second, divergent control.\r\n"
    b"    expect(find.text('Detection sensitivity'), findsOneWidget);"
)
new = (
    b"    expect(find.text('Your messages stay on your device'), findsOneWidget);\r\n"
    b"\r\n"
    b"    // Detection sensitivity lives on the Shield tab, where the thresholds it\r\n"
    b"    // changes are displayed beside it. Settings must link there rather than\r\n"
    b"    // carry a second, divergent control. The settings list grows as more\r\n"
    b"    // preferences are added, so scroll like a real user would.\r\n"
    b"    await tester.scrollUntilVisible(\r\n"
    b"      find.text('Detection sensitivity'),\r\n"
    b"      160,\r\n"
    b"      scrollable: find.byType(Scrollable).first,\r\n"
    b"    );\r\n"
    b"    await tester.pumpAndSettle();\r\n"
    b"    expect(find.text('Detection sensitivity'), findsOneWidget);"
)

n = raw.count(old)
print("matches:", n)
if n != 1:
    raise SystemExit("unexpected match count")
raw = raw.replace(old, new)
with open(p, "wb") as f:
    f.write(raw)
print("patched")
