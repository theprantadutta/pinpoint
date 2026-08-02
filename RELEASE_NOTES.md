# Release notes — 3.0.0 (build 29)

Paste the block below straight into the Play Console release-notes field. It
accepts every language in one paste as long as each is wrapped in its own
locale tag.

**Play Console caps release notes at 500 characters per language.** Every block
below is comfortably under that — the English copy is kept short on purpose,
because the Romance-language translations run roughly 20% longer and still have
to fit. Re-check the counts if you edit anything.

**Locale tags** are Play's codes, not the app's. The app ships `es`, `bn` and
`fa`; Play wants `es-ES`, `bn-BD` and `fa`. If most of your Spanish users are in
Latin America, swap `es-ES` for `es-419` — the copy itself works for both.

**"Pinpoint" is a brand name and is left untranslated in every locale**,
including Arabic and Persian, where it stays in Latin script.

---

## What shipped in this release

- Nine languages, with full right-to-left layouts for Arabic and Persian
- An in-app language picker, defaulting to the device language
- Dates, numbers and push notifications now follow the chosen language
- Two-pane tablet layout — note list and editor side by side
- Premium unlocks immediately after purchase
- Walkthrough and onboarding now follow the app's accent colour

---

## Paste this into Play Console

```text
<en-US>
Pinpoint now speaks your language.

• 9 languages, including Arabic and Persian with full right-to-left layouts
• Choose your language in Settings, or follow your device
• Dates and notifications now match your language

Also new:
• Tablet layout with your notes and the editor side by side
• Premium unlocks the moment you buy
• Polish and stability fixes
</en-US>

<es-ES>
Pinpoint ya habla tu idioma.

• 9 idiomas, incluidos árabe y persa con diseño completo de derecha a izquierda
• Elige tu idioma en Ajustes o sigue el de tu dispositivo
• Las fechas y las notificaciones ahora coinciden con tu idioma

Además:
• Diseño para tablet con tus notas y el editor en paralelo
• Premium se activa en cuanto compras
• Mejoras de estabilidad y acabado
</es-ES>

<pt-BR>
O Pinpoint agora fala o seu idioma.

• 9 idiomas, incluindo árabe e persa com layout completo da direita para a esquerda
• Escolha o idioma em Configurações ou siga o do aparelho
• Datas e notificações agora seguem o seu idioma

Também novo:
• Layout para tablet com suas notas e o editor lado a lado
• O Premium é liberado assim que você compra
• Melhorias de estabilidade e acabamento
</pt-BR>

<it-IT>
Pinpoint ora parla la tua lingua.

• 9 lingue, tra cui arabo e persiano con layout completo da destra a sinistra
• Scegli la lingua in Impostazioni o segui quella del dispositivo
• Date e notifiche ora seguono la tua lingua

Inoltre:
• Layout per tablet con le tue note e l'editor affiancati
• Premium si attiva subito dopo l'acquisto
• Correzioni di stabilità e rifiniture
</it-IT>

<fr-FR>
Pinpoint parle désormais votre langue.

• 9 langues, dont l'arabe et le persan avec une mise en page de droite à gauche
• Choisissez votre langue dans les Paramètres ou suivez celle de l'appareil
• Les dates et les notifications suivent votre langue

Également :
• Mise en page tablette avec vos notes et l'éditeur côte à côte
• Premium débloqué dès l'achat
• Corrections de stabilité et finitions
</fr-FR>

<th>
Pinpoint พูดภาษาของคุณแล้ว

• 9 ภาษา รวมถึงอาหรับและเปอร์เซียพร้อมเลย์เอาต์ขวาไปซ้ายเต็มรูปแบบ
• เลือกภาษาได้ในการตั้งค่า หรือใช้ตามอุปกรณ์
• วันที่และการแจ้งเตือนตรงกับภาษาของคุณแล้ว

ใหม่อีกด้วย:
• เลย์เอาต์แท็บเล็ตแสดงโน้ตและตัวแก้ไขคู่กัน
• ปลดล็อกพรีเมียมทันทีที่ซื้อ
• ปรับปรุงความเสถียรและรายละเอียด
</th>

<bn-BD>
Pinpoint এখন আপনার ভাষায় কথা বলে।

• ৯টি ভাষা, আরবি ও ফারসিসহ — সম্পূর্ণ ডান-থেকে-বাম লেআউট
• সেটিংসে ভাষা বেছে নিন, বা ডিভাইসের ভাষা অনুসরণ করুন
• তারিখ ও নোটিফিকেশন এখন আপনার ভাষায়

আরও নতুন:
• ট্যাবলেটে নোট ও এডিটর পাশাপাশি
• কেনার সঙ্গে সঙ্গেই প্রিমিয়াম চালু
• স্থিতিশীলতা ও পরিমার্জন
</bn-BD>

<ar>
‏Pinpoint يتحدث لغتك الآن.

• ٩ لغات، منها العربية والفارسية بتخطيط كامل من اليمين إلى اليسار
• اختر لغتك من الإعدادات أو اتبع لغة جهازك
• التواريخ والإشعارات تطابق لغتك الآن

جديد أيضًا:
• تخطيط للأجهزة اللوحية يعرض ملاحظاتك والمحرر جنبًا إلى جنب
• تفعيل Premium فور الشراء
• تحسينات في الاستقرار والتفاصيل
</ar>

<fa>
‏Pinpoint اکنون به زبان شما صحبت می‌کند.

• ۹ زبان، از جمله عربی و فارسی با چیدمان کامل راست‌به‌چپ
• زبان را در تنظیمات انتخاب کنید یا از زبان دستگاه پیروی کنید
• تاریخ‌ها و اعلان‌ها اکنون با زبان شما هماهنگ‌اند

همچنین:
• چیدمان تبلت با نمایش هم‌زمان یادداشت‌ها و ویرایشگر
• فعال‌سازی Premium بلافاصله پس از خرید
• بهبود پایداری و جزئیات
</fa>
```

---

## Notes on the translations

- **Numerals.** Bengali, Arabic and Persian use their own digit forms (৯, ٩, ۹)
  rather than `9`, matching how the app itself renders numbers in those
  locales. The Latin `9` is kept in Thai, which uses Western digits normally.
- **RTL blocks** open with U+200F (right-to-left mark) so the Latin-script
  "Pinpoint" at the start of the line does not flip the paragraph direction in
  Play's preview.
- **"Premium"** is left as-is in Arabic and Persian because that is how the
  paywall labels it in-app; translating it here would not match what users see.
