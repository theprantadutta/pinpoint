# Release notes — 3.2.1 (build 32)

Covers **3.2.0 and 3.2.1 together**: the last version users actually received
was 3.1.0 (build 30), so everything both of those builds changed is new to them.

Paste the block below straight into the Play Console release-notes field. It
accepts every language in one paste as long as each is wrapped in its own
locale tag. The App Store has no equivalent — its "What's New" is one field per
language, so those are listed separately further down.

**Play Console caps release notes at 500 characters per language.** Every block
is under it; the English copy is kept short on purpose because the Romance
translations run roughly 20% longer and still have to fit. Current counts are
tabulated at the end — re-check them if you edit anything.

**Locale tags** are Play's codes, not the app's. The app ships `es`, `bn` and
`fa`; Play wants `es-ES`, `bn-BD` and `fa`. If most of your Spanish users are in
Latin America, swap `es-ES` for `es-419` — the copy itself works for both.

**"Pinpoint" is a brand name and is left untranslated in every locale**,
including Arabic and Persian, where it stays in Latin script. It does not appear
in this release's copy, which opens on the trial instead.

---

## What shipped since 3.1.0

New:

- The subscription screen now shows your free trial, on both stores, and only
  when you are actually eligible for one
- A Display screen under Settings → Appearance: turn on smooth motion and see
  the refresh rate really in use, plus why it is being held down

Fixed:

- Two editor crashes — one on typing, one on selecting text
- Purchases silently never completing once the subscription screen had been
  closed, which on Play auto-refunded after about three days
- Crashes on a duplicate folder name, on opening some popup menus, and on
  dismissing the upgrade sheet

---

## Paste this into Play Console

```text
<en-US>
Your free trial, now visible.

• The subscription screen shows your free trial when you're eligible
• New Display settings: smooth motion, plus the refresh rate actually in use

Fixed:
• Crashes while typing or selecting text in a note
• Purchases not completing after you had closed the subscription screen
• Crashes when a folder name was already taken, or when opening some menus
</en-US>

<es-ES>
Tu prueba gratuita, ahora visible.

• La pantalla de suscripción muestra tu prueba gratuita si tienes derecho a ella
• Nuevos ajustes de Pantalla: movimiento fluido y la frecuencia real en uso

Corregido:
• Cierres al escribir o seleccionar texto en una nota
• Compras que no se completaban tras cerrar la pantalla de suscripción
• Cierres al repetir el nombre de una carpeta o al abrir algunos menús
</es-ES>

<pt-BR>
Seu teste gratuito, agora visível.

• A tela de assinatura mostra seu teste gratuito quando você tem direito a ele
• Novos ajustes de Tela: movimento suave e a taxa de atualização em uso

Corrigido:
• Falhas ao digitar ou selecionar texto em uma nota
• Compras que não se concluíam depois de fechar a tela de assinatura
• Falhas ao repetir o nome de uma pasta ou ao abrir alguns menus
</pt-BR>

<it-IT>
La tua prova gratuita, ora visibile.

• La schermata di abbonamento mostra la tua prova gratuita se ne hai diritto
• Nuove impostazioni Schermo: movimento fluido e frequenza di aggiornamento in uso

Risolto:
• Arresti durante la scrittura o la selezione del testo in una nota
• Acquisti non completati dopo aver chiuso la schermata di abbonamento
• Arresti con un nome di cartella già esistente o all'apertura di alcuni menu
</it-IT>

<fr-FR>
Votre essai gratuit, enfin visible.

• L'écran d'abonnement affiche votre essai gratuit si vous y avez droit
• Nouveaux réglages Affichage : mouvement fluide et fréquence réellement utilisée

Corrigé :
• Plantages lors de la saisie ou de la sélection de texte dans une note
• Achats non finalisés après la fermeture de l'écran d'abonnement
• Plantages avec un nom de dossier déjà pris ou à l'ouverture de certains menus
</fr-FR>

<th>
ทดลองใช้ฟรีของคุณ แสดงให้เห็นแล้ว

• หน้าจอการสมัครสมาชิกแสดงช่วงทดลองใช้ฟรีเมื่อคุณมีสิทธิ์
• การตั้งค่าการแสดงผลใหม่ เปิดการเคลื่อนไหวลื่นไหลและดูอัตรารีเฟรชที่ใช้จริง

แก้ไขแล้ว:
• แอปปิดตัวขณะพิมพ์หรือเลือกข้อความในโน้ต
• การซื้อไม่สำเร็จหลังจากปิดหน้าจอการสมัครสมาชิก
• แอปปิดตัวเมื่อชื่อโฟลเดอร์ซ้ำหรือเมื่อเปิดบางเมนู
</th>

<bn-BD>
আপনার ফ্রি ট্রায়াল, এখন দৃশ্যমান।

• সাবস্ক্রিপশন স্ক্রিনে আপনার ফ্রি ট্রায়াল দেখা যাবে, যদি আপনি যোগ্য হন
• নতুন ডিসপ্লে সেটিংস: স্মুথ মোশন চালু করুন এবং ব্যবহৃত রিফ্রেশ রেট দেখুন

সংশোধন:
• নোটে টাইপ বা টেক্সট নির্বাচন করার সময় ক্র্যাশ
• সাবস্ক্রিপশন স্ক্রিন বন্ধ করার পর কেনাকাটা সম্পূর্ণ না হওয়া
• ফোল্ডারের নাম আগে থেকেই থাকলে বা কিছু মেনু খুললে ক্র্যাশ
</bn-BD>

<ar>
‏تجربتك المجانية، ظاهرة الآن.

• شاشة الاشتراك تعرض تجربتك المجانية إذا كنت مؤهلاً لها
• إعدادات عرض جديدة: فعّل الحركة السلسة واطّلع على معدل التحديث المستخدم

تم الإصلاح:
• أعطال أثناء الكتابة أو تحديد النص في ملاحظة
• عمليات شراء لا تكتمل بعد إغلاق شاشة الاشتراك
• أعطال عند تكرار اسم مجلد أو عند فتح بعض القوائم
</ar>

<fa>
‏دورهٔ آزمایشی رایگان شما، اکنون قابل مشاهده است.

• صفحهٔ اشتراک دورهٔ آزمایشی رایگان شما را نشان می‌دهد، اگر واجد شرایط باشید
• تنظیمات نمایش جدید: حرکت روان و نرخ نوسازی در حال استفاده

رفع اشکال:
• خرابی هنگام تایپ یا انتخاب متن در یادداشت
• تکمیل‌نشدن خریدها پس از بستن صفحهٔ اشتراک
• خرابی هنگام تکراری بودن نام پوشه یا باز کردن برخی منوها
</fa>
```

---

## App Store Connect — one field per language

App Store Connect has a separate "What's New" box for each localisation, with a
4000-character limit, so these are the same strings without the locale tags. If
a language is left blank there, everyone sees the English text — which reads
oddly in an app that advertises nine languages.

### English  (en-US)

```text
Your free trial, now visible.

• The subscription screen shows your free trial when you're eligible
• New Display settings: smooth motion, plus the refresh rate actually in use

Fixed:
• Crashes while typing or selecting text in a note
• Purchases not completing after you had closed the subscription screen
• Crashes when a folder name was already taken, or when opening some menus
```

### Spanish  (es-ES)

```text
Tu prueba gratuita, ahora visible.

• La pantalla de suscripción muestra tu prueba gratuita si tienes derecho a ella
• Nuevos ajustes de Pantalla: movimiento fluido y la frecuencia real en uso

Corregido:
• Cierres al escribir o seleccionar texto en una nota
• Compras que no se completaban tras cerrar la pantalla de suscripción
• Cierres al repetir el nombre de una carpeta o al abrir algunos menús
```

### Portuguese (Brazil)  (pt-BR)

```text
Seu teste gratuito, agora visível.

• A tela de assinatura mostra seu teste gratuito quando você tem direito a ele
• Novos ajustes de Tela: movimento suave e a taxa de atualização em uso

Corrigido:
• Falhas ao digitar ou selecionar texto em uma nota
• Compras que não se concluíam depois de fechar a tela de assinatura
• Falhas ao repetir o nome de uma pasta ou ao abrir alguns menus
```

### Italian  (it-IT)

```text
La tua prova gratuita, ora visibile.

• La schermata di abbonamento mostra la tua prova gratuita se ne hai diritto
• Nuove impostazioni Schermo: movimento fluido e frequenza di aggiornamento in uso

Risolto:
• Arresti durante la scrittura o la selezione del testo in una nota
• Acquisti non completati dopo aver chiuso la schermata di abbonamento
• Arresti con un nome di cartella già esistente o all'apertura di alcuni menu
```

### French  (fr-FR)

```text
Votre essai gratuit, enfin visible.

• L'écran d'abonnement affiche votre essai gratuit si vous y avez droit
• Nouveaux réglages Affichage : mouvement fluide et fréquence réellement utilisée

Corrigé :
• Plantages lors de la saisie ou de la sélection de texte dans une note
• Achats non finalisés après la fermeture de l'écran d'abonnement
• Plantages avec un nom de dossier déjà pris ou à l'ouverture de certains menus
```

### Thai  (th)

```text
ทดลองใช้ฟรีของคุณ แสดงให้เห็นแล้ว

• หน้าจอการสมัครสมาชิกแสดงช่วงทดลองใช้ฟรีเมื่อคุณมีสิทธิ์
• การตั้งค่าการแสดงผลใหม่ เปิดการเคลื่อนไหวลื่นไหลและดูอัตรารีเฟรชที่ใช้จริง

แก้ไขแล้ว:
• แอปปิดตัวขณะพิมพ์หรือเลือกข้อความในโน้ต
• การซื้อไม่สำเร็จหลังจากปิดหน้าจอการสมัครสมาชิก
• แอปปิดตัวเมื่อชื่อโฟลเดอร์ซ้ำหรือเมื่อเปิดบางเมนู
```

### Bengali  (bn-BD)

```text
আপনার ফ্রি ট্রায়াল, এখন দৃশ্যমান।

• সাবস্ক্রিপশন স্ক্রিনে আপনার ফ্রি ট্রায়াল দেখা যাবে, যদি আপনি যোগ্য হন
• নতুন ডিসপ্লে সেটিংস: স্মুথ মোশন চালু করুন এবং ব্যবহৃত রিফ্রেশ রেট দেখুন

সংশোধন:
• নোটে টাইপ বা টেক্সট নির্বাচন করার সময় ক্র্যাশ
• সাবস্ক্রিপশন স্ক্রিন বন্ধ করার পর কেনাকাটা সম্পূর্ণ না হওয়া
• ফোল্ডারের নাম আগে থেকেই থাকলে বা কিছু মেনু খুললে ক্র্যাশ
```

### Arabic  (ar)

```text
‏تجربتك المجانية، ظاهرة الآن.

• شاشة الاشتراك تعرض تجربتك المجانية إذا كنت مؤهلاً لها
• إعدادات عرض جديدة: فعّل الحركة السلسة واطّلع على معدل التحديث المستخدم

تم الإصلاح:
• أعطال أثناء الكتابة أو تحديد النص في ملاحظة
• عمليات شراء لا تكتمل بعد إغلاق شاشة الاشتراك
• أعطال عند تكرار اسم مجلد أو عند فتح بعض القوائم
```

### Persian  (fa)

```text
‏دورهٔ آزمایشی رایگان شما، اکنون قابل مشاهده است.

• صفحهٔ اشتراک دورهٔ آزمایشی رایگان شما را نشان می‌دهد، اگر واجد شرایط باشید
• تنظیمات نمایش جدید: حرکت روان و نرخ نوسازی در حال استفاده

رفع اشکال:
• خرابی هنگام تایپ یا انتخاب متن در یادداشت
• تکمیل‌نشدن خریدها پس از بستن صفحهٔ اشتراک
• خرابی هنگام تکراری بودن نام پوشه یا باز کردن برخی منوها
```

---

## Character counts

| Locale | Characters (limit 500) |
| --- | --- |
| `en-US` | 382 |
| `es-ES` | 400 |
| `pt-BR` | 384 |
| `it-IT` | 424 |
| `fr-FR` | 419 |
| `th` | 324 |
| `bn-BD` | 362 |
| `ar` | 315 |
| `fa` | 345 |

---

## Notes on the translations

- **No numerals appear in this release's copy**, so the digit-form question that
  applied to 3.0.0 (৯ / ٩ / ۹ versus `9`) does not arise here.
- **RTL blocks** open with U+200F (right-to-left mark). It is invisible but load
  bearing: it keeps Play's preview from flipping paragraph direction on a line
  that starts with punctuation or Latin script. Preserve it when copying.
- **"Display" / "smooth motion"** are translated rather than kept in English,
  because the in-app settings screen is itself localised — the wording here
  matches the labels a user will find under Settings.
- **Store-specific wording is avoided.** The same sentence ships to Play and the
  App Store, so the trial line says "your free trial" rather than naming a
  length: Play offers 3 days monthly and 7 days yearly, the App Store offer is
  configured separately, and eligibility varies per user.
