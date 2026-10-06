# Release notes — What's new

**Play Console caps release notes at 500 characters per language.** Every block
is under it — counts are tabulated at the end. No version number appears in the
copy, by design: the store already shows it.

---

## What shipped

The headline is the Sketchbook redesign, which touches every screen. Alongside it:

New:

- Google Drive backups for every signed-in account, free and premium: every
  note, folder and voice recording, encrypted with the account key
- Voice recordings are queued and retried, so one made offline uploads later;
  recordings are kept out of the cache directory Android can clear
- PDF export flows over pages and keeps formatting; Markdown export is real
  Markdown
- Play in-app updates download in the background (flexible by default)
- A full-screen launch screen and a signing-out screen

Fixed:

- Deleted folders came back from the server on other devices
- Switching accounts without restarting read notes with the previous key
- A sync could skip notes for good, and device clocks decided what downloaded
- At the free cap, edits and deletions of synced notes stopped syncing

Deliberately not in the copy: the purchase and entitlement hardening from the
premium audit, the server-time sync change and the folder cap enforcement. They
matter, but none is something a user would recognise from a sentence.

---

## Paste this into Play Console

```text
<en-US>
A fresh new look, and backups in your own Google Drive.

• A brand-new design, in light and dark
• Back up everything to Google Drive, encrypted and free for everyone
• Voice notes recorded offline upload once you're back online
• Cleaner PDF and Markdown exports, even for long notes
• Updates download in the background while you keep writing

Fixed:
• Deleted folders no longer come back on your other devices
• Switching accounts now loads the right notes
</en-US>

<es-ES>
Un diseño totalmente nuevo y copias en tu propio Google Drive.

• Diseño renovado, en modo claro y oscuro
• Copia todo en Google Drive, cifrado y gratis para todos
• Las notas de voz grabadas sin conexión se suben al reconectarte
• Exportaciones a PDF y Markdown más limpias, incluso en notas largas
• Las actualizaciones se descargan mientras sigues escribiendo

Corregido:
• Las carpetas eliminadas ya no vuelven en otros dispositivos
• Al cambiar de cuenta se cargan las notas correctas
</es-ES>

<pt-BR>
Um visual totalmente novo e backups no seu próprio Google Drive.

• Design renovado, nos modos claro e escuro
• Faça backup de tudo no Google Drive, criptografado e grátis para todos
• Notas de voz gravadas offline são enviadas ao reconectar
• Exportações em PDF e Markdown mais limpas
• As atualizações são baixadas enquanto você continua escrevendo

Corrigido:
• Pastas excluídas não voltam mais em outros aparelhos
• Ao trocar de conta, as notas certas são carregadas
</pt-BR>

<it-IT>
Un aspetto tutto nuovo e backup nel tuo Google Drive.

• Design completamente rinnovato, in chiaro e scuro
• Backup di tutto su Google Drive, crittografato e gratis per tutti
• Le note vocali registrate offline si caricano appena torni online
• Esportazioni PDF e Markdown più pulite
• Gli aggiornamenti si scaricano mentre continui a scrivere

Corretto:
• Le cartelle eliminate non ricompaiono più sugli altri dispositivi
• Cambiando account vengono caricate le note giuste
</it-IT>

<fr-FR>
Un tout nouveau look et des sauvegardes dans votre Google Drive.

• Un design entièrement repensé, en clair et en sombre
• Sauvegardez tout sur Google Drive, chiffré et gratuit pour tous
• Les notes vocales enregistrées hors ligne s'envoient au retour du réseau
• Des exports PDF et Markdown plus propres
• Les mises à jour se téléchargent pendant que vous écrivez

Corrigé :
• Les dossiers supprimés ne reviennent plus sur vos autres appareils
• Changer de compte charge désormais les bonnes notes
</fr-FR>

<th>
โฉมใหม่ทั้งหมด พร้อมสำรองข้อมูลไว้ใน Google Drive ของคุณเอง

• ดีไซน์ใหม่ทั้งหมด ทั้งโหมดสว่างและมืด
• สำรองทุกอย่างไปยัง Google Drive แบบเข้ารหัส ใช้ได้ฟรีสำหรับทุกคน
• โน้ตเสียงที่บันทึกตอนออฟไลน์จะอัปโหลดเมื่อกลับมาออนไลน์
• ส่งออก PDF และ Markdown ได้เรียบร้อยขึ้น แม้โน้ตยาว
• อัปเดตดาวน์โหลดเบื้องหลังระหว่างที่คุณเขียนต่อ

แก้ไขแล้ว:
• โฟลเดอร์ที่ลบแล้วจะไม่กลับมาบนอุปกรณ์อื่นอีก
• การสลับบัญชีจะโหลดโน้ตที่ถูกต้อง
</th>

<bn-BD>
একদম নতুন চেহারা, আর আপনার নিজের Google Drive-এ ব্যাকআপ।

• সম্পূর্ণ নতুন ডিজাইন, লাইট ও ডার্ক মোডে
• সবকিছু Google Drive-এ ব্যাকআপ নিন, এনক্রিপ্টেড ও সবার জন্য ফ্রি
• অফলাইনে রেকর্ড করা ভয়েস নোট অনলাইনে ফিরলেই আপলোড হয়
• PDF ও Markdown এক্সপোর্ট আরও পরিচ্ছন্ন, লম্বা নোটেও
• লেখার সময়েই পেছনে আপডেট ডাউনলোড হয়

ঠিক করা হয়েছে:
• মুছে ফেলা ফোল্ডার আর অন্য ডিভাইসে ফিরে আসে না
• অ্যাকাউন্ট বদলালে এখন সঠিক নোট লোড হয়
</bn-BD>

<ar>
مظهر جديد كليًا، ونسخ احتياطية في Google Drive الخاص بك.

• تصميم جديد بالكامل، بالوضعين الفاتح والداكن
• انسخ كل شيء احتياطيًا إلى Google Drive، مشفّرًا ومجانًا للجميع
• تُرفع الملاحظات الصوتية المسجلة دون اتصال فور عودتك إلى الإنترنت
• تصدير أنظف إلى PDF وMarkdown، حتى للملاحظات الطويلة
• تُنزَّل التحديثات في الخلفية بينما تواصل الكتابة

تم الإصلاح:
• لم تعد المجلدات المحذوفة تعود على أجهزتك الأخرى
• تبديل الحساب يحمّل الآن الملاحظات الصحيحة
</ar>

<fa>
ظاهری کاملاً تازه، و پشتیبان در Google Drive خودتان.

• طراحی کاملاً نو، در حالت روشن و تیره
• از همه‌چیز در Google Drive پشتیبان بگیرید، رمزگذاری‌شده و رایگان برای همه
• یادداشت‌های صوتی ضبط‌شده در حالت آفلاین با آنلاین شدن بارگذاری می‌شوند
• خروجی PDF و Markdown تمیزتر، حتی برای یادداشت‌های طولانی
• به‌روزرسانی‌ها در پس‌زمینه دانلود می‌شوند و شما به نوشتن ادامه می‌دهید

رفع شد:
• پوشه‌های حذف‌شده دیگر روی دستگاه‌های دیگرتان برنمی‌گردند
• تعویض حساب اکنون یادداشت‌های درست را بارگذاری می‌کند
</fa>
```

---

## Character counts

| Locale | Characters |
| --- | --- |
| `en-US` | 459 |
| `es-ES` | 489 |
| `pt-BR` | 470 |
| `it-IT` | 474 |
| `fr-FR` | 498 |
| `th` | 422 |
| `bn-BD` | 420 |
| `ar` | 447 |
| `fa` | 496 |

---

## Notes on the translations

- **No numerals appear in this copy**, so the native-digit convention (৯ / ٩ /
  ۹) does not arise.
- "Google Drive", "PDF" and "Markdown" are product and format names and stay
  untranslated in every locale.
- "Free for everyone" is accurate: Drive backup needs a signed-in account but
  no premium plan.
