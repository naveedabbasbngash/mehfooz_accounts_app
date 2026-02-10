from pathlib import Path

out_path = Path('output/pdf/mehfooz_accounts_app_summary_one_page.pdf')
out_path.parent.mkdir(parents=True, exist_ok=True)

# Page size: US Letter (points)
W, H = 612, 792
margin_x = 48
start_y = H - 54
line_h = 15

lines = [
    ("Mehfooz Accounts App - One Page Repo Summary", 14),
    ("", 12),
    ("WHAT IT IS", 12),
    ("Mehfooz Accounts App is a Flutter app for account/ledger operations across company datasets.", 11),
    ("It combines local SQLite workflows, optional remote sync, and in-app PDF reporting.", 11),
    ("", 12),
    ("WHO IT IS FOR", 12),
    ("Primary persona in docs: Not found in repo.", 11),
    ("Inferred from screens and queries: accounting staff managing pending balances and cash books.", 11),
    ("", 12),
    ("WHAT IT DOES", 12),
    ("- Multi-step auth: email check, password login/set password, forgot password, saved account chooser.", 11),
    ("- Imports .sqlite/.db files (share intent, picker, iOS Open-In/iCloud) into app-managed storage.", 11),
    ("- Maintains per-user local databases and restores the active user DB on launch.", 11),
    ("- Home dashboard shows cash-in-hand, AccID=1 summary, and pending amounts by currency/company.", 11),
    ("- Transactions screen supports search, debit/credit/date filters, balance mode, and detail panels.", 11),
    ("- Generates report PDFs: balance, credit, debit, pending, ledger, and last-credit summary.", 11),
    ("- Optional sync pulls server batches, applies local upserts/deletes, then sends ack; supports auto-sync.", 11),
    ("", 12),
    ("HOW IT WORKS (REPO EVIDENCE)", 12),
    ("- UI: Flutter screens in lib/ui; state managed with Provider + ChangeNotifier viewmodels.", 11),
    ("- Data layer: repositories run Drift SQL over Acc_Personal, Transactions_P, AccType, Company, Db_Info.", 11),
    ("- Local persistence: DatabaseManager activates per-user SQLite files under app documents.", 11),
    ("- Integrations: AuthService and SyncService call HTTPS endpoints at kheloaurjeeto.net.", 11),
    ("- Flow: login/restore DB -> viewmodels watch repository streams -> UI updates; import/sync mutate DB.", 11),
    ("", 12),
    ("HOW TO RUN (MINIMAL)", 12),
    ("1) Install Flutter SDK (repo pubspec requires Dart SDK ^3.10.0) and platform toolchains.", 11),
    ("2) From repo root: flutter pub get", 11),
    ("3) Start app: flutter run", 11),
    ("4) Environment variable setup instructions: Not found in repo.", 11),
    ("5) Full backend/local server setup guide: Not found in repo.", 11),
]

# Build text operations
text_ops = []
y = start_y
for text, size in lines:
    if y < 48:
        raise SystemExit('Content overflowed page; reduce lines.')
    # Escape PDF text chars
    escaped = text.replace('\\', '\\\\').replace('(', '\\(').replace(')', '\\)')
    text_ops.append(f"BT /F1 {size} Tf 1 0 0 1 {margin_x} {y:.2f} Tm ({escaped}) Tj ET")
    y -= line_h

stream = "\n".join(text_ops).encode('latin-1', errors='replace')

objects = []

def add_obj(content: bytes):
    objects.append(content)

# 1 Catalog
add_obj(b"<< /Type /Catalog /Pages 2 0 R >>")
# 2 Pages
add_obj(b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>")
# 3 Page
add_obj(b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>")
# 4 Font
add_obj(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
# 5 Contents
add_obj(b"<< /Length " + str(len(stream)).encode('ascii') + b" >>\nstream\n" + stream + b"\nendstream")

# Write PDF with xref
pdf = bytearray()
pdf.extend(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n")
offsets = [0]
for i, obj in enumerate(objects, start=1):
    offsets.append(len(pdf))
    pdf.extend(f"{i} 0 obj\n".encode('ascii'))
    pdf.extend(obj)
    pdf.extend(b"\nendobj\n")

xref_start = len(pdf)
pdf.extend(f"xref\n0 {len(objects)+1}\n".encode('ascii'))
pdf.extend(b"0000000000 65535 f \n")
for off in offsets[1:]:
    pdf.extend(f"{off:010d} 00000 n \n".encode('ascii'))

pdf.extend(
    b"trailer\n<< /Size " + str(len(objects)+1).encode('ascii') + b" /Root 1 0 R >>\n"
)
pdf.extend(b"startxref\n" + str(xref_start).encode('ascii') + b"\n%%EOF\n")

out_path.write_bytes(pdf)
print(out_path)
