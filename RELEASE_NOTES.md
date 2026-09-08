# Release notes — 3.2.2 (build 33)

Covers **3.2.1 and 3.2.2 together**. 3.2.1 did reach the App Store, but the two
went out close enough together that the trial and Display work is still new to
most users, and repeating it costs nothing.

**Play Console caps release notes at 500 characters per language.** Every block
is under it — French is the longest at 498, so trim before adding anything.
Counts are tabulated at the end.

**Locale tags** are Play's codes, not the app's. Swap `es-ES` for `es-419` if
most of your Spanish users are in Latin America; the copy works for both.

**Persian ships to Play only.** App Store Connect does not offer Persian as a
store localization at all, so the App Store section below has eight languages
where Play has nine. The app itself is still translated into Persian.

---

## What shipped since 3.1.0

New:

- The subscription screen shows your free trial, on both stores, and only when
  you are actually eligible for one
- A Display screen under Settings → Appearance: smooth motion, plus the refresh
  rate really in use and why it is being held down

Fixed:

- Delete Account ran to completion on the server but the client swapped the UI
  mid-flow, so no toast fired and the user was stranded on a signed-in screen
- SQLite foreign keys were never enforced, so every declared cascade was
  decorative and orphan rows accumulated; schema v11 turns enforcement on,
  rebuilds three tables and purges what had built up
- Two editor crashes (typing, and selecting text), purchases silently not
  completing after the paywall was closed once, and crashes on a duplicate
  folder name, some popup menus, and the upgrade sheet

---

## Paste this into Play Console

```text
<en-US>
Your free trial, now visible.

• The subscription screen shows your free trial when you're eligible
• New Display settings: smooth motion and the refresh rate in use

Fixed:
• Delete Account now finishes and tells you the result
• Deleting a note or folder now clears everything attached to it
• Crashes while typing or selecting text in a note
• Purchases not completing after closing the subscription screen
• Crashes on a duplicate folder name or when opening some menus
</en-US>

<es-ES>
Tu prueba gratuita, ahora visible.

• La pantalla de suscripción muestra tu prueba gratuita si puedes usarla
• Nuevos ajustes de Pantalla: movimiento fluido y la frecuencia real

Corregido:
• Eliminar cuenta ahora termina y te informa del resultado
• Al borrar una nota o carpeta se elimina todo lo asociado
• Cierres al escribir o seleccionar texto en una nota
• Compras sin completar tras cerrar la pantalla de suscripción
• Cierres por nombre de carpeta repetido o al abrir algunos menús
</es-ES>

<pt-BR>
Seu teste gratuito, agora visível.

• A tela de assinatura mostra seu teste gratuito quando você tem direito
• Novos ajustes de Tela: movimento suave e a taxa de atualização em uso

Corrigido:
• Excluir conta agora conclui e informa o resultado
• Excluir uma nota ou pasta remove tudo o que estava ligado a ela
• Falhas ao digitar ou selecionar texto em uma nota
• Compras não concluídas depois de fechar a tela de assinatura
• Falhas com nome de pasta repetido ou ao abrir alguns menus
</pt-BR>

<it-IT>
La tua prova gratuita, ora visibile.

• La schermata di abbonamento mostra la prova gratuita se ne hai diritto
• Nuove impostazioni Schermo: movimento fluido e frequenza in uso

Risolto:
• Elimina account ora si completa e comunica l'esito
• Eliminare una nota o cartella rimuove tutto ciò che vi è collegato
• Arresti durante la scrittura o la selezione del testo
• Acquisti non completati dopo aver chiuso la schermata
• Arresti con un nome di cartella già esistente o aprendo alcuni menu
</it-IT>

<fr-FR>
Votre essai gratuit, enfin visible.

• L'écran d'abonnement affiche votre essai gratuit si vous y avez droit
• Nouveaux réglages Affichage : mouvement fluide et fréquence utilisée

Corrigé :
• Supprimer le compte va au bout et vous indique le résultat
• Supprimer une note ou un dossier efface tout ce qui y est rattaché
• Plantages lors de la saisie ou de la sélection de texte
• Achats non finalisés après la fermeture de l'écran
• Plantages avec un nom de dossier déjà pris ou en ouvrant un menu
</fr-FR>

<th>
ทดลองใช้ฟรีของคุณ แสดงให้เห็นแล้ว

• หน้าจอการสมัครสมาชิกแสดงช่วงทดลองใช้ฟรีเมื่อคุณมีสิทธิ์
• การตั้งค่าการแสดงผลใหม่ การเคลื่อนไหวลื่นไหลและอัตรารีเฟรชที่ใช้จริง

แก้ไขแล้ว:
• ลบบัญชีทำงานจนเสร็จและแจ้งผลให้ทราบ
• ลบโน้ตหรือโฟลเดอร์จะลบทุกอย่างที่เกี่ยวข้องด้วย
• แอปปิดตัวขณะพิมพ์หรือเลือกข้อความในโน้ต
• การซื้อไม่สำเร็จหลังจากปิดหน้าจอการสมัครสมาชิก
• แอปปิดตัวเมื่อชื่อโฟลเดอร์ซ้ำหรือเปิดบางเมนู
</th>

<bn-BD>
আপনার ফ্রি ট্রায়াল, এখন দৃশ্যমান।

• সাবস্ক্রিপশন স্ক্রিনে আপনার ফ্রি ট্রায়াল দেখা যাবে, যদি আপনি যোগ্য হন
• নতুন ডিসপ্লে সেটিংস: স্মুথ মোশন এবং ব্যবহৃত রিফ্রেশ রেট

সংশোধন:
• অ্যাকাউন্ট মুছে ফেলা এখন সম্পূর্ণ হয় এবং ফলাফল জানায়
• নোট বা ফোল্ডার মুছলে তার সঙ্গে যুক্ত সবকিছু মুছে যায়
• নোটে টাইপ বা টেক্সট নির্বাচনের সময় ক্র্যাশ
• সাবস্ক্রিপশন স্ক্রিন বন্ধ করার পর কেনাকাটা সম্পূর্ণ না হওয়া
• ফোল্ডারের নাম আগে থেকেই থাকলে বা মেনু খুললে ক্র্যাশ
</bn-BD>

<ar>
‏تجربتك المجانية، ظاهرة الآن.

• شاشة الاشتراك تعرض تجربتك المجانية إذا كنت مؤهلاً لها
• إعدادات عرض جديدة: الحركة السلسة ومعدل التحديث المستخدم

تم الإصلاح:
• حذف الحساب يكتمل الآن ويخبرك بالنتيجة
• حذف ملاحظة أو مجلد يزيل كل ما هو مرتبط بها
• أعطال أثناء الكتابة أو تحديد النص في ملاحظة
• عمليات شراء لا تكتمل بعد إغلاق شاشة الاشتراك
• أعطال عند تكرار اسم مجلد أو عند فتح بعض القوائم
</ar>

<fa>
‏دورهٔ آزمایشی رایگان شما، اکنون قابل مشاهده است.

• صفحهٔ اشتراک دورهٔ آزمایشی رایگان شما را نشان می‌دهد
• تنظیمات نمایش جدید: حرکت روان و نرخ نوسازی در حال استفاده

رفع اشکال:
• حذف حساب اکنون کامل می‌شود و نتیجه را اعلام می‌کند
• حذف یادداشت یا پوشه هر چیز وابسته به آن را نیز حذف می‌کند
• خرابی هنگام تایپ یا انتخاب متن در یادداشت
• تکمیل‌نشدن خریدها پس از بستن صفحهٔ اشتراک
• خرابی هنگام تکراری بودن نام پوشه یا باز کردن منوها
</fa>
```

---

## App Store Connect — one field per language

Already entered for 3.2.2 in App Store Connect across all eight localizations.
Kept here as the source of truth, and because Play needs the same strings.

### English  (en-US)

```text
Your free trial, now visible.

• The subscription screen shows your free trial when you're eligible
• New Display settings: smooth motion and the refresh rate in use

Fixed:
• Delete Account now finishes and tells you the result
• Deleting a note or folder now clears everything attached to it
• Crashes while typing or selecting text in a note
• Purchases not completing after closing the subscription screen
• Crashes on a duplicate folder name or when opening some menus
```

### Spanish  (es-ES)

```text
Tu prueba gratuita, ahora visible.

• La pantalla de suscripción muestra tu prueba gratuita si puedes usarla
• Nuevos ajustes de Pantalla: movimiento fluido y la frecuencia real

Corregido:
• Eliminar cuenta ahora termina y te informa del resultado
• Al borrar una nota o carpeta se elimina todo lo asociado
• Cierres al escribir o seleccionar texto en una nota
• Compras sin completar tras cerrar la pantalla de suscripción
• Cierres por nombre de carpeta repetido o al abrir algunos menús
```

### Portuguese (Brazil)  (pt-BR)

```text
Seu teste gratuito, agora visível.

• A tela de assinatura mostra seu teste gratuito quando você tem direito
• Novos ajustes de Tela: movimento suave e a taxa de atualização em uso

Corrigido:
• Excluir conta agora conclui e informa o resultado
• Excluir uma nota ou pasta remove tudo o que estava ligado a ela
• Falhas ao digitar ou selecionar texto em uma nota
• Compras não concluídas depois de fechar a tela de assinatura
• Falhas com nome de pasta repetido ou ao abrir alguns menus
```

### Italian  (it-IT)

```text
La tua prova gratuita, ora visibile.

• La schermata di abbonamento mostra la prova gratuita se ne hai diritto
• Nuove impostazioni Schermo: movimento fluido e frequenza in uso

Risolto:
• Elimina account ora si completa e comunica l'esito
• Eliminare una nota o cartella rimuove tutto ciò che vi è collegato
• Arresti durante la scrittura o la selezione del testo
• Acquisti non completati dopo aver chiuso la schermata
• Arresti con un nome di cartella già esistente o aprendo alcuni menu
```

### French  (fr-FR)

```text
Votre essai gratuit, enfin visible.

• L'écran d'abonnement affiche votre essai gratuit si vous y avez droit
• Nouveaux réglages Affichage : mouvement fluide et fréquence utilisée

Corrigé :
• Supprimer le compte va au bout et vous indique le résultat
• Supprimer une note ou un dossier efface tout ce qui y est rattaché
• Plantages lors de la saisie ou de la sélection de texte
• Achats non finalisés après la fermeture de l'écran
• Plantages avec un nom de dossier déjà pris ou en ouvrant un menu
```

### Thai  (th)

```text
ทดลองใช้ฟรีของคุณ แสดงให้เห็นแล้ว

• หน้าจอการสมัครสมาชิกแสดงช่วงทดลองใช้ฟรีเมื่อคุณมีสิทธิ์
• การตั้งค่าการแสดงผลใหม่ การเคลื่อนไหวลื่นไหลและอัตรารีเฟรชที่ใช้จริง

แก้ไขแล้ว:
• ลบบัญชีทำงานจนเสร็จและแจ้งผลให้ทราบ
• ลบโน้ตหรือโฟลเดอร์จะลบทุกอย่างที่เกี่ยวข้องด้วย
• แอปปิดตัวขณะพิมพ์หรือเลือกข้อความในโน้ต
• การซื้อไม่สำเร็จหลังจากปิดหน้าจอการสมัครสมาชิก
• แอปปิดตัวเมื่อชื่อโฟลเดอร์ซ้ำหรือเปิดบางเมนู
```

### Bengali  (bn-BD)

```text
আপনার ফ্রি ট্রায়াল, এখন দৃশ্যমান।

• সাবস্ক্রিপশন স্ক্রিনে আপনার ফ্রি ট্রায়াল দেখা যাবে, যদি আপনি যোগ্য হন
• নতুন ডিসপ্লে সেটিংস: স্মুথ মোশন এবং ব্যবহৃত রিফ্রেশ রেট

সংশোধন:
• অ্যাকাউন্ট মুছে ফেলা এখন সম্পূর্ণ হয় এবং ফলাফল জানায়
• নোট বা ফোল্ডার মুছলে তার সঙ্গে যুক্ত সবকিছু মুছে যায়
• নোটে টাইপ বা টেক্সট নির্বাচনের সময় ক্র্যাশ
• সাবস্ক্রিপশন স্ক্রিন বন্ধ করার পর কেনাকাটা সম্পূর্ণ না হওয়া
• ফোল্ডারের নাম আগে থেকেই থাকলে বা মেনু খুললে ক্র্যাশ
```

### Arabic  (ar)

```text
‏تجربتك المجانية، ظاهرة الآن.

• شاشة الاشتراك تعرض تجربتك المجانية إذا كنت مؤهلاً لها
• إعدادات عرض جديدة: الحركة السلسة ومعدل التحديث المستخدم

تم الإصلاح:
• حذف الحساب يكتمل الآن ويخبرك بالنتيجة
• حذف ملاحظة أو مجلد يزيل كل ما هو مرتبط بها
• أعطال أثناء الكتابة أو تحديد النص في ملاحظة
• عمليات شراء لا تكتمل بعد إغلاق شاشة الاشتراك
• أعطال عند تكرار اسم مجلد أو عند فتح بعض القوائم
```

---

## Character counts

| Locale | Characters (limit 500) |
| --- | --- |
| `en-US` | 473 |
| `es-ES` | 490 |
| `pt-BR` | 486 |
| `it-IT` | 490 |
| `fr-FR` | 498 |
| `th` | 401 |
| `bn-BD` | 451 |
| `ar` | 385 |
| `fa` | 431 |

---

## Notes on the translations

- **No numerals appear in this copy**, so the native-digit convention (৯ / ٩ /
  ۹) does not arise.
- **RTL blocks** open with U+200F. Invisible but load bearing: it stops Play's
  preview flipping paragraph direction on a line starting with punctuation.
  Preserve it when copying.
- **The trial line never names a length.** Play offers 3 days monthly and 7
  yearly, the App Store offer is configured separately, and eligibility is per
  user — so a specific number would be wrong for someone.
- **"Delete Account" and "Display"** are translated rather than left in English,
  matching the in-app labels a user will actually find in Settings.
