# Release notes — 3.4.0 (build 35)

**Play Console caps release notes at 500 characters per language.** Every block
is under it — counts are tabulated at the end.

---

## What shipped since 3.2.2

The headline change is invisible: in-app purchases moved to Google Play Billing
9.1 and StoreKit 2, ahead of Google's cutoff for app updates. Nothing to
announce there — but the rewrite closed three gaps that users *can* feel, and
those are what the copy below covers.

New:

- A deferred payment — a slow card, a parental approval — now unlocks premium
  when it clears, instead of never
- A purchase that completed while the app was closed is picked up on the next
  open, rather than being lost until the next purchase attempt
- Restore Purchases reports what it actually found, instead of guessing after a
  fixed three-second wait

Fixed:

- Premium granted while the server could not reach the store could not be taken
  away again, so a cancellation or refund left it running until its invented
  expiry. Subscription state now follows the store.

Also in this build, and also invisible: R8 is switched back on (Play Console
flagged obfuscation at 2%, under its 25% threshold), and the system bars are
now transparent with insets handled, which Android 15 forces on any app
targeting SDK 35+. The second one is mildly visible — content runs under the
status and gesture bars instead of sitting inside a black band — but it is not
a feature anyone asked for, so it stays out of the copy.

3.3.0 was never uploaded; these notes carried over to 3.4.0 unchanged because
nothing user-facing was added in between.

Deliberately not in the copy: the billing-library migration itself, and the fact
that the entitlement fix *removes* access for anyone who was holding an
unrevokable grant. Neither is something to advertise.

---

## Paste this into Play Console

```text
<en-US>
Purchases that keep up with you.

• A payment waiting for approval unlocks as soon as it clears
• A purchase finished while the app was closed is picked up next time
• Restore Purchases now tells you exactly what it found

Fixed:
• Subscription status now follows the store, including when you cancel
</en-US>

<es-ES>
Compras que van a tu ritmo.

• Un pago pendiente de aprobación se activa en cuanto se confirma
• Una compra hecha con la app cerrada se recupera al volver a abrirla
• Restaurar compras ahora te dice exactamente qué ha encontrado

Corregido:
• El estado de tu suscripción sigue a la tienda, también al cancelar
</es-ES>

<pt-BR>
Compras que acompanham você.

• Um pagamento aguardando aprovação é liberado assim que é confirmado
• Uma compra feita com o app fechado é recuperada ao abri-lo de novo
• Restaurar compras agora informa exatamente o que encontrou

Corrigido:
• O status da assinatura segue a loja, inclusive quando você cancela
</pt-BR>

<it-IT>
Acquisti al tuo passo.

• Un pagamento in attesa di approvazione si attiva appena è confermato
• Un acquisto completato con l'app chiusa viene recuperato alla riapertura
• Ripristina acquisti ora indica esattamente cosa ha trovato

Corretto:
• Lo stato dell'abbonamento segue lo store, anche quando disdici
</it-IT>

<fr-FR>
Des achats qui vous suivent.

• Un paiement en attente de validation s'active dès qu'il est confirmé
• Un achat terminé app fermée est récupéré à la prochaine ouverture
• Restaurer les achats indique désormais ce qui a été trouvé

Corrigé :
• L'état de l'abonnement suit la boutique, y compris en cas de résiliation
</fr-FR>

<th>
การซื้อที่ตามทันคุณ

• การชำระเงินที่รออนุมัติจะปลดล็อกทันทีที่ได้รับการยืนยัน
• การซื้อที่เสร็จขณะปิดแอปจะถูกดึงกลับมาเมื่อเปิดแอปครั้งถัดไป
• กู้คืนการซื้อจะบอกคุณอย่างชัดเจนว่าพบอะไรบ้าง

แก้ไข:
• สถานะการสมัครสมาชิกเป็นไปตามสโตร์ รวมถึงเมื่อคุณยกเลิก
</th>

<bn-BD>
কেনাকাটা এবার আপনার সঙ্গে তাল মিলিয়ে।

• অনুমোদনের অপেক্ষায় থাকা পেমেন্ট নিশ্চিত হওয়ামাত্র চালু হবে
• অ্যাপ বন্ধ থাকা অবস্থায় সম্পন্ন কেনা পরেরবার খুললেই ফিরে পাবেন
• কেনাকাটা পুনরুদ্ধার এখন ঠিক কী পাওয়া গেছে তা জানাবে

সংশোধন:
• সাবস্ক্রিপশনের অবস্থা এখন স্টোর অনুসরণ করে, বাতিল করলেও
</bn-BD>

<ar>
‏عمليات شراء تواكبك.

• الدفعة التي تنتظر الموافقة تُفعَّل فور تأكيدها
• الشراء الذي اكتمل والتطبيق مغلق يُستعاد عند فتحه مرة أخرى
• استعادة المشتريات تخبرك الآن بما عُثر عليه بالضبط

تم الإصلاح:
• حالة الاشتراك تتبع المتجر، بما في ذلك عند الإلغاء
</ar>

<fa>
‏خریدهایی که همراه شما هستند.

• پرداختی که منتظر تأیید است، به‌محض تأیید فعال می‌شود
• خریدی که هنگام بسته بودن برنامه کامل شده، بار بعد بازیابی می‌شود
• بازیابی خریدها اکنون دقیقاً می‌گوید چه چیزی پیدا شده است

رفع اشکال:
• وضعیت اشتراک از فروشگاه پیروی می‌کند، از جمله هنگام لغو
</fa>
```

---

## Character counts

| Locale | Characters |
| --- | --- |
| `en-US` | 300 |
| `es-ES` | 309 |
| `pt-BR` | 310 |
| `it-IT` | 306 |
| `fr-FR` | 315 |
| `th` | 254 |
| `bn-BD` | 290 |
| `ar` | 247 |
| `fa` | 281 |

---

## Notes on the translations

- **No numerals appear in this copy**, so the native-digit convention (৯ / ٩ /
  ۹) does not arise. In particular no trial length is named: eligibility is per
  user, so any specific number would be wrong for someone.
- **RTL blocks** open with U+200F. Invisible but load bearing: it stops Play's
  preview flipping paragraph direction on a line starting with punctuation.
  Preserve it when copying.
- **"Restore Purchases"** is translated rather than left in English, matching
  the in-app button a user will actually find on the subscription screen.
- **"the store" is kept generic** rather than named as Google Play, because the
  same copy ships to users on both stores.
